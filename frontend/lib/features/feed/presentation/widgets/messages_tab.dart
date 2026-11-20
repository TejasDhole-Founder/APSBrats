import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/communities_tab.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Social-screen-only palette (kept separate from the shared AppColors/kTxt
// tokens so this redesign doesn't shift color anywhere else in the app).
const _kMaroon = Color(0xFF8B1118);
const _kMaroonDeep = Color(0xFF6F0D13);
const _kMsgCream = Color(0xFFF8F5ED);
const _kMsgTextPrimary = Color(0xFF241B1C);
const _kMsgTextSecondary = Color(0xFF8C6F70);

enum _Filter { all, direct, groups, unread }

const _filterLabels = {
  _Filter.all: 'All',
  _Filter.direct: 'Direct',
  _Filter.groups: 'Groups',
  _Filter.unread: 'Unread',
};

/// The Social bottom tab: Messages (direct chats + group/community chats in one
/// list) and Communities (discover / join / create) behind one segmented control.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  var _segment = 0;
  var _communitiesVisited = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CrimsonHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/aps_crest.png',
                    width: 28,
                    height: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'APS Brat',
                    style: GoogleFonts.mulish(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Social',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: _SegmentedControl(
            index: _segment,
            labels: const ['Messages', 'Communities'],
            icons: const [
              HugeIcons.strokeRoundedMessage01,
              HugeIcons.strokeRoundedUserGroup,
            ],
            onChanged: (i) => setState(() {
              _segment = i;
              if (i == 1) _communitiesVisited = true;
            }),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _segment,
            children: [
              const _MessagesView(),
              if (_communitiesVisited)
                const CommunitiesTab()
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.index,
    required this.labels,
    required this.icons,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final List<AppIconData> icons;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEFEC),
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? _kMaroon : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: icons[i],
                        size: 18,
                        color: i == index ? Colors.white : _kMaroon,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: i == index ? Colors.white : _kMaroon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── One row of the unified list ──────────────────────────────────────────────

class _Row {
  const _Row({
    required this.kind,
    required this.title,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.leading,
    required this.route,
  });

  /// direct or groups (school communities); interest communities use all,
  /// so they only show under All and Unread.
  final _Filter kind;
  final String title;
  final String preview;
  final DateTime? time;
  final int unreadCount;
  final Widget leading;
  final String route;

  bool get unread => unreadCount > 0;
}

class _MessagesView extends ConsumerStatefulWidget {
  const _MessagesView();

  @override
  ConsumerState<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends ConsumerState<_MessagesView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Row> _rows(
    List<Conversation> direct,
    List<CommunityChatItem> communities,
  ) {
    final rows = <_Row>[
      for (final c in direct)
        _Row(
          kind: _Filter.direct,
          title: c.person.name,
          preview: c.preview ?? 'Say hi 👋',
          time: c.time,
          unreadCount: c.unreadCount,
          leading: AvatarCircle(
            initials: c.person.initials,
            bg: c.person.bg,
            fg: c.person.fg,
            imageUrl: c.person.profilePicUrl,
            size: 50,
            fontSize: 16,
            online: c.person.online,
          ),
          route: '/home/chat/${c.id}',
        ),
      for (final c in communities)
        _Row(
          kind: c.community.isSchool ? _Filter.groups : _Filter.all,
          title: c.community.name,
          preview: c.lastMessage?.preview ?? c.community.membersLabel,
          time: c.time,
          unreadCount: c.unreadCount,
          leading: CommunityIcon(community: c.community, size: 50),
          route: '/home/community/${c.community.id}/chat',
        ),
    ];
    rows.sort((a, b) {
      final at = a.time, bt = b.time;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return rows;
  }

  List<_Row> _visible(List<_Row> all) {
    final q = _query.trim().toLowerCase();
    return all.where((r) {
      final matchesFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.unread => r.unread,
        _ => r.kind == _filter,
      };
      return matchesFilter &&
          (q.isEmpty ||
              r.title.toLowerCase().contains(q) ||
              r.preview.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(conversationsProvider);
    ref.invalidate(myCommunityChatsProvider);
    ref.invalidate(batchmatesProvider);
  }

  Future<void> _pickFilter() async {
    final picked = await showModalBottomSheet<_Filter>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final f in _Filter.values)
              ListTile(
                title: Text(
                  _filterLabels[f]!,
                  style: TextStyle(
                    fontWeight: f == _filter
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: f == _filter ? _kMaroon : _kMsgTextPrimary,
                  ),
                ),
                trailing: f == _filter
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        color: _kMaroon,
                      )
                    : null,
                onTap: () => Navigator.pop(context, f),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final communities = ref.watch(myCommunityChatsProvider);
    final friends = ref.watch(batchmatesProvider);

    // Communities failing must not hide direct chats: treat as empty there.
    final direct = conversations.valueOrNull ?? const <Conversation>[];
    final groups = communities.valueOrNull ?? const <CommunityChatItem>[];
    final all = _rows(direct, groups);
    final visible = _visible(all);
    final unreadTotal = all.where((r) => r.unread).length;
    final loading = conversations.isLoading && !conversations.hasValue;
    final failed = conversations.hasError && !conversations.hasValue;
    final online = (friends.valueOrNull ?? const <Person>[])
        .where((p) => p.online)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: FeedSearchBar(
            hint: 'Search messages...',
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            onFilterTap: _pickFilter,
            filterActive: _filter != _Filter.all,
            onClear: _query.isEmpty
                ? null
                : () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
          ),
        ),
        _QuickRow(online: online),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: f == _Filter.unread && unreadTotal > 0
                        ? 'Unread ($unreadTotal)'
                        : _filterLabels[f]!,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: RefreshIndicator(
            color: _kMaroon,
            onRefresh: _refresh,
            child: loading
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : failed
                ? ListView(
                    children: [
                      EmptyState(
                        icon: HugeIcons.strokeRoundedWifiOff01,
                        title: 'Could not load messages',
                        message: 'Check your connection and try again.',
                        action: TextButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : all.isEmpty
                ? ListView(
                    children: const [
                      EmptyState(
                        icon: HugeIcons.strokeRoundedMessage01,
                        image: kEmptyInboxImage,
                        title: 'No messages yet',
                        message:
                            'Connect with a batchmate and say hi — your chats will show up here.',
                      ),
                    ],
                  )
                : visible.isEmpty
                ? ListView(
                    children: const [
                      EmptyState(
                        icon: HugeIcons.strokeRoundedSearchRemove,
                        title: 'No matches',
                        message: 'Nothing here matches your search or filter.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 84,
                      color: Color(0x14000000),
                    ),
                    itemBuilder: (context, i) => _RowTile(
                      row: visible[i],
                      onTap: () => context
                          .push<void>(visible[i].route)
                          .then((_) => _refresh()),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kMaroon : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? _kMaroon : const Color(0x1F000000),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kMsgTextPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Quick row: New chat + online friends + View all ──────────────────────────

class _QuickRow extends ConsumerWidget {
  const _QuickRow({required this.online});

  final List<Person> online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showFriendsSheet(context, ref),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _kMaroon, width: 1.4),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    color: _kMaroon,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'New chat',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _kMsgTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 66,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: online.length > 6 ? 6 : online.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = online[i];
                  return GestureDetector(
                    onTap: () => _openChatWith(context, ref, p),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarCircle(
                          initials: p.initials,
                          bg: p.bg,
                          fg: p.fg,
                          imageUrl: p.profilePicUrl,
                          size: 46,
                          fontSize: 15,
                          online: true,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 52,
                          child: Text(
                            p.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _kMsgTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showFriendsSheet(context, ref),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'View all',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _kMaroon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friends picker (View all / New chat / compose icon) ──────────────────────

Future<void> _openChatWith(
  BuildContext context,
  WidgetRef ref,
  Person person,
) async {
  final router = GoRouter.of(context);
  try {
    final c = await ref.read(chatRepositoryProvider).openWith(person.id);
    router.go('/home/chat/${c.id}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

Future<void> _showFriendsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, scroll) => Consumer(
        builder: (_, ref, _) {
          final friends = ref.watch(batchmatesProvider);
          return Column(
            children: [
              const SizedBox(height: 14),
              const Text(
                'Your friends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kMsgTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: friends.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(batchmatesProvider),
                      child: const Text('Could not load. Retry'),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: HugeIcons.strokeRoundedUserGroup02,
                          title: 'No friends yet',
                          message: 'Connect with batchmates to start chatting.',
                        )
                      : ListView.builder(
                          controller: scroll,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final p = list[i];
                            return ListTile(
                              leading: AvatarCircle(
                                initials: p.initials,
                                bg: p.bg,
                                fg: p.fg,
                                imageUrl: p.profilePicUrl,
                                size: 42,
                                fontSize: 14,
                                online: p.online,
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _kMsgTextPrimary,
                                ),
                              ),
                              subtitle: p.detail.isEmpty
                                  ? null
                                  : Text(
                                      p.detail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _openChatWith(context, ref, p);
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

// ── Row tile ─────────────────────────────────────────────────────────────────

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.onTap});

  final _Row row;
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
    final unread = row.unread;
    return Material(
      color: unread ? _kMsgCream.withValues(alpha: 0.6) : Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: _kMsgCream,
        highlightColor: _kMsgCream,
        child: Row(
          children: [
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
                    row.leading,
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.title,
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
                                _formatTime(row.time),
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
                                  row.preview,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (row.unreadCount > 0) ...[
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
                                    row.unreadCount > 9
                                        ? '9+'
                                        : '${row.unreadCount}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
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
