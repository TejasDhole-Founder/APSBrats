import 'dart:async';

import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Communities bottom tab: my schools to join (cover cards), the
/// communities I'm in (a swipeable row), and Discover (only ones I'm not in).
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
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
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
          CrimsonHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Communities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    FeedIconBtn(
                      icon: Icons.add_rounded,
                      onTap: () => showCreateCommunitySheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: appInputDecoration('Search communities').copyWith(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
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
                      data: (m) => [
                        if (m.suggested.isNotEmpty) ...[
                          _heading('Your schools'),
                          for (final c in m.suggested) ...[
                            SchoolCommunityCard(community: c),
                            const SizedBox(height: 10),
                          ],
                        ],
                        _heading(
                          'Your communities',
                          trailing: m.joined.isEmpty
                              ? null
                              : Text(
                                  '${m.joined.length}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kTxt3,
                                  ),
                                ),
                        ),
                        if (m.joined.isEmpty)
                          const Text(
                            "You haven't joined any yet. Join your school above, or find a group below.",
                            style: TextStyle(fontSize: 12.5, color: kTxt3),
                          )
                        else
                          SizedBox(
                            height: 148,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: m.joined.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, i) =>
                                  _JoinedCard(community: m.joined[i]),
                            ),
                          ),
                      ],
                    ),
                  _heading(
                    _query.isEmpty ? 'Discover' : 'Results for "$_query"',
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
                      return [
                        if (list.isEmpty && _query.isNotEmpty)
                          EmptyState(
                            icon: Icons.groups_outlined,
                            image: kEmptyInboxImage,
                            title: 'Nothing found',
                            message:
                                'No community matches "$_query". You could create it.',
                          )
                        else if (list.isEmpty)
                          const Text(
                            "You're in every group so far.",
                            style: TextStyle(fontSize: 12.5, color: kTxt3),
                          )
                        else
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
                        const SizedBox(height: 12),
                        PromptCard(
                          hint: "Can't find your group? Create one",
                          leading: const Icon(
                            Icons.group_add_outlined,
                            color: AppColors.crimson,
                            size: 26,
                          ),
                          trailingIcon: Icons.add_circle_outline_rounded,
                          onTap: () => showCreateCommunitySheet(context),
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

/// One of my schools I haven't joined: a cover strip, the APS badge, Join.
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
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.crimson,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 26, 12, 12),
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
                        CommunityPill(
                          label: 'Join',
                          icon: Icons.add_rounded,
                          filled: true,
                          onTap: () => _joinCommunity(context, ref, c),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 12,
                top: 22,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2.5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: CommunityIcon(community: c, size: 42, onDark: true),
                ),
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
      width: 144,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/home/community/${c.id}'),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: communityCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CommunityIcon(community: c, size: 40),
                    const Spacer(),
                    if (c.isOwner)
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: AppColors.gold,
                        semanticLabel: 'Owner',
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTxt,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                Text(
                  c.isOwner ? 'Owner · ${c.membersLabel}' : c.membersLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: kTxt3),
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
/// Requested / Joined. Tap to open it.
class CommunityTile extends ConsumerWidget {
  const CommunityTile({
    super.key,
    required this.community,
    this.divider = false,
  });

  final Community community;
  final bool divider;

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
            if (c.isMember)
              _Pill(c.isOwner ? 'Owner' : 'Joined')
            else if (c.requested)
              const _Pill('Requested')
            else
              CommunityPill(
                label: c.isPrivate ? 'Request' : 'Join',
                filled: !c.isPrivate,
                onTap: () => _joinCommunity(context, ref, c),
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
          : Icon(
              community.isPrivate
                  ? Icons.lock_outline_rounded
                  : Icons.groups_rounded,
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
