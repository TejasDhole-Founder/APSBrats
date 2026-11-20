import 'dart:convert';

import 'package:apsbrat_frontend/app.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_draft_store.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/school_history_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory stand-in for the device's secure storage.
final Map<String, String> _disk = {};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    _disk.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          switch (call.method) {
            case 'read':
              return _disk[key];
            case 'write':
              _disk[key!] = args!['value'] as String;
              return null;
            case 'delete':
              _disk.remove(key);
              return null;
            case 'deleteAll':
              _disk.clear();
              return null;
            case 'readAll':
              return Map<String, String>.of(_disk);
            case 'containsKey':
              return _disk.containsKey(key);
          }
          return null;
        });
  });

  OnboardingDraftStore newStore() =>
      OnboardingDraftStore(const FlutterSecureStorage());

  const sample = OnboardingFlowState(
    firstName: 'Aarav',
    lastName: 'Sharma',
    username: 'aarav.sharma',
    email: 'aarav@example.com',
    dob: '01/02/2000',
    city: 'Pune',
    isStudent: true,
    schoolHistory: [
      SchoolHistoryDraft(
        schoolId: 's1',
        schoolName: 'APS Patiala',
        classFrom: '10th',
        classTo: '12th',
        section: 'A',
        isMostMissed: true,
      ),
      SchoolHistoryDraft(schoolId: 's2', schoolName: 'APS Pune'),
    ],
    instagram: 'aarav.ig',
    step: 3,
  );

  group('saving and restoring', () {
    test('state survives a JSON round trip, including schools and step', () {
      final copy = OnboardingFlowState.fromJson(
        jsonDecode(jsonEncode(sample.toJson())) as Map<String, dynamic>,
      );
      expect(copy.fullName, 'Aarav Sharma');
      expect(copy.username, 'aarav.sharma');
      expect(copy.isStudent, isTrue);
      expect(copy.instagram, 'aarav.ig');
      expect(copy.step, 3);
      expect(copy.schoolHistory.length, 2);
      expect(copy.schoolHistory.first.schoolName, 'APS Patiala');
      expect(copy.schoolHistory.first.isMostMissed, isTrue);
    });

    test(
      'a saved draft is loaded back for the same signed-in account',
      () async {
        _disk['user_id'] = 'user-1';
        final store = newStore();
        await store.save(sample);

        final loaded = await store.load();
        expect(loaded?.firstName, 'Aarav');
        expect(loaded?.step, 3);
      },
    );

    test('nothing is saved when nobody is signed in', () async {
      await newStore().save(sample);
      expect(_disk.containsKey('onboarding_draft'), isFalse);
    });

    test("another account's draft is discarded, not shown", () async {
      _disk['user_id'] = 'user-1';
      final store = newStore();
      await store.save(sample);

      _disk['user_id'] = 'user-2';
      expect(await store.load(), isNull);
      expect(_disk.containsKey('onboarding_draft'), isFalse);
    });

    test('an unreadable draft is ignored and removed', () async {
      _disk['user_id'] = 'user-1';
      _disk['onboarding_draft'] = '{not json';
      expect(await newStore().load(), isNull);
      expect(_disk.containsKey('onboarding_draft'), isFalse);
    });
  });

  group('the notifier', () {
    test('every change is written to the device', () async {
      _disk['user_id'] = 'user-1';
      final notifier = OnboardingFlowNotifier(newStore());

      notifier.syncIdentity(
        firstName: 'Aarav',
        lastName: 'Sharma',
        username: 'aarav',
        dob: '',
        city: 'Pune',
        profession: '',
        gender: '',
        isStudent: false,
      );
      await pumpEventQueue();

      final saved = await newStore().load();
      expect(saved?.firstName, 'Aarav');
      expect(saved?.city, 'Pune');
    });

    test('the step only moves forward', () {
      final notifier = OnboardingFlowNotifier(newStore());
      notifier.markStep(3);
      notifier.markStep(2);
      expect(notifier.step, 3);
    });

    test('a fresh notifier picks the draft back up', () async {
      _disk['user_id'] = 'user-1';
      await newStore().save(sample);

      final notifier = OnboardingFlowNotifier(newStore());
      expect(
        await resumeOnboardingRoute(notifier),
        '/onboarding/schools/socials',
      );
      expect(notifier.step, 3);
    });

    test(
      'a late draft load never overwrites what the user already typed',
      () async {
        _disk['user_id'] = 'user-1';
        await newStore().save(sample);

        final notifier = OnboardingFlowNotifier(newStore());
        notifier.markStep(2);
        await notifier.hydrate();
        expect(notifier.step, 2);
      },
    );

    test('finishing registration forgets the draft', () async {
      _disk['user_id'] = 'user-1';
      final notifier = OnboardingFlowNotifier(newStore());
      notifier.markStep(2);
      await pumpEventQueue();
      expect(_disk.containsKey('onboarding_draft'), isTrue);

      notifier.reset();
      await pumpEventQueue();
      expect(_disk.containsKey('onboarding_draft'), isFalse);
    });

    test('with no draft the user starts at the profile step', () async {
      _disk['user_id'] = 'user-1';
      expect(
        await resumeOnboardingRoute(OnboardingFlowNotifier(newStore())),
        '/onboarding',
      );
    });
  });

  group('closing and reopening the app', () {
    Future<void> launchWithDraft(WidgetTester tester, int step) async {
      _disk['user_id'] = 'user-1';
      await newStore().save(sample.copyWith(step: step));
      // A roomy screen (the test font is wider than the real one) and no real
      // network: the school picker gets an empty list.
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The test font is wider than the real one, so some cards report tiny
      // pixel overflows that do not happen on a device. Ignore only those.
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

    // Closes the app and lets the deferred "save on leave" timer run before the
    // test ends.
    Future<void> closeApp(WidgetTester tester) async {
      // Let the pending profile request (a dio timeout) finish while the app
      // is still alive; otherwise it fires after the providers are disposed.
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('step 1: the typed details are back in the form', (
      tester,
    ) async {
      await launchWithDraft(tester, 1);
      expect(
        find.textContaining('TELL US ABOUT', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Aarav'), findsOneWidget);
      expect(find.text('Sharma'), findsOneWidget);
      expect(find.text('aarav.sharma'), findsOneWidget);
      // The login email is shown even though no live session exists yet.
      expect(find.text('aarav@example.com'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('step 2: the user lands on the schools screen', (tester) async {
      await launchWithDraft(tester, 2);
      expect(
        find.textContaining('CALL HOME', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('TELL US ABOUT', findRichText: true),
        findsNothing,
      );
      await closeApp(tester);
    });
  });
}
