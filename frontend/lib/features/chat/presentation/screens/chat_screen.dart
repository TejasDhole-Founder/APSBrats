import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/chat/presentation/chat_controller.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// The app's own maroon and white (same values as the Messages tab).
const kChatWallpaper = Color(0xFFF8F5ED); // warm cream behind the bubbles
const kChatMaroon = Color(0xFF8B1118);
const _mineBubble = kChatMaroon;
const _theirsBubble = Colors.white;
const _accent = kChatMaroon;
const _gold = Color(0xFFE8B547);
const _timeGrey = Color(0xFF8C6F70);
const _textDark = Color(0xFF241B1C);
const _onMine = Colors.white;
const _onMineSoft = Color(0xCCFFFFFF);

/// One conversation, laid out like WhatsApp: my messages green on the right,
/// theirs white on the left, time inside each bubble, a date chip between
/// days, and a message bar with emoji, photo and camera. No voice messages,
/// payments or calls.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _uploading = false;

  /// WhatsApp-style: 😊 swaps the keyboard for the emoji panel, ⌨ swaps back.
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    // Tapping the text box brings the keyboard back and closes the emoji panel.
    _focus.addListener(() {
      if (_focus.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
    // The list is reversed (newest at the bottom), so "older" is at the far end.
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200) {
        ref
            .read(chatControllerProvider(widget.conversationId).notifier)
            .loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  ChatController get _chat =>
      ref.read(chatControllerProvider(widget.conversationId).notifier);

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    final sending = _chat.send(text);
    _jumpToNewest();
    final sent = await sending;
    if (!sent && mounted && _text.text.isEmpty) _text.text = text;
  }

  /// 📎 opens the gallery, 📷 the camera. The photo goes with any typed text.
  Future<void> _sendPhoto(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(mediaRepositoryProvider)
          .uploadPhoto(photo, kind: UploadKind.chat);
      final caption = _text.text.trim();
      _text.clear();
      await _chat.send(caption, imageUrl: url);
      _jumpToNewest();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't upload the photo. Try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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

  void _jumpToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.conversationId));
    // Say why a message didn't go ("You can send photos once you're connected").
    ref.listen(
      chatControllerProvider(widget.conversationId).select((s) => s.error),
      (_, error) {
        if (error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
    );

    final conversations =
        ref.watch(conversationsProvider).valueOrNull ?? const <Conversation>[];
    final person = conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull
        ?.person;

    return PopScope(
      // Back closes the emoji panel first, like WhatsApp.
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        backgroundColor: kChatWallpaper,
        appBar: _TopBar(person: person),
        body: Column(
          children: [
            Expanded(
              child: state.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : state.messages.isEmpty
                  ? const ChatEmptyHint()
                  : ChatMessageList(
                      messages: state.messages,
                      pendingIds: state.pendingIds,
                      controller: _scroll,
                      loadingOlder: state.loadingOlder,
                    ),
            ),
            ChatMessageBar(
              controller: _text,
              focusNode: _focus,
              uploading: _uploading,
              showEmoji: _showEmoji,
              onEmoji: _toggleEmoji,
              onAttach: () => _sendPhoto(ImageSource.gallery),
              onCamera: () => _sendPhoto(ImageSource.camera),
              onSend: _send,
            ),
            if (_showEmoji) ChatEmojiPanel(controller: _text),
          ],
        ),
      ),
    );
  }
}

/// The full emoji set with recents, categories, search, skin tones (long
/// press) and backspace, styled like WhatsApp's panel. Typing goes straight
/// into the message box at the cursor.
class ChatEmojiPanel extends StatelessWidget {
  const ChatEmojiPanel({super.key, required this.controller});

  final TextEditingController controller;

  static const _panel = Color(0xFFFAF8F5);
  static const _icon = Color(0xFF9A7070);

  @override
  Widget build(BuildContext context) {
    // Apple's emoji look small next to Android's at the same size.
    final iOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return SafeArea(
      top: false,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(
          height: 300,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28 * (iOS ? 1.2 : 1.0),
            backgroundColor: _panel,
            recentsLimit: 32,
          ),
          categoryViewConfig: const CategoryViewConfig(
            // Open on smileys; "Recent" is empty until they've used some.
            initCategory: Category.SMILEYS,
            backgroundColor: _panel,
            indicatorColor: _accent,
            iconColor: _icon,
            iconColorSelected: _accent,
            dividerColor: Color(0xFFE8E2DA),
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            backgroundColor: _panel,
            buttonColor: _panel,
            buttonIconColor: _icon,
          ),
          searchViewConfig: const SearchViewConfig(
            backgroundColor: _panel,
            buttonIconColor: _icon,
            hintText: 'Search emoji',
          ),
        ),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.person});

  final Person? person;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final p = person;
    return AppBar(
      backgroundColor: kChatMaroon,
      foregroundColor: Colors.white,
      surfaceTintColor: kChatMaroon,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 40,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: InkWell(
        onTap: p == null ? null : () => context.push('/home/profile/${p.id}'),
        child: Row(
          children: [
            AvatarCircle(
              initials: p?.initials ?? '?',
              imageUrl: p?.profilePicUrl,
              bg: const Color(0xFFFEF9EE),
              fg: kChatMaroon,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p?.name ?? 'Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if ((p?.online ?? false)
                          ? 'online'
                          : activeLabel(p?.lastActiveAt)
                      case final status?)
                    Text(
                      status,
                      style: const TextStyle(fontSize: 12, color: _gold),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (p != null)
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (_) => context.push('/home/profile/${p.id}'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('View profile')),
            ],
          ),
      ],
    );
  }
}

