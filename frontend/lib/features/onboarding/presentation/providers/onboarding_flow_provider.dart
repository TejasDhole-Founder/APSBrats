import 'dart:async';

import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_draft_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SchoolHistoryDraft {
  const SchoolHistoryDraft({
    this.schoolId = '',
    this.schoolName = '',
    this.classFrom = '',
    this.classTo = '',
    this.section = '',
    this.stream = '',
    this.yearJoined = '',
    this.yearLeft = '',
    this.isMostMissed = false,
  });

  final String schoolId;
  final String schoolName;
  final String classFrom;
  final String classTo;
  final String section;

  /// Stream code (see kStreams), only for entries reaching Class 11/12.
  final String stream;
  final String yearJoined;
  final String yearLeft;
  final bool isMostMissed;

  Map<String, dynamic> toJson() => {
    'schoolId': schoolId,
    'schoolName': schoolName,
    'classFrom': classFrom,
    'classTo': classTo,
    'section': section,
    'stream': stream,
    'yearJoined': yearJoined,
    'yearLeft': yearLeft,
    'isMostMissed': isMostMissed,
  };

  factory SchoolHistoryDraft.fromJson(Map<String, dynamic> json) =>
      SchoolHistoryDraft(
        schoolId: json['schoolId'] as String? ?? '',
        schoolName: json['schoolName'] as String? ?? '',
        classFrom: json['classFrom'] as String? ?? '',
        classTo: json['classTo'] as String? ?? '',
        section: json['section'] as String? ?? '',
        stream: json['stream'] as String? ?? '',
        yearJoined: json['yearJoined'] as String? ?? '',
        yearLeft: json['yearLeft'] as String? ?? '',
        isMostMissed: json['isMostMissed'] as bool? ?? false,
      );

  SchoolHistoryDraft copyWith({
    String? schoolId,
    String? schoolName,
    String? classFrom,
    String? classTo,
    String? section,
    String? stream,
    String? yearJoined,
    String? yearLeft,
    bool? isMostMissed,
  }) {
    return SchoolHistoryDraft(
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      classFrom: classFrom ?? this.classFrom,
      classTo: classTo ?? this.classTo,
      section: section ?? this.section,
      stream: stream ?? this.stream,
      yearJoined: yearJoined ?? this.yearJoined,
      yearLeft: yearLeft ?? this.yearLeft,
      isMostMissed: isMostMissed ?? this.isMostMissed,
    );
  }
}

/// Why the school list cannot be saved yet, or null when every card is complete
/// and no two schools overlap in classes or years.
String? schoolDraftsProblem(List<SchoolHistoryDraft> drafts) {
  if (drafts.isEmpty) return 'Add at least one school.';
  final incomplete = drafts.any(
    (d) => d.schoolId.isEmpty || d.classFrom.isEmpty || d.classTo.isEmpty,
  );
  if (incomplete) {
    return 'Please select a school, class from, and class to for each card.';
  }
  for (final d in drafts) {
    final joined = int.tryParse(d.yearJoined);
    final left = int.tryParse(d.yearLeft);
    if (joined != null && left != null && left < joined) {
      return '${_label(d)}: year left cannot be before year joined.';
    }
    if (_classTo(d) < _classFrom(d)) {
      return '${_label(d)}: "class to" cannot be lower than "class from".';
    }
    if (needsStream(d) && d.stream.isEmpty) {
      return 'Pick the stream (Science / Commerce / Arts) for ${_label(d)}.';
    }
  }
  return schoolOverlapProblem(drafts);
}

