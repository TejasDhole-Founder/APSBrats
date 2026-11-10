import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget frame(int step) => MaterialApp(
    home: OnboardingFrame(
      step: step,
      title: 'Title',
      subtitle: 'Subtitle',
      child: const SizedBox(),
    ),
  );

  testWidgets('progress bar has three steps and no Verify step', (
    tester,
  ) async {
    await tester.pumpWidget(frame(1));
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Schools'), findsOneWidget);
    expect(find.text('Socials'), findsOneWidget);
    expect(find.text('Verify'), findsNothing);
  });

  testWidgets('the last step is 3', (tester) async {
    await tester.pumpWidget(frame(3));
    await tester.pump();

    expect(find.text('3'), findsWidgets);
    expect(find.text('4'), findsNothing);
  });
}
