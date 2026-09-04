import 'package:flutter_riverpod/flutter_riverpod.dart';

class SchoolHistoryDraft {
  const SchoolHistoryDraft({
    this.schoolId = '',
    this.schoolName = '',
    this.classFrom = '',
    this.classTo = '',
    this.section = '',
    this.yearJoined = '',
    this.yearLeft = '',
    this.isMostMissed = false,
  });

  final String schoolId;
  final String schoolName;
  final String classFrom;
  final String classTo;
  final String section;
  final String yearJoined;
  final String yearLeft;
  final bool isMostMissed;

  SchoolHistoryDraft copyWith({
    String? schoolId,
    String? schoolName,
    String? classFrom,
    String? classTo,
    String? section,
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
      yearJoined: yearJoined ?? this.yearJoined,
      yearLeft: yearLeft ?? this.yearLeft,
      isMostMissed: isMostMissed ?? this.isMostMissed,
    );
  }
}

class OnboardingFlowState {
  const OnboardingFlowState({
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.phone = '',
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
  final String phone;
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
    String? phone,
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
      phone: phone ?? this.phone,
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
    required String phone,
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
      phone: phone,
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

  bool validateSchoolDrafts() {
    return state.schoolHistory.every(
      (item) =>
          item.schoolId.isNotEmpty &&
          item.classFrom.isNotEmpty &&
          item.classTo.isNotEmpty,
    );
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
