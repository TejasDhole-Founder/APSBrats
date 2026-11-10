import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/notifications/data/notification_models.dart';
import 'package:apsbrat_frontend/features/notifications/data/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Every event in one list. Connection requests carry Accept / Decline inline
/// while they are still open, so most are answered without leaving Home.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Requests answered on this screen, so the buttons vanish at once.
  final _answered = <String>{};

  @override
  void initState() {
    super.initState();
    // Opening the screen always shows the latest, never a cached list.
    Future.microtask(() {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    });
  }

  Future<void> _respond(AppNotification n, {required bool accept}) async {
    final actor = n.actorId;
    if (actor == null) return;
    setState(() => _answered.add(n.id));
    try {
      final repo = ref.read(connectionRepositoryProvider);
      if (accept) {
        await repo.accept(actor);
      } else {
        await repo.end(actor);
      }
      refreshConnections(ref, otherUserId: actor);
      ref.invalidate(notificationsProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _answered.remove(n.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  void _open(AppNotification n) {
    if (n.refType == 'USER' && n.refId != null) {
      context.go('/home/profile/${n.refId}');
    } else if (n.refType == 'POST' && n.refId != null) {
      // Someone commented on my post: open it with its comments.
      context.push('/home/post/${n.refId}');
    } else if (n.refType == 'EVENT' && n.refId != null) {
      // An event I RSVP'd to changed or was cancelled.
      context.push('/home/event/${n.refId}');
    } else if (n.actorId != null) {
      context.go('/home/profile/${n.actorId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider);
    final unread = items.valueOrNull?.where((n) => !n.read).length;

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
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (unread != null)
                          Text(
                            unread == 0 ? 'All caught up' : '$unread new',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: (unread ?? 0) == 0 ? null : _markAllRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(color: kGoldLight, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.crimson),
                ),
                error: (_, __) => EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load notifications',
                  message: 'Check your connection and try again.',
                  action: TextButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Retry'),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Nothing yet',
                      message:
                          'Requests, accepted connections and school news will show up here.',
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.crimson,
                    onRefresh: () async =>
                        ref.invalidate(notificationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final n = list[i];
                        final open = n.actionable && !_answered.contains(n.id);
                        return _NotificationTile(
                          notification: n,
                          showActions: open,
                          onTap: () => _open(n),
                          onAccept: () => _respond(n, accept: true),
                          onDecline: () => _respond(n, accept: false),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.showActions,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  final AppNotification notification;
  final bool showActions;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final highlight = n.isRequest && showActions;
    final initials = n.actorInitials ?? _iconFor(n.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFBF3E1)
              : (n.read ? Colors.white : const Color(0xFFFCF7F7)),
          border: Border.all(color: highlight ? AppColors.gold : kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: kCrimsonLight,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.crimson,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: n.read
                              ? FontWeight.w600
                              : FontWeight.w800,
                          color: kTxt,
                        ),
                      ),
                      if ((n.body ?? '').isNotEmpty)
                        Text(
                          n.body!,
                          style: const TextStyle(fontSize: 11, color: kTxt3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _ago(n.createdAt),
                  style: const TextStyle(fontSize: 10.5, color: kTxt3),
                ),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.crimson,
                        minimumSize: const Size(0, 34),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTxt2,
                        minimumSize: const Size(0, 34),
                        side: const BorderSide(color: kBorder, width: 1.5),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: onDecline,
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _iconFor(String type) => switch (type) {
    'JOIN' => '🏫',
    'MESSAGE' => '💬',
    'CONNECTION_ACCEPTED' => '🤝',
    _ => '•',
  };

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes} m';
    if (d.inDays < 1) return '${d.inHours} h';
    if (d.inDays < 7) return '${d.inDays} d';
    return '${t.day}/${t.month}';
  }
}