// ── Messages ─────────────────────────────────────────────────────────────────

/// A message, or the date chip that starts a new day.
sealed class ChatRow {}

class ChatDateRow extends ChatRow {
  ChatDateRow(this.day);
  final DateTime day;
}

class ChatMessageRow extends ChatRow {
  ChatMessageRow(this.message, {required this.firstOfGroup});
  final ChatMessage message;

  /// First of a run from the same person: gets the bubble tail and more space above.
  final bool firstOfGroup;
}

/// Oldest-first messages into rows with a date chip at each new day.
List<ChatRow> buildChatRows(List<ChatMessage> messages) {
  final rows = <ChatRow>[];
  ChatMessage? previous;
  for (final m in messages) {
    final time = (m.createdAt ?? DateTime.now()).toLocal();
    final previousTime = previous?.createdAt?.toLocal();
    final newDay =
        previousTime == null || !DateUtils.isSameDay(previousTime, time);
    if (newDay) rows.add(ChatDateRow(time));
    // A new run starts on a new day, or when the sender changes.
    final newSender =
        previous?.mine != m.mine ||
        (!m.mine && previous?.senderId != m.senderId);
    rows.add(ChatMessageRow(m, firstOfGroup: newDay || newSender));
    previous = m;
  }
  return rows;
}

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.pendingIds,
    required this.controller,
    required this.loadingOlder,
    this.senders = const {},
    this.onLongPress,
  });

  final List<ChatMessage> messages;
  final Set<String> pendingIds;
  final ScrollController controller;
  final bool loadingOlder;

  /// Group chats: sender id -> person; their face and name lead each run.
  final Map<String, Person> senders;
  final ValueChanged<ChatMessage>? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Reversed so the newest message sits at the bottom and new ones appear there.
    final rows = buildChatRows(messages).reversed.toList();
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      itemCount: rows.length + (loadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return switch (rows[i]) {
          ChatDateRow(:final day) => _DateChip(day: day),
          ChatMessageRow(:final message, :final firstOfGroup) => _Bubble(
            message: message,
            firstOfGroup: firstOfGroup,
            pending: pendingIds.contains(message.id),
            sender: senders.isEmpty || message.mine
                ? null
                : senders[message.senderId],
            onLongPress: onLongPress == null
                ? null
                : () => onLongPress!(message),
          ),
        };
      },
    );
  }
}

