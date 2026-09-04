import 'dart:async';
import 'dart:math';

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';

class ChatOverlay extends StatefulWidget {
  const ChatOverlay({super.key, required this.person, required this.onBack});

  final AppPerson person;
  final VoidCallback onBack;

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  static final _random = Random();

  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <(String, String)>[...dummyChatHistory];
  Timer? _replyTimer;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _replyTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(('me', text)));
    _ctrl.clear();
    _scrollToBottom();

    // The fake auto-reply only runs in demo mode.
    if (!kShowDemoContent) return;
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final reply = dummyAutoReplies[_random.nextInt(dummyAutoReplies.length)];
      setState(() => _messages.add(('them', reply)));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.crimson,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AvatarCircle(
                        initials: widget.person.initials,
                        bg: widget.person.bg,
                        fg: widget.person.fg,
                        size: 36,
                        fontSize: 13,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.person.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${widget.person.detail} · ${widget.person.school}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FeedIconBtn(icon: Icons.more_vert_rounded),
                    ],
                  ),
                ),
              ),
            ),

            // Messages
            Expanded(
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(14),
                itemCount: _messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final (who, text) = _messages[i];
                  final isMe = who == 'me';
                  return Row(
                    mainAxisAlignment: isMe
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe) ...[
                        AvatarCircle(
                          initials: widget.person.initials,
                          bg: widget.person.bg,
                          fg: widget.person.fg,
                          size: 26,
                          fontSize: 9,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.crimson : Colors.white,
                                border: isMe
                                    ? null
                                    : Border.all(color: kBorder),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 3),
                                  bottomRight: Radius.circular(isMe ? 3 : 14),
                                ),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMe ? Colors.white : kTxt,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isMe ? 'Just now ✓✓' : 'Just now',
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe
                                    ? kTxt2.withValues(alpha: 0.5)
                                    : kTxt3.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEDE9FE),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'AS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4C1D95),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Input
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(fontSize: 13, color: kTxt),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: const TextStyle(
                            color: kTxt3,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFDF9F9),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: const BorderSide(color: kBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: const BorderSide(color: kBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: const BorderSide(
                              color: kCrimsonMed,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.crimson,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 17,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
