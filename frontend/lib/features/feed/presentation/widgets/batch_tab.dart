import 'dart:async';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';

import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/connections/data/circle_repository.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/school_history_editor.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The people tab. At rest it shows MY circle (friends, classmates, everyone
/// from my schools ranked by mutual friends) — no search query runs. Typing a
/// name switches the same screen into search, scoped to my schools first.
class BatchTab extends ConsumerStatefulWidget {
  const BatchTab({super.key});

  @override
  ConsumerState<BatchTab> createState() => _BatchTabState();
}

enum _Segment { classmates, batchmates }

class _BatchTabState extends ConsumerState<BatchTab> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  // ── Search mode ──
  String _query = '';
  bool _everywhere = false;
  PeopleQuery _filters = kEveryoneQuery;
  int _pages = 1;

  // ── Circle mode ──
  _Segment _segment = _Segment.classmates;
  String? _entryId; // null = all my schools
  bool _batchOnly = false;
  int _circlePages = 1;

  /// Connection requests sent from this screen (so the button flips to "Requested").
  final _requested = <String>{};

  bool get _searching => _query.isNotEmpty || _hasFilters;
  bool get _hasFilters => _filters != kEveryoneQuery;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _query = text.trim();
          _pages = 1;
        });
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() {
      _query = '';
      _filters = kEveryoneQuery;
      _everywhere = false;
      _pages = 1;
    });
  }

  PeopleQuery get _searchQuery => (
    q: _query,
    schoolId: _filters.schoolId,
    batch: _filters.batch,
    classTo: _filters.classTo,
    section: _filters.section,
    stream: _filters.stream,
    status: _filters.status,
    city: _filters.city,
    mine: !_everywhere,
    page: 0,
  );

  PeopleQuery _searchPage(int page) => (
    q: _searchQuery.q,
    schoolId: _searchQuery.schoolId,
    batch: _searchQuery.batch,
    classTo: _searchQuery.classTo,
    section: _searchQuery.section,
    stream: _searchQuery.stream,
    status: _searchQuery.status,
    city: _searchQuery.city,
    mine: _searchQuery.mine,
    page: page,
  );

  CirclePage _circlePage(int page) =>
      (entryId: _entryId, batchOnly: _batchOnly, page: page);

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<PeopleQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FiltersSheet(initial: _filters),
    );
    if (result != null) {
      setState(() {
        _filters = result;
        _pages = 1;
      });
    }
  }

  void _openProfile(Person p) => context.go('/home/profile/${p.id}');

  Future<void> _connect(Person p) async {
    setState(() => _requested.add(p.id));
    try {
      await ref.read(connectionRepositoryProvider).request(p.id);
      refreshConnections(ref, otherUserId: p.id);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _requested.remove(p.id));
      final payload = e.response?.data;
      final message = payload is Map && payload['error'] is String
          ? payload['error'] as String
          : 'Could not send request. Try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _accept(Person p) async {
    try {
      await ref.read(connectionRepositoryProvider).accept(p.id);
      refreshConnections(ref, otherUserId: p.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept. Try again.')),
      );
    }
  }

  Future<void> _invite() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite your batchmates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kTxt,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              _inviteMessage,
              style: TextStyle(fontSize: 13, color: kTxt2, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.crimson,
                minimumSize: const Size(double.infinity, 46),
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: _inviteMessage),
                );
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite message copied — paste it anywhere'),
                  ),
                );
              },
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCopy01,
                size: 16,
              ),
              label: const Text(
                'Copy invite message',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final summary =
        ref.watch(circleSummaryProvider).valueOrNull ?? CircleSummary.empty;
    final mySchools =
        ref.watch(mySchoolHistoryProvider).valueOrNull ?? const [];

    return PopScope(
      // Back while searching clears the search first.
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSearch();
      },
      child: Column(
        children: [
          _Header(
            summary: summary,
            searching: _searching,
            everywhere: _everywhere,
            hasFilters: _hasFilters,
            segment: _segment,
            searchCtrl: _searchCtrl,
            searchFocus: _searchFocus,
            onSearchChanged: _onSearchChanged,
            onClear: _clearSearch,
            onFilters: _openFilters,
            onBell: () => context.go('/home/requests'),
            onScope: (everywhere) => setState(() {
              _everywhere = everywhere;
              _pages = 1;
            }),
            onSegment: (s) => setState(() {
              _segment = s;
              _circlePages = 1;
            }),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.crimson,
              onRefresh: () async => refreshConnections(ref),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: _searching
                    ? _searchBody()
                    : _circleBody(summary, mySchools),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode B: search ─────────────────────────────────────────────────────────

  List<Widget> _searchBody() {
    final first = ref.watch(peopleSearchProvider(_searchQuery));
    final more = <Person>[];
    var lastPageFull = false;
    for (var p = 1; p < _pages; p++) {
      final page = ref.watch(peopleSearchProvider(_searchPage(p))).valueOrNull;
      if (page == null) break;
      more.addAll(page);
      lastPageFull = page.length == kPeoplePageSize;
    }

    return [
      first.when(
        loading: () => const _Loading(),
        error: (_, __) => EmptyState(
          icon: HugeIcons.strokeRoundedWifiOff01,
          title: 'Could not search',
          message: 'Check your connection and try again.',
          action: TextButton(
            onPressed: () => ref.invalidate(peopleSearchProvider(_searchQuery)),
            child: const Text('Retry'),
          ),
        ),
        data: (firstPage) {
          final people = [...firstPage, ...more];
          final canShowMore = _pages == 1
              ? firstPage.length == kPeoplePageSize
              : lastPageFull;
          if (people.isEmpty) {
            return _NoMatchState(
              onChangeFilters: _openFilters,
              onClear: _clearSearch,
              onInvite: _invite,
              onSearchEverywhere: _everywhere
                  ? null
                  : () => setState(() {
                      _everywhere = true;
                      _pages = 1;
                    }),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHead(
                _everywhere
                    ? '${people.length}${canShowMore ? '+' : ''} APS brats found'
                    : '${people.length} in your schools',
              ),
              const SizedBox(height: 10),
              for (final p in people) ...[
                _PersonCard(
                  person: p,
                  requested: _requested.contains(p.id),
                  onTap: () => _openProfile(p),
                  onConnect: () => _connect(p),
                  onAccept: () => _accept(p),
                ),
                const SizedBox(height: 10),
              ],
              if (canShowMore) _ShowMore(onTap: () => setState(() => _pages++)),
              if (!_everywhere) ...[
                const SizedBox(height: 6),
                _WidenCard(
                  query: _query,
                  onTap: () => setState(() {
                    _everywhere = true;
                    _pages = 1;
                  }),
                ),
              ],
            ],
          );
        },
      ),
    ];
  }

  // ── Mode A: my circle ──────────────────────────────────────────────────────

  List<Widget> _circleBody(CircleSummary summary, List<SchoolHistory> schools) {
    switch (_segment) {
      case _Segment.classmates:
        return _classmatesBody(summary, schools);
      case _Segment.batchmates:
        return _batchmatesBody(summary, schools);
    }
  }

  List<Widget> _classmatesBody(
    CircleSummary summary,
    List<SchoolHistory> schools,
  ) {
    if (!summary.hasSection && schools.isNotEmpty) {
      return [
        _HintCardWide(
          icon: HugeIcons.strokeRoundedMortarboard01,
          title: 'Add your section to find classmates',
          body:
              'Classmates are matched by school, section and years. None of your school entries has a section yet.',
          action: 'Edit schools',
          onTap: () => context.go('/home/edit-schools'),
        ),
      ];
    }
    return [
      if (schools.length > 1) ...[
        _SchoolPicker(
          schools: schools,
          selected: _entryId,
          allLabel: 'All my schools',
          onChanged: (id) => setState(() {
            _entryId = id;
            _circlePages = 1;
          }),
        ),
        const SizedBox(height: 12),
      ],
      ..._pagedCircleList(
        provider: classmatesProvider,
        headline: (n, more) => '$n${more ? '+' : ''} classmates',
        emptyTitle: 'No classmates here yet',
        emptyBody:
            'Nobody from your section has joined yet. Invite them — you will be the first face they see.',
        showSuggested: true,
      ),
    ];
  }

  List<Widget> _batchmatesBody(
    CircleSummary summary,
    List<SchoolHistory> schools,
  ) {
    return [
      if (schools.length > 1) ...[
        _SchoolPicker(
          schools: schools,
          selected: _entryId,
          allLabel: 'All my schools',
          onChanged: (id) => setState(() {
            _entryId = id;
            _circlePages = 1;
          }),
        ),
        const SizedBox(height: 10),
      ],
      Row(
        children: [
          const Expanded(
            child: Text(
              'MOST MUTUAL FRIENDS FIRST',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: kTxt3,
              ),
            ),
          ),
          _ToggleChip(
            label: 'My batch only',
            active: _batchOnly,
            onTap: () => setState(() {
              _batchOnly = !_batchOnly;
              _circlePages = 1;
            }),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ..._pagedCircleList(
        provider: schoolmatesProvider,
        headline: (n, more) => null,
        emptyTitle: 'Nobody from your schools yet',
        emptyBody:
            'When people from your schools join APS Brat they will show up here, ranked by the friends you share.',
        showSuggested: false,
      ),
    ];
  }

  /// Shared list for classmates / schoolmates: first page decides loading and
  /// empty states, extra pages append below with "Show more".
  List<Widget> _pagedCircleList({
    required FutureProviderFamily<List<Person>, CirclePage> provider,
    required String? Function(int count, bool more) headline,
    required String emptyTitle,
    required String emptyBody,
    required bool showSuggested,
  }) {
    final first = ref.watch(provider(_circlePage(0)));
    final more = <Person>[];
    var lastPageFull = false;
    for (var p = 1; p < _circlePages; p++) {
      final page = ref.watch(provider(_circlePage(p))).valueOrNull;
      if (page == null) break;
      more.addAll(page);
      lastPageFull = page.length == kCirclePageSize;
    }

    return [
      first.when(
        loading: () => const _Loading(),
        error: (_, __) => EmptyState(
          icon: HugeIcons.strokeRoundedWifiOff01,
          title: 'Could not load',
          message: 'Check your connection and try again.',
          action: TextButton(
            onPressed: () => ref.invalidate(provider(_circlePage(0))),
            child: const Text('Retry'),
          ),
        ),
        data: (firstPage) {
          final people = [...firstPage, ...more];
          final canShowMore = _circlePages == 1
              ? firstPage.length == kCirclePageSize
              : lastPageFull;
          if (people.isEmpty) {
            return _SmallEmpty(
              title: emptyTitle,
              body: emptyBody,
              onInvite: _invite,
            );
          }
          final friendIds =
              (ref.watch(batchmatesProvider).valueOrNull ?? const [])
                  .map((p) => p.id)
                  .toSet();
          final suggested = showSuggested
              ? people
                    .where(
                      (p) =>
                          p.relation == 'NONE' &&
                          !friendIds.contains(p.id) &&
                          !_requested.contains(p.id),
                    )
                    .take(6)
                    .toList()
              : const <Person>[];
          final head = headline(people.length, canShowMore);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (suggested.isNotEmpty) ...[
                const _SectionHead('Suggested for you'),
                const SizedBox(height: 8),
                _SuggestedStrip(
                  people: suggested,
                  requested: _requested,
                  onTap: _openProfile,
                  onConnect: _connect,
                ),
                const SizedBox(height: 14),
              ],
              if (head != null) ...[
                _SectionHead(head),
                const SizedBox(height: 8),
              ],
              for (final p in people) ...[
                _PersonCard(
                  person: p,
                  requested: _requested.contains(p.id),
                  connected: friendIds.contains(p.id),
                  onTap: () => _openProfile(p),
                  onConnect: () => _connect(p),
                  onAccept: () => _accept(p),
                ),
                const SizedBox(height: 10),
              ],
              if (canShowMore)
                _ShowMore(onTap: () => setState(() => _circlePages++)),
              const SizedBox(height: 4),
              _InviteBanner(onTap: _invite),
            ],
          );
        },
      ),
    ];
  }
}

const _inviteMessage =
    'Join me on APS Brat — the alumni network for Army Public School brats. '
    'Find your batchmates, join your school community and relive the days!';

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.summary,
    required this.searching,
    required this.everywhere,
    required this.hasFilters,
    required this.segment,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onClear,
    required this.onFilters,
    required this.onBell,
    required this.onScope,
    required this.onSegment,
  });

  final CircleSummary summary;
  final bool searching;
  final bool everywhere;
  final bool hasFilters;
  final _Segment segment;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final VoidCallback onFilters;
  final VoidCallback onBell;
  final ValueChanged<bool> onScope;
  final ValueChanged<_Segment> onSegment;

  @override
  Widget build(BuildContext context) {
    final counts = searching
        ? (everywhere
              ? 'Searching all APS brats${hasFilters ? ' · filters on' : ''}'
              : 'Searching your schools${hasFilters ? ' · filters on' : ''}')
        : null;

    return CrimsonHeader(
      waveColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Batchmates',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              _Bell(count: summary.incomingRequests, onTap: onBell),
            ],
          ),
          const SizedBox(height: 4),
          counts != null
              ? Text(
                  counts,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                )
              : _CountsLine(summary: summary),
          const SizedBox(height: 12),
          FeedSearchBar(
            hint: 'Search by name…',
            controller: searchCtrl,
            focusNode: searchFocus,
            onChanged: onSearchChanged,
            onFilterTap: onFilters,
            filterActive: hasFilters,
            onClear: searching ? onClear : null,
          ),
          const SizedBox(height: 12),
          if (searching)
            Row(
              children: [
                const Text(
                  'In',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(width: 6),
                _HeaderChip(
                  label: 'My schools',
                  active: !everywhere,
                  onTap: () => onScope(false),
                ),
                const SizedBox(width: 6),
                _HeaderChip(
                  label: 'Everywhere',
                  active: everywhere,
                  onTap: () => onScope(true),
                ),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _HeaderChip(
                    label: 'Classmates',
                    active: segment == _Segment.classmates,
                    onTap: () => onSegment(_Segment.classmates),
                  ),
                  const SizedBox(width: 6),
                  _HeaderChip(
                    label: 'Batchmates',
                    active: segment == _Segment.batchmates,
                    onTap: () => onSegment(_Segment.batchmates),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountsLine extends StatelessWidget {
  const _CountsLine({required this.summary});

  final CircleSummary summary;

  @override
  Widget build(BuildContext context) {
    TextSpan n(int v) => TextSpan(
      text: '$v',
      style: const TextStyle(color: kGoldLight, fontWeight: FontWeight.w800),
    );
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11.5, color: Colors.white70),
        children: [
          n(summary.friends),
          const TextSpan(text: ' friends · '),
          n(summary.classmates),
          const TextSpan(text: ' classmates · '),
          n(summary.schoolmates),
          const TextSpan(text: ' from your schools'),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FeedIconBtn(icon: HugeIcons.strokeRoundedNotification01, onTap: onTap),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.crimson, width: 2),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.crimsonDark,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.crimsonDark : const Color(0xFFF1DDC9),
          ),
        ),
      ),
    );
  }
}

