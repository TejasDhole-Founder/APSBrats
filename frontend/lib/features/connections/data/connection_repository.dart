import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionRepository {
  ConnectionRepository(this._dio);
  final Dio _dio;

  Future<List<Person>> batchmates() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connections);
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Person>> pending() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectionsPending);
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> statusWith(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectionStatus(userId));
    return (res.data['data'] as Map<String, dynamic>)['status'] as String? ?? 'NONE';
  }

  Future<void> request(String userId) async => _dio.post<dynamic>(ApiEndpoints.connectionRequest(userId));
  Future<void> accept(String userId) async => _dio.put<dynamic>(ApiEndpoints.connectionAccept(userId));
}

final connectionRepositoryProvider =
    Provider<ConnectionRepository>((ref) => ConnectionRepository(ref.watch(dioProvider)));

final batchmatesProvider = FutureProvider<List<Person>>((ref) => ref.watch(connectionRepositoryProvider).batchmates());
final pendingConnectionsProvider =
    FutureProvider<List<Person>>((ref) => ref.watch(connectionRepositoryProvider).pending());
