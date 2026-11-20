import 'dart:async';

import 'package:apsbrat_frontend/core/app_root.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/routes/app_router.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_socket.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      localizationsDelegates: const [CountryLocalizations.delegate],
      builder: (context, child) {
        final content = _PhoneWidth(
          child: _ConnectionBanner(child: child ?? const SizedBox.shrink()),
        );
        // Production shows no corner banner at all.
        if (flavor == AppFlavor.prod) return content;
        return Banner(
          message: flavor.name.toUpperCase(),
          location: BannerLocation.topEnd,
          color: AppColors.goldDark.withValues(alpha: 0.92),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          child: content,
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

/// A strip above the screen while the server is unreachable or chat is
/// reconnecting. It appears only after the problem has lasted [_delay], and
/// never on the splash or login screens. The widget tree keeps the same shape
/// either way, so the router's Navigator (and the back stack) is never rebuilt.
class _ConnectionBanner extends ConsumerStatefulWidget {
  const _ConnectionBanner({required this.child});

  final Widget child;

  @override
  ConsumerState<_ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends ConsumerState<_ConnectionBanner> {
  static const _delay = Duration(seconds: 10);
  static const _quietPaths = {'/', '/login'};

  Timer? _timer;
  bool _showBanner = false;
  late final ValueNotifier<bool> _reconnecting;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _reconnecting = ref.read(chatSocketProvider).reconnecting;
    _reconnecting.addListener(_refresh);
    _router = ref.read(appRouterProvider);
    _router.routeInformationProvider.addListener(_refresh);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reconnecting.removeListener(_refresh);
    _router.routeInformationProvider.removeListener(_refresh);
    super.dispose();
  }

  bool get _problem => ref.read(networkOfflineProvider) || _reconnecting.value;

  bool get _onQuietScreen =>
      _quietPaths.contains(_router.routeInformationProvider.value.uri.path);

  void _refresh() {
    if (!mounted) return;
    if (_problem) {
      _timer ??= Timer(_delay, () {
        _timer = null;
        if (mounted && _problem) setState(() => _showBanner = true);
      });
    } else {
      _timer?.cancel();
      _timer = null;
      if (_showBanner) setState(() => _showBanner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(networkOfflineProvider, (_, _) => _refresh());
    final offline = ref.watch(networkOfflineProvider);
    final reconnecting = _reconnecting.value;
    final message = offline
        ? "You're offline. We'll retry when you're back."
        : reconnecting
        ? 'Reconnecting to chat…'
        : null;
    final show = _showBanner && message != null && !_onQuietScreen;

    return Column(
      children: [
        if (show)
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
                      HugeIcon(
                        icon: offline
                            ? HugeIcons.strokeRoundedCloudOff
                            : HugeIcons.strokeRoundedRefresh,
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
            removeTop: show,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
