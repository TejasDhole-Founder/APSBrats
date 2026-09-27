import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/connections/data/circle_repository.dart';
import 'package:apsbrat_frontend/features/notifications/data/notification_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionRepository {
  ConnectionRepository(this._dio);
  final Dio _dio;

  /// My friends (accepted connections), A→Z.
  Future<List<Person>> batchmates() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connections);
    return dataList(res, Person.fromJson);
  }

  /// Requests waiting for me.
  Future<List<Person>> pending() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectionsPending);
    return dataList(res, Person.fromJson);
  }

  /// Requests I sent that are still unanswered.
  Future<List<Person>> sent() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectionsSent);
    return dataList(res, Person.fromJson);
  }

  Future<String> statusWith(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectionStatus(userId));
    return dataMap(res)['status'] as String? ?? 'NONE';
  }

  /// People connected to both me and [userId].
  Future<List<Person>> mutual(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.connectionMutual(userId));
    return dataList(res, Person.fromJson);
  }

  Future<void> request(String userId) async =>
      _dio.post<dynamic>(ApiEndpoints.connectionRequest(userId));

  Future<void> accept(String userId) async =>
      _dio.put<dynamic>(ApiEndpoints.connectionAccept(userId));

  /// Decline a request I received, withdraw one I sent, or remove a friend.
  /// The server picks the right one from the current state.
  Future<void> end(String userId) async =>
      _dio.delete<dynamic>(ApiEndpoints.connectionRequest(userId));
}

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(ref.watch(dioProvider)),
);

final batchmatesProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(connectionRepositoryProvider).batchmates(),
);
final pendingConnectionsProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(connectionRepositoryProvider).pending(),
);
final sentConnectionsProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(connectionRepositoryProvider).sent(),
);

final mutualConnectionsProvider = FutureProvider.family<List<Person>, String>(
  (ref, userId) => ref.watch(connectionRepositoryProvider).mutual(userId),
);

/// NONE · PENDING_OUT · PENDING_IN · CONNECTED — between me and [userId].
final connectionStatusProvider = FutureProvider.family<String, String>(
  (ref, userId) => ref.watch(connectionRepositoryProvider).statusWith(userId),
);

/// Every list that changes when a connection changes. Call after request,
/// accept, decline, withdraw or remove so all screens agree.
void refreshConnections(WidgetRef ref, {String? otherUserId}) {
  ref.invalidate(batchmatesProvider);
  ref.invalidate(pendingConnectionsProvider);
  ref.invalidate(sentConnectionsProvider);
  ref.invalidate(circleSummaryProvider);
  ref.invalidate(classmatesProvider);
  ref.invalidate(schoolmatesProvider);
  ref.invalidate(peopleSearchProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadNotificationCountProvider);
  if (otherUserId != null) {
    ref.invalidate(connectionStatusProvider(otherUserId));
    ref.invalidate(mutualConnectionsProvider(otherUserId));
  }
}
