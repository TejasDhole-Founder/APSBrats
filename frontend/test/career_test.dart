import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_draft_store.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/school_history_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, String> _disk = {};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _disk
      ..clear()
      ..['user_id'] = 'user-1';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map?;
            final key = args?['key'] as String?;
            switch (call.method) {
              case 'read':
                return _disk[key];
              case 'write':
                _disk[key!] = args!['value'] as String;
              case 'delete':
                _disk.remove(key);
            }
            return null;
          },
        );
  });

  OnboardingFlowNotifier notifier() => OnboardingFlowNotifier(
    OnboardingDraftStore(const FlutterSecureStorage()),
  );

  group('what is sent to the server', () {
    test('a picked company sends its id, a typed one sends the name', () {
      const picked = CareerDraft(
        organizationId: 'org-1',
        organizationName: 'Zomato',
        title: 'Engineer',
        startYear: 2022,
        startMonth: 6,
      );
      expect(picked.toRequest()['organizationId'], 'org-1');
      expect(picked.toRequest().containsKey('organizationName'), isFalse);
      expect(picked.toRequest()['startDate'], '2022-06-01');
      expect(picked.toRequest()['endDate'], isNull);

      final typed = picked.copyWith(organizationId: '');
      expect(typed.toRequest()['organizationName'], 'Zomato');
      expect(typed.toRequest().containsKey('organizationId'), isFalse);
    });

    test('college uses whole years', () {
      const study = CareerDraft(
        kind: kEducation,
        organizationName: 'NIT Trichy',
        title: 'B.Tech',
        startYear: 2017,
        startMonth: 8,
        endYear: 2021,
        current: false,
      );
      expect(study.toRequest()['startDate'], '2017-01-01');
      expect(study.toRequest()['endDate'], '2021-01-01');
    });

    test('missing fields and backwards dates are caught before saving', () {
      expect(const CareerDraft().problem, 'Enter your company');
      expect(
        const CareerDraft(
          organizationName: 'TCS',
          title: 'Intern',
          startYear: 2021,
          startMonth: 5,
          endYear: 2021,
          endMonth: 1,
          current: false,
        ).problem,
        "The end can't be before the start",
      );
    });
  });

  test('the headline prefers the current job and skips hidden entries', () {
    CareerEntry entry(
      String kind,
      String title,
      String org, {
      DateTime? end,
      bool hidden = false,
    }) => CareerEntry(
      id: title,
      kind: kind,
      organizationId: org,
      organizationName: org,
      title: title,
      startDate: DateTime(2020),
      endDate: end,
      isHidden: hidden,
    );

    expect(
      careerHeadline([
        entry(kEducation, 'MBA', 'IIM A'),
        entry(kWork, 'Engineer', 'Zomato'),
      ]),
      'Engineer at Zomato',
    );
    expect(
      careerHeadline([entry(kWork, 'Engineer', 'Zomato', hidden: true)]),
      isNull,
    );
    expect(
      careerHeadline([entry(kWork, 'Intern', 'TCS', end: DateTime(2021))]),
      isNull,
    );
  });

  group('signup steps', () {
    test('alumni resume on After school, students skip it', () async {
      final alumni = notifier()..markStep(3);
      expect(
        await resumeOnboardingRoute(alumni),
        '/onboarding/schools/after-school',
      );
      alumni.markStep(4);
      expect(
        await resumeOnboardingRoute(alumni),
        '/onboarding/schools/after-school/socials',
      );

      final student = notifier()
        ..syncIdentity(
          firstName: 'A',
          lastName: 'B',
          username: 'ab',
          dob: '',
          city: '',
          profession: '',
          gender: '',
          isStudent: true,
        )
        ..markStep(4);
      expect(
        await resumeOnboardingRoute(student),
        '/onboarding/schools/socials',
      );
    });

    test('starts with one blank job and one blank college; add as many as '
        'you like; Skip clears them', () {
      final flow = notifier();
      expect(flow.debugState.career.map((c) => c.kind), [kWork, kEducation]);
      expect(flow.debugState.career.every((c) => c.isBlank), isTrue);

      flow
        ..addCareer(kWork)
        ..addCareer(kWork)
        ..addCareer(kEducation);
      final kinds = flow.debugState.career.map((c) => c.kind).toList();
      expect(kinds.where((k) => k == kWork).length, 3);
      expect(kinds.where((k) => k == kEducation).length, 2);
      // A new job is "currently here", a new college is finished.
      expect(flow.debugState.career[2].current, isTrue);
      expect(flow.debugState.career.last.current, isFalse);

      flow.removeCareer(0);
      expect(flow.debugState.career.length, 4);

      flow.skipAfterSchool();
      expect(flow.debugState.career, isEmpty);
    });

    test('the After school answers survive closing the app', () {
      const saved = OnboardingFlowState(
        career: [
          CareerDraft(
            organizationName: 'Zomato',
            title: 'Engineer',
            startYear: 2022,
          ),
          CareerDraft(
            organizationName: 'TCS',
            title: 'Intern',
            startYear: 2021,
          ),
        ],
      );
      final copy = OnboardingFlowState.fromJson(saved.toJson());
      expect(copy.career.map((c) => c.organizationName), ['Zomato', 'TCS']);
      expect(copy.career.first.startYear, 2022);
    });
  });

  group('progress bar', () {
    Widget frame({required bool alumni, int step = 1}) => MaterialApp(
      home: OnboardingFrame(
        step: step,
        showAfterSchool: alumni,
        title: 'Title',
        subtitle: 'Subtitle',
        child: const SizedBox(),
      ),
    );

    testWidgets('alumni see four steps', (tester) async {
      await tester.pumpWidget(frame(alumni: true));
      expect(find.text('After school'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('students see three, ending on Socials', (tester) async {
      await tester.pumpWidget(frame(alumni: false, step: 4));
      expect(find.text('After school'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsNothing);
    });
  });

  Future<void> launchAt(WidgetTester tester, String draftJson) async {
    _disk['onboarding_draft'] = draftJson;
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apsSchoolsProvider.overrideWith((ref) async => const [])],
        child: const ApsBratApp(flavor: AppFlavor.dev),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Back walks an alumnus from Socials to the first step, keeping '
      'what they typed', (tester) async {
    await launchAt(
      tester,
      '{"userId":"user-1","state":{"firstName":"Aarav","step":4,'
      '"isStudent":false,'
      '"career":[{"kind":"WORK","organizationName":"Zomato"}]}}',
    );
    expect(find.textContaining('socials', findRichText: true), findsWidgets);

    await tapBack(tester);
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('Zomato'), findsOneWidget);

    await tapBack(tester);
    expect(
      find.textContaining('call home', findRichText: true),
      findsOneWidget,
    );

    await tapBack(tester);
    expect(
      find.textContaining('tell us about', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Aarav'), findsOneWidget);
    // First step: nothing to go back to.
    expect(find.byTooltip('Back'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('after reopening the app, finishing registration does not claim '
      'the session expired', (tester) async {
    // Saved login on the device, but nothing in memory (fresh app start).
    await launchAt(
      tester,
      '{"userId":"user-1","state":{"firstName":"Aarav","step":4,"isStudent":true}}',
    );
    await tester.tap(find.text('Complete registration'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('session expired'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('a student goes back from Socials straight to Schools', (
    tester,
  ) async {
    await launchAt(
      tester,
      '{"userId":"user-1","state":{"firstName":"Aarav","step":4,"isStudent":true}}',
    );
    await tapBack(tester);
    expect(
      find.textContaining('call home', findRichText: true),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('an alumnus reopening the app lands on After school, and Skip '
      'moves on to Socials', (tester) async {
    _disk['onboarding_draft'] =
        '{"userId":"user-1","state":{"firstName":"Aarav","step":3,"isStudent":false}}';
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apsSchoolsProvider.overrideWith((ref) async => const [])],
        child: const ApsBratApp(flavor: AppFlavor.dev),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('after', findRichText: true), findsWidgets);
    // One blank job card and one blank college card to start with.
    expect(find.text('COMPANY'), findsOneWidget);
    expect(find.text('COLLEGE / INSTITUTE'), findsOneWidget);

    // Two more companies.
    await tester.tap(find.text('Add another company'));
    await tester.pump();
    await tester.tap(find.text('Add another company'));
    await tester.pump();
    expect(find.text('COMPANY'), findsNWidgets(3));

    // Blank cards don't block Continue.
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('socials', findRichText: true), findsWidgets);

    await tapBack(tester);
    // A half-filled card does block it, with a reason.
    await tester.enterText(find.byType(TextField).first, 'Zomato');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter your job title'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('socials', findRichText: true), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
