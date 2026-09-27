import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/observability/error_reporter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _initFirebase() async {
  // Google sign-in needs this. Until google-services.json / GoogleService-Info.plist
  // are dropped in, this throws — caught here so the rest of the app (email OTP
  // login included) keeps working without Firebase configured yet.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase not configured yet — Google sign-in will be unavailable: $e');
  }
}

void main() {
  ErrorReporter.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.install();
    _initFirebase();
    runApp(const ProviderScope(child: ApsBratApp(flavor: AppFlavor.dev)));
  });
}
