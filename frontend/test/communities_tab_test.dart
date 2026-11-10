import 'package:apsbrat_frontend/features/feed/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('five tabs fit a phone and Communities opens its own page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();

    for (final label in [
      'Home',
      'Batchmates',
      'Communities',
      'Messages',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }

    await tester.tap(find.text('Communities').last);
    await tester.pump();
    // The real tab: search box and the Discover section (no server in tests).
    expect(find.text('Discover'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Home opens the chat connection, which leaves a retry timer behind.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
