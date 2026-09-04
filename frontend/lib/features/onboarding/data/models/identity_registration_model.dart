import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:intl/intl.dart';

class IdentityRegistrationModel {
  const IdentityRegistrationModel({
    required this.username,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.dob,
    required this.city,
    required this.profession,
    required this.gender,
    required this.currentStatus,
  });

  final String username;
  final String fullName;
  final String phone;
  final String? email;
  final String? dob;
  final String? city;
  final String? profession;
  final String? gender;
  final String currentStatus;

  factory IdentityRegistrationModel.fromFlow(OnboardingFlowState flow) {
    return IdentityRegistrationModel(
      username: flow.username.trim(),
      fullName: flow.fullName,
      phone: flow.phone.trim(),
      email: flow.email.trim().isEmpty ? null : flow.email.trim().toLowerCase(),
      dob: _parseDob(flow.dob.trim()),
      city: flow.city.trim().isEmpty ? null : flow.city.trim(),
      profession: flow.profession.trim().isEmpty
          ? null
          : flow.profession.trim(),
      gender: flow.gender.isEmpty ? null : flow.gender,
      currentStatus: flow.isStudent ? 'STUDENT' : 'ALUMNI',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'dob': dob,
      'city': city,
      'profession': profession,
      'gender': gender,
      'currentStatus': currentStatus,
    };
  }

  static String? _parseDob(String value) {
    if (value.isEmpty) return null;
    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(value);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return null;
    }
  }
}
