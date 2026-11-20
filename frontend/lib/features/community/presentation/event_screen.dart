import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/community/presentation/post_card.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// "Sat, 20 Dec · 6:00 pm – 9:00 pm", or both dates when it runs overnight.
String eventWhenLabel(CommunityEvent e) {
  String time(DateTime t) => DateFormat('h:mm a').format(t).toLowerCase();
  final day = DateFormat('EEE, d MMM');
  final start = '${day.format(e.startsAt)} · ${time(e.startsAt)}';
  final end = e.endsAt;
  if (end == null) return start;
  return DateUtils.isSameDay(end, e.startsAt)
      ? '$start – ${time(end)}'
      : '$start – ${day.format(end)} · ${time(end)}';
}

/// Going / Interested, then refresh every list that shows the event.
/// Tapping my current answer clears it.
Future<void> setEventRsvp(
  BuildContext context,
  WidgetRef ref,
  CommunityEvent e,
  String status,
) async {
  try {
    await ref
        .read(communityRepositoryProvider)
        .setRsvp(e.id, e.myRsvp == status ? null : status);
    ref.invalidate(eventProvider(e.id));
    ref.invalidate(eventAttendeesProvider(e.id));
    ref.invalidate(communityEventsProvider((e.communityId, false)));
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(err))));
    }
  }
}

/// Month over day, as on a desk calendar.
class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.date,
    this.strong = true,
    this.muted = false,
  });

  final DateTime date;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bg = muted
        ? const Color(0xFFF3F0EC)
        : (strong ? AppColors.crimson : kCrimsonLight);
    final fg = muted ? kTxt2 : (strong ? Colors.white : AppColors.crimson);
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── On the Feed tab ──────────────────────────────────────────────────────────

/// The next event, highlighted at the top of the feed (with a Going button).
class NextEventCard extends ConsumerWidget {
  const NextEventCard({super.key, required this.community});