// ── Circle pieces ─────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: kTxt3,
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.crimson : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? AppColors.crimson : kBorder2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.crimson,
          ),
        ),
      ),
    );
  }
}

class _SchoolPicker extends StatelessWidget {
  const _SchoolPicker({
    required this.schools,
    required this.selected,
    required this.allLabel,
    required this.onChanged,
  });

  final List<SchoolHistory> schools;
  final String? selected;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F2),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: schools.any((s) => s.id == selected) ? selected : null,
          isExpanded: true,
          isDense: true,
          padding: const EdgeInsets.symmetric(vertical: 10),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: kTxt,
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            for (final s in schools)
              DropdownMenuItem<String?>(
                value: s.id,
                child: Text(
                  '${s.schoolName ?? 'School'} · Class ${s.classFrom}–${s.classTo}'
                  '${s.section.isNotEmpty ? ' · ${s.section}' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SuggestedStrip extends StatelessWidget {
  const _SuggestedStrip({
    required this.people,
    required this.requested,
    required this.onTap,
    required this.onConnect,
  });

  final List<Person> people;
  final Set<String> requested;
  final ValueChanged<Person> onTap;
  final ValueChanged<Person> onConnect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = people[i];
          final sent = requested.contains(p.id);
          return GestureDetector(
            onTap: () => onTap(p),
            child: Container(
              width: 112,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF7F2),
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  AvatarCircle(
                    initials: p.initials,
                    bg: p.bg,
                    fg: p.fg,
                    size: 40,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: kTxt,
                    ),
                  ),
                  Text(
                    p.mutualCount > 0 ? '${p.mutualCount} mutual' : p.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: kTxt3),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: sent
                        ? const _MiniPill('✓ Sent', filled: true)
                        : GestureDetector(
                            onTap: () => onConnect(p),
                            child: const _MiniPill('Connect'),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.text, {this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFE3F4EA) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: filled ? const Color(0xFFE3F4EA) : AppColors.crimson,
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: filled ? const Color(0xFF1E7F52) : AppColors.crimson,
        ),
      ),
    );
  }
}

