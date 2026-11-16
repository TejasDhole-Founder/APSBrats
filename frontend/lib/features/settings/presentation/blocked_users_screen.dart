import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart'
    show friendlyError;
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/settings/data/block_repository.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// People I've blocked, each with an Unblock button.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            CrimsonHeader(
              waveColor: Colors.white,
              child: Row(
                children: [
                  FeedIconBtn(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Blocked users',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: blocked.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.crimson),
                ),
                error: (e, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(blockedUsersProvider),
                    child: Text('${friendlyError(e)}  Retry'),
                  ),
                ),
                data: (people) => people.isEmpty
                    ? const EmptyState(
                        icon: HugeIcons.strokeRoundedCancel01,
                        title: "You haven't blocked anyone",
                        message:
                            'People you block can\'t find you or message you.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          for (final p in people)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AvatarCircle(
                                initials: p.initials,
                                imageUrl: p.profilePicUrl,
                                bg: p.bg,
                                fg: p.fg,
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  p.detail,
                                  p.school,
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: OutlinedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await ref
                                        .read(blockRepositoryProvider)
                                        .unblock(p.id);
                                    refreshAfterBlock(ref, p.id);
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(friendlyError(e))),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.crimson,
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text('Unblock'),
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