  final Community community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref
        .watch(communityEventsProvider((community.id, false)))
        .valueOrNull;
    final next = list?.events.where((e) => !e.cancelled).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final going = next.myRsvp == 'GOING';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/home/event/${next.id}'),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: communityCard(
              color: const Color(0xFFFFFBF2),
              line: const Color(0xFFE8D3A2),
            ),
            child: Row(
              children: [
                _DateBadge(date: next.startsAt),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTxt,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('EEE h:mm a').format(next.startsAt)} · ${next.goingCount} going',
                        style: const TextStyle(fontSize: 12, color: kTxt3),
                      ),
                    ],
                  ),
                ),
                if (community.isMember)
                  CommunityPill(
                    label: going ? 'Going' : 'Go',
                    icon: going ? HugeIcons.strokeRoundedTick02 : null,
                    filled: going,
                    onTap: () => setEventRsvp(context, ref, next, 'GOING'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Events tab ───────────────────────────────────────────────────────────────

class EventsTab extends ConsumerWidget {
  const EventsTab({super.key, required this.community});

  final Community community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final upcoming = ref.watch(communityEventsProvider((c.id, false)));
    final past = ref.watch(communityEventsProvider((c.id, true)));
    final canCreate = upcoming.valueOrNull?.canCreate ?? false;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: kTxt,
        ),
      ),
    );

    List<Widget> section(
      AsyncValue<EventList> value,
      String empty,
      List<Widget> Function(List<CommunityEvent>) build,
    ) => value.when(
      loading: () => [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.crimson),
          ),
        ),
      ],
      error: (e, _) => [
        Text(
          friendlyError(e),
          style: const TextStyle(fontSize: 12, color: kTxt3),
        ),
      ],
      data: (l) => l.events.isEmpty
          ? [Text(empty, style: const TextStyle(fontSize: 12.5, color: kTxt3))]
          : build(l.events),
    );

    return CommunityTabBody(
      storageKey: 'events-${c.id}',
      onRefresh: () async {
        ref.invalidate(communityEventsProvider((c.id, false)));
        ref.invalidate(communityEventsProvider((c.id, true)));
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          sliver: SliverList.list(
            children: [
              if (canCreate)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      CommunityPill(
                        label: 'Create an event',
                        icon: HugeIcons.strokeRoundedAdd01,
                        filled: true,
                        expand: true,
                        onTap: () => showEventForm(context, ref, c.id),
                      ),
                    ],
                  ),
                ),
              heading('Upcoming'),
              ...section(
                upcoming,
                canCreate
                    ? 'Nothing planned yet. Plan a reunion or meetup.'
                    : 'Nothing planned yet.',
                (events) => [
                  _FeaturedEvent(event: events.first, community: c),
                  for (final e in events.skip(1)) EventTile(event: e),
                ],
              ),
              heading('Past'),
              ...section(
                past,
                'No past events yet.',
                (events) => [for (final e in events) EventTile(event: e)],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The soonest event, big: cover, when, where, and the RSVP buttons.
class _FeaturedEvent extends ConsumerWidget {
  const _FeaturedEvent({required this.event, required this.community});

  final CommunityEvent event;
  final Community community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/home/event/${e.id}'),
          child: Ink(
            decoration: communityCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: SizedBox(
                    height: 110,
                    child: e.coverUrl != null
                        ? NetworkPhoto(
                            url: e.coverUrl!,
                            maxHeight: 110,
                            borderRadius: 0,
                            openOnTap: false,
                          )
                        : Container(
                            color: const Color(0xFFF2E6D6),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedParty,
                              size: 34,
                              color: Color(0xFFB08A5A),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventWhenLabel(e).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.crimson,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTxt,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedLocation01,
                            size: 14,
                            color: kTxt3,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              e.venue,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kTxt3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.cancelled
                                  ? 'Cancelled'
                                  : '${e.goingCount} going · ${e.interestedCount} interested',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: e.cancelled ? Colors.redAccent : kTxt2,
                              ),
                            ),
                          ),
                          if (community.isMember && !e.cancelled) ...[
                            CommunityPill(
                              label: 'Going',
                              filled: e.myRsvp == 'GOING',
                              onTap: () =>
                                  setEventRsvp(context, ref, e, 'GOING'),
                            ),
                            const SizedBox(width: 6),
                            CommunityPill(
                              label: 'Interested',
                              filled: e.myRsvp == 'INTERESTED',
                              onTap: () =>
                                  setEventRsvp(context, ref, e, 'INTERESTED'),
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
      ),
    );
  }
}

/// Date badge, title, when and where; past events show their photos.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final past = !e.started
        ? false
        : (e.endsAt ?? e.startsAt).isBefore(
            DateTime.now(),
          ); // endsAt is always set now
    final status = e.cancelled
        ? 'Cancelled'
        : past
        ? (e.photoCount > 0
              ? '${e.photoCount} ${e.photoCount == 1 ? 'photo' : 'photos'} shared'
              : 'No photos yet')
        : [
            '${e.goingCount} going',
            if (e.myRsvp == 'GOING') "You're going",
            if (e.myRsvp == 'INTERESTED') "You're interested",
          ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/home/event/${e.id}'),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: communityCard(),
            child: Row(
              children: [
                _DateBadge(
                  date: e.startsAt,
                  strong: false,
                  muted: past || e.cancelled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTxt,
                          decoration: e.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('h:mm a').format(e.startsAt).toLowerCase()} · ${e.venue}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kTxt3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: e.cancelled
                              ? Colors.redAccent
                              : AppColors.crimson,
                        ),
                      ),
                    ],
                  ),
                ),
                if (past && !e.cancelled)
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedImage02,
                    size: 20,
                    color: AppColors.crimson,
                  )
                else
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: kTxt3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── One event ────────────────────────────────────────────────────────────────

