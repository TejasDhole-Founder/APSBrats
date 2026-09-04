import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Secure storage has no platform implementation in tests — answer every
  // call with null so the router treats the user as logged out.
  const storageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(storageChannel, (call) async => null);

  testWidgets('renders splash screen route', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ApsBratApp(flavor: AppFlavor.dev),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Get started — it's free"), findsOneWidget);
  });
}
