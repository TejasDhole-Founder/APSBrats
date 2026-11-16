import 'dart:async';
import 'dart:convert';

import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/communities_tab.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_chat_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/community/presentation/event_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/memories_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/post_card.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart'
    show kPeoplePageSize;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One community: a header that collapses into the app bar, then four tabs
/// (Feed, Events, Memories, Members). Chat opens from the header.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({
    super.key,
    required this.communityId,
    this.initialTab = 0,
  });

  final String communityId;

  /// 0 Feed, 1 Events, 2 Memories, 3 Members.
  final int initialTab;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _outer = ScrollController();

  /// Header scrolled away: show the name in the app bar instead.
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _outer.addListener(() {
      final collapsed = _outer.offset > 120;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  /// Interest communities have Chat as their second tab; schools open it from the header.
  bool _chatIsTab = false;

  /// The header's Chat button and the app bar's chat icon.
  void _openChatFor(Community c) {
    if (_chatIsTab) {
      _tabs.animateTo(1);
    } else {
      _openChat(context, ref, c.id);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _outer.dispose();
    super.dispose();
  }

  /// Fits the header's content: crimson band, badge, name, meta, about, buttons.
  double _headerHeight(Community c, bool tabs) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final about = !c.isSchool && (c.description ?? '').isNotEmpty ? 40.0 : 0.0;
    return top +
        20 +
        34 +
        26 +
        22 +
        30 +
        about +
        14 +
        40 +
        16 +
        (tabs ? 60 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider(widget.communityId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kCommunityBg,
        body: community.when(
          loading: () => const _Shell(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.crimson),
            ),
          ),
          error: (e, _) => _Shell(
            child: EmptyState(
              icon: HugeIcons.strokeRoundedUserGroup,
              image: kEmptyInboxImage,
              title: statusOf(e) == 404
                  ? 'Community not found'
                  : "Couldn't load this community",
              message: statusOf(e) == 404
                  ? "It may have been deleted, or it's only for another school's students."
                  : friendlyError(e),
            ),
          ),
          data: (c) {
            _chatIsTab = !c.isSchool;
            final readable = !c.isPrivate || c.isMember;
            return NestedScrollView(
              controller: _outer,
              headerSliverBuilder: (context, _) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar(
                    pinned: true,
                    expandedHeight: _headerHeight(c, readable),
                    backgroundColor: AppColors.crimson,
                    foregroundColor: Colors.white,
                    surfaceTintColor: AppColors.crimson,
                    systemOverlayStyle: SystemUiOverlayStyle.light,
                    leading: IconButton(
                      tooltip: 'Back',
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    title: _collapsed
                        ? Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                    actions: [
                      if (_collapsed && c.isMember)
                        IconButton(
                          tooltip: 'Community chat',
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedMessage01,
                          ),
                          onPressed: () => _openChatFor(c),
                        ),
                      IconButton(
                        tooltip: 'Share',
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedShare01,
                        ),
                        onPressed: () => Share.share(
                          'Join ${c.name} on APS Brats, the app for Army Public School alumni.',
                        ),
                      ),
                      if (c.isOwner) _OwnerMenu(community: c),
                    ],
                    // The header slides up with the page and fades out as it
                    // collapses, leaving a plain crimson bar with the tabs.
                    flexibleSpace: LayoutBuilder(
                      builder: (context, box) {
                        final full = _headerHeight(c, readable);
                        final min =
                            MediaQuery.paddingOf(context).top +
                            kToolbarHeight +
                            (readable ? 60 : 0);
                        final t = ((box.maxHeight - min) / (full - min)).clamp(
                          0.0,
                          1.0,
                        );
                        return ClipRect(
                          child: Stack(
                            children: [
                              Positioned(
                                top: box.maxHeight - full,
                                left: 0,
                                right: 0,
                                height: full,
                                child: Opacity(
                                  opacity: ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                                  child: _Header(
                                    community: c,
                                    onChat: () => _openChatFor(c),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    bottom: readable
                        ? PreferredSize(
                            preferredSize: const Size.fromHeight(60),
                            child: Material(
                              color: Colors.white,
                              child: TabBar(
                                controller: _tabs,
                                labelColor: AppColors.crimson,
                                unselectedLabelColor: kTxt3,
                                indicatorColor: AppColors.crimson,
                                indicatorSize: TabBarIndicatorSize.label,
                                dividerColor: kCardLine,
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                tabs: [
                                  const Tab(
                                    height: 60,
                                    icon: HugeIcon(
                                      icon: HugeIcons
                                          .strokeRoundedLeftToRightListBullet,
                                      size: 20,
                                    ),
                                    text: 'Feed',
                                  ),
                                  if (c.isSchool) ...const [
                                    Tab(
                                      height: 60,
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedCalendar03,
                                        size: 20,
                                      ),
                                      text: 'Events',
                                    ),
                                    Tab(
                                      height: 60,
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedImage02,
                                        size: 20,
                                      ),
                                      text: 'Memories',
                                    ),
                                  ] else ...const [
                                    Tab(
                                      height: 60,
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedMessage01,
                                        size: 20,
                                      ),
                                      text: 'Chat',
                                    ),
                                    Tab(
                                      height: 60,
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedCalendar03,
                                        size: 20,
                                      ),
                                      text: 'Events',
                                    ),
                                  ],
                                  const Tab(
                                    height: 60,
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedUserGroup02,
                                      size: 20,
                                    ),
                                    text: 'Members',
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
              body: readable
                  ? TabBarView(
                      controller: _tabs,
                      children: [
                        _FeedTab(community: c),
                        if (c.isSchool) ...[
                          EventsTab(community: c),
                          MemoriesTab(community: c),
                        ] else ...[
                          c.isMember
                              ? CommunityChatScreen(
                                  communityId: c.id,
                                  embedded: true,
                                )
                              : const _JoinToChat(),
                          EventsTab(community: c),
                        ],
                        _MembersTab(community: c),
                      ],
                    )
                  : Builder(
                      builder: (context) => CustomScrollView(
                        slivers: [
                          SliverOverlapInjector(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                  context,
                                ),
                          ),
                          SliverToBoxAdapter(
                            child: EmptyState(
                              icon: HugeIcons.strokeRoundedLockKey,
                              image: kEmptyInboxImage,
                              title: 'Members only',
                              message: c.requested
                                  ? "You'll see the posts once the owner approves your request."
                                  : 'Ask to join to see what members are sharing.',
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _openChat(BuildContext context, WidgetRef ref, String id) async {
  await context.push('/home/community/$id/chat');
  if (context.mounted) ref.invalidate(communityChatSummaryProvider(id));
}

/// Shown in the Chat tab to someone who hasn't joined an open community.
class _JoinToChat extends StatelessWidget {
  const _JoinToChat();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Join this community to chat with its members.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: kTxt3),
      ),
    ),
  );
}

/// Plain back-button header for loading and error states.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CrimsonHeader(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FeedIconBtn(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            onTap: () => context.pop(),
          ),
        ),
      ),
      Expanded(child: SingleChildScrollView(child: child)),
    ],
  );
}

/// Owner tools: join requests (private) and delete.
class _OwnerMenu extends ConsumerWidget {
  const _OwnerMenu({required this.community});

  final Community community;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final c = community;
    final ok = await confirmDialog(
      context,
      title: 'Delete ${c.name}?',
      message: "All its posts and members go with it. This can't be undone.",
      action: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    try {
      await ref.read(communityRepositoryProvider).delete(c.id);
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(discoverProvider);
      ref.invalidate(postFeedProvider(''));
      router.go('/home');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Owner options',
      icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical),
      onSelected: (v) => v == 'requests'
          ? context.push('/home/community/${community.id}/requests')
          : _delete(context, ref),
      itemBuilder: (_) => [
        if (community.isPrivate)
          const PopupMenuItem(value: 'requests', child: Text('Join requests')),
        const PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete community',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerStatefulWidget {
  const _Header({required this.community, required this.onChat});

  final VoidCallback onChat;

  final Community community;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(communityProvider(widget.community.id));
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(discoverProvider);
      ref.invalidate(postFeedProvider(''));
      if (done != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _join() => _run(
    () async {
      await ref.read(communityRepositoryProvider).join(widget.community.id);
      ref.invalidate(postFeedProvider(widget.community.id));
    },
    done: widget.community.isPrivate
        ? 'Request sent. The owner will review it.'
        : null,
  );

  Future<void> _leave() async {
    final ok = await confirmDialog(
      context,
      title: 'Leave ${widget.community.name}?',
      message: widget.community.isPrivate
          ? "You'll need the owner's approval to join again."
          : 'You can join again anytime.',
      action: 'Leave',
    );
    if (ok) {
      _run(
        () => ref.read(communityRepositoryProvider).leave(widget.community.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.community;
    final readable = !c.isPrivate || c.isMember;
    final faces = readable
        ? ref
                  .watch(
                    communityMembersProvider((
                      communityId: c.id,
                      q: '',
                      batch: null,
                      page: 0,
                    )),
                  )
                  .valueOrNull ??
              const <Person>[]
        : const <Person>[];
    // A new chat message here while this page is open: refresh the unread count.
    ref.listen(communityPushProvider, (_, next) {
      if (c.isMember && next.valueOrNull?.communityId == c.id) {
        ref.invalidate(communityChatSummaryProvider(c.id));
      }
    });
    final summary = c.isMember
        ? ref.watch(communityChatSummaryProvider(c.id)).valueOrNull
        : null;
    final unread = summary?.unreadCount ?? 0;
    final extra = c.memberCount - faces.take(3).length;
    final band = MediaQuery.paddingOf(context).top + kToolbarHeight + 20;
    final banner = communityBannerAsset(c);

    return Container(
      color: kCommunityBg,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Stack(
          children: [
            Container(
              height: band,
              decoration: BoxDecoration(
                color: AppColors.crimson,
                image: banner == null
                    ? null
                    : DecorationImage(
                        image: AssetImage(banner),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Padding(
              // Schools show only the banner; the name sits below it.
              padding: EdgeInsets.fromLTRB(
                16,
                c.isSchool ? band + 12 : band - 30,
                16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!c.isSchool) ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: kCommunityBg, width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: CommunityIcon(
                        community: c,
                        size: 56,
                        onDark: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kTxt,
                          ),
                        ),
                      ),
                      if (c.isSchool) ...[
                        const SizedBox(width: 6),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                          size: 18,
                          color: AppColors.crimson,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      HugeIcon(
                        icon: c.isSchool
                            ? HugeIcons.strokeRoundedBuilding06
                            : HugeIcons.strokeRoundedHexagon,
                        size: 14,
                        color: kTxt3,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          c.kindLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: kTxt3),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: kCardLine,
                      ),
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedUserGroup,
                        size: 15,
                        color: kTxt3,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.membersLabel,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, color: kTxt3),
                      ),
                    ],
                  ),
                  if (faces.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AvatarStack(people: faces, size: 26),
                        if (extra > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '+$extra members',
                            style: const TextStyle(fontSize: 12, color: kTxt3),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (!c.isSchool && (c.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      c.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: kTxt2,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (c.isMember)
                        Expanded(
                          child: PopupMenuButton<String>(
                            tooltip: 'Membership',
                            enabled: !_busy && !c.isOwner,
                            onSelected: (_) => _leave(),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'leave',
                                child: Text(
                                  'Leave community',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                            child: IgnorePointer(
                              child: Row(
                                children: [
                                  CommunityPill(
                                    label: c.isOwner ? 'Owner' : 'Joined',
                                    icon: HugeIcons.strokeRoundedTick02,
                                    trailing: c.isOwner
                                        ? null
                                        : HugeIcons.strokeRoundedArrowDown01,
                                    expand: true,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (c.requested)
                        const CommunityPill(
                          label: 'Requested · waiting for the owner',
                          icon: HugeIcons.strokeRoundedClock01,
                          expand: true,
                        )
                      else
                        CommunityPill(
                          label: c.isPrivate ? 'Request to join' : 'Join',
                          icon: HugeIcons.strokeRoundedAdd01,
                          filled: true,
                          expand: true,
                          onTap: _busy ? null : _join,
                        ),
                      if (c.isMember) ...[
                        const SizedBox(width: 10),
                        CommunityPill(
                          label: unread > 0 ? 'Chat · $unread' : 'Chat',
                          icon: HugeIcons.strokeRoundedMessage01,
                          filled: true,
                          expand: true,
                          onTap: widget.onChat,
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
    );
  }
}

// ── Feed tab ─────────────────────────────────────────────────────────────────

/// A tab's scroll body under the collapsing header. Calls [onNearEnd] to
/// fetch the next page.
class CommunityTabBody extends StatelessWidget {
  const CommunityTabBody({
    super.key,
    required this.storageKey,
    required this.slivers,
    this.onNearEnd,
    this.onRefresh,
  });

  final String storageKey;
  final List<Widget> slivers;
  final VoidCallback? onNearEnd;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget body = CustomScrollView(
      key: PageStorageKey(storageKey),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
    if (onRefresh != null) {
      body = RefreshIndicator(
        color: AppColors.crimson,
        onRefresh: onRefresh!,
        child: body,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onNearEnd != null && n.metrics.extentAfter < 400) onNearEnd!();
        return false;
      },
      child: body,
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final feed = ref.watch(postFeedProvider(c.id));
    final notifier = ref.read(postFeedProvider(c.id).notifier);
    final sort = ref.watch(postSortProvider(c.id));

    return CommunityTabBody(
      storageKey: 'feed-${c.id}',
      onNearEnd: notifier.loadMore,
      onRefresh: () async {
        ref.invalidate(communityProvider(c.id));
        ref.invalidate(communityEventsProvider((c.id, false)));
        await notifier.refresh();
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverList.list(
                children: [
                  if (c.isMember) ...[
                    PromptCard(
                      hint: 'Share a memory or update',
                      actionIcons: c.isSchool
                          ? const [
                              HugeIcons.strokeRoundedImage02,
                              HugeIcons.strokeRoundedVideo01,
                              HugeIcons.strokeRoundedFile01,
                            ]
                          : null,
                      onTap: () => showPostComposer(
                        context,
                        communityId: c.id,
                        communityName: c.name,
                        onPosted: notifier.prepend,
                        allowMemory: c.isSchool,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  NextEventCard(community: c),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Posts',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kTxt,
                            ),
                          ),
                        ),
                        _SortToggle(
                          value: sort,
                          onChanged: (v) =>
                              ref.read(postSortProvider(c.id).notifier).state =
                                  v,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
              // Built lazily: only posts near the viewport exist as widgets.
              SliverList.builder(
                itemCount: feed.items.length,
                itemBuilder: (context, i) {
                  final p = feed.items[i];
                  return Padding(
                    key: ValueKey(p.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PostCard(
                      post: p,
                      onChanged: notifier.replace,
                      onDeleted: () => notifier.remove(p.id),
                    ),
                  );
                },
              ),
              SliverList.list(
                children: [
                  if (feed.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.crimson,
                        ),
                      ),
                    )
                  else if (feed.error != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            friendlyError(feed.error!),
                            style: const TextStyle(fontSize: 12, color: kTxt3),
                          ),
                        ),
                        TextButton(
                          onPressed: notifier.refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (feed.items.isEmpty && sort == 'popular')
                    const EmptyState(
                      icon: HugeIcons.strokeRoundedFire,
                      image: kEmptyInboxImage,
                      title: 'Nothing popular yet',
                      message:
                          'Popular shows posts from the last 30 days. Switch to Latest for older ones.',
                    )
                  else if (feed.items.isEmpty)
                    EmptyState(
                      icon: HugeIcons.strokeRoundedComment01,
                      image: kEmptyInboxImage,
                      title: 'No posts yet',
                      message: c.isMember
                          ? 'Be the first to share a memory or ask a question.'
                          : 'Join and be the first to post.',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Latest | Popular, as a small segmented switch.
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in const [
            ('latest', 'Latest'),
            ('popular', 'Popular'),
          ])
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: value == v ? AppColors.crimson : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: value == v ? Colors.white : kTxt3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── New post sheet ───────────────────────────────────────────────────────────

/// The full composer, as a sheet. [eventId]: photos from that event.
/// [asMemory]: opens with "School memory" on.
Future<void> showPostComposer(
  BuildContext context, {
  required String communityId,
  required String communityName,
  ValueChanged<Post>? onPosted,
  String? eventId,
  String? eventTitle,
  bool asMemory = false,
  bool allowMemory = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => PostComposer(
      communityId: communityId,
      communityName: communityName,
      eventId: eventId,
      eventTitle: eventTitle,
      asMemory: asMemory,
      allowMemory: allowMemory,
      onPosted: (p) => onPosted?.call(p),
    ),
  );
}

/// Text and up to 10 photos. With [eventId], the post is shared from that
/// event; otherwise photos can be marked as a school memory.
class PostComposer extends ConsumerStatefulWidget {
  const PostComposer({
    super.key,
    required this.communityId,
    required this.onPosted,
    this.communityName = '',
    this.eventId,
    this.eventTitle,
    this.asMemory = false,
    this.allowMemory = false,
  });

  final String communityId;
  final String communityName;
  final ValueChanged<Post> onPosted;
  final String? eventId;
  final String? eventTitle;
  final bool asMemory;

  /// School communities only: show the "School memory" switch.
  final bool allowMemory;

  @override
  ConsumerState<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends ConsumerState<PostComposer> {
  final _text = TextEditingController();
  bool _busy = false;

  static const _maxPhotos = 10;

  /// Attached photos, in slider order. Each is uploaded as soon as it's
  /// picked, so pressing "Post" is quick.
  final List<String> _photoUrls = [];

  /// "Uploading 2 of 4…" while photos go up.
  String? _uploading;

  /// Mark the photos as a school memory (year + category).
  late bool _memory = widget.asMemory;
  int? _memoryYear;
  String? _memoryCategory;

  static final _memoryYears = [
    for (var y = DateTime.now().year; y >= kFirstMemoryYear; y--) y,
  ];

  /// Posts outside events can be memories (they need a photo to post).
  bool get _canBeMemory => widget.allowMemory && widget.eventId == null;

  /// Text and uploaded photos survive closing the sheet (or a failed post)
  /// until the post goes through.
  String get _draftKey =>
      'post_draft:${widget.communityId}:${widget.eventId ?? ''}:${widget.asMemory}';
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final raw = (await SharedPreferences.getInstance()).getString(_draftKey);
    if (raw == null || !mounted) return;
    final draft = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      if (_text.text.isEmpty) _text.text = draft['text'] as String? ?? '';
      if (_photoUrls.isEmpty) {
        _photoUrls.addAll((draft['photos'] as List<dynamic>? ?? []).cast());
      }
    });
  }

  Future<void> _saveDraft(String text, List<String> photos) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.trim().isEmpty && photos.isEmpty) {
      await prefs.remove(_draftKey);
    } else {
      await prefs.setString(
        _draftKey,
        jsonEncode({'text': text, 'photos': photos}),
      );
    }
  }

  Future<void> _addPhotos() async {
    final picked = await pickPhotos(
      context,
      max: _maxPhotos - _photoUrls.length,
    );
    if (picked.isEmpty || !mounted) return;
    await _upload(picked);
  }

  /// On failure the photos not yet uploaded are kept, behind a Retry button.
  Future<void> _upload(List<XFile> files) async {
    var done = 0;
    try {
      for (final file in files) {
        setState(
          () => _uploading = 'Uploading ${done + 1} of ${files.length}…',
        );
        final url = await ref
            .read(mediaRepositoryProvider)
            .uploadPhoto(file, kind: UploadKind.post);
        if (!mounted) return;
        setState(() => _photoUrls.add(url));
        done++;
      }
    } catch (e) {
      final remaining = files.sublist(done);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyError(e, "Couldn't upload the photo. Try again."),
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (mounted) _upload(remaining);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  void dispose() {
    if (!_posted) unawaited(_saveDraft(_text.text, List.of(_photoUrls)));
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_text.text.trim().isEmpty && _photoUrls.isEmpty) {
      _snack('Write something or add a photo');
      return;
    }
    final memory = _memory && _canBeMemory;
    if (memory && _photoUrls.isEmpty) {
      _snack('Add at least one photo to share a memory');
      return;
    }
    if (memory && (_memoryYear == null || _memoryCategory == null)) {
      _snack("Pick the year and what it's about");
      return;
    }
    setState(() => _busy = true);
    try {
      final post = await ref
          .read(communityRepositoryProvider)
          .createPost(
            widget.communityId,
            _text.text,
            imageUrls: List.of(_photoUrls),
            eventId: widget.eventId,
            memoryYear: memory ? _memoryYear : null,
            memoryCategory: memory ? _memoryCategory : null,
          );
      _posted = true;
      unawaited(_saveDraft('', const []));
      widget.onPosted(post);
      ref.invalidate(postFeedProvider(''));
      if (widget.eventId != null) {
        ref.invalidate(postFeedProvider(widget.communityId));
      }
      if (memory) {
        ref.invalidate(memoriesProvider);
        ref.invalidate(memoryYearsProvider(widget.communityId));
      }
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final where = widget.eventTitle != null
        ? 'Sharing photos from ${widget.eventTitle}'
        : widget.communityName.isEmpty
        ? 'Posting to the community'
        : 'Posting in ${widget.communityName}';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: kCardLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.asMemory ? 'Add a memory' : 'New post',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kTxt,
                    ),
                  ),
                ),
                CommunityPill(
                  label: _busy ? 'Posting…' : 'Post',
                  filled: true,
                  onTap: _busy || _uploading != null ? null : _post,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const MyAvatar(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: kTxt3),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _text,
              autofocus: !widget.asMemory,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, color: kTxt, height: 1.4),
              decoration: InputDecoration(
                hintText: widget.eventId != null
                    ? 'Share photos and memories from the event'
                    : widget.asMemory
                    ? 'What do you remember about this photo?'
                    : 'Share a memory, a question or an update',
                hintStyle: const TextStyle(color: kTxt3),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
              ),
            ),
            SizedBox(
              height: 72,
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                onReorder: (from, to) => setState(() {
                  final url = _photoUrls.removeAt(from);
                  _photoUrls.insert(to > from ? to - 1 : to, url);
                }),
                footer: _photoUrls.length >= _maxPhotos
                    ? null
                    : InkWell(
                        onTap: _uploading != null ? null : _addPhotos,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(color: kCardLine, width: 1.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _uploading != null
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.crimson,
                                    ),
                                  ),
                                )
                              : const HugeIcon(
                                  icon: HugeIcons.strokeRoundedImage01,
                                  color: AppColors.crimson,
                                ),
                        ),
                      ),
                children: [
                  for (var i = 0; i < _photoUrls.length; i++)
                    Padding(
                      key: ValueKey(_photoUrls[i]),
                      padding: const EdgeInsets.only(right: 8),
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: NetworkPhoto(
                                url: _photoUrls[i],
                                maxHeight: 64,
                                borderRadius: 10,
                                openOnTap: false,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _photoUrls.removeAt(i)),
                                child: Semantics(
                                  button: true,
                                  label: 'Remove photo ${i + 1}',
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCancel01,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
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
            if (_canBeMemory) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
                decoration: communityCard(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedNote01,
                          color: AppColors.crimson,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'School memory',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTxt,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _memory,
                          activeTrackColor: AppColors.crimson,
                          onChanged: (v) => setState(() => _memory = v),
                        ),
                      ],
                    ),
                    if (_memory)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _memoryYear,
                              isExpanded: true,
                              decoration: appInputDecoration('Year'),
                              items: [
                                for (final y in _memoryYears)
                                  DropdownMenuItem(value: y, child: Text('$y')),
                              ],
                              onChanged: (v) => setState(() => _memoryYear = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _memoryCategory,
                              isExpanded: true,
                              decoration: appInputDecoration('What is it?'),
                              items: [
                                for (final (code, label) in kMemoryCategories)
                                  DropdownMenuItem(
                                    value: code,
                                    child: Text(label),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _memoryCategory = v),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${_photoUrls.length}/$_maxPhotos photos',
              style: const TextStyle(fontSize: 11.5, color: kTxt3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Members tab ──────────────────────────────────────────────────────────────

/// Search by name, filter by batch, connect or message from the row.
class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab({required this.community});

  final Community community;

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int? _batch;

  /// Pages loaded so far; reaching the end adds one.
  int _pages = 1;

  /// People I sent a request to from this screen (until the list reloads).
  final _requested = <String>{};

  static final _years = List.generate(
    DateTime.now().year + 2 - 1980,
    (i) => DateTime.now().year + 1 - i,
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() {
        _query = text.trim();
        _pages = 1;
      }),
    );
  }

  CommunityMembersQuery _page(int i) =>
      (communityId: widget.community.id, q: _query, batch: _batch, page: i);

  Future<void> _act(Person p) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (p.relation) {
        case 'CONNECTED':
          final chat = await ref.read(chatRepositoryProvider).openWith(p.id);
          if (mounted) context.push('/home/chat/${chat.id}');
          return;
        case 'PENDING_IN':
          await ref.read(connectionRepositoryProvider).accept(p.id);
        default:
          await ref.read(connectionRepositoryProvider).request(p.id);
          setState(() => _requested.add(p.id));
      }
      refreshConnections(ref, otherUserId: p.id);
      ref.invalidate(communityMembersProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.community;
    final pages = [
      for (var i = 0; i < _pages; i++)
        ref.watch(communityMembersProvider(_page(i))),
    ];
    final people = [for (final p in pages) ...?p.valueOrNull];
    final last = pages.last;
    final filtered = _query.isNotEmpty || _batch != null;
    final online = c.isMember
        ? ref.watch(communityChatSummaryProvider(c.id)).valueOrNull?.onlineCount
        : null;
    final hasMore = (last.valueOrNull?.length ?? 0) >= kPeoplePageSize;

    return CommunityTabBody(
      storageKey: 'members-${c.id}',
      onNearEnd: () {
        if (hasMore && !last.isLoading) setState(() => _pages++);
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: _onSearch,
                          textInputAction: TextInputAction.search,
                          decoration: appInputDecoration('Search members')
                              .copyWith(
                                prefixIcon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedSearch01,
                                  size: 20,
                                ),
                                isDense: true,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: communityCard(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _batch,
                            hint: const Text(
                              'Batch',
                              style: TextStyle(fontSize: 13),
                            ),
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowDown01,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Any batch'),
                              ),
                              for (final y in _years)
                                DropdownMenuItem(value: y, child: Text('$y')),
                            ],
                            onChanged: (v) => setState(() {
                              _batch = v;
                              _pages = 1;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    [
                      c.membersLabel,
                      if ((online ?? 0) > 0) '$online active now',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: kTxt3),
                  ),
                  const SizedBox(height: 8),
                  if (people.isEmpty && pages.first.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.crimson,
                        ),
                      ),
                    )
                  else if (people.isEmpty && pages.first.hasError)
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(communityMembersProvider(_page(0))),
                      child: Text(
                        '${friendlyError(pages.first.error!)}  Retry',
                      ),
                    )
                  else if (people.isEmpty)
                    EmptyState(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      image: kEmptyInboxImage,
                      title: filtered ? 'No members found' : 'No one else yet',
                      message: filtered
                          ? 'Try another name or batch.'
                          : "You're the only member so far. Invite your batchmates!",
                    ),
                ],
              ),
              // One card around the list, but rows are built lazily as they scroll in.
              if (people.isNotEmpty)
                DecoratedSliver(
                  decoration: communityCard(),
                  sliver: SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.builder(
                      itemCount: people.length,
                      itemBuilder: (context, i) => _MemberRow(
                        key: ValueKey(people[i].id),
                        person: people[i],
                        divider: i < people.length - 1,
                        requested: _requested.contains(people[i].id),
                        onAction: () => _act(people[i]),
                      ),
                    ),
                  ),
                ),
              if (last.isLoading && people.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.crimson,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.person,
    required this.divider,
    required this.requested,
    required this.onAction,
  });

  final Person person;
  final bool divider;
  final bool requested;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final status = p.online ? 'Active now' : null;
    final subtitle = [
      p.detail,
      if (status != null)
        status
      else if (p.mutualCount > 0)
        '${p.mutualCount} mutual',
    ].where((s) => s.isNotEmpty).join(' · ');

    final Widget action = switch (p.relation) {
      'CONNECTED' => IconButton.filledTonal(
        tooltip: 'Message ${p.name}',
        style: IconButton.styleFrom(
          backgroundColor: kTint,
          foregroundColor: AppColors.crimson,
        ),
        onPressed: onAction,
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedMessage01, size: 18),
      ),
      _ when requested || p.relation == 'PENDING_OUT' => const _SmallPill(
        'Requested',
      ),
      'PENDING_IN' => CommunityPill(
        label: 'Accept',
        filled: true,
        onTap: onAction,
      ),
      _ => _SmallPill('Connect', onTap: onAction, outlined: true),
    };

    return InkWell(
      onTap: () => context.push('/home/profile/${p.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: Color(0xFFF0E6E6)))
              : null,
        ),
        child: Row(
          children: [
            AvatarCircle(
              initials: p.initials,
              imageUrl: p.profilePicUrl,
              bg: p.bg,
              fg: p.fg,
              online: p.online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTxt,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kTxt3),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.label, {this.onTap, this.outlined = false});

  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.white : kTint,
      shape: StadiumBorder(
        side: outlined
            ? const BorderSide(color: Color(0xFFE5D6D6))
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onTap == null ? kTxt3 : AppColors.crimsonDark,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Owner: people waiting to join ────────────────────────────────────────────

class JoinRequestsScreen extends ConsumerStatefulWidget {
  const JoinRequestsScreen({super.key, required this.communityId});

  final String communityId;

  @override
  ConsumerState<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends ConsumerState<JoinRequestsScreen> {
  bool _busy = false;

  Future<void> _decide(List<String> userIds, {required bool approve}) async {
    setState(() => _busy = true);
    try {
      for (final id in userIds) {
        await ref
            .read(communityRepositoryProvider)
            .decide(widget.communityId, id, approve: approve);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      ref.invalidate(joinRequestsProvider(widget.communityId));
      ref.invalidate(communityProvider(widget.communityId));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(joinRequestsProvider(widget.communityId));
    final count = requests.valueOrNull?.length ?? 0;

    Widget round(
      AppIconData icon,
      bool filled,
      VoidCallback onTap,
      String tip,
    ) => IconButton.filled(
      tooltip: tip,
      style: IconButton.styleFrom(
        backgroundColor: filled ? AppColors.crimson : kTint,
        foregroundColor: filled ? Colors.white : kTxt2,
      ),
      onPressed: _busy ? null : onTap,
      icon: HugeIcon(icon: icon, size: 18),
    );

    return Scaffold(
      backgroundColor: kCommunityBg,
      appBar: AppBar(
        backgroundColor: AppColors.crimson,
        foregroundColor: Colors.white,
        surfaceTintColor: AppColors.crimson,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Join requests',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (count > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.crimsonDark,
                ),
              ),
            ),
        ],
      ),
      body: requests.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.crimson),
        ),
        error: (e, _) => Center(
          child: EmptyState(
            icon: HugeIcons.strokeRoundedWifiOff01,
            title: 'Could not load requests',
            message: friendlyError(e),
            action: TextButton(
              onPressed: () =>
                  ref.invalidate(joinRequestsProvider(widget.communityId)),
              child: const Text('Retry'),
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: HugeIcons.strokeRoundedUserCheck01,
                  image: kEmptyInboxImage,
                  title: 'No requests right now',
                  message: 'When someone asks to join, they appear here.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Container(
                    decoration: communityCard(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: i < list.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFF0E6E6),
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push(
                                    '/home/profile/${list[i].person.id}',
                                  ),
                                  child: AvatarCircle(
                                    initials: list[i].person.initials,
                                    imageUrl: list[i].person.profilePicUrl,
                                    bg: list[i].person.bg,
                                    fg: list[i].person.fg,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        list[i].person.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kTxt,
                                        ),
                                      ),
                                      Text(
                                        [
                                              list[i].person.detail,
                                              shortTimeAgo(list[i].requestedAt),
                                            ]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · '),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: kTxt3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                round(
                                  HugeIcons.strokeRoundedCancel01,
                                  false,
                                  () => _decide([
                                    list[i].person.id,
                                  ], approve: false),
                                  'Reject',
                                ),
                                round(
                                  HugeIcons.strokeRoundedTick02,
                                  true,
                                  () => _decide([
                                    list[i].person.id,
                                  ], approve: true),
                                  'Approve',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (list.length > 1) ...[
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _decide([
                              for (final r in list) r.person.id,
                            ], approve: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.crimson,
                        side: const BorderSide(color: kCardLine),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Approve all ${list.length}'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