/// A student is in one school at a time, so two entries may not share a
/// class or an academic year. Sessions run April to March, so one school
/// ending in 2019 and the next starting in 2019 is fine; 8-9 in 2018-2020
/// and 10-12 in 2019-2021 is not.
String? schoolOverlapProblem(List<SchoolHistoryDraft> drafts) {
  for (var i = 0; i < drafts.length; i++) {
    for (var j = i + 1; j < drafts.length; j++) {
      final a = drafts[i];
      final b = drafts[j];
      final classesOverlap =
          _classFrom(a) <= _classTo(b) && _classFrom(b) <= _classTo(a);
      if (classesOverlap) {
        return '${_label(a)} and ${_label(b)} overlap in classes. '
            'Each class can belong to only one school.';
      }
      final (aStart, aEnd) = _years(a);
      final (bStart, bEnd) = _years(b);
      final yearsOverlap = aStart < bEnd && bStart < aEnd;
      if (yearsOverlap) {
        return '${_label(a)} ($aStart-$aEnd) and ${_label(b)} ($bStart-$bEnd) '
            'overlap in years. You can only be in one school at a time.';
      }
      // Lower classes must come earlier in time than higher classes.
      final aFirst = _classTo(a) < _classFrom(b);
      final earlierEnd = aFirst ? aEnd : bEnd;
      final laterStart = aFirst ? bStart : aStart;
      if (earlierEnd > laterStart) {
        return '${_label(a)} and ${_label(b)}: the lower classes must be '
            'in the earlier years.';
      }
    }
  }
  return null;
}

/// How many school years a card covers. One class takes one session, so
/// Class 11 to 12 is two: joining in 2019 means leaving in 2021.
/// Null until both classes are picked.
int? schoolSpanYears(SchoolHistoryDraft d) {
  if (d.classFrom.isEmpty || d.classTo.isEmpty) return null;
  final span = _classTo(d) - _classFrom(d) + 1;
  return span < 1 ? null : span;
}

/// Works out one year from the other. [fill] is 'left' (from Year Joined) or
/// 'joined' (from Year Left). The source year must be a full 4-digit year;
/// otherwise the filled year is cleared rather than left stale.
SchoolHistoryDraft fillSchoolYear(SchoolHistoryDraft d, String fill) {
  final span = schoolSpanYears(d);
  if (span == null) return d;
  int? year(String s) {
    final y = int.tryParse(s);
    return (s.length == 4 && y != null && y >= 1900) ? y : null;
  }

  if (fill == 'left') {
    final joined = year(d.yearJoined);
    return d.copyWith(yearLeft: joined == null ? '' : '${joined + span}');
  }
  final left = year(d.yearLeft);
  return d.copyWith(yearJoined: left == null ? '' : '${left - span}');
}

/// Stream is chosen in Class 11, so only entries reaching 11 or 12 have one.
const kStreamFirstClass = 11;

bool needsStream(SchoolHistoryDraft d) => _classTo(d) >= kStreamFirstClass;

/// Dropdown labels are "10th" etc.; only the digits matter.
int _classNumber(String label) =>
    int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

int _classFrom(SchoolHistoryDraft d) => _classNumber(d.classFrom);
int _classTo(SchoolHistoryDraft d) => _classNumber(d.classTo);

/// Years as they will be saved: a missing "left" means this year and a
/// missing "joined" means left minus the number of classes (same rule as the
/// API payload builder).
(int, int) _years(SchoolHistoryDraft d) {
  final end = int.tryParse(d.yearLeft) ?? DateTime.now().year;
  final start = int.tryParse(d.yearJoined) ?? (end - (schoolSpanYears(d) ?? 1));
  return (start, end);
}

String _label(SchoolHistoryDraft d) {
  final name = d.schoolName.isEmpty ? 'School' : d.schoolName;
  return '$name (Class ${d.classFrom}-${d.classTo})';
}

