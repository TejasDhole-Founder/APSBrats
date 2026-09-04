import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Profile> byUsername(String username) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.profile(username));
    return Profile.fromJson(dataMap(res));
  }

  Future<List<SocialLink>> socialLinks(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.userSocialLinks(userId));
    return dataList(res, SocialLink.fromJson);
  }

  /// Creates or updates one social link. `label` is only used for CUSTOM.
  Future<SocialLink> saveSocialLink({
    required String userId,
    required String platform,
    required String handle,
    String? label,
  }) async {
    final res = await _dio.put<dynamic>(
      ApiEndpoints.userSocialLink(userId, platform),
      data: {'handle': handle, if (label != null) 'label': label},
    );
    return SocialLink.fromJson(dataMap(res));
  }

  Future<String> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post<dynamic>(
      ApiEndpoints.usersMeAvatar,
      data: form,
    );
    return dataMap(res)['profilePicUrl'] as String? ?? '';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

final profileProvider = FutureProvider.family<Profile, String>(
  (ref, username) => ref.watch(profileRepositoryProvider).byUsername(username),
);

/// Social links of the logged-in user; empty when nobody is logged in.
final mySocialLinksProvider = FutureProvider<List<SocialLink>>((ref) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return const [];
  return ref.watch(profileRepositoryProvider).socialLinks(userId);
});
