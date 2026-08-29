import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
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
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => Community.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DiscoverCommunity>> discover() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.communitiesDiscover);
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => DiscoverCommunity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Community> get(String id) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.community(id));
    return Community.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<PagedResult<CommunityMessage>> messages(String id, {String? cursor, int limit = 30}) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.communityMessages(id),
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = res.data['data'] as Map<String, dynamic>?;
    if (data == null) {
      return PagedResult.empty<CommunityMessage>();
    }
    return PagedResult.fromJson(data, CommunityMessage.fromJson);
  }

  Future<CommunityMessage> send(String id, String body) async {
    final res = await _dio.post<dynamic>(ApiEndpoints.communityMessages(id), data: {'body': body});
    return CommunityMessage.fromJson(res.data['data'] as Map<String, dynamic>);
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
