import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/community/presentation/community_ui.dart';
import 'package:apsbrat_frontend/features/community/presentation/post_card.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A post with its comments (oldest first) and a box to add one.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  /// Local copy so likes and new comments show at once.
  Post? _post;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Keeps the community page and Home in step with what changed here. Only
  /// lists that are open are touched (reading a closed one would refetch it).
  void _syncFeeds(Post post, {bool removed = false}) {
    final feeds = [
      for (final key in [post.communityId, '']) postFeedProvider(key),
      if (post.eventId != null) eventPostsProvider(post.eventId!),
    ];
    for (final provider in feeds) {
      if (!ref.exists(provider)) continue;
      final feed = ref.read(provider.notifier);
      removed ? feed.remove(post.id) : feed.replace(post);
    }
    if (removed && post.memoryYear != null) ref.invalidate(memoriesProvider);
  }

  Future<void> _send(Post post) async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .addComment(post.id, _text.text);
      _text.clear();
      final updated = post.copyWith(commentCount: post.commentCount + 1);
      setState(() => _post = updated);
      _syncFeeds(updated);
      ref.invalidate(commentsProvider(post.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Post post, PostComment c) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this comment?',
      message: "It will be removed for everyone.",
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await ref.read(communityRepositoryProvider).deleteComment(c.id);
      final updated = post.copyWith(commentCount: post.commentCount - 1);
      setState(() => _post = updated);
      _syncFeeds(updated);
      ref.invalidate(commentsProvider(post.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(postProvider(widget.postId));
    final comments = ref.watch(commentsProvider(widget.postId));

    return Scaffold(
      backgroundColor: kCommunityBg,
      appBar: AppBar(
        backgroundColor: AppColors.crimson,
        foregroundColor: Colors.white,
        surfaceTintColor: AppColors.crimson,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Post',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (loaded.valueOrNull case final p?)
              Text(
                p.communityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loaded.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.crimson),
              ),
              error: (e, _) => SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.forum_outlined,
                  image: kEmptyInboxImage,
                  title: statusOf(e) == 404
                      ? 'This post is gone'
                      : "Couldn't load this post",
                  message: statusOf(e) == 404
                      ? 'It was deleted or hidden.'
                      : friendlyError(e),
                ),
              ),
              data: (fetched) {
                final post = _post ?? fetched;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  children: [
                    PostCard(
                      post: post,
                      openOnTap: false,
                      onChanged: (p) {
                        setState(() => _post = p);
                        _syncFeeds(p);
                      },
                      onDeleted: () {
                        _syncFeeds(post, removed: true);
                        context.pop();
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      post.commentCount == 0
                          ? 'Comments'
                          : 'Comments · ${post.commentCount}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kTxt,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...comments.when(
                      loading: () => [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.crimson,
                            ),
                          ),
                        ),
                      ],
                      error: (e, _) => [
                        Row(
                          children: [
                            Expanded(child: Text(friendlyError(e))),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                commentsProvider(widget.postId),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ],
                      data: (page) => page.items.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No comments yet. Say something nice.',
                                  style: TextStyle(fontSize: 12, color: kTxt3),
                                ),
                              ),
                            ]
                          : [
                              for (final c in page.items)
                                _CommentRow(
                                  comment: c,
                                  onDelete: () => _deleteComment(post, c),
                                  onReport: () => showReportSheet(
                                    context,
                                    ref,
                                    'COMMENT',
                                    c.id,
                                  ),
                                ),
                              if (page.hasMore)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Showing the first 50 comments.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: kTxt3,
                                    ),
                                  ),
                                ),
                            ],
                    ),
                  ],
                );
              },
            ),
          ),
          if (loaded.hasValue)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: kCardLine)),
                ),
                child: Row(
                  children: [
                    const MyAvatar(size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: appInputDecoration('Add a comment')
                            .copyWith(
                              counterText: '',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(color: kCardLine),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(color: kCardLine),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: 'Send',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.crimson,
                      ),
                      onPressed: _sending
                          ? null
                          : () => _send(_post ?? loaded.requireValue),
                      icon: const Icon(Icons.send_rounded, size: 20),
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

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.onDelete,
    required this.onReport,
  });

  final PostComment comment;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  Future<void> _actions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
            if (comment.canDelete)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (action == 'delete') onDelete();
    if (action == 'report') onReport();
  }

  @override
  Widget build(BuildContext context) {
    final c = comment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/home/profile/${c.author.id}'),
            child: AvatarCircle(
              initials: c.author.initials,
              imageUrl: c.author.profilePicUrl,
              bg: c.author.bg,
              fg: c.author.fg,
              size: 32,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _actions(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                decoration: const BoxDecoration(
                  color: kTint,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${c.author.name}  ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kTxt,
                            ),
                          ),
                          TextSpan(
                            text: shortTimeAgo(c.createdAt),
                            style: const TextStyle(fontSize: 11, color: kTxt3),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.body,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: kTxt,
                        height: 1.4,
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
