import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Profile> byId(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.profile(userId));
    return Profile.fromJson(dataMap(res));
  }

  Future<PrivacySettings> mySettings() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.usersMeSettings);
    return PrivacySettings.fromJson(dataMap(res));
  }

  Future<PrivacySettings> setPrivate(bool isPrivate) async {
    final res = await _dio.put<dynamic>(
      ApiEndpoints.usersMeSettings,
      data: {'isPrivate': isPrivate},
    );
    return PrivacySettings.fromJson(dataMap(res));
  }

  /// The logged-in user's own account details (GET /users/me).
  Future<AuthUser> me() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.usersMe);
    return AuthUser.fromJson(dataMap(res));
  }

  /// Saves the editable profile fields (PUT /users/me). Phone is not editable.
  Future<AuthUser> updateMe({
    required String fullName,
    required String username,
    String? email,
    String? city,
    String? profession,
    String? gender,
    String? dob,
    String? bio,
    String? currentStatus,
  }) async {
    final res = await _dio.put<dynamic>(
      ApiEndpoints.usersMe,
      data: {
        'fullName': fullName,
        'username': username,
        'email': email,
        'city': city,
        'profession': profession,
        'gender': gender,
        'dob': dob,
        'bio': bio,
        'currentStatus': currentStatus,
      },
    );
    return AuthUser.fromJson(dataMap(res));
  }

  Future<List<SchoolHistory>> schoolHistory(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.userSchoolHistory(userId));
    return dataList(res, SchoolHistory.fromJson);
  }

  /// Replaces the whole school list (the backend deletes and re-inserts).
  Future<void> replaceSchoolHistory(
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    await _dio.post<dynamic>(
      ApiEndpoints.userSchoolHistoryBulk(userId),
      data: {'items': items},
    );
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

/// Keyed by user id (profiles are never addressed by username).
final profileProvider = FutureProvider.family<Profile, String>(
  (ref, userId) => ref.watch(profileRepositoryProvider).byId(userId),
);

final mySettingsProvider = FutureProvider<PrivacySettings>(
  (ref) => ref.watch(profileRepositoryProvider).mySettings(),
);

/// The logged-in user, or null when nobody is logged in.
final meProvider = FutureProvider<AuthUser?>((ref) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return null;
  return ref.watch(profileRepositoryProvider).me();
});

/// Social links of the logged-in user; empty when nobody is logged in.
final mySocialLinksProvider = FutureProvider<List<SocialLink>>((ref) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return const [];
  return ref.watch(profileRepositoryProvider).socialLinks(userId);
});

/// School history of the logged-in user; empty when nobody is logged in.
final mySchoolHistoryProvider = FutureProvider<List<SchoolHistory>>((
  ref,
) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return const [];
  return ref.watch(profileRepositoryProvider).schoolHistory(userId);
});
