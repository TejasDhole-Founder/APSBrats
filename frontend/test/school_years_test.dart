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
    // The year fields are read-only: a tap opens the year wheel, Done picks.
    String yearText(WidgetTester tester, int field) =>
        tester
            .widget<TextField>(find.byType(TextField).at(field))
            .controller!
            .text;

    Future<void> pickYear(WidgetTester tester, int field) async {
      await tester.tap(find.byType(TextField).at(field));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

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

    testWidgets('picking the year joined fills the year left', (tester) async {
      await showCard(tester, class11to12.copyWith(yearJoined: '2019'));
      await pickYear(tester, 1);
      expect(yearText(tester, 2), '2021');
    });

    testWidgets('picking the year left fills the year joined', (tester) async {
      await showCard(tester, class11to12.copyWith(yearLeft: '2021'));
      await pickYear(tester, 2);
      expect(yearText(tester, 1), '2019');
    });

    testWidgets('a year you set yourself is never overwritten', (
      tester,
    ) async {
      await showCard(
        tester,
        class11to12.copyWith(yearJoined: '2019', yearLeft: '2022'),
      );
      // Re-picking the joined year must leave your 2022 alone.
      await pickYear(tester, 1);
      expect(yearText(tester, 1), '2019');
      expect(yearText(tester, 2), '2022');
    });
  });
}