/// "Today", "Yesterday", a weekday within the last week, or "5 October 2026".
String chatDayLabel(DateTime day, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final d = DateUtils.dateOnly(day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(d);
  return DateFormat('d MMMM y').format(d);
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          chatDayLabel(day),
          style: const TextStyle(fontSize: 12.5, color: _timeGrey),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.firstOfGroup,
    required this.pending,
    this.sender,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool firstOfGroup;
  final bool pending;

  /// Group chats: who sent it (someone else). Their face sits beside the
  /// run and their name tops its first bubble.
  final Person? sender;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final colour = mine ? _mineBubble : _theirsBubble;
    final time = DateFormat(
      'h:mm a',
    ).format((message.createdAt ?? DateTime.now()).toLocal()).toLowerCase();
    final hasPhoto = message.imageUrl != null;
    final hasText = message.body.isNotEmpty;
    final onPhoto = hasPhoto && !hasText;

    // Time (and my tick) tucked into the bubble's bottom-right corner.
    final stamp = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: onPhoto ? Colors.white : (mine ? _onMineSoft : _timeGrey),
          ),
        ),
        if (mine) ...[
          const SizedBox(width: 3),
          Icon(
            pending ? Icons.access_time_rounded : Icons.done_rounded,
            size: 15,
            semanticLabel: pending ? 'Sending' : 'Sent',
            color: onPhoto ? Colors.white : (mine ? _onMineSoft : _timeGrey),
          ),
        ],
      ],
    );

    final Widget content = hasPhoto
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  NetworkPhoto(
                    url: message.imageUrl!,
                    maxHeight: 300,
                    borderRadius: 6,
                  ),
                  if (!hasText)
                    Positioned(
                      right: 6,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: stamp,
                      ),
                    ),
                ],
              ),
              if (hasText)
                _TextWithStamp(text: message.body, stamp: stamp, mine: mine),
            ],
          )
        : _TextWithStamp(text: message.body, stamp: stamp, mine: mine);
    final senderName = firstOfGroup ? sender?.name : null;
    final Widget body = senderName == null
        ? content
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(9, hasPhoto ? 3 : 6, 9, 0),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kChatMaroon,
                  ),
                ),
              ),
              content,
            ],
          );

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: CustomPaint(
        painter: firstOfGroup ? _TailPainter(colour: colour, mine: mine) : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: hasPhoto ? 280 : double.infinity,
          ),
          padding: EdgeInsets.all(hasPhoto ? 3 : 0),
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(!mine && firstOfGroup ? 0 : 8),
              topRight: Radius.circular(mine && firstOfGroup ? 0 : 8),
              bottomLeft: const Radius.circular(8),
              bottomRight: const Radius.circular(8),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 0.5,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: body,
        ),
      ),
    );
    final face = sender;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mine ? 60 : 8,
        firstOfGroup ? 6 : 1.5,
        mine ? 8 : 60,
        1.5,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: face == null
            ? bubble
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (firstOfGroup)
                    AvatarCircle(
                      initials: face.initials,
                      imageUrl: face.profilePicUrl,
                      bg: face.bg,
                      fg: face.fg,
                      size: 28,
                      fontSize: 10,
                    )
                  else
                    const SizedBox(width: 28),
                  const SizedBox(width: 10),
                  Flexible(child: bubble),
                ],
              ),
      ),
    );
  }
}

/// Text that flows round the time stamp: a short message keeps the time on
/// the same line, a long one leaves it in the bottom-right corner.
class _TextWithStamp extends StatelessWidget {
  const _TextWithStamp({
    required this.text,
    required this.stamp,
    required this.mine,
  });

  final String text;
  final Widget stamp;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
      child: Stack(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: text),
                // Room for the time so it never overlaps the last line.
                WidgetSpan(child: SizedBox(width: mine ? 78 : 60, height: 12)),
              ],
            ),
            style: TextStyle(
              fontSize: 15,
              color: mine ? _onMine : _textDark,
              height: 1.3,
            ),
          ),
          Positioned(right: 0, bottom: -2, child: stamp),
        ],
      ),
    );
  }
}

/// The little triangle on the first bubble of a group.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.colour, required this.mine});

  final Color colour;
  final bool mine;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (mine) {
      path
        ..moveTo(size.width - 1, 0)
        ..lineTo(size.width + 8, 0)
        ..lineTo(size.width - 1, 10)
        ..close();
    } else {
      path
        ..moveTo(1, 0)
        ..lineTo(-8, 0)
        ..lineTo(1, 10)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.colour != colour || old.mine != mine;
}

class ChatEmptyHint extends StatelessWidget {
  const ChatEmptyHint({
    super.key,
    this.text = 'Say hi 👋 and start the conversation',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEECD),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _timeGrey),
        ),
      ),
    );
  }
}

// ── Message bar ──────────────────────────────────────────────────────────────

class ChatMessageBar extends StatelessWidget {
  const ChatMessageBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.uploading,
    required this.showEmoji,
    required this.onEmoji,
    required this.onAttach,
    required this.onCamera,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool uploading;
  final bool showEmoji;
  final VoidCallback onEmoji;
  final VoidCallback onAttach;
  final VoidCallback onCamera;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    const iconColour = _timeGrey;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: showEmoji ? 'Keyboard' : 'Emoji',
                      color: iconColour,
                      icon: Icon(
                        showEmoji
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                      ),
                      onPressed: onEmoji,
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 16, color: _textDark),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Color(0xFFBBA7A8)),
                          // The app's default input style is a filled box; WhatsApp's isn't.
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 13),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    if (uploading)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accent,
                          ),
                        ),
                      )
                    else ...[
                      IconButton(
                        tooltip: 'Send a photo',
                        color: iconColour,
                        icon: Transform.rotate(
                          angle: -0.6,
                          child: const Icon(Icons.attach_file_rounded),
                        ),
                        onPressed: onAttach,
                      ),
                      IconButton(
                        tooltip: 'Take a photo',
                        color: iconColour,
                        icon: const Icon(Icons.photo_camera_outlined),
                        onPressed: onCamera,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  tooltip: 'Send',
                  style: IconButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                  ),
                  onPressed: value.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.send_rounded, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
