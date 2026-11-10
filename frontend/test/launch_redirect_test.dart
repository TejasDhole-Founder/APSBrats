import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/core/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  // A signed-in account that never finished registration: a user id is saved,
  // the onboarding-done flag is not.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'read' && call.arguments['key'] == 'user_id') {
            return 'user-1';
          }
          return null;
        });
  });

  testWidgets('unfinished registration resumes on launch, but back to the '
      'welcome screen is not bounced into it again', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ApsBratApp(flavor: AppFlavor.dev)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.textContaining('tell us about', findRichText: true),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final router = container.read(appRouterProvider);

    router.go('/login?mode=signup');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Send Code'), findsOneWidget);

    router.go('/');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text("Get Started — It's Free"), findsOneWidget);
    expect(
      find.textContaining('tell us about', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('without a verified email, any registration screen sends you '
      'to verify your email first', (tester) async {
    // Nobody has verified an OTP: no user id is stored.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);

    await tester.pumpWidget(
      const ProviderScope(child: ApsBratApp(flavor: AppFlavor.dev)),
    );
    await tester.pump();
    final router = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(appRouterProvider);

    for (final location in [
      '/onboarding',
      '/onboarding/schools',
      '/onboarding/schools/after-school',
      '/onboarding/schools/socials',
    ]) {
      router.go(location);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/login?mode=signup',
        reason: '$location should redirect',
      );
      expect(find.text('Send Code'), findsOneWidget);
    }
  });
}
