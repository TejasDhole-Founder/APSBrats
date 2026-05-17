import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('renders splash screen route', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ApsBratApp(flavor: AppFlavor.dev),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to APS Brat'), findsOneWidget);
  });
}
