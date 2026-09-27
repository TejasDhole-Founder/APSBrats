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
  final start =
      int.tryParse(d.yearJoined) ??
      (end - (_classTo(d) - _classFrom(d)).clamp(0, 20));
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
    );
  }
}

class OnboardingFlowNotifier extends StateNotifier<OnboardingFlowState> {
  OnboardingFlowNotifier() : super(const OnboardingFlowState());

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

  void reset() {
    state = const OnboardingFlowState();
  }
}

final onboardingFlowProvider =
    StateNotifierProvider<OnboardingFlowNotifier, OnboardingFlowState>(
      (ref) => OnboardingFlowNotifier(),
    );
