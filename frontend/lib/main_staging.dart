import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/observability/error_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  ErrorReporter.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.install();
    runApp(
      const ProviderScope(
        child: ApsBratApp(flavor: AppFlavor.staging),
      ),
    );
  });
}
