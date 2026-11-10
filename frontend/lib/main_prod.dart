import 'package:apsbrat_frontend/core/app_root.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/observability/error_reporter.dart';
import 'package:flutter/material.dart';

void main() {
  ErrorReporter.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.install();
    runApp(const AppRoot(flavor: AppFlavor.prod));
  });
}
