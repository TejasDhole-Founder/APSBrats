import 'dart:async';
import 'dart:math';

import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

const kAccessTokenKey = 'access_token';
const kRefreshTokenKey = 'refresh_token';
const kUserIdKey = 'user_id';

/// Non-empty once the onboarding profile step has completed — lets the
/// router decide /home vs /onboarding on cold start without a network call.
const kOnboardingDoneKey = 'onboarding_done';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Flips to `true` when the refresh token is rejected and the session can no
/// longer be recovered. The app/router should watch this, drop the user to the
/// login screen, and reset it afterwards.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

/// True after a request couldn't reach the server; false again on the next
/// response of any kind. A real request is a truer signal than the OS's
/// "connected to Wi-Fi", which says nothing about reaching the internet.
final networkOfflineProvider = StateProvider<bool>((ref) => false);

/// The server runs a POST with the same key only once (IdempotencyFilter),
/// so a retried POST can't create a duplicate post, message or RSVP.
const kIdempotencyHeader = 'Idempotency-Key';

final _random = Random.secure();

String _newIdempotencyKey() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  // A dependency-free client used only to refresh tokens, so the refresh call
  // itself never re-enters the 401 interceptor below.
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  // Single-flight guard: concurrent 401s share one refresh round-trip.
  Future<String?>? refreshInFlight;

  Future<String?> refreshAccessToken() async {
    final refreshToken = await secureStorage.read(key: kRefreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      final res = await refreshDio.post<dynamic>(
        ApiEndpoints.authRefresh,
        data: {'refreshToken': refreshToken},
      );
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        return null;
      }
      await secureStorage.write(key: kAccessTokenKey, value: newAccess);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await secureStorage.write(key: kRefreshTokenKey, value: newRefresh);
      }
      return newAccess;
    } on DioException {
      return null;
    }
  }

  Future<void> clearSession() async {
    await secureStorage.delete(key: kAccessTokenKey);
    await secureStorage.delete(key: kRefreshTokenKey);
    await secureStorage.delete(key: kUserIdKey);
    ref.read(sessionExpiredProvider.notifier).state = true;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.read(key: kAccessTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // putIfAbsent: retries reuse these options, so they keep the same key.
        if (options.method == 'POST') {
          options.headers.putIfAbsent(kIdempotencyHeader, _newIdempotencyKey);
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        ref.read(networkOfflineProvider.notifier).state = false;
        handler.next(response);
      },
      onError: (error, handler) async {
        final response = error.response;
        final requestOptions = error.requestOptions;
        final isAuthCall = requestOptions.path.contains('/auth/');
        final alreadyRetried = requestOptions.extra['__retried__'] == true;
        ref.read(networkOfflineProvider.notifier).state =
            response == null &&
            (error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout);

        if (response?.statusCode != 401 || isAuthCall || alreadyRetried) {
          return handler.next(error);
        }

        refreshInFlight ??= refreshAccessToken().whenComplete(() {
          refreshInFlight = null;
        });
        final newToken = await refreshInFlight;

        if (newToken == null) {
          await clearSession();
          return handler.next(error);
        }

        try {
          final opts = requestOptions
            ..extra['__retried__'] = true
            ..headers['Authorization'] = 'Bearer $newToken';
          final retried = await dio.fetch<dynamic>(opts);
          return handler.resolve(retried);
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    ),
  );

  // Retries transient failures. A POST qualifies only with an idempotency key
  // and a body that can be re-sent (FormData streams can't), and auth calls
  // never do: a re-sent "send code" would hit the resend cooldown.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final opts = error.requestOptions;
        final attempt = (opts.extra['__attempt__'] as int?) ?? 0;
        final status = error.response?.statusCode;
        final transient = switch (error.type) {
          DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout => true,
          DioExceptionType.badResponse =>
            status == 502 || status == 503 || status == 504,
          _ => false,
        };
        final replayable =
            opts.method == 'GET' ||
            (opts.method == 'POST' &&
                opts.headers.containsKey(kIdempotencyHeader) &&
                opts.data is! FormData &&
                !opts.path.contains('/auth/'));
        if (!transient || !replayable || attempt >= 2) {
          return handler.next(error);
        }
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << attempt)),
        );
        try {
          final res = await dio.fetch<dynamic>(
            opts..extra['__attempt__'] = attempt + 1,
          );
          return handler.resolve(res);
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    ),
  );

  const isProd = bool.fromEnvironment('dart.vm.product');
  if (!isProd) {
    dio.interceptors.add(
      PrettyDioLogger(
        // Avoid leaking sensitive values such as password/token in logs.
        requestHeader: false,
        requestBody: false,
        responseBody: true,
      ),
    );
  }

  return dio;
});
