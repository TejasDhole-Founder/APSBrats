import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:flutter_test/flutter_test.dart';

SchoolHistoryDraft school(
  String name,
  int from,
  int to,
  String joined,
  String left,
) => SchoolHistoryDraft(
  schoolId: name,
  schoolName: name,
  classFrom: '$from',
  classTo: '$to',
  stream: to >= 11 ? 'COMMERCE' : '',
  yearJoined: joined,
  yearLeft: left,
);

void main() {
  test('adjacent schools sharing the boundary year are fine', () {
    expect(
      schoolDraftsProblem([
        school('APS Pune', 6, 9, '2015', '2019'),
        school('APS Delhi', 10, 12, '2019', '2022'),
      ]),
      isNull,
    );
  });

  test('rejects overlapping years', () {
    expect(
      schoolDraftsProblem([
        school('APS Pune', 8, 9, '2018', '2020'),
        school('APS Delhi', 10, 12, '2019', '2021'),
      ]),
      contains('overlap in years'),
    );
  });

  test('rejects overlapping classes', () {
    expect(
      schoolDraftsProblem([
        school('APS Pune', 8, 10, '2016', '2019'),
        school('APS Delhi', 10, 12, '2019', '2022'),
      ]),
      contains('overlap in classes'),
    );
  });

  test('rejects lower classes after higher classes', () {
    expect(
      schoolDraftsProblem([
        school('APS Pune', 10, 12, '2015', '2018'),
        school('APS Delhi', 6, 9, '2019', '2022'),
      ]),
      contains('lower classes'),
    );
  });

  test('class 11-12 entries need a stream', () {
    expect(
      schoolDraftsProblem([
        school('APS Pune', 10, 12, '2019', '2022').copyWith(stream: ''),
      ]),
      contains('stream'),
    );
    expect(
      schoolDraftsProblem([school('APS Pune', 6, 10, '2015', '2019')]),
      isNull,
    );
  });

  test('works when years are left blank', () {
    expect(
      schoolDraftsProblem([
        school('APS Pune', 6, 9, '', ''),
        school('APS Delhi', 10, 12, '', ''),
      ]),
      isNotNull,
    );
  });
}