class _ShowMore extends StatelessWidget {
  const _ShowMore({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedArrowDown01,
          color: AppColors.crimson,
        ),
        label: const Text(
          'Show more',
          style: TextStyle(
            color: AppColors.crimson,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
    );
  }
}

class _WidenCard extends StatelessWidget {
  const _WidenCard({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: kBorder2, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Text(
              'Not who you are looking for?',
              style: TextStyle(fontSize: 12, color: kTxt2),
            ),
            const SizedBox(height: 2),
            Text(
              query.isEmpty
                  ? 'Search all APS brats →'
                  : 'Search all APS brats for “$query” →',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.crimson,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCardWide extends StatelessWidget {
  const _HintCardWide({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final AppIconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 22, color: AppColors.crimson),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.crimson,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B5322),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    '$action →',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.crimson,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallEmpty extends StatelessWidget {
  const _SmallEmpty({
    required this.title,
    required this.body,
    required this.onInvite,
  });

  final String title;
  final String body;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Image.asset(
          'assets/images/batchmates_empty.png',
          height: 150,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _IllustrationFallback(),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: kTxt,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: kTxt3, height: 1.45),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: const Size(0, 40),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 12.5),
          ),
          onPressed: onInvite,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedSent, size: 15),
          label: const Text(
            'Invite Friends',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.requested,
    required this.onTap,
    required this.onConnect,
    this.connected = false,
    this.onAccept,
  });

  final Person person;
  final bool requested;

  /// Already a friend (shows "Connected" instead of Connect).
  final bool connected;

  final VoidCallback onTap;
  final VoidCallback onConnect;
  /// Called when the person has asked ME and I tap Accept.
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    // "12A · Class 2022 · APS Patiala" — school on every row.
    final where = [
      if (person.detail.isNotEmpty) person.detail,
      if (person.school.isNotEmpty) person.school,
      if (person.mutualCount > 0)
        '${person.mutualCount} mutual ${person.mutualCount == 1 ? 'batchmate' : 'batchmates'}',
    ].join(' · ');
    final status = switch (person.currentStatus) {
      'STUDENT' => 'Student',
      _ => 'Alumni',
    };

    // Button state comes from the server's relation, plus what was tapped
    // on this screen a moment ago.
    final isConnected = connected || person.relation == 'CONNECTED';
    final isRequested = requested || person.relation == 'PENDING_OUT';
    final askedMe = person.relation == 'PENDING_IN';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEDE7E7)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarCircle(
              initials: person.initials,
              bg: person.bg,
              fg: person.fg,
              size: 54,
              fontSize: 17,
              online: person.online,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2235),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    where,
                    style: const TextStyle(fontSize: 11.5, color: kTxt3),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // The backend already puts "Alumni"/"Student" in tags;
                      // skip those so the status shows exactly once.
                      for (final t
                          in person.tags
                              .where((t) => t != 'Alumni' && t != 'Student')
                              .take(2))
                        _Pill(t),
                      _Pill(status),
                      if ((person.city ?? '').isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedLocation01,
                              size: 12,
                              color: kTxt2,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              person.city!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: kTxt2,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                if (isConnected)
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F4EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E7F52),
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isRequested
                          ? kCrimsonLight
                          : AppColors.crimson,
                      foregroundColor: isRequested ? kCrimsonMed : Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isRequested
                        ? null
                        : (askedMe ? (onAccept ?? onConnect) : onConnect),
                    icon: HugeIcon(
                      icon: isRequested
                          ? HugeIcons.strokeRoundedTick02
                          : HugeIcons.strokeRoundedUserAdd02,
                      size: 15,
                    ),
                    label: Text(
                      isRequested
                          ? 'Requested'
                          : (askedMe ? 'Accept' : 'Connect'),
                    ),
                  ),
                IconButton(
                  onPressed: onTap,
                  tooltip: 'View profile',
                  visualDensity: VisualDensity.compact,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    size: 18,
                    color: kTxt3,
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

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kCrimsonLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: kCrimsonMed,
        ),
      ),
    );
  }
}

