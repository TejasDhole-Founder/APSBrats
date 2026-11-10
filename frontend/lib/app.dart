import 'package:apsbrat_frontend/core/app_root.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/routes/app_router.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_socket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApsBratApp extends ConsumerWidget {
  const ApsBratApp({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    ref.listen<bool>(sessionExpiredProvider, (previous, expired) async {
      if (!expired) return;
      await ref.read(authRepositoryProvider).clearLocal();
      if (context.mounted) await AppRoot.restart(context);
    });
    return MaterialApp.router(
      title: 'APS Brat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return Banner(
          message: flavor.name.toUpperCase(),
          location: BannerLocation.topEnd,
          color: flavor == AppFlavor.prod
              ? Colors.transparent
              : AppColors.goldDark.withValues(alpha: 0.92),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          child: _PhoneWidth(
            child: _ConnectionBanner(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

/// Every screen is a single phone-style column. On a tablet or desktop browser it
/// is centred at [_maxWidth] instead of stretched edge to edge, and MediaQuery
/// reports that width, so screens that size things from it lay out the same way.
class _PhoneWidth extends StatelessWidget {
  const _PhoneWidth({required this.child});

  static const _maxWidth = 640.0;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width.clamp(0.0, _maxWidth);
    // Same widget shape at every width: resizing a browser window across
    // _maxWidth must not rebuild the Navigator and lose the back stack.
    return ColoredBox(
      color: const Color(0xFFF3F0EC),
      child: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A strip above every screen while the server is unreachable or chat is
/// reconnecting. The widget tree keeps the same shape either way, so the
/// router's Navigator (and the back stack) is never rebuilt.
class _ConnectionBanner extends ConsumerWidget {
  const _ConnectionBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(networkOfflineProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: ref.watch(chatSocketProvider).reconnecting,
      builder: (context, reconnecting, _) {
        final message = offline
            ? "You're offline. We'll retry when you're back."
            : reconnecting
            ? 'Reconnecting to chat…'
            : null;
        return Column(
          children: [
            if (message != null)
              Material(
                color: AppColors.crimson,
                child: SafeArea(
                  bottom: false,
                  child: Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            offline
                                ? Icons.cloud_off_rounded
                                : Icons.sync_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: message != null,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
