import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Communities half of the Social tab: my schools, the communities I'm in
/// (a swipeable row with See all), and Discover (only ones I'm not in).
class CommunitiesTab extends ConsumerStatefulWidget {
  const CommunitiesTab({super.key});

  @override
  ConsumerState<CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<CommunitiesTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing before searching.
  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _query = text.trim()),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(myCommunitiesProvider);
    ref.invalidate(discoverProvider);
    await ref
        .read(myCommunitiesProvider.future)
        .catchError((_) => const MyCommunities(joined: [], suggested: []));
  }

  Widget _heading(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kTxt,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myCommunitiesProvider);
    final discover = ref.watch(discoverProvider(_query));

    return Container(
      color: kCommunityBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: FeedSearchBar(
                    hint: 'Search communities...',
                    controller: _search,
                    onChanged: _onSearch,
                  ),
                ),
                const SizedBox(width: 10),
                SquareIconButton(
                  icon: HugeIcons.strokeRoundedAdd01,
                  onTap: () => showCreateCommunitySheet(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.crimson,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                children: [
                  if (_query.isEmpty)
                    ...mine.when(
                      loading: () => [const _Loading()],
                      error: (e, _) => [
                        _ErrorRow(message: friendlyError(e), onRetry: _refresh),
                      ],
                      data: (m) {
                        final schools = [
                          ...m.joined.where((c) => c.isSchool),
                          ...m.suggested,
                        ];
                        final groups = m.joined
                            .where((c) => !c.isSchool)
                            .toList();
                        return [
                          if (schools.isNotEmpty) ...[
                            _heading('Your Schools'),
                            for (final c in schools) ...[
                              SchoolCommunityCard(community: c),
                              const SizedBox(height: 10),
                            ],
                          ],
                          _heading(
                            'Your Communities',
                            trailing: groups.isEmpty
                                ? null
                                : SeeAllButton(
                                    onTap: () =>
                                        context.push('/home/communities'),
                                  ),
                          ),
                          if (groups.isEmpty)
                            const Text(
                              "You haven't joined any yet. Find a group below.",
                              style: TextStyle(fontSize: 12.5, color: kTxt3),
                            )
                          else
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: groups.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (_, i) =>
                                    _JoinedCard(community: groups[i]),
                              ),
                            ),
                        ];
                      },
                    ),
                  _heading(
                    _query.isEmpty
                        ? 'Discover Communities'
                        : 'Results for "$_query"',
                  ),
                  ...discover.when(
                    loading: () => [const _Loading()],
                    error: (e, _) => [
                      _ErrorRow(message: friendlyError(e), onRetry: _refresh),
                    ],
                    data: (all) {
                      // Search shows everything that matches; browsing hides
                      // what I'm already in (it's in the row above).
                      final list = _query.isEmpty
                          ? all.where((c) => !c.isMember).toList()
                          : all;
                      if (list.isEmpty && _query.isNotEmpty) {
                        return [
                          EmptyState(
                            icon: HugeIcons.strokeRoundedUserGroup,
                            image: kEmptyInboxImage,
                            title: 'Nothing found',
                            message:
                                'No community matches "$_query". You could create it.',
                          ),
                        ];
                      }
                      if (list.isEmpty) {
                        return [
                          const Text(
                            "You're in every group so far.",
                            style: TextStyle(fontSize: 12.5, color: kTxt3),
                          ),
                        ];
                      }
                      return [
                        Container(
                          decoration: communityCard(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              for (var i = 0; i < list.length; i++)
                                CommunityTile(
                                  community: list[i],
                                  divider: i < list.length - 1,
                                ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Join (or request to join) a community, refreshing the lists.
Future<void> _joinCommunity(
  BuildContext context,
  WidgetRef ref,
  Community c,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final updated = await ref.read(communityRepositoryProvider).join(c.id);
    ref.invalidate(myCommunitiesProvider);
    ref.invalidate(discoverProvider);
    if (updated.requested) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Request sent. The owner will review it.'),
        ),
      );
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

/// White rounded square button (the "+" next to the search bar).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.onTap});

  final AppIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: HugeIcon(icon: icon, size: 22, color: AppColors.crimson),
        ),
      ),
    );
  }
}

/// "See all ›" in a dashed crimson outline.
class SeeAllButton extends StatelessWidget {
  const SeeAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(AppColors.crimson),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.crimson,
                ),
              ),
              SizedBox(width: 2),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: AppColors.crimson,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}

/// Outlined "✓ Joined" (or "Owner") pill.
class JoinedPill extends StatelessWidget {
  const JoinedPill({super.key, this.label = 'Joined'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.crimson),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedTick02,
            size: 14,
            color: AppColors.crimson,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.crimson,
            ),
          ),
        ],
      ),
    );
  }
}

