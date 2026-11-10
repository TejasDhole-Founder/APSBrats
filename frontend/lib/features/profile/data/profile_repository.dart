import 'dart:async';
import 'dart:convert';

import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/media/photos.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<PrivacySettings> setShowActivity(bool show) async {
    final res = await _dio.put<dynamic>(
      ApiEndpoints.usersMeSettings,
      data: {'showActivity': show},
    );
    return PrivacySettings.fromJson(dataMap(res));
  }

  /// The logged-in user's own account details (GET /users/me).
  Future<AuthUser> me() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.usersMe);
    return AuthUser.fromJson(dataMap(res));
  }

  /// Saves the editable profile fields (PUT /users/me). Phone and email are not editable.
  Future<AuthUser> updateMe({
    required String fullName,
    required String username,
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

  /// Bytes, not a file path: a path doesn't exist on the web.
  Future<String> uploadAvatar(XFile photo) async {
    final form = FormData.fromMap({'file': await photoPart(photo)});
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

/// Local-first loading for the logged-in user's own data.
///
/// First build of the app session: show the copy saved on this device at once,
/// then fetch once in the background and swap the fresh copy in. Any later
/// rebuild (an edit screen calls `ref.invalidate`) goes straight to the server,
/// so the user never sees their old data after saving. The copy lives in
/// secure storage under the user's id, so logout's `deleteAll` wipes it.
Future<T> localFirst<T>(
  FutureProviderRef<T> ref, {
  required String name,
  required String path,
  required String userId,
  required T Function(dynamic data) parse,
}) async {
  final storage = ref.read(secureStorageProvider);
  final dio = ref.read(dioProvider);
  final key = 'cache_${name}_$userId';
  final isEditRefresh = ref.state.hasValue;
  var alive = true;
  ref.onDispose(() => alive = false);

  Future<T> fetch() async {
    final res = await dio.get<dynamic>(path);
    final data = res.data['data'];
    unawaited(
      storage.write(key: key, value: jsonEncode(data)).catchError((_) {}),
    );
    return parse(data);
  }

  if (isEditRefresh) return fetch();

  T? cached;
  try {
    final raw = await storage.read(key: key);
    if (raw != null) cached = parse(jsonDecode(raw));
  } catch (_) {
    await storage.delete(key: key);
  }
  if (cached == null) return fetch();

  unawaited(
    fetch().then((fresh) {
      if (alive) ref.state = AsyncData(fresh);
    }, onError: (Object _) {}),
  );
  return cached;
}

List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
    ((data as List?) ?? const [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();

/// The logged-in user, or null when nobody is logged in.
final meProvider = FutureProvider<AuthUser?>((ref) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return null;
  return localFirst<AuthUser?>(
    ref,
    name: 'me',
    path: ApiEndpoints.usersMe,
    userId: userId,
    parse: (d) => AuthUser.fromJson(d as Map<String, dynamic>),
  );
});

/// Social links of the logged-in user; empty when nobody is logged in.
final mySocialLinksProvider = FutureProvider<List<SocialLink>>((ref) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return const [];
  return localFirst(
    ref,
    name: 'socials',
    path: ApiEndpoints.userSocialLinks(userId),
    userId: userId,
    parse: (d) => _list(d, SocialLink.fromJson),
  );
});

/// School history of the logged-in user; empty when nobody is logged in.
final mySchoolHistoryProvider = FutureProvider<List<SchoolHistory>>((
  ref,
) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return const [];
  return localFirst(
    ref,
    name: 'schools',
    path: ApiEndpoints.userSchoolHistory(userId),
    userId: userId,
    parse: (d) => _list(d, SchoolHistory.fromJson),
  );
});
