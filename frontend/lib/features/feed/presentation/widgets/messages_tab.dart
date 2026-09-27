import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
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

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  bool _showCommunities = false;

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
              const SizedBox(height: 14),
              _ToggleBar(
                showCommunities: _showCommunities,
                onToggle: (v) => setState(() => _showCommunities = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showCommunities
              ? _CommunitiesView()
              : const _DirectMessagesView(),
        ),
      ],
    );
  }
}

// ── Toggle bar ────────────────────────────────────────────────────────────────

class _ToggleBar extends StatelessWidget {
  const _ToggleBar({required this.showCommunities, required this.onToggle});

  final bool showCommunities;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _ToggleItem(
            label: 'Direct messages',
            icon: Icons.chat_bubble_rounded,
            active: !showCommunities,
            onTap: () => onToggle(false),
          ),
          _ToggleItem(
            label: 'Communities',
            icon: Icons.people_alt_rounded,
            active: showCommunities,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? _kMaroon : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? _kMaroon : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Communities view ──────────────────────────────────────────────────────────

class _CommunitiesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (dummyCommunities.isEmpty && dummyDiscoverCommunities.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: 'No communities yet',
          message:
              'Your class and school communities appear here automatically once your school history is set.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        const SectionLabel('YOUR AUTO-JOINED COMMUNITIES'),
        const SizedBox(height: 10),
        ...dummyCommunities.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CommunityCard(community: c),
          ),
        ),
        const SizedBox(height: 8),
        const SectionLabel('DISCOVER MORE'),
        const SizedBox(height: 10),
        ...dummyDiscoverCommunities.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DiscoverCard(community: c),
          ),
        ),
      ],
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.community});

  final AppCommunity community;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // APS square logo
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.crimson,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'APS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTxt,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (community.isYourSection)
                          _PillBadge(
                            label: 'Your section',
                            icon: Icons.people_alt_rounded,
                            color: AppColors.gold,
                            textColor: AppColors.crimsonDark,
                            bgColor: const Color(0xFFFDF6E3),
                          )
                        else if (community.isYourSchool)
                          _PillBadge(
                            label: 'Your school',
                            icon: Icons.school_rounded,
                            color: AppColors.gold,
                            textColor: AppColors.crimsonDark,
                            bgColor: const Color(0xFFFDF6E3),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline_rounded,
                          size: 12,
                          color: kTxt3,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${community.members} members',
                          style: const TextStyle(fontSize: 11, color: kTxt3),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${community.online} online',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Unread badge
              if (community.unreadCount > 0)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.crimson,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${community.unreadCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    community.autoJoinLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Last message preview
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: kTxt2),
              children: [
                TextSpan(
                  text: '${community.lastSender}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kTxt,
                  ),
                ),
                TextSpan(text: community.lastMessage),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Avatar stack
              SizedBox(
                height: 22,
                width: 22.0 + (community.avatars.length - 1).clamp(0, 4) * 14.0,
                child: Stack(
                  children: List.generate(
                    community.avatars.length.clamp(0, 5),
                    (i) => Positioned(
                      left: i * 14.0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: community.avatars[i].bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          community.avatars[i].initials,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: community.avatars[i].fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (community.members > 5)
                Text(
                  '+${community.members - 5}',
                  style: const TextStyle(fontSize: 10, color: kTxt3),
                ),
              const Spacer(),
              Text(
                community.time,
                style: const TextStyle(fontSize: 10, color: kTxt3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.bgColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatefulWidget {
  const _DiscoverCard({required this.community});

  final AppDiscoverCommunity community;

  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kCrimsonLight,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0x2F7B1414)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'APS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: kCrimsonMed,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.community.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTxt,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.community.memberCount} · ${widget.community.subtitle}',
                  style: const TextStyle(fontSize: 11, color: kTxt3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _joined = !_joined),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: _joined ? kCrimsonLight : Colors.white,
                border: Border.all(
                  color: _joined ? const Color(0x2F7B1414) : AppColors.crimson,
                ),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _joined ? 'Joined' : 'Join',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _joined ? kCrimsonMed : AppColors.crimson,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Direct messages view ──────────────────────────────────────────────────────

class _DirectMessagesView extends ConsumerStatefulWidget {
  const _DirectMessagesView();

  @override
  ConsumerState<_DirectMessagesView> createState() => _DirectMessagesViewState();
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
            error: (_, __) => const Center(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load messages',
                message: 'Check your connection and try again.',
              ),
            ),
            data: (conversations) {
              if (conversations.isEmpty) {
                return const Center(
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
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
                                  color: unread ? _kMaroonDeep : _kMsgTextSecondary,
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
                                        ? _kMsgTextPrimary.withValues(alpha: 0.75)
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
                                  constraints: const BoxConstraints(minWidth: 20),
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
                                  color: _kMsgTextSecondary.withValues(alpha: 0.5),
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
