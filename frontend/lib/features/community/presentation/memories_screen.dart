import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_screen.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// School memories: photo posts marked as memories, grouped by year (newest
/// first), filtered by year and category. Tap one to open the post.
class MemoriesTab extends ConsumerStatefulWidget {
  const MemoriesTab({super.key, required this.community});

  final Community community;

  @override
  ConsumerState<MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends ConsumerState<MemoriesTab> {
  int? _year;
  String? _category;

  MemoriesQuery get _query =>
      (communityId: widget.community.id, year: _year, category: _category);

  @override
  Widget build(BuildContext context) {
    final c = widget.community;
    final feed = ref.watch(memoriesProvider(_query));
    final notifier = ref.read(memoriesProvider(_query).notifier);
    final years =
        ref.watch(memoryYearsProvider(c.id)).valueOrNull ?? const <int>[];

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.crimson,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.crimsonDark,
        ),
        side: BorderSide(color: selected ? AppColors.crimson : kCardLine),
        shape: const StadiumBorder(),
        onSelected: (_) => onTap(),
      ),
    );

    // Year groups, in the server's order (newest year first).
    final groups = <(int, List<Post>)>[];
    for (final p in feed.items) {
      final y = p.memoryYear ?? 0;
      if (groups.isEmpty || groups.last.$1 != y) groups.add((y, []));
      groups.last.$2.add(p);
    }

    return CommunityTabBody(
      storageKey: 'memories-${c.id}',
      onNearEnd: notifier.loadMore,
      onRefresh: () async {
        ref.invalidate(memoryYearsProvider(c.id));
        await notifier.refresh();
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          sliver: SliverList.list(
            children: [
              if (c.isMember) ...[
                PromptCard(
                  hint: 'Got an old school photo?',
                  leading: const Icon(
                    Icons.history_edu_rounded,
                    color: AppColors.crimson,
                    size: 26,
                  ),
                  trailingIcon: Icons.add_circle_outline_rounded,
                  onTap: () => showPostComposer(
                    context,
                    communityId: c.id,
                    communityName: c.name,
                    asMemory: true,
                    allowMemory: true,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    chip(
                      'Any year',
                      _year == null,
                      () => setState(() => _year = null),
                    ),
                    for (final y in years)
                      chip('$y', _year == y, () => setState(() => _year = y)),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    chip(
                      'All',
                      _category == null,
                      () => setState(() => _category = null),
                    ),
                    for (final (code, label) in kMemoryCategories)
                      chip(
                        label,
                        _category == code,
                        () => setState(() => _category = code),
                      ),
                  ],
                ),
              ),
              if (feed.items.isEmpty && feed.loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.crimson),
                  ),
                )
              else if (feed.items.isEmpty && feed.error != null)
                TextButton(
                  onPressed: notifier.refresh,
                  child: Text('${friendlyError(feed.error!)}  Retry'),
                )
              else if (feed.items.isEmpty)
                EmptyState(
                  icon: Icons.photo_library_outlined,
                  image: kEmptyInboxImage,
                  title: _year == null && _category == null
                      ? 'No memories yet'
                      : 'Nothing for this filter',
                  message:
                      'Share an old school photo and mark it as a school memory.',
                ),
            ],
          ),
        ),
        for (final (year, posts) in groups) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '$year',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kTxt,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [for (final p in posts) _MemoryTile(post: p)],
            ),
          ),
        ],
        if (feed.loading && feed.items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.crimson),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/post/${post.id}'),
      child: Semantics(
        button: true,
        label:
            '${memoryCategoryLabel(post.memoryCategory)} ${post.memoryYear}, by ${post.author.name}',
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkPhoto(
              url: post.imageUrls.first,
              maxHeight: 200,
              borderRadius: 8,
              openOnTap: false,
            ),
            Positioned(
              left: 4,
              bottom: 4,
              right: 4,
              child: Text(
                memoryCategoryLabel(post.memoryCategory),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
            if (post.imageUrls.length > 1)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.collections_rounded,
                  size: 16,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 3)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
