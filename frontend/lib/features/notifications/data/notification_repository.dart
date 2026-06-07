import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/notifications/data/notification_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationRepository {
  NotificationRepository(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> list() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.notifications);
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.notificationsUnreadCount);
    return ((res.data['data'] as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async => _dio.post<dynamic>(ApiEndpoints.notificationRead(id));
  Future<void> markAllRead() async => _dio.post<dynamic>(ApiEndpoints.notificationsReadAll);
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref.watch(dioProvider)));

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) => ref.watch(notificationRepositoryProvider).list());
final unreadNotificationCountProvider =
    FutureProvider<int>((ref) => ref.watch(notificationRepositoryProvider).unreadCount());
