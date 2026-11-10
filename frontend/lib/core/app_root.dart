import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the app's [ProviderScope]. [AppRoot.restart] swaps in a brand-new one,
/// which drops every cached provider (profile, conversations, friends...) and
/// closes the chat socket -- so nothing from one user can show up for the next.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.flavor});

  final AppFlavor flavor;

  /// Wipes in-memory state and returns the app to its first screen. Call it
  /// after the stored session has been cleared.
  static Future<void> restart(BuildContext context) async {
    final state = context.findAncestorStateOfType<_AppRootState>();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    try {
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
    } catch (_) {}
    state?._restart();
  }

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Key _scopeKey = UniqueKey();

  void _restart() {
    if (mounted) setState(() => _scopeKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _scopeKey,
      child: ProviderScope(child: ApsBratApp(flavor: widget.flavor)),
    );
  }
}
