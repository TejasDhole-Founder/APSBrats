import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  Widget field(Widget? Function(Widget icon) wrap) => MaterialApp(
    home: Scaffold(
      body: TextField(
        decoration: InputDecoration(
          prefixIcon: wrap(
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar04,
              size: 18,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('an icon in a field slot keeps the size it was given', (
    tester,
  ) async {
    await tester.pumpWidget(field(fieldIconSlot));
    await tester.pump();

    expect(tester.getSize(find.byType(HugeIcon)), const Size(18, 18));
  });

  testWidgets('without the slot helper the field stretches the icon', (
    tester,
  ) async {
    await tester.pumpWidget(field((icon) => icon));
    await tester.pump();

    // The reason fieldIconSlot exists: the slot forces 48 px and a HugeIcon
    // draws itself to fill its box.
    expect(tester.getSize(find.byType(HugeIcon)).width, greaterThan(18));
  });

  testWidgets('appInputDecoration suffix icons are not stretched', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            decoration: appInputDecoration(
              'DD / MM / YYYY',
              suffix: const HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar03,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(HugeIcon)), const Size(16, 16));
  });
}