// ── "Can't find your friends?" banner ─────────────────────────────────────────

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF1F1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: kCrimsonLight,
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedUserAdd01,
                size: 20,
                color: AppColors.crimson,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Can't find your friends?",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2235),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Invite them to join APS Brats and grow your network!',
                    style: TextStyle(fontSize: 11, color: kTxt2),
                  ),
                ],
              ),
            ),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.crimson,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filters sheet ─────────────────────────────────────────────────────────────

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial});

  final PeopleQuery initial;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late String? _schoolId = widget.initial.schoolId;
  late int? _batch = widget.initial.batch;
  late int? _classTo = widget.initial.classTo;
  late String? _section = widget.initial.section;
  late String? _stream = widget.initial.stream;
  late String? _status = widget.initial.status;
  late final _city = TextEditingController(text: widget.initial.city ?? '');

  static final _years = List.generate(
    DateTime.now().year + 2 - 1980,
    (i) => DateTime.now().year + 1 - i,
  );

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  void _apply() {
    final city = _city.text.trim();
    Navigator.of(context).pop((
      q: '',
      schoolId: _schoolId,
      batch: _batch,
      classTo: _classTo,
      section: _section,
      stream: _stream,
      status: _status,
      city: city.isEmpty ? null : city,
      mine: widget.initial.mine,
      page: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final schools = ref.watch(apsSchoolsProvider).valueOrNull ?? const [];
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kTxt,
              ),
            ),
            const SizedBox(height: 14),
            _drop<String>('School', _schoolId, [
              const DropdownMenuItem(
                value: null,
                child: Text('All APS Schools'),
              ),
              for (final s in schools)
                DropdownMenuItem(
                  value: s['id']?.toString(),
                  child: Text(s['name']?.toString() ?? ''),
                ),
            ], (v) => setState(() => _schoolId = v)),
            Row(
              children: [
                Expanded(
                  child: _drop<int>('Batch', _batch, [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    for (final y in _years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ], (v) => setState(() => _batch = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drop<int>('Class', _classTo, [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    for (int c = 1; c <= 12; c++)
                      DropdownMenuItem(value: c, child: Text('$c')),
                  ], (v) => setState(() => _classTo = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drop<String>('Section', _section, [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    for (final s in kSectionOptions)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ], (v) => setState(() => _section = v)),
                ),
              ],
            ),
            _drop<String>('Stream (Class 11-12)', _stream, [
              const DropdownMenuItem(value: null, child: Text('Any')),
              for (final e in kStreams.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ], (v) => setState(() => _stream = v)),
            _drop<String>('Status', _status, const [
              DropdownMenuItem(value: null, child: Text('Everyone')),
              DropdownMenuItem(value: 'STUDENT', child: Text('Students')),
              DropdownMenuItem(value: 'ALUMNI', child: Text('Alumni')),
            ], (v) => setState(() => _status = v)),
            const Text('LOCATION', style: _label),
            const SizedBox(height: 5),
            TextField(
              controller: _city,
              style: const TextStyle(fontSize: 13, color: kTxt),
              decoration: _dec('Any city'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.crimson,
                      side: const BorderSide(color: AppColors.crimson),
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.of(context).pop(kEveryoneQuery),
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _apply,
                    child: const Text(
                      'Show results',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

  static const _label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    color: AppColors.crimson,
  );

  Widget _drop<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T?>> items,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: _label),
          const SizedBox(height: 5),
          DropdownButtonFormField<T?>(
            initialValue: value,
            isExpanded: true,
            isDense: true,
            items: items,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13, color: kTxt),
            decoration: _dec(''),
          ),
        ],
      ),
    );
  }

  static InputDecoration _dec(String hint) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: border(const Color(0xFFDDDDDD)),
      enabledBorder: border(const Color(0xFFDDDDDD)),
      focusedBorder: border(AppColors.crimson),
    );
  }
}

