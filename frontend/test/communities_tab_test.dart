import 'package:apsbrat_frontend/features/feed/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('four tabs fit a phone and Social opens Communities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();

    for (final label in ['Home', 'Batchmates', 'Social', 'Profile']) {
      expect(find.text(label), findsWidgets, reason: label);
    }

    // Messages and Communities share the Social tab behind a segmented control.
    await tester.tap(find.text('Social').last);
    await tester.pump();
    await tester.tap(find.text('Communities').last);
    await tester.pump();
    // The real tab: the Discover section (no server in tests).
    expect(find.text('Discover Communities'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Home opens the chat connection, which leaves a retry timer behind.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
