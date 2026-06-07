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
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(dioProvider)));

final profileProvider =
    FutureProvider.family<Profile, String>((ref, username) => ref.watch(profileRepositoryProvider).byUsername(username));
