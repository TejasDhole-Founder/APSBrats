import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.onOpenChat});

  final ValueChanged<AppPerson> onOpenChat;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  bool _showCommunities = true;

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
              : _DirectMessagesView(onOpenChat: widget.onOpenChat),
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
            label: 'Communities',
            active: showCommunities,
            onTap: () => onToggle(true),
          ),
          _ToggleItem(
            label: 'Direct messages',
            active: !showCommunities,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
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
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active
                  ? AppColors.crimson
                  : Colors.white.withValues(alpha: 0.7),
            ),
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

class _DirectMessagesView extends StatelessWidget {
  const _DirectMessagesView({required this.onOpenChat});

  final ValueChanged<AppPerson> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: FeedSearchBar(hint: 'Search messages...', onChanged: (_) {}),
        ),
        Expanded(
          child: dummyMessages.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    message:
                        'Connect with a batchmate and say hi — your chats will show up here.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  itemCount: dummyMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = dummyMessages[i];
                    return _MessageCard(
                      msg: m,
                      onTap: () => onOpenChat(m.person),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.msg, required this.onTap});

  final AppChatMsg msg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: msg.unread ? kCrimsonLight : Colors.white,
          border: Border.all(
            color: msg.unread ? const Color(0x3F7B1414) : kBorder,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AvatarCircle(
              initials: msg.person.initials,
              bg: msg.person.bg,
              fg: msg.person.fg,
              size: 46,
              fontSize: 15,
              online: msg.person.online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.person.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTxt,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.preview,
                    style: TextStyle(
                      fontSize: 12,
                      color: msg.unread ? kTxt2 : kTxt3,
                      fontWeight: msg.unread
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  msg.time,
                  style: const TextStyle(fontSize: 10, color: kTxt3),
                ),
                const SizedBox(height: 5),
                if (msg.unreadCount > 0)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.crimson,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${msg.unreadCount}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
