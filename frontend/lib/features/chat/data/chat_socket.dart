import 'dart:async';
import 'dart:convert';

import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// One WebSocket connection for the whole app -- not one per chat screen.
/// Connect once (HomeScreen does this after login/on cold start), every open
/// chat screen and the conversations list just listen to [messages].
class ChatSocket {
  ChatSocket(this._storage);

  final FlutterSecureStorage _storage;
  StompClient? _client;
  final _controller = StreamController<ChatMessage>.broadcast();

  /// Every message pushed to this device, whichever conversation it belongs
  /// to -- listeners filter by `conversationId` themselves (see
  /// ChatController.receive).
  Stream<ChatMessage> get messages => _controller.stream;

  Future<void> connect() async {
    if (_client?.isActive ?? false) return;
    final token = await _storage.read(key: kAccessTokenKey);
    if (token == null || token.isEmpty) return;

    _client = StompClient(
      config: StompConfig(
        url: Env.wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: _onConnect,
        onWebSocketError: (dynamic _) {},
        onStompError: (_) {},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame _) {
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
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}

final chatSocketProvider = Provider<ChatSocket>((ref) {
  final socket = ChatSocket(ref.watch(secureStorageProvider));
  ref.onDispose(socket.disconnect);
  return socket;
});
