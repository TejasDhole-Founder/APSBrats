import 'dart:async';

import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_socket.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = false,
    this.loadingOlder = false,
    this.hasMore = false,
    this.nextCursor,
    this.pendingIds = const {},
    this.error,
  });

  /// Oldest first, newest last -- matches how a chat screen scrolls.
  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final String? nextCursor;

  /// Ids of messages we've sent but haven't gotten the server's confirmed
  /// copy back for yet (optimistic send -- see ChatController.send).
  final Set<String> pendingIds;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    String? nextCursor,
    Set<String>? pendingIds,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      pendingIds: pendingIds ?? this.pendingIds,
      error: error,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this.conversationId, this._ref)
    : super(const ChatState());

  final ChatRepository _repo;
  final String conversationId;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.messages(conversationId);
      state = ChatState(
        messages: page.items,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
      unawaited(markRead());
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Could not load messages');
    }
  }

  Future<void> loadOlder() async {
    if (!state.hasMore || state.loadingOlder) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.messages(
        conversationId,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        messages: [...page.items, ...state.messages],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        loadingOlder: false,
      );
    } catch (_) {
      state = state.copyWith(loadingOlder: false);
    }
  }

  /// Adds the message to the list immediately (before the server has even
  /// seen it), then swaps in the server's real copy once it responds -- so
  /// sending feels instant instead of waiting on a round trip.
  /// Returns false if it failed, so the screen can put the text back.
  Future<bool> send(String body, {String? imageUrl}) async {
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: '',
      body: body,
      imageUrl: imageUrl,
      mine: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      pendingIds: {...state.pendingIds, tempId},
    );

    try {
      final saved = await _repo.send(conversationId, body, imageUrl: imageUrl);
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == tempId) saved else m,
        ],
        pendingIds: {...state.pendingIds}..remove(tempId),
      );
      _ref.invalidate(conversationsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id != tempId) m,
        ],
        pendingIds: {...state.pendingIds}..remove(tempId),
        // The server's reason when it gave one ("You can send photos once
        // you're connected").
        error: _serverMessage(e) ?? 'Message failed to send',
      );
      return false;
    }
  }

  static String? _serverMessage(Object e) {
    if (e is! DioException) return null;
    final payload = e.response?.data;
    final message = payload is Map<String, dynamic> ? payload['error'] : null;
    return message is String && message.isNotEmpty ? message : null;
  }

  /// Called by the WebSocket listener (Chapter 12) when a live push arrives
  /// for this conversation. Ignored here until then.
  void receive(ChatMessage message) {
    if (message.conversationId != conversationId) return;
    if (state.messages.any((m) => m.id == message.id)) return;
    state = state.copyWith(messages: [...state.messages, message]);
    markRead();
  }

  Future<void> markRead() async {
    try {
      await _repo.markRead(conversationId);
      _ref.invalidate(conversationsProvider);
    } catch (_) {
      // best-effort -- an unread badge staying stale for a moment is fine.
    }
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, String>((ref, conversationId) {
      final controller = ChatController(
        ref.watch(chatRepositoryProvider),
        conversationId,
        ref,
      );
      controller.load();

      // Live pushes for THIS conversation while its screen is open -- other
      // conversations' pushes are handled separately (see HomeScreen), since
      // this controller only exists while its own chat screen is on-screen.
      final subscription = ref
          .read(chatSocketProvider)
          .messages
          .listen(controller.receive);
      ref.onDispose(subscription.cancel);

      return controller;
    });
