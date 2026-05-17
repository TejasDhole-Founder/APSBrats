import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/identity_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/school_history_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/social_link_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:dio/dio.dart';

class OnboardingRegistrationService {
  const OnboardingRegistrationService();

  Future<String> registerSequential({
    required Dio dio,
    required OnboardingFlowState flow,
  }) async {
    // Step 1: identity registration
    final identity = IdentityRegistrationModel.fromFlow(flow);
    final userResponse = await dio.post<dynamic>(
      ApiEndpoints.users,
      data: identity.toJson(),
    );

    final userBody = userResponse.data as Map<String, dynamic>;
    final userData = userBody['data'] as Map<String, dynamic>? ?? {};
    final userId = userData['id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('Invalid user id returned from registration');
    }

    // Step 2: school history save
    final schoolItems = flow.schoolHistory
        .where((item) => item.schoolId.isNotEmpty)
        .map(SchoolHistoryRegistrationModel.fromDraft)
        .map((item) => item.toJson())
        .toList();
    if (schoolItems.isNotEmpty) {
      await dio.post<dynamic>(
        '${ApiEndpoints.users}/$userId/school-history/bulk',
        data: {'items': schoolItems},
      );
    }

    // Step 3: social links save
    final socials = SocialLinkRegistrationModel.fromFlow(flow);
    for (final social in socials) {
      await dio.put<dynamic>(
        '${ApiEndpoints.users}/$userId/social-links/${social.platform}',
        data: social.toJson(),
      );
    }

    return userId;
  }
}