/// A school community: cover strip, the APS badge, Join / ✓ Joined.
class SchoolCommunityCard extends ConsumerWidget {
  const SchoolCommunityCard({super.key, required this.community});

  final Community community;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/home/community/${c.id}'),
        child: Ink(
          decoration: communityCard(),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.crimson, AppColors.crimsonDark],
                      ),
                      image: communityBannerAsset(c) == null
                          ? null
                          : DecorationImage(
                              image: AssetImage(communityBannerAsset(c)!),
                              fit: BoxFit.cover,
                            ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kTxt,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.kindLabel} · ${c.membersLabel}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kTxt3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (c.isMember)
                          const JoinedPill()
                        else
                          CommunityPill(
                            label: 'Join',
                            filled: true,
                            onTap: () => _joinCommunity(context, ref, c),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A community I'm in, as a compact card in the swipeable row.
class _JoinedCard extends StatelessWidget {
  const _JoinedCard({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final c = community;
    return SizedBox(
      width: 172,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/home/community/${c.id}'),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: communityCard(),
            child: Row(
              children: [
                CommunityIcon(community: c, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kTxt,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.membersLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: kTxt3),
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

/// A community row: icon, name, kind and size, and Join / Request /
/// Requested / Joined. Tap to open it. [menu] adds a ⋮ (Open / Leave).
class CommunityTile extends ConsumerWidget {
  const CommunityTile({
    super.key,
    required this.community,
    this.divider = false,
    this.menu = false,
  });

  final Community community;
  final bool divider;
  final bool menu;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final c = community;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave ${c.name}?'),
        content: const Text("You'll stop seeing its posts and chat."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(communityRepositoryProvider).leave(c.id);
      ref
        ..invalidate(myCommunitiesProvider)
        ..invalidate(myCommunityChatsProvider)
        ..invalidate(discoverProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    return InkWell(
      onTap: () => context.push('/home/community/${c.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: Color(0xFFF0E6E6)))
              : null,
        ),
        child: Row(
          children: [
            CommunityIcon(community: c, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
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
                    '${c.kindLabel} · ${c.membersLabel}',
                    style: const TextStyle(fontSize: 12, color: kTxt3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (c.isOwner)
              const JoinedPill(label: 'Owner')
            else if (c.isMember)
              const JoinedPill()
            else if (c.requested)
              const _Pill('Requested')
            else
              CommunityPill(
                label: c.isPrivate ? 'Request' : 'Join',
                filled: !c.isPrivate,
                onTap: () => _joinCommunity(context, ref, c),
              ),
            if (menu)
              PopupMenuButton<String>(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreVertical,
                  color: kTxt,
                ),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'open') {
                    context.push('/home/community/${c.id}');
                  } else {
                    _leave(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('Open')),
                  if (c.isMember && !c.isOwner)
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('Leave community'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityIcon extends StatelessWidget {
  const CommunityIcon({
    super.key,
    required this.community,
    this.size = 42,
    this.onDark = false,
  });

  final Community community;
  final double size;

  /// On the crimson header the badge turns gold, so it doesn't vanish.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark
            ? AppColors.gold
            : (community.isSchool ? AppColors.crimson : kCrimsonLight),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: community.isSchool
          ? Text(
              'APS',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w800,
                color: onDark ? AppColors.crimsonDark : Colors.white,
              ),
            )
          : HugeIcon(
              icon: community.isPrivate
                  ? HugeIcons.strokeRoundedLockKey
                  : HugeIcons.strokeRoundedUserGroup,
              color: AppColors.crimson,
              size: size * 0.5,
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kTint,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kTxt2,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
  );
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: kTxt3),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

// ── Create a community ───────────────────────────────────────────────────────

Future<void> showCreateCommunitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CreateSheet(),
  );
}

class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet();

  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _private = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 3) {
      setState(() => _error = 'Give it a name of at least 3 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(communityRepositoryProvider)
          .create(
            name: _name.text,
            description: _description.text,
            isPrivate: _private,
          );
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(discoverProvider);
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/home/community/${created.id}');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create a community',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'For a field, an exam or an interest. You can make up to 5.',
              style: TextStyle(fontSize: 12, color: kTxt3),
            ),
            const SizedBox(height: 16),
            const Text('NAME', style: appFieldLabelStyle),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: appInputDecoration('Software Developers'),
            ),
            const Text(
              'WHAT IS IT ABOUT? (OPTIONAL)',
              style: appFieldLabelStyle,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLength: 500,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: appInputDecoration(
                'Careers, interviews and tech talk for APS alumni',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.crimson,
              title: const Text(
                'Private',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _private
                    ? 'People ask to join and you approve them. Only members see posts.'
                    : 'Public: anyone can join and read posts.',
                style: const TextStyle(fontSize: 12),
              ),
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.crimsonDark,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_busy ? 'Creating…' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
