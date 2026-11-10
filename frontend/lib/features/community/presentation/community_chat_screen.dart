import 'dart:async';

import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_socket.dart';
import 'package:apsbrat_frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/communities_tab.dart';
import 'package:apsbrat_frontend/features/community/presentation/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Every live group-chat push to this device (any community).
final communityPushProvider = StreamProvider<CommunityMessage>(
  (ref) => ref
      .watch(chatSocketProvider)
      .communityMessages
      .map(CommunityMessage.fromJson),
);

class CommunityChatState {
  const CommunityChatState({
    this.messages = const [],
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = false,
    this.nextCursor,
    this.error,
  });

  /// Oldest first, newest last.
  final List<CommunityMessage> messages;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final String? nextCursor;
  final Object? error;

  CommunityChatState copyWith({
    List<CommunityMessage>? messages,
    bool? loadingOlder,
    bool? hasMore,
    String? nextCursor,
  }) => CommunityChatState(
    messages: messages ?? this.messages,
    loading: loading,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMore: hasMore ?? this.hasMore,
    nextCursor: nextCursor ?? this.nextCursor,
    error: error,
  );
}

class CommunityChatController extends StateNotifier<CommunityChatState> {
  CommunityChatController(this._repo, this.communityId)
    : super(const CommunityChatState()) {
    _load();
  }

  final CommunityRepository _repo;
  final String communityId;

  Future<void> _load() async {
    try {
      final page = await _repo.chatMessages(communityId);
      if (!mounted) return;
      state = CommunityChatState(
        messages: page.items,
        loading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
      markRead();
    } catch (e) {
      if (mounted) state = CommunityChatState(loading: false, error: e);
    }
  }

  Future<void> loadOlder() async {
    if (!state.hasMore || state.loadingOlder) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.chatMessages(
        communityId,
        cursor: state.nextCursor,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: [...page.items, ...state.messages],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        loadingOlder: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(loadingOlder: false);
    }
  }

  /// A live push or my own sent message: added once; a removal notice drops it.
  void receive(CommunityMessage m) {
    if (m.communityId != communityId) return;
    if (m.removed) {
      remove(m.id);
    } else if (!state.messages.any((x) => x.id == m.id)) {
      state = state.copyWith(messages: [...state.messages, m]);
    }
  }

  void remove(String id) => state = state.copyWith(
    messages: state.messages.where((x) => x.id != id).toList(),
  );

  /// Throws the server's reason ("You're sending a lot…") for the screen to show.
  Future<void> send(String body, {String? imageUrl}) async => receive(
    await _repo.sendChatMessage(communityId, body, imageUrl: imageUrl),
  );

  void markRead() =>
      unawaited(_repo.markChatRead(communityId).catchError((_) {}));
}

final communityChatProvider = StateNotifierProvider.autoDispose
    .family<CommunityChatController, CommunityChatState, String>((ref, id) {
      final controller = CommunityChatController(
        ref.watch(communityRepositoryProvider),
        id,
      );
      ref.listen(communityPushProvider, (_, next) {
        final m = next.valueOrNull;
        if (m == null || m.communityId != id) return;
        controller.receive(m);
        if (!m.removed) controller.markRead();
      });
      return controller;
    });

/// A community's group chat, laid out like the 1:1 chat with each sender's
/// name on their first bubble. Long-press a message to report or delete it.
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    super.key,
    required this.communityId,
    this.embedded = false,
  });

  final String communityId;

  /// As a tab on the community page: just the messages and the message bar
  /// (the page already has the header).
  final bool embedded;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _showEmoji = false;

  CommunityChatController get _chat =>
      ref.read(communityChatProvider(widget.communityId).notifier);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
    // The list is reversed, so "older" is at the far end.
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200) _chat.loadOlder();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send({String? imageUrl}) async {
    final text = _text.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    setState(() => _busy = true);
    _text.clear();
    try {
      await _chat.send(text, imageUrl: imageUrl);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      _text.text = text;
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(mediaRepositoryProvider)
          .uploadPhoto(photo, kind: UploadKind.chat);
      await _send(imageUrl: url);
    } catch (e) {
      _snack(friendlyError(e, "Couldn't upload the photo. Try again."));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actions(ChatMessage m, bool canModerate) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
            if (m.mine || canModerate)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await showReportSheet(context, ref, 'COMMUNITY_MESSAGE', m.id);
      return;
    }
    try {
      await ref.read(communityRepositoryProvider).deleteChatMessage(m.id);
      _chat.remove(m.id);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      setState(() => _showEmoji = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityChatProvider(widget.communityId));
    final myId = ref.watch(myUserIdProvider).valueOrNull;
    final community = ref.watch(communityProvider(widget.communityId));
    final summary = ref
        .watch(communityChatSummaryProvider(widget.communityId))
        .valueOrNull;
    final canModerate = summary?.canModerate ?? false;
    final online = summary?.onlineCount ?? 0;

    final messages = [
      for (final m in state.messages)
        ChatMessage(
          id: m.id,
          conversationId: m.communityId,
          senderId: m.sender.id,
          body: m.body,
          imageUrl: m.imageUrl,
          mine: m.sender.id == myId,
          createdAt: m.createdAt,
        ),
    ];

    final body = Column(
      children: [
        Expanded(
          child: state.loading
              ? const Center(
                  child: CircularProgressIndicator(color: kChatMaroon),
                )
              : state.error != null
              ? ChatEmptyHint(text: friendlyError(state.error!))
              : messages.isEmpty
              ? const ChatEmptyHint(
                  text: 'No messages yet. Say hi to your community 👋',
                )
              : ChatMessageList(
                  messages: messages,
                  pendingIds: const {},
                  controller: _scroll,
                  loadingOlder: state.loadingOlder,
                  senders: {
                    for (final m in state.messages) m.sender.id: m.sender,
                  },
                  onLongPress: (m) => _actions(m, canModerate),
                ),
        ),
        ChatMessageBar(
          controller: _text,
          focusNode: _focus,
          uploading: _busy,
          showEmoji: _showEmoji,
          onEmoji: _toggleEmoji,
          onAttach: () => _sendPhoto(ImageSource.gallery),
          onCamera: () => _sendPhoto(ImageSource.camera),
          onSend: _send,
        ),
        if (_showEmoji) ChatEmojiPanel(controller: _text),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: kChatWallpaper, child: body);
    }

    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        backgroundColor: kChatWallpaper,
        appBar: AppBar(
          backgroundColor: kChatMaroon,
          foregroundColor: Colors.white,
          surfaceTintColor: kChatMaroon,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Row(
            children: [
              if (community.valueOrNull case final c?) ...[
                CommunityIcon(community: c, size: 34, onDark: true),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.valueOrNull?.name ?? 'Community chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (community.valueOrNull case final c?)
                      Text(
                        [
                          c.membersLabel,
                          if (online > 0) '$online online',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}
