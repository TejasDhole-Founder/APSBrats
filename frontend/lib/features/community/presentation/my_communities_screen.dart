import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/communities_tab.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Show { all, joined, requested, owned }

/// "See all" from the Communities half of Social: everything I'm in, asked to
/// join, or own, with a filter and a ⋮ menu on each row.
class MyCommunitiesScreen extends ConsumerStatefulWidget {
  const MyCommunitiesScreen({super.key});

  @override
  ConsumerState<MyCommunitiesScreen> createState() =>
      _MyCommunitiesScreenState();
}

class _MyCommunitiesScreenState extends ConsumerState<MyCommunitiesScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Show _show = _Show.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myCommunitiesProvider);

    return Scaffold(
      backgroundColor: kCommunityBg,
      body: Column(
        children: [
          CrimsonHeader(
            child: Row(
              children: [
                FeedIconBtn(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Your Communities',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                FeedIconBtn(
                  icon: HugeIcons.strokeRoundedAdd01,
                  onTap: () => showCreateCommunitySheet(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: FeedSearchBar(
              hint: 'Search your communities...',
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: mine.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.crimson),
              ),
              error: (e, _) => Center(
                child: EmptyState(
                  icon: HugeIcons.strokeRoundedWifiOff01,
                  title: 'Could not load communities',
                  message: friendlyError(e),
                  action: TextButton(
                    onPressed: () => ref.invalidate(myCommunitiesProvider),
                    child: const Text('Retry'),
                  ),
                ),
              ),
              data: (m) {
                final groups = m.joined.where((c) => !c.isSchool).toList();
                final joined = groups.where((c) => !c.isOwner).toList();
                final owned = groups.where((c) => c.isOwner).toList();
                final requested = m.requested;
                final base = switch (_show) {
                  _Show.all => [...groups, ...requested],
                  _Show.joined => joined,
                  _Show.requested => requested,
                  _Show.owned => owned,
                };
                final q = _query.toLowerCase();
                final shown = q.isEmpty
                    ? base
                    : base
                          .where((c) => c.name.toLowerCase().contains(q))
                          .toList();
                final counts = {
                  _Show.all: groups.length + requested.length,
                  _Show.joined: joined.length,
                  _Show.requested: requested.length,
                  _Show.owned: owned.length,
                };
                const labels = {
                  _Show.all: 'All',
                  _Show.joined: 'Joined',
                  _Show.requested: 'Requested',
                  _Show.owned: 'Owned',
                };
                return Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        children: [
                          for (final s in _Show.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                label: '${labels[s]} (${counts[s]})',
                                selected: _show == s,
                                onTap: () => setState(() => _show = s),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: shown.isEmpty
                          ? ListView(
                              children: const [
                                EmptyState(
                                  icon: HugeIcons.strokeRoundedUserGroup,
                                  image: kEmptyInboxImage,
                                  title: 'Nothing here',
                                  message:
                                      'No community matches this filter yet.',
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
                              itemCount: shown.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => Container(
                                decoration: communityCard(),
                                padding: const EdgeInsets.only(left: 12),
                                child: CommunityTile(
                                  community: shown[i],
                                  menu: true,
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
          color: selected ? AppColors.crimson : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.crimson : kCardLine),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : kTxt,
          ),
        ),
      ),
    );
  }
}
