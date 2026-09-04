import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> requestOtp(String phone) async {
    await _dio.post<dynamic>(
      ApiEndpoints.authRequestOtp,
      data: {'phone': phone},
    );
  }

  Future<AuthUser> verifyOtp(String phone, String code) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.authVerifyOtp,
      data: {'phone': phone, 'code': code},
    );
    final body = res.data as Map<String, dynamic>;
    final tokens = AuthTokens.fromJson(body['data'] as Map<String, dynamic>);
    await _storage.write(key: kAccessTokenKey, value: tokens.accessToken);
    await _storage.write(key: kRefreshTokenKey, value: tokens.refreshToken);
    await _storage.write(key: kUserIdKey, value: tokens.user.id);
    return tokens.user;
  }

  Future<void> logout() async {
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
    await _storage.delete(key: kUserIdKey);
  }

  Future<String?> currentUserId() => _storage.read(key: kUserIdKey);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});
