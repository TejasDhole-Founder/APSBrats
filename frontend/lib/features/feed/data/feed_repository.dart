import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/feed/data/feed_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedRepository {
  FeedRepository(this._dio);
  final Dio _dio;

  Future<List<FeedEvent>> activity() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.feedActivity);
    return dataList(res, FeedEvent.fromJson);
  }

  Future<List<Person>> recentJoins() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.feedRecentJoins);
    return dataList(res, Person.fromJson);
  }

  Future<BatchmateBanner> banner() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.feedBanner);
    return BatchmateBanner.fromJson(dataMap(res));
  }
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(dioProvider)),
);

final feedActivityProvider = FutureProvider<List<FeedEvent>>(
  (ref) => ref.watch(feedRepositoryProvider).activity(),
);
final recentJoinsProvider = FutureProvider<List<Person>>(
  (ref) => ref.watch(feedRepositoryProvider).recentJoins(),
);
final batchmateBannerProvider = FutureProvider<BatchmateBanner>(
  (ref) => ref.watch(feedRepositoryProvider).banner(),
);