class OnboardingFlowState {
  const OnboardingFlowState({
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.email = '',
    this.dob = '',
    this.city = '',
    this.profession = '',
    this.gender = '',
    this.isStudent = false,
    this.schoolHistory = const [SchoolHistoryDraft()],
    this.instagram = '',
    this.linkedin = '',
    this.whatsapp = '',
    this.twitter = '',
    this.customLabel = '',
    this.customHandle = '',
    this.career = const [
      CareerDraft(),
      CareerDraft(kind: kEducation, current: false),
    ],
    this.step = 1,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String dob;
  final String city;
  final String profession;
  final String gender;
  final bool isStudent;
  final List<SchoolHistoryDraft> schoolHistory;
  final String instagram;
  final String linkedin;
  final String whatsapp;
  final String twitter;
  final String customLabel;
  final String customHandle;

  /// The jobs and colleges typed on the "After school" step (alumni only),
  /// as many of each as they like. Starts with one blank card of each kind;
  /// blank cards are ignored.
  final List<CareerDraft> career;

  /// Furthest step reached (1 profile, 2 schools, 3 after school, 4 socials):
  /// where a returning user is taken back to.
  final int step;

  String get fullName => '$firstName $lastName'.trim();

  OnboardingFlowState copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? dob,
    String? city,
    String? profession,
    String? gender,
    bool? isStudent,
    List<SchoolHistoryDraft>? schoolHistory,
    String? instagram,
    String? linkedin,
    String? whatsapp,
    String? twitter,
    String? customLabel,
    String? customHandle,
    List<CareerDraft>? career,
    int? step,
  }) {
    return OnboardingFlowState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      city: city ?? this.city,
      profession: profession ?? this.profession,
      gender: gender ?? this.gender,
      isStudent: isStudent ?? this.isStudent,
      schoolHistory: schoolHistory ?? this.schoolHistory,
      instagram: instagram ?? this.instagram,
      linkedin: linkedin ?? this.linkedin,
      whatsapp: whatsapp ?? this.whatsapp,
      twitter: twitter ?? this.twitter,
      customLabel: customLabel ?? this.customLabel,
      customHandle: customHandle ?? this.customHandle,
      career: career ?? this.career,
      step: step ?? this.step,
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'username': username,
    'email': email,
    'dob': dob,
    'city': city,
    'profession': profession,
    'gender': gender,
    'isStudent': isStudent,
    'schoolHistory': [for (final d in schoolHistory) d.toJson()],
    'instagram': instagram,
    'linkedin': linkedin,
    'whatsapp': whatsapp,
    'twitter': twitter,
    'customLabel': customLabel,
    'customHandle': customHandle,
    'career': [for (final c in career) c.toJson()],
    'step': step,
  };

