import 'dart:async';
import 'dart:convert';

import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// One WebSocket connection for the whole app -- not one per chat screen.
/// Connect once (HomeScreen does this after login/on cold start), every open
/// chat screen and the conversations list just listen to [messages].
class ChatSocket {
  ChatSocket(this._storage, this._dio);

  final FlutterSecureStorage _storage;
  final Dio _dio;
  StompClient? _client;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _communityController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Every message pushed to this device, whichever conversation it belongs
  /// to -- listeners filter by `conversationId` themselves (see
  /// ChatController.receive).
  Stream<ChatMessage> get messages => _controller.stream;

  /// Community group-chat pushes (raw JSON; the community feature parses
  /// them and filters by `communityId`).
  Stream<Map<String, dynamic>> get communityMessages =>
      _communityController.stream;

  /// True while a started connection is down and the library is retrying;
  /// the app-wide banner shows "Reconnecting to chat…" from this.
  final reconnecting = ValueNotifier<bool>(false);

  void _dropped(String why) {
    if (_client == null) return;
    reconnecting.value = true;
    debugPrint('ChatSocket: $why');
  }

  /// Phones pause sockets in the background; on resume a dead one is
  /// replaced instead of waiting for the library's retry timer.
  void reconnectIfDropped() {
    final client = _client;
    if (client == null || client.connected) return;
    disconnect();
    connect();
  }

  Future<void> connect() async {
    if (_client?.isActive ?? false) return;
    final token = await _storage.read(key: kAccessTokenKey);
    if (token == null || token.isEmpty) return;

    // The access token lives 15 minutes, so each (re)connect first makes an
    // ordinary API call: the Dio interceptor refreshes an expired token, and
    // the headers below are then updated with the fresh one.
    final headers = {'Authorization': 'Bearer $token'};
    _client = StompClient(
      config: StompConfig(
        url: Env.wsUrl,
        stompConnectHeaders: headers,
        webSocketConnectHeaders: headers,
        beforeConnect: () async {
          try {
            await _dio.get<dynamic>(ApiEndpoints.usersMe);
          } catch (_) {
            // Offline: the library retries in a few seconds.
          }
          final fresh = await _storage.read(key: kAccessTokenKey);
          if (fresh != null && fresh.isNotEmpty) {
            headers['Authorization'] = 'Bearer $fresh';
          }
        },
        onConnect: _onConnect,
        onWebSocketError: (dynamic e) => _dropped('socket error: $e'),
        onWebSocketDone: () => _dropped('socket closed'),
        onStompError: (frame) => _dropped('STOMP error: ${frame.body}'),
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame _) {
    reconnecting.value = false;
    _client!.subscribe(
      destination: '/user/queue/messages',
      callback: (frame) {
        final body = frame.body;
        if (body == null) return;
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          _controller.add(ChatMessage.fromJson(json));
        } catch (_) {
          // Malformed push -- ignore rather than crash every listener.
        }
      },
    );
    _client!.subscribe(
      destination: '/user/queue/community',
      callback: (frame) {
        final body = frame.body;
        if (body == null) return;
        try {
          _communityController.add(jsonDecode(body) as Map<String, dynamic>);
        } catch (_) {}
      },
    );
  }

  void disconnect() {
    final client = _client;
    _client = null;
    reconnecting.value = false;
    client?.deactivate();
  }
}

final chatSocketProvider = Provider<ChatSocket>((ref) {
  final socket = ChatSocket(
    ref.watch(secureStorageProvider),
    ref.watch(dioProvider),
  );
  final lifecycle = AppLifecycleListener(onResume: socket.reconnectIfDropped);
  ref.onDispose(() {
    lifecycle.dispose();
    socket.disconnect();
  });
  return socket;
});
