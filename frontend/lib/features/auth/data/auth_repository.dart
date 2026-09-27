import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> requestOtp(String email) async {
    await _dio.post<dynamic>(
      ApiEndpoints.authRequestOtp,
      data: {'email': email},
    );
  }

  Future<AuthUser> verifyOtp(String email, String code) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.authVerifyOtp,
      data: {'email': email, 'code': code},
    );
    return _storeAndReturn(res);
  }

  /// Google sign-in on-device via Firebase, then hand the resulting Firebase
  /// ID token to the backend, which verifies it and logs in or creates the
  /// account. Returns null if the user cancels the Google picker.
  Future<AuthUser?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn(scopes: const ['email']).signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final firebaseUser = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final idToken = await firebaseUser.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Google sign-in did not return a token');
    }

    final res = await _dio.post<dynamic>(
      ApiEndpoints.authGoogle,
      data: {'idToken': idToken},
    );
    return _storeAndReturn(res);
  }

  Future<AuthUser> _storeAndReturn(Response<dynamic> res) async {
    final body = res.data as Map<String, dynamic>;
    final tokens = AuthTokens.fromJson(body['data'] as Map<String, dynamic>);
    await _storage.write(key: kAccessTokenKey, value: tokens.accessToken);
    await _storage.write(key: kRefreshTokenKey, value: tokens.refreshToken);
    await _storage.write(key: kUserIdKey, value: tokens.user.id);
    await _storage.write(
      key: kOnboardingDoneKey,
      value: tokens.user.needsOnboarding ? '' : '1',
    );
    return tokens.user;
  }

  Future<void> logout() async {
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
    await _storage.delete(key: kUserIdKey);
    await _storage.delete(key: kOnboardingDoneKey);
  }

  Future<String?> currentUserId() => _storage.read(key: kUserIdKey);

  /// True once the onboarding profile step has run — checked at cold start
  /// (see the router) without a network call.
  Future<bool> onboardingDone() async =>
      (await _storage.read(key: kOnboardingDoneKey))?.isNotEmpty ?? false;

  Future<void> markOnboardingDone() =>
      _storage.write(key: kOnboardingDoneKey, value: '1');
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
  );
});
