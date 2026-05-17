import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';

class SchoolHistoryRegistrationModel {
  const SchoolHistoryRegistrationModel({
    required this.schoolId,
    required this.classFrom,
    required this.classTo,
    required this.section,
    required this.batchStart,
    required this.batchEnd,
    required this.isPrimary,
  });

  final String schoolId;
  final int classFrom;
  final int classTo;
  final String section;
  final int batchStart;
  final int batchEnd;
  final bool isPrimary;

  factory SchoolHistoryRegistrationModel.fromDraft(SchoolHistoryDraft draft) {
    final classFrom = int.tryParse(draft.classFrom.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final classTo = int.tryParse(draft.classTo.replaceAll(RegExp(r'[^0-9]'), '')) ?? classFrom;
    final batchEnd = int.tryParse(draft.yearLeft) ?? DateTime.now().year;
    final batchStart = int.tryParse(draft.yearJoined) ?? (batchEnd - (classTo - classFrom).clamp(0, 20));

    return SchoolHistoryRegistrationModel(
      schoolId: draft.schoolId,
      classFrom: classFrom,
      classTo: classTo,
      section: draft.section.trim().isEmpty ? 'A' : draft.section.trim().toUpperCase(),
      batchStart: batchStart,
      batchEnd: batchEnd,
      isPrimary: draft.isMostMissed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schoolId': schoolId,
      'classFrom': classFrom,
      'classTo': classTo,
      'section': section,
      'batchStart': batchStart,
      'batchEnd': batchEnd,
      'isPrimary': isPrimary,
    };
  }
}
