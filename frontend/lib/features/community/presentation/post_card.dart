import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// One post: author, time, text, a comment count, a Share icon and a "..."
/// menu (Pin for owners/staff, Report, Delete).
class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onChanged,
    required this.onDeleted,
    this.showCommunity = false,
    this.openOnTap = true,
  });

  final Post post;
  final ValueChanged<Post> onChanged;
  final VoidCallback onDeleted;

  /// On Home, posts come from several communities, so say which one.
  final bool showCommunity;

  /// Tapping opens the post with its comments (off on the post screen itself).
  final bool openOnTap;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _liking = false;

  /// The heart fills at once; the server's answer then sets the real count.
  /// If the request fails, the heart goes back.
  Future<void> _toggleLike() async {
    if (_liking) return;
    final before = widget.post;
    final optimistic = before.toggledLike();
    widget.onChanged(optimistic);
    _liking = true;
    try {
      final fresh = await ref
          .read(communityRepositoryProvider)
          .setLiked(before.id, liked: optimistic.likedByMe);
      if (mounted) widget.onChanged(fresh);
    } catch (e) {
      if (!mounted) return;
      widget.onChanged(before);
      _snack(friendlyError(e));
    } finally {
      _liking = false;
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this post?',
      message: "It will be removed for everyone. This can't be undone.",
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(communityRepositoryProvider).deletePost(widget.post.id);
      widget.onDeleted();
      if (mounted) _snack('Post deleted');
    } catch (e) {
      if (mounted) _snack(friendlyError(e));
    }
  }

  Future<void> _togglePin() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fresh = await ref
          .read(communityRepositoryProvider)
          .setPinned(widget.post.id, pinned: !widget.post.pinned);
      widget.onChanged(fresh);
      // Pinned posts lead their community's feed, so reload it in the new order.
      ref.invalidate(postFeedProvider(fresh.communityId));
      messenger.showSnackBar(
        SnackBar(
          content: Text(fresh.pinned ? 'Pinned to the top' : 'Unpinned'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  // ponytail: text-only share; add a link once posts have web pages / deep links.
  void _share() {
    final p = widget.post;
    Share.share(
      [
        '${p.author.name} in ${p.communityName}:',
        if (p.body.isNotEmpty) p.body else 'Shared a photo post.',
        'Shared from APS Brats',
      ].join('\n\n'),
      subject: 'A post from ${p.communityName}',
    );
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return InkWell(
      onTap: widget.openOnTap ? () => context.push('/home/post/${p.id}') : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEADCDC), width: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.pinned)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPin,
                      size: 14,
                      color: kTxt3,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pinned',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kTxt3,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/home/profile/${p.author.id}'),
                  child: AvatarCircle(
                    initials: p.author.initials,
                    imageUrl: p.author.profilePicUrl,
                    bg: p.author.bg,
                    fg: p.author.fg,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.author.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kTxt,
                        ),
                      ),
                      Text(
                        [
                          if (widget.showCommunity) p.communityName,
                          if (!widget.showCommunity &&
                              p.author.detail.isNotEmpty)
                            p.author.detail,
                          shortTimeAgo(p.createdAt),
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11, color: kTxt3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreHorizontal,
                    color: kTxt3,
                  ),
                  onSelected: (v) => switch (v) {
                    'delete' => _delete(),
                    'pin' => _togglePin(),
                    _ => showReportSheet(context, ref, 'POST', p.id),
                  },
                  itemBuilder: (_) => [
                    if (p.canPin)
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(p.pinned ? 'Unpin' : 'Pin to top'),
                      ),
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                    if (p.canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (p.memoryYear != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedNote01,
                      size: 14,
                      color: AppColors.crimson,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Throwback · ${memoryCategoryLabel(p.memoryCategory)} ${p.memoryYear}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                  ],
                ),
              ),
            if (p.eventId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: () => context.push('/home/event/${p.eventId}'),
                  child: Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        size: 14,
                        color: AppColors.crimson,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'From ${p.eventTitle ?? 'an event'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.crimson,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (p.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  p.body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kTxt,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (p.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PhotoSlider(urls: p.imageUrls),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0E6E6))),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _toggleLike,
                    style: TextButton.styleFrom(
                      foregroundColor: p.likedByMe
                          ? Colors.redAccent
                          : const Color(0xFF7A5A5A),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: HugeIcon(
                      icon: p.likedByMe
                          ? HugeIcons.strokeRoundedHeart
                          : HugeIcons.strokeRoundedHeart,
                      size: 20,
                    ),
                    label: Text('${p.likeCount}'),
                  ),
                  TextButton.icon(
                    onPressed: widget.openOnTap
                        ? () => context.push('/home/post/${p.id}')
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7A5A5A),
                      disabledForegroundColor: const Color(0xFF7A5A5A),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMessage01,
                      size: 18,
                    ),
                    label: Text('${p.commentCount}'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Share',
                    visualDensity: VisualDensity.compact,
                    onPressed: _share,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShare01,
                      size: 20,
                      color: Color(0xFF7A5A5A),
                    ),
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

/// Lets the user pick a reason, then files the report. Three different
/// people reporting the same post hides it until staff review.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref,
  String targetType,
  String targetId,
) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              "Why are you reporting this?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          for (final (code, label) in kReportReasons)
            ListTile(
              title: Text(label),
              onTap: () => Navigator.of(sheetContext).pop(code),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  try {
    await ref
        .read(communityRepositoryProvider)
        .report(targetType, targetId, reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks. We'll take a look.")),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// A plain yes/no dialog. Returns true when [action] was pressed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
