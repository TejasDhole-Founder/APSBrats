import 'dart:async';

import 'package:flutter/foundation.dart';

/// Central crash/error sink. Today it logs; it is the single seam where a real
/// backend (Crashlytics/Sentry) is attached without touching call sites.
///
/// Wire real reporting by replacing the body of [report] (e.g. call
/// `FirebaseCrashlytics.instance.recordError` / `Sentry.captureException`).
class ErrorReporter {
  const ErrorReporter._();

  static bool _installed = false;

  /// Installs global Flutter + async error handlers. Call once from `main`.
  static void install() {
    if (_installed) return;
    _installed = true;

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousOnError?.call(details);
      report(details.exception, details.stack, context: details.context?.toString());
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      report(error, stack, context: 'PlatformDispatcher');
      return true;
    };
  }

  /// Runs [body] in a guarded zone so uncaught async errors are captured.
  static void runGuarded(void Function() body) {
    runZonedGuarded(body, (error, stack) => report(error, stack, context: 'Zone'));
  }

  static void report(Object error, StackTrace? stack, {String? context}) {
    // In release, forward to the configured crash backend instead of printing.
    debugPrint('[ErrorReporter${context == null ? '' : ':$context'}] $error');
    if (stack != null && kDebugMode) {
      debugPrintStack(stackTrace: stack);
    }
  }
}
