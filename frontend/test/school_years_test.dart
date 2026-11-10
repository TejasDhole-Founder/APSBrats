import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/school_history_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const class11to12 = SchoolHistoryDraft(classFrom: '11th', classTo: '12th');

  group('working out the other year', () {
    test('joined Class 11 in 2019 -> left after Class 12 in 2021', () {
      final d = fillSchoolYear(
        class11to12.copyWith(yearJoined: '2019'),
        'left',
      );
      expect(d.yearLeft, '2021');
    });

    test('and the other way round', () {
      final d = fillSchoolYear(
        class11to12.copyWith(yearLeft: '2021'),
        'joined',
      );
      expect(d.yearJoined, '2019');
    });

    test('Class 1 to 10 is ten years', () {
      const d = SchoolHistoryDraft(
        classFrom: '1st',
        classTo: '10th',
        yearJoined: '2005',
      );
      expect(fillSchoolYear(d, 'left').yearLeft, '2015');
    });

    test(
      'nothing is guessed until both classes are picked or the year is complete',
      () {
        const noClasses = SchoolHistoryDraft(yearJoined: '2019');
        expect(fillSchoolYear(noClasses, 'left').yearLeft, '');
        final half = fillSchoolYear(
          class11to12.copyWith(yearJoined: '201'),
          'left',
        );
        expect(half.yearLeft, '');
      },
    );
  });

  group('in the school card', () {
    Future<void> showCard(WidgetTester tester, SchoolHistoryDraft start) async {
      var draft = start;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apsSchoolsProvider.overrideWith((ref) async => const [])],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => SchoolHistoryEditor(
                    drafts: [draft],
                    onAdd: () {},
                    onRemove: (_) {},
                    onUpdate: (_, d) => setState(() => draft = d),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('typing the year joined fills the year left', (tester) async {
      await showCard(tester, class11to12);
      await tester.enterText(find.byType(TextField).at(1), '2019');
      await tester.pump();
      expect(find.text('2021'), findsOneWidget);
    });

    testWidgets('typing the year left fills the year joined', (tester) async {
      await showCard(tester, class11to12);
      await tester.enterText(find.byType(TextField).at(2), '2021');
      await tester.pump();
      expect(find.text('2019'), findsOneWidget);
    });

    testWidgets('a year you typed yourself is never overwritten', (
      tester,
    ) async {
      await showCard(tester, class11to12);
      await tester.enterText(find.byType(TextField).at(1), '2019');
      await tester.pump();
      // Correct the suggestion by hand (e.g. repeated a year).
      await tester.enterText(find.byType(TextField).at(2), '2022');
      await tester.pump();
      // Changing the joined year now leaves your 2022 alone.
      await tester.enterText(find.byType(TextField).at(1), '2018');
      await tester.pump();
      expect(find.text('2022'), findsOneWidget);
      expect(find.text('2018'), findsOneWidget);
    });
  });
}
