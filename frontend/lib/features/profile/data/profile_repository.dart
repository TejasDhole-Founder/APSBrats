import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Profile> byUsername(String username) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.profile(username));
    return Profile.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<String> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post<dynamic>(ApiEndpoints.usersMeAvatar, data: form);
    final data = res.data['data'] as Map<String, dynamic>?;
    return (data?['profilePicUrl'] as String?) ?? '';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(dioProvider)));

final profileProvider =
    FutureProvider.family<Profile, String>((ref, username) => ref.watch(profileRepositoryProvider).byUsername(username));
