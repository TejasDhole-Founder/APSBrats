import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DPDP self-service: right-to-access (export) and right-to-erasure (delete).
class AccountRepository {
  AccountRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> exportMyData() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.usersMeExport);
    return (res.data['data'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteMyAccount() async {
    await _dio.delete<dynamic>(ApiEndpoints.usersMe);
  }
}

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(ref.watch(dioProvider)));
