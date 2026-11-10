import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(storageChannel, (call) async => null);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ApsBratApp(flavor: AppFlavor.dev)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Get Started opens the screen in create-account wording', (
    tester,
  ) async {
    await openApp(tester);
    await tester.ensureVisible(find.text("Get Started — It's Free"));
    await tester.tap(find.text("Get Started — It's Free"));
    await settle(tester);

    expect(find.textContaining('Join us', findRichText: true), findsOneWidget);
    expect(find.text('Create your account with your email'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
  });

  testWidgets('Log In opens the screen in log-in wording', (tester) async {
    await openApp(tester);
    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await settle(tester);

    expect(
      find.textContaining('Welcome back', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Enter your email to log in'), findsOneWidget);
  });

  testWidgets('the link switches between log in and create account', (
    tester,
  ) async {
    await openApp(tester);
    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await settle(tester);

    await tester.ensureVisible(find.text('New here?  Create an account'));
    await tester.tap(find.text('New here?  Create an account'));
    await settle(tester);
    expect(find.textContaining('Join us', findRichText: true), findsOneWidget);

    await tester.ensureVisible(find.text('Already an APS brat?  Log in'));
    await tester.tap(find.text('Already an APS brat?  Log in'));
    await settle(tester);
    expect(
      find.textContaining('Welcome back', findRichText: true),
      findsOneWidget,
    );
  });
}
