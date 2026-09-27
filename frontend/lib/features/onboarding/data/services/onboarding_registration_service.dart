import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/availability_model.dart';
import 'package:dio/dio.dart';

/// The account already exists by the time onboarding runs (email or Google
/// sign-in created it) — this is just the live username check the identity
/// step uses, shared with the "edit profile" page.
class OnboardingRegistrationService {
  const OnboardingRegistrationService();

  Future<Availability> usernameAvailability(Dio dio, String username) async {
    final res = await dio.get<dynamic>(
      ApiEndpoints.usersUsernameAvailable,
      queryParameters: {'username': username},
    );
    return Availability.fromJson(dataMap(res));
  }
}