/// Cover, when, where, who's organizing, Going / Interested, details, and
/// the photos members shared from it.
class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  Future<void> _cancel(CommunityEvent e) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel ${e.title}?',
      message:
          "Everyone who said Going or Interested will be told. This can't be undone.",
      action: 'Cancel event',
    );
    if (!ok) return;
    try {
      await ref.read(communityRepositoryProvider).cancelEvent(e.id);
      ref.invalidate(eventProvider(e.id));
      ref.invalidate(communityEventsProvider((e.communityId, false)));
      ref.invalidate(communityEventsProvider((e.communityId, true)));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(err))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kCommunityBg,
        body: event.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.crimson),
          ),
          error: (e, _) => SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
                EmptyState(
                  icon: HugeIcons.strokeRoundedCalendarRemove01,
                  image: kEmptyInboxImage,
                  title: statusOf(e) == 404
                      ? 'Event not found'
                      : "Couldn't load this event",
                  message: friendlyError(e),
                ),
              ],
            ),
          ),
          data: _body,
        ),
      ),
    );
  }

  Widget _body(CommunityEvent e) {
    final community = ref.watch(communityProvider(e.communityId)).valueOrNull;
    final isMember = community?.isMember ?? false;
    final posts = ref.watch(eventPostsProvider(e.id));
    final feed = ref.read(eventPostsProvider(e.id).notifier);
    final going =
        ref.watch(eventAttendeesProvider(e.id)).valueOrNull?['GOING'] ??
        const <Person>[];
    final photoPosts = posts.items
        .where((p) => p.imageUrls.isNotEmpty)
        .toList();
    final textPosts = posts.items.where((p) => p.imageUrls.isEmpty).toList();

    Widget infoRow(
      Widget leading,
      String text, {
      VoidCallback? onTap,
      bool divider = true,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: Color(0xFFF0E6E6)))
              : null,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13.5, color: kTxt),
              ),
            ),
            if (onTap != null)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: kTxt3,
              ),
          ],
        ),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: e.coverUrl != null ? 210 : null,
          backgroundColor: AppColors.crimson,
          foregroundColor: Colors.white,
          surfaceTintColor: AppColors.crimson,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: e.coverUrl == null
              ? const Text(
                  'Event',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                )
              : null,
          leading: IconButton(
            tooltip: 'Back',
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (e.canManage && !e.cancelled)
              PopupMenuButton<String>(
                tooltip: 'Manage event',
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical),
                onSelected: (v) => v == 'edit'
                    ? showEventForm(context, ref, e.communityId, existing: e)
                    : _cancel(e),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      'Cancel event',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
          ],
          flexibleSpace: e.coverUrl == null
              ? null
              : FlexibleSpaceBar(
                  background: NetworkPhoto(
                    url: e.coverUrl!,
                    maxHeight: 260,
                    borderRadius: 0,
                    openOnTap: false,
                  ),
                ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(
            children: [
              if (e.cancelled)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'This event was cancelled.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                eventWhenLabel(e).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.crimson,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kTxt,
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: () => context.push('/home/community/${e.communityId}'),
                child: Text(
                  e.communityName,
                  style: const TextStyle(fontSize: 12.5, color: kTxt3),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: communityCard(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    infoRow(
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        size: 18,
                        color: AppColors.crimson,
                      ),
                      e.venue,
                    ),
                    if (e.organizer case final o?)
                      infoRow(
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          size: 18,
                          color: AppColors.crimson,
                        ),
                        'Organized by ${o.name}',
                        onTap: () => context.push('/home/profile/${o.id}'),
                      ),
                    infoRow(
                      going.isEmpty
                          ? const HugeIcon(
                              icon: HugeIcons.strokeRoundedUserGroup,
                              size: 18,
                              color: AppColors.crimson,
                            )
                          : AvatarStack(people: going, size: 22),
                      '${e.goingCount} going · ${e.interestedCount} interested',
                      divider: false,
                      onTap: e.goingCount + e.interestedCount == 0
                          ? null
                          : () => _showAttendees(e),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!e.cancelled)
                isMember
                    ? Row(
                        children: [
                          CommunityPill(
                            label: 'Going',
                            icon: e.myRsvp == 'GOING'
                                ? HugeIcons.strokeRoundedTick02
                                : HugeIcons.strokeRoundedCalendarCheck01,
                            filled: e.myRsvp == 'GOING',
                            expand: true,
                            onTap: () => setEventRsvp(context, ref, e, 'GOING'),
                          ),
                          const SizedBox(width: 10),
                          CommunityPill(
                            label: 'Interested',
                            icon: e.myRsvp == 'INTERESTED'
                                ? HugeIcons.strokeRoundedTick02
                                : HugeIcons.strokeRoundedStar,
                            filled: e.myRsvp == 'INTERESTED',
                            expand: true,
                            onTap: () =>
                                setEventRsvp(context, ref, e, 'INTERESTED'),
                          ),
                        ],
                      )
                    : const Text(
                        "Join the community to say you're going.",
                        style: TextStyle(fontSize: 12.5, color: kTxt3),
                      ),
              if ((e.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  e.description!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kTxt,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Photos and memories',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kTxt,
                      ),
                    ),
                  ),
                  if (isMember && e.started && !e.cancelled)
                    TextButton.icon(
                      onPressed: () => showPostComposer(
                        context,
                        communityId: e.communityId,
                        communityName: e.communityName,
                        eventId: e.id,
                        eventTitle: e.title,
                        onPosted: feed.prepend,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.crimson,
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedImage01,
                        size: 18,
                      ),
                      label: const Text('Share'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (photoPosts.isNotEmpty)
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    for (final p in photoPosts)
                      GestureDetector(
                        onTap: () => context.push('/home/post/${p.id}'),
                        child: NetworkPhoto(
                          url: p.imageUrls.first,
                          maxHeight: 160,
                          borderRadius: 8,
                          openOnTap: false,
                        ),
                      ),
                  ],
                ),
              for (final p in textPosts) ...[
                const SizedBox(height: 10),
                PostCard(
                  post: p,
                  onChanged: feed.replace,
                  onDeleted: () => feed.remove(p.id),
                ),
              ],
              if (posts.loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.crimson),
                  ),
                )
              else if (posts.hasMore)
                TextButton(
                  onPressed: feed.loadMore,
                  child: const Text('Show more'),
                )
              else if (posts.items.isEmpty)
                Text(
                  e.started
                      ? 'No photos yet. Were you there? Share yours.'
                      : 'Photos can be shared once the event starts.',
                  style: const TextStyle(fontSize: 12.5, color: kTxt3),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAttendees(CommunityEvent e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => Consumer(
          builder: (context, ref, _) {
            final people = ref.watch(eventAttendeesProvider(e.id));
            return people.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.crimson),
              ),
              error: (err, _) => Center(
                child: EmptyState(
                  icon: HugeIcons.strokeRoundedWifiOff01,
                  title: 'Could not load who is going',
                  message: friendlyError(err),
                  action: TextButton(
                    onPressed: () =>
                        ref.invalidate(eventAttendeesProvider(e.id)),
                    child: const Text('Retry'),
                  ),
                ),
              ),
              data: (groups) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  for (final (key, label) in const [
                    ('GOING', 'Going'),
                    ('INTERESTED', 'Interested'),
                  ])
                    if ((groups[key] ?? const []).isNotEmpty) ...[
                      SectionLabel('$label · ${groups[key]!.length}'),
                      for (final p in groups[key]!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarCircle(
                            initials: p.initials,
                            imageUrl: p.profilePicUrl,
                            bg: p.bg,
                            fg: p.fg,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            [
                              p.detail,
                              p.school,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.of(sheet).pop();
                            context.push('/home/profile/${p.id}');
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Create / edit ────────────────────────────────────────────────────────────

Future<void> showEventForm(
  BuildContext context,
  WidgetRef ref,
  String communityId, {
  CommunityEvent? existing,
}) async {
  final saved = await showModalBottomSheet<CommunityEvent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _EventForm(communityId: communityId, existing: existing),
  );
  if (saved == null) return;
  ref.invalidate(communityEventsProvider((communityId, false)));
  ref.invalidate(communityEventsProvider((communityId, true)));
  ref.invalidate(eventProvider(saved.id));
  if (existing == null && context.mounted) {
    context.push('/home/event/${saved.id}');
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({required this.communityId, this.existing});

  final String communityId;
  final CommunityEvent? existing;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _venue = TextEditingController(text: widget.existing?.venue);
  late final _details = TextEditingController(
    text: widget.existing?.description,
  );
  // Start and end each have a date and a time, and all four are required.
  late DateTime? _date = widget.existing?.startsAt;
  late TimeOfDay? _start = widget.existing == null
      ? null
      : TimeOfDay.fromDateTime(widget.existing!.startsAt);
  late DateTime? _endDate = widget.existing?.endsAt;
  late TimeOfDay? _end = widget.existing?.endsAt == null
      ? null
      : TimeOfDay.fromDateTime(widget.existing!.endsAt!);
  late String? _cover = widget.existing?.coverUrl;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = start ? _date : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _date ?? today,
      // Plan from today on; an event being edited may already sit earlier.
      firstDate: current != null && current.isBefore(today) ? current : today,
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _date = picked;
        // End defaults to the same day (or later, if the start moved past it).
        if (_endDate == null || _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (start ? _start : _end) ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _pickCover() async {
    final picked = await pickPhotos(context, max: 1);
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(mediaRepositoryProvider)
          .uploadPhoto(picked.first, kind: UploadKind.event);
      if (mounted) setState(() => _cover = url);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DateTime _at(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  Future<void> _save() async {
    final title = _title.text.trim();
    final venue = _venue.text.trim();
    final error = title.length < 3
        ? 'Give it a title of at least 3 characters'
        : venue.isEmpty
        ? 'Where is it? Add a venue, or write Online'
        : _date == null || _start == null
        ? 'Pick the start date and time'
        : _endDate == null || _end == null
        ? 'Pick the end date and time'
        : !_at(_endDate!, _end!).isAfter(_at(_date!, _start!))
        ? 'The event must end after it starts'
        : !_at(_endDate!, _end!).isAfter(DateTime.now())
        ? 'That end time has already passed. Pick a later one'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(communityRepositoryProvider)
          .saveEvent(
            communityId: widget.communityId,
            eventId: widget.existing?.id,
            title: title,
            venue: venue,
            startsAt: _at(_date!, _start!),
            endsAt: _at(_endDate!, _end!),
            description: _details.text,
            coverUrl: _cover,
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      AppIconData icon,
      String? value,
      String hint,
      VoidCallback onTap,
    ) => Expanded(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: kCardLine),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                HugeIcon(icon: icon, size: 18, color: AppColors.crimson),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: value == null ? kTxt3 : kTxt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    const label = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: kTxt2,
      letterSpacing: 0.4,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
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
                    widget.existing == null ? 'Create an event' : 'Edit event',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kTxt,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: kTxt3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _busy ? null : _pickCover,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: _cover == null ? 70 : 130,
                decoration: BoxDecoration(
                  border: Border.all(color: kCardLine, width: 1.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _cover == null
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedImage01,
                            size: 18,
                            color: AppColors.crimson,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add a cover photo',
                            style: TextStyle(
                              color: AppColors.crimson,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkPhoto(
                            url: _cover!,
                            maxHeight: 130,
                            borderRadius: 0,
                            openOnTap: false,
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: IconButton.filled(
                              tooltip: 'Remove cover',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: () => setState(() => _cover = null),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCancel01,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('TITLE', style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: appInputDecoration('Class of 2015 reunion'),
            ),
            const Text('STARTS', style: label),
            const SizedBox(height: 6),
            Row(
              children: [
                field(
                  HugeIcons.strokeRoundedCalendar03,
                  _date == null
                      ? null
                      : DateFormat('EEE, d MMM').format(_date!),
                  'Date',
                  () => _pickDate(start: true),
                ),
                const SizedBox(width: 8),
                field(
                  HugeIcons.strokeRoundedClock01,
                  _start?.format(context),
                  'Time',
                  () => _pickTime(true),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('ENDS', style: label),
            const SizedBox(height: 6),
            Row(
              children: [
                field(
                  HugeIcons.strokeRoundedCalendarCheck01,
                  _endDate == null
                      ? null
                      : DateFormat('EEE, d MMM').format(_endDate!),
                  'Date',
                  () => _pickDate(start: false),
                ),
                const SizedBox(width: 8),
                field(
                  HugeIcons.strokeRoundedClock01,
                  _end?.format(context),
                  'Time',
                  () => _pickTime(false),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('WHERE', style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _venue,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: appInputDecoration('APS Pune hall, or Online')
                  .copyWith(
                    prefixIcon: fieldIconSlot(
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        size: 18,
                        color: AppColors.crimson,
                      ),
                    ),
                  ),
            ),
            const Text('DETAILS (OPTIONAL)', style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _details,
              maxLength: 2000,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: appInputDecoration(
                'Agenda, dress code, contribution, who to contact',
              ),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                CommunityPill(
                  label: _busy
                      ? 'Saving…'
                      : widget.existing == null
                      ? 'Create event'
                      : 'Save changes',
                  filled: true,
                  expand: true,
                  onTap: _busy ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
