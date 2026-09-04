import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/network/paged_result.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityRepository {
  CommunityRepository(this._dio);
  final Dio _dio;

  Future<List<Community>> myCommunities() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.communities);
    return dataList(res, Community.fromJson);
  }

  Future<List<DiscoverCommunity>> discover() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.communitiesDiscover);
    return dataList(res, DiscoverCommunity.fromJson);
  }

  Future<Community> get(String id) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.community(id));
    return Community.fromJson(dataMap(res));
  }

  Future<PagedResult<CommunityMessage>> messages(String id, {String? cursor, int limit = 30}) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.communityMessages(id),
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = dataMap(res);
    if (data.isEmpty) {
      return PagedResult.empty<CommunityMessage>();
    }
    return PagedResult.fromJson(data, CommunityMessage.fromJson);
  }

  Future<CommunityMessage> send(String id, String body) async {
    final res = await _dio.post<dynamic>(ApiEndpoints.communityMessages(id), data: {'body': body});
    return CommunityMessage.fromJson(dataMap(res));
  }

  Future<void> join(String id) async => _dio.post<dynamic>(ApiEndpoints.communityJoin(id));
  Future<void> markRead(String id) async => _dio.post<dynamic>(ApiEndpoints.communityRead(id));
}

final communityRepositoryProvider =
    Provider<CommunityRepository>((ref) => CommunityRepository(ref.watch(dioProvider)));

final myCommunitiesProvider =
    FutureProvider<List<Community>>((ref) => ref.watch(communityRepositoryProvider).myCommunities());
final discoverCommunitiesProvider =
    FutureProvider<List<DiscoverCommunity>>((ref) => ref.watch(communityRepositoryProvider).discover());
final communityProvider =
    FutureProvider.family<Community, String>((ref, id) => ref.watch(communityRepositoryProvider).get(id));
final communityMessagesProvider =
    FutureProvider.family<PagedResult<CommunityMessage>, String>((ref, id) => ref.watch(communityRepositoryProvider).messages(id));
