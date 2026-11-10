import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Messages-screen-only palette (kept separate from the shared AppColors/kTxt
// tokens so this redesign doesn't shift color anywhere else in the app).
const _kMaroon = Color(0xFF8B1118);
const _kMaroonDeep = Color(0xFF6F0D13);
const _kMsgCream = Color(0xFFF8F5ED);
const _kMsgTextPrimary = Color(0xFF241B1C);
const _kMsgTextSecondary = Color(0xFF8C6F70);

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CrimsonHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  FeedIconBtn(icon: Icons.edit_rounded),
                ],
              ),
            ],
          ),
        ),
        const Expanded(child: _DirectMessagesView()),
      ],
    );
  }
}

// ── Direct messages view ──────────────────────────────────────────────────────

class _DirectMessagesView extends ConsumerStatefulWidget {
  const _DirectMessagesView();

  @override
  ConsumerState<_DirectMessagesView> createState() =>
      _DirectMessagesViewState();
}

class _DirectMessagesViewState extends ConsumerState<_DirectMessagesView> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Conversation> _filter(List<Conversation> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.person.name.toLowerCase().contains(q) ||
              (c.preview ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: FeedSearchBar(
                  hint: 'Search messages...',
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _kMaroon,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: conversationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load messages',
                message: 'Check your connection and try again.',
                action: TextButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (conversations) {
              if (conversations.isEmpty) {
                // Scrollable so the illustration never overflows a short screen.
                return const SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    image: kEmptyInboxImage,
                    title: 'No messages yet',
                    message:
                        'Connect with a batchmate and say hi — your chats will show up here.',
                  ),
                );
              }
              final filtered = _filter(conversations);
              if (filtered.isEmpty) {
                return Center(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'Nobody in your messages matches "$_query".',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 84,
                  color: Color(0x14000000),
                ),
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return _MessageCard(
                    conversation: c,
                    onTap: () => context.go('/home/chat/${c.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  static String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final sameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;
    if (sameDay) {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == time.year &&
        yesterday.month == time.month &&
        yesterday.day == time.day) {
      return 'Yesterday';
    }
    final daysAgo = now.difference(time).inDays;
    if (daysAgo < 7) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    final person = conversation.person;
    final unread = conversation.unread;

    return Material(
      // A continuous flat list, not a stack of separate cards -- unread rows
      // get a very subtle warm tint instead of a heavy box treatment.
      color: unread ? _kMsgCream.withValues(alpha: 0.6) : Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: _kMsgCream,
        highlightColor: _kMsgCream,
        child: Row(
          children: [
            // Thin left indicator = "this conversation has unread messages".
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: unread ? 3 : 0,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _kMaroon,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(unread ? 15 : 18, 14, 16, 14),
                child: Row(
                  children: [
                    AvatarCircle(
                      initials: person.initials,
                      bg: person.bg,
                      fg: person.fg,
                      imageUrl: person.profilePicUrl,
                      size: 50,
                      fontSize: 16,
                      online: person.online,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  person.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: _kMsgTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(conversation.time),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: unread
                                      ? _kMaroonDeep
                                      : _kMsgTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.preview ?? 'Say hi 👋',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: unread
                                        ? _kMsgTextPrimary.withValues(
                                            alpha: 0.75,
                                          )
                                        : _kMsgTextSecondary,
                                    fontWeight: unread
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conversation.unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                    vertical: 2,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: _kMaroon,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    conversation.unreadCount > 9
                                        ? '9+'
                                        : '${conversation.unreadCount}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ] else
                                const SizedBox(width: 8),
                              if (conversation.unreadCount == 0)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: _kMsgTextSecondary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                            ],
                          ),
                        ],
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
