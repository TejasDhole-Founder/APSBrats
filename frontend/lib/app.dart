import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/routes/app_router.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApsBratApp extends ConsumerWidget {
  const ApsBratApp({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    ref.listen<bool>(sessionExpiredProvider, (previous, expired) {
      if (expired) {
        router.go('/login');
        ref.read(sessionExpiredProvider.notifier).state = false;
      }
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
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
