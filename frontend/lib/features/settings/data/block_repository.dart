import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlockRepository {
  BlockRepository(this._dio);
  final Dio _dio;

  Future<void> block(String userId) =>
      _dio.post<dynamic>(ApiEndpoints.userBlock(userId));

  Future<void> unblock(String userId) =>
      _dio.delete<dynamic>(ApiEndpoints.userBlock(userId));

  Future<List<Person>> blocked() async => dataList(
    await _dio.get<dynamic>(ApiEndpoints.usersMeBlocks),
    Person.fromJson,
  );
}

final blockRepositoryProvider = Provider<BlockRepository>(
  (ref) => BlockRepository(ref.watch(dioProvider)),
);

final blockedUsersProvider = FutureProvider.autoDispose<List<Person>>(
  (ref) => ref.watch(blockRepositoryProvider).blocked(),
);

/// Everything that shows people changes when someone is blocked or unblocked.
void refreshAfterBlock(WidgetRef ref, String userId) {
  refreshConnections(ref, otherUserId: userId);
  ref.invalidate(communityMembersProvider);
  ref.invalidate(peopleSearchProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(profileProvider(userId));
  ref.invalidate(blockedUsersProvider);
}
