import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/features/connections/data/circle_repository.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/batch_tab.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mySchools = [
  SchoolHistory(
    id: '1',
    schoolId: 'school-1',
    schoolName: 'APS Patiala',
    classFrom: 11,
    classTo: 12,
    section: 'A',
    batchStart: 2021,
    batchEnd: 2022,
    isPrimary: true,
  ),
];

const _rahul = Person(
  id: 'u1',
  username: 'rahul',
  initials: 'RS',
  name: 'Rahul Sharma',
  school: 'APS Pune',
  detail: '12A · Class 2019',
  city: 'Pune',
  job: null,
  currentStatus: 'ALUMNI',
  profilePicUrl: null,
  online: false,
  tags: [],
  mutualCount: 3,
);

Widget _tab({
  required List<Person> friends,
  required CircleSummary summary,
  List<Person> schoolmates = const [],
}) {
  return ProviderScope(
    overrides: [
      mySchoolHistoryProvider.overrideWith((ref) async => _mySchools),
      circleSummaryProvider.overrideWith((ref) async => summary),
      batchmatesProvider.overrideWith((ref) async => friends),
      classmatesProvider.overrideWith((ref, q) async => const <Person>[]),
      schoolmatesProvider.overrideWith((ref, q) async => schoolmates),
      peopleSearchProvider.overrideWith((ref, query) async => const <Person>[]),
    ],
    child: MaterialApp(home: Scaffold(body: const BatchTab())),
  );
}

void main() {
  testWidgets('Batchmates opens on Classmates; friends live on the Social tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _tab(
        friends: const [_rahul],
        summary: const CircleSummary(
          friends: 1,
          incomingRequests: 2,
          sentRequests: 0,
          classmates: 4,
          schoolmates: 40,
          hasSection: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No Friends segment here any more: the Social tab lists friends.
    expect(find.text('Friends'), findsNothing);
    expect(find.text('Classmates'), findsOneWidget);
    expect(find.text('Batchmates'), findsWidgets);
    expect(find.text('Message'), findsNothing);
    // Bell badge still shows the incoming request count.
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
