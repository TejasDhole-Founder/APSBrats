import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Secure storage has no platform implementation in tests — answer every
  // call with null so the router treats the user as logged out.
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(storageChannel, (call) async => null);

  // The login button shimmers forever, so pump fixed durations instead of
  // pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('system back from login returns to welcome', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ApsBratApp(flavor: AppFlavor.dev)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await settle(tester);
    expect(find.text('Send Code'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await settle(tester);
    expect(handled, isTrue);
    expect(find.text("Get Started — It's Free"), findsOneWidget);
    expect(find.text('Send Code'), findsNothing);
  });
}