// ── Empty state (nobody on the platform yet) ─────────────────────────────────

/// Search/filter returned nothing: same illustration, shorter copy and
/// buttons to change filters or invite friends.
class _NoMatchState extends StatelessWidget {
  const _NoMatchState({
    required this.onChangeFilters,
    required this.onClear,
    required this.onInvite,
    this.onSearchEverywhere,
  });

  final VoidCallback onChangeFilters;
  final VoidCallback onClear;
  final VoidCallback onInvite;

  /// Shown while the search is limited to my schools.
  final VoidCallback? onSearchEverywhere;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Image.asset(
          'assets/images/batchmates_empty.png',
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _IllustrationFallback(),
        ),
        const SizedBox(height: 10),
        const Text(
          'No batchmates match',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2235),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try a different name, another school or fewer filters.'
          '\n'
          'Or invite the friends you are looking for!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: kTxt3, height: 1.45),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.crimson,
                  minimumSize: const Size(0, 42),
                  textStyle: const TextStyle(fontSize: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onChangeFilters,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSetting07,
                  size: 15,
                ),
                label: const Text(
                  'Change Filters',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.crimson,
                  minimumSize: const Size(0, 42),
                  textStyle: const TextStyle(fontSize: 13),
                  side: const BorderSide(color: AppColors.crimson, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onInvite,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSent,
                  size: 15,
                ),
                label: const Text(
                  'Invite Friends',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        if (onSearchEverywhere != null) ...[
          const SizedBox(height: 10),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFBF3E1),
              foregroundColor: AppColors.crimson,
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onSearchEverywhere,
            child: const Text(
              'Search all APS brats instead',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: onClear,
          child: const Text(
            'Clear search & show my circle',
            style: TextStyle(
              color: AppColors.crimson,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _IllustrationFallback extends StatelessWidget {
  const _IllustrationFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: kCrimsonLight,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 22,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedBank,
              size: 26,
              color: AppColors.crimson.withValues(alpha: 0.18),
            ),
          ),
          const Positioned(
            bottom: 24,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 40,
              color: kCrimsonMed,
            ),
          ),
        ],
      ),
    );
  }
}