  factory OnboardingFlowState.fromJson(Map<String, dynamic> json) {
    final schools = [
      for (final d in (json['schoolHistory'] as List? ?? const []))
        SchoolHistoryDraft.fromJson(d as Map<String, dynamic>),
    ];
    return OnboardingFlowState(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      dob: json['dob'] as String? ?? '',
      city: json['city'] as String? ?? '',
      profession: json['profession'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      isStudent: json['isStudent'] as bool? ?? false,
      schoolHistory: schools.isEmpty ? const [SchoolHistoryDraft()] : schools,
      instagram: json['instagram'] as String? ?? '',
      linkedin: json['linkedin'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      twitter: json['twitter'] as String? ?? '',
      customLabel: json['customLabel'] as String? ?? '',
      customHandle: json['customHandle'] as String? ?? '',
      career: json['career'] is List
          ? [
              for (final c in json['career'] as List)
                CareerDraft.fromJson(c as Map<String, dynamic>),
            ]
          : const OnboardingFlowState().career,
      step: (json['step'] as num?)?.toInt() ?? 1,
    );
  }
}

class OnboardingFlowNotifier extends StateNotifier<OnboardingFlowState> {
  OnboardingFlowNotifier(this._store) : super(const OnboardingFlowState());

  final OnboardingDraftStore _store;

  /// True once the user has changed anything this session; a late draft load
  /// must never overwrite what they just typed.
  bool _touched = false;

  int get step => state.step;

  bool get isStudent => state.isStudent;

  /// Every change is also written to the device, so closing the app mid-way
  /// loses nothing.
  @override
  set state(OnboardingFlowState value) {
    _touched = true;
    super.state = value;
    unawaited(_store.save(value).catchError((_) {}));
  }

  /// Loads a previously saved draft, if there is one for this account.
  Future<void> hydrate() async {
    if (_touched) return;
    final saved = await _store.load();
    if (saved != null && mounted && !_touched) super.state = saved;
  }

  /// Moves the "furthest step" marker forward (never back).
  void markStep(int step) {
    if (step > state.step) state = state.copyWith(step: step);
  }

  /// Saves what has been typed so far on the profile step (no validation).
  void syncIdentity({
    required String firstName,
    required String lastName,
    required String username,
    required String dob,
    required String city,
    required String profession,
    required String gender,
    required bool isStudent,
    String? email,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      username: username,
      // Keep the saved email when the live session is not available yet.
      email: (email == null || email.isEmpty) ? null : email,
      dob: dob,
      city: city,
      profession: profession,
      gender: gender,
      isStudent: isStudent,
    );
  }

  void saveIdentity({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String dob,
    required String city,
    required String profession,
    required String gender,
    required bool isStudent,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      dob: dob,
      city: city,
      profession: profession,
      gender: gender,
      isStudent: isStudent,
    );
  }

  void addSchoolDraft() {
    state = state.copyWith(
      schoolHistory: [...state.schoolHistory, const SchoolHistoryDraft()],
    );
  }

  void removeSchoolDraft(int index) {
    if (state.schoolHistory.length <= 1) return;
    final next = [...state.schoolHistory]..removeAt(index);
    state = state.copyWith(schoolHistory: next);
  }

  void updateSchoolDraft(int index, SchoolHistoryDraft draft) {
    final next = [...state.schoolHistory];
    next[index] = draft;
    state = state.copyWith(schoolHistory: next);
  }

  void saveSocials({
    required String instagram,
    required String linkedin,
    required String whatsapp,
    required String twitter,
    required String customLabel,
    required String customHandle,
  }) {
    state = state.copyWith(
      instagram: instagram,
      linkedin: linkedin,
      whatsapp: whatsapp,
      twitter: twitter,
      customLabel: customLabel,
      customHandle: customHandle,
    );
  }

  void updateCareer(int index, CareerDraft draft) {
    final next = [...state.career];
    next[index] = draft;
    state = state.copyWith(career: next);
  }

  /// "+ Add another company / college". A new job starts as "currently
  /// working here"; a new college as finished.
  void addCareer(String kind) {
    state = state.copyWith(
      career: [
        ...state.career,
        kind == kWork
            ? const CareerDraft()
            : const CareerDraft(kind: kEducation, current: false),
      ],
    );
  }

  void removeCareer(int index) {
    final next = [...state.career]..removeAt(index);
    state = state.copyWith(career: next);
  }

  /// Skip: nothing from this step is saved.
  void skipAfterSchool() {
    state = state.copyWith(career: const []);
  }

  /// Registration finished (or abandoned): forget the draft everywhere.
  void reset() {
    _touched = false;
    super.state = const OnboardingFlowState();
    unawaited(_store.clear());
  }
}

/// Where a returning user should land: loads their saved draft and picks the
/// furthest step they had reached.
Future<String> resumeOnboardingRoute(OnboardingFlowNotifier flow) async {
  await flow.hydrate();
  final student = flow.isStudent;
  return switch (flow.step) {
    >= 4 when student => '/onboarding/schools/socials',
    >= 4 => '/onboarding/schools/after-school/socials',
    // Drafts saved before the "After school" step existed used 3 for socials.
    3 when student => '/onboarding/schools/socials',
    3 => '/onboarding/schools/after-school',
    2 => '/onboarding/schools',
    _ => '/onboarding',
  };
}

final onboardingFlowProvider =
    StateNotifierProvider<OnboardingFlowNotifier, OnboardingFlowState>(
      (ref) => OnboardingFlowNotifier(
        OnboardingDraftStore(ref.watch(secureStorageProvider)),
      ),
    );
