import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart'
    show kPeoplePageSize;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityRepository {
  CommunityRepository(this._dio);
  final Dio _dio;

  // ── Communities ─────────────────────────────────────────────────────────

  Future<MyCommunities> mine() async => MyCommunities.fromJson(
    dataMap(await _dio.get<dynamic>(ApiEndpoints.communitiesMine)),
  );

  Future<List<Community>> discover(String query) async => dataList(
    await _dio.get<dynamic>(
      ApiEndpoints.communitiesDiscover,
      queryParameters: {'q': query.trim()},
    ),
    Community.fromJson,
  );

  Future<Community> get(String id) async => Community.fromJson(
    dataMap(await _dio.get<dynamic>(ApiEndpoints.community(id))),
  );

  Future<Community> create({
    required String name,
    String? description,
    required bool isPrivate,
  }) async => Community.fromJson(
    dataMap(
      await _dio.post<dynamic>(
        ApiEndpoints.communities,
        data: {
          'name': name.trim(),
          if ((description ?? '').trim().isNotEmpty)
            'description': description!.trim(),
          'visibility': isPrivate ? 'PRIVATE' : 'OPEN',
        },
      ),
    ),
  );

  /// Public / school: joined at once. Private: a request is sent.
  Future<Community> join(String id) async => Community.fromJson(
    dataMap(await _dio.post<dynamic>(ApiEndpoints.communityJoin(id))),
  );

  Future<void> leave(String id) =>
      _dio.delete<dynamic>(ApiEndpoints.communityLeave(id));

  Future<void> delete(String id) =>
      _dio.delete<dynamic>(ApiEndpoints.community(id));

  Future<List<JoinRequestItem>> requests(String id) async => dataList(
    await _dio.get<dynamic>(ApiEndpoints.communityRequests(id)),
    JoinRequestItem.fromJson,
  );

  Future<void> decide(String id, String userId, {required bool approve}) =>
      _dio.post<dynamic>(
        ApiEndpoints.communityRequestDecision(
          id,
          userId,
          approve ? 'approve' : 'reject',
        ),
      );

  Future<void> removeMember(String id, String userId) =>
      _dio.delete<dynamic>(ApiEndpoints.communityMember(id, userId));

  // ── Posts ───────────────────────────────────────────────────────────────

  /// [communityId] null means the Home feed (all my communities).
  /// [sort] ('latest' / 'popular') only applies to a community.
  Future<PageOf<Post>> posts({
    String? communityId,
    String? cursor,
    String sort = 'latest',
  }) async {
    final res = await _dio.get<dynamic>(
      communityId == null
          ? ApiEndpoints.feedHome
          : ApiEndpoints.communityPosts(communityId),
      queryParameters: {
        'cursor': ?cursor,
        'limit': 20,
        if (communityId != null) 'sort': sort,
      },
    );
    return PageOf.fromJson(dataMap(res), Post.fromJson);
  }

  /// Members of a community, by name and optional batch (passing-out year).
  Future<List<Person>> members(CommunityMembersQuery query) async => dataList(
    await _dio.get<dynamic>(
      ApiEndpoints.communityMembers(query.communityId),
      queryParameters: {
        'q': query.q,
        'batch': ?query.batch,
        'page': query.page,
        'size': kPeoplePageSize,
      },
    ),
    Person.fromJson,
  );

  Future<Post> post(String id) async =>
      Post.fromJson(dataMap(await _dio.get<dynamic>(ApiEndpoints.post(id))));

  /// Text, up to 10 photos (addresses from MediaRepository.uploadPhoto), or both.
  /// [eventId]: photos shared from that event.
  Future<Post> createPost(
    String communityId,
    String body, {
    List<String> imageUrls = const [],
    String? eventId,
    int? memoryYear,
    String? memoryCategory,
  }) async => Post.fromJson(
    dataMap(
      await _dio.post<dynamic>(
        ApiEndpoints.communityPosts(communityId),
        data: {
          'body': body.trim(),
          'imageUrls': imageUrls,
          'eventId': ?eventId,
          'memoryYear': ?memoryYear,
          'memoryCategory': ?memoryCategory,
        },
      ),
    ),
  );

  // ── Memories ────────────────────────────────────────────────────────────

  Future<PageOf<Post>> memories(MemoriesQuery query, {String? cursor}) async =>
      PageOf.fromJson(
        dataMap(
          await _dio.get<dynamic>(
            ApiEndpoints.communityMemories(query.communityId),
            queryParameters: {
              'year': ?query.year,
              'category': ?query.category,
              'cursor': ?cursor,
              'limit': 30,
            },
          ),
        ),
        Post.fromJson,
      );

  Future<List<int>> memoryYears(String communityId) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.communityMemoryYears(communityId),
    );
    return [
      for (final y in (res.data['data'] as List?) ?? const [])
        (y as num).toInt(),
    ];
  }

  // ── Events ──────────────────────────────────────────────────────────────

  Future<EventList> events(String communityId, {bool past = false}) async =>
      EventList.fromJson(
        dataMap(
          await _dio.get<dynamic>(
            ApiEndpoints.communityEvents(communityId),
            queryParameters: {'when': past ? 'past' : 'upcoming'},
          ),
        ),
      );

  Future<CommunityEvent> event(String id) async => CommunityEvent.fromJson(
    dataMap(await _dio.get<dynamic>(ApiEndpoints.event(id))),
  );

  /// Creates in [communityId], or edits [eventId] when given.
  Future<CommunityEvent> saveEvent({
    required String communityId,
    String? eventId,
    required String title,
    required String venue,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    String? coverUrl,
  }) async {
    final data = {
      'title': title.trim(),
      'venue': venue.trim(),
      'startsAt': startsAt.toIso8601String(),
      'endsAt': endsAt.toIso8601String(),
      'description': description?.trim(),
      'coverUrl': coverUrl,
    };
    final res = eventId == null
        ? await _dio.post<dynamic>(
            ApiEndpoints.communityEvents(communityId),
            data: data,
          )
        : await _dio.put<dynamic>(ApiEndpoints.event(eventId), data: data);
    return CommunityEvent.fromJson(dataMap(res));
  }

  Future<CommunityEvent> cancelEvent(String id) async =>
      CommunityEvent.fromJson(
        dataMap(await _dio.post<dynamic>(ApiEndpoints.eventCancel(id))),
      );

  /// [status] 'GOING' / 'INTERESTED', or null to clear my answer.
  Future<CommunityEvent> setRsvp(String id, String? status) async =>
      CommunityEvent.fromJson(
        dataMap(
          status == null
              ? await _dio.delete<dynamic>(ApiEndpoints.eventRsvp(id))
              : await _dio.put<dynamic>(
                  ApiEndpoints.eventRsvp(id),
                  data: {'status': status},
                ),
        ),
      );

  /// {'GOING': [...], 'INTERESTED': [...]}
  Future<Map<String, List<Person>>> attendees(String id) async {
    final data = dataMap(
      await _dio.get<dynamic>(ApiEndpoints.eventAttendees(id)),
    );
    return {
      for (final key in const ['GOING', 'INTERESTED'])
        key: [
          for (final p in (data[key] as List?) ?? const [])
            Person.fromJson(p as Map<String, dynamic>),
        ],
    };
  }

  Future<PageOf<Post>> eventPosts(String eventId, {String? cursor}) async =>
      PageOf.fromJson(
        dataMap(
          await _dio.get<dynamic>(
            ApiEndpoints.eventPosts(eventId),
            queryParameters: {'cursor': ?cursor, 'limit': 20},
          ),
        ),
        Post.fromJson,
      );

  Future<void> deletePost(String id) =>
      _dio.delete<dynamic>(ApiEndpoints.post(id));

  /// Returns the post with the server's count, so the heart settles on the truth.
  Future<Post> setLiked(String postId, {required bool liked}) async =>
      Post.fromJson(
        dataMap(
          liked
              ? await _dio.put<dynamic>(ApiEndpoints.postLike(postId))
              : await _dio.delete<dynamic>(ApiEndpoints.postLike(postId)),
        ),
      );

  Future<Post> setPinned(String postId, {required bool pinned}) async =>
      Post.fromJson(
        dataMap(
          pinned
              ? await _dio.put<dynamic>(ApiEndpoints.postPin(postId))
              : await _dio.delete<dynamic>(ApiEndpoints.postPin(postId)),
        ),
      );

  Future<PageOf<PostComment>> comments(String postId, {String? cursor}) async =>
      PageOf.fromJson(
        dataMap(
          await _dio.get<dynamic>(
            ApiEndpoints.postComments(postId),
            queryParameters: {'cursor': ?cursor, 'limit': 50},
          ),
        ),
        PostComment.fromJson,
      );

  Future<PostComment> addComment(String postId, String body) async =>
      PostComment.fromJson(
        dataMap(
          await _dio.post<dynamic>(
            ApiEndpoints.postComments(postId),
            data: {'body': body.trim()},
          ),
        ),
      );

  Future<void> deleteComment(String id) =>
      _dio.delete<dynamic>(ApiEndpoints.comment(id));

  // ── Group chat ──────────────────────────────────────────────────────────

  Future<CommunityChatSummary> chatSummary(String communityId) async =>
      CommunityChatSummary.fromJson(
        dataMap(
          await _dio.get<dynamic>(ApiEndpoints.communityChat(communityId)),
        ),
      );

  /// Oldest first within the page; [cursor] walks back in time.
  Future<PageOf<CommunityMessage>> chatMessages(
    String communityId, {
    String? cursor,
  }) async => PageOf.fromJson(
    dataMap(
      await _dio.get<dynamic>(
        ApiEndpoints.communityChatMessages(communityId),
        queryParameters: {'cursor': ?cursor, 'limit': 30},
      ),
    ),
    CommunityMessage.fromJson,
  );

  Future<CommunityMessage> sendChatMessage(
    String communityId,
    String body, {
    String? imageUrl,
  }) async => CommunityMessage.fromJson(
    dataMap(
      await _dio.post<dynamic>(
        ApiEndpoints.communityChatMessages(communityId),
        data: {'body': body.trim(), 'imageUrl': ?imageUrl},
      ),
    ),
  );

  Future<void> markChatRead(String communityId) =>
      _dio.post<dynamic>(ApiEndpoints.communityChatRead(communityId));

  Future<void> deleteChatMessage(String id) =>
      _dio.delete<dynamic>(ApiEndpoints.communityMessage(id));

  /// [targetType] is 'POST', 'COMMENT', 'COMMUNITY_MESSAGE' or 'USER'
  /// (a person: [targetId] is their user id).
  Future<void> report(String targetType, String targetId, String reason) =>
      _dio.post<dynamic>(
        ApiEndpoints.reports,
        data: {
          'targetType': targetType,
          if (targetType == 'USER')
            'targetUserId': targetId
          else
            'targetId': targetId,
          'reason': reason,
        },
      );
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(dioProvider)),
);

final myCommunitiesProvider = FutureProvider.autoDispose<MyCommunities>(
  (ref) => ref.watch(communityRepositoryProvider).mine(),
);

final discoverProvider = FutureProvider.autoDispose
    .family<List<Community>, String>(
      (ref, query) => ref.watch(communityRepositoryProvider).discover(query),
    );

final communityProvider = FutureProvider.autoDispose.family<Community, String>(
  (ref, id) => ref.watch(communityRepositoryProvider).get(id),
);

final joinRequestsProvider = FutureProvider.autoDispose
    .family<List<JoinRequestItem>, String>(
      (ref, id) => ref.watch(communityRepositoryProvider).requests(id),
    );

/// A record, so equal queries share one provider entry.
typedef CommunityMembersQuery = ({
  String communityId,
  String q,
  int? batch,
  int page,
});

final communityMembersProvider = FutureProvider.autoDispose
    .family<List<Person>, CommunityMembersQuery>(
      (ref, query) => ref.watch(communityRepositoryProvider).members(query),
    );

/// The chat card on a community page (members only).
final communityChatSummaryProvider = FutureProvider.autoDispose
    .family<CommunityChatSummary, String>(
      (ref, id) => ref.watch(communityRepositoryProvider).chatSummary(id),
    );

/// Key: (community id, past?).
final communityEventsProvider = FutureProvider.autoDispose
    .family<EventList, (String, bool)>(
      (ref, key) =>
          ref.watch(communityRepositoryProvider).events(key.$1, past: key.$2),
    );

final eventProvider = FutureProvider.autoDispose.family<CommunityEvent, String>(
  (ref, id) => ref.watch(communityRepositoryProvider).event(id),
);

final eventAttendeesProvider = FutureProvider.autoDispose
    .family<Map<String, List<Person>>, String>(
      (ref, id) => ref.watch(communityRepositoryProvider).attendees(id),
    );

final postProvider = FutureProvider.autoDispose.family<Post, String>(
  (ref, id) => ref.watch(communityRepositoryProvider).post(id),
);

final commentsProvider = FutureProvider.autoDispose
    .family<PageOf<PostComment>, String>(
      (ref, postId) => ref.watch(communityRepositoryProvider).comments(postId),
    );

/// Shows a server error message ("Join this community first") instead of
/// Dio's technical text.
String friendlyError(
  Object error, [
  String fallback = 'Something went wrong. Try again.',
]) {
  if (error is DioException) {
    final payload = error.response?.data;
    final message = payload is Map<String, dynamic> ? payload['error'] : null;
    if (message is String && message.isNotEmpty) return message;
    if (error.response == null) {
      return "Couldn't connect. Check your internet and try again.";
    }
  }
  return fallback;
}

/// HTTP status of a failed request, if any (403 = join first, 404 = not found).
int? statusOf(Object error) =>
    error is DioException ? error.response?.statusCode : null;

// ── A scrolling list of posts (a community page, or Home) ──────────────────

class PostFeedState {
  const PostFeedState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.loading = false,
    this.error,
  });

  final List<Post> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loading;
  final Object? error;

  PostFeedState copyWith({
    List<Post>? items,
    String? nextCursor,
    bool? hasMore,
    bool? loading,
    Object? error,
    bool clearError = false,
  }) => PostFeedState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Loads pages as you scroll and keeps likes, new posts and deletions in
/// sync without reloading the whole list.
class PostFeedNotifier extends StateNotifier<PostFeedState> {
  PostFeedNotifier(this._fetch) : super(const PostFeedState()) {
    refresh();
  }

  /// Loads the page after [cursor] (null = first page).
  final Future<PageOf<Post>> Function(String? cursor) _fetch;

  Future<void> refresh() async {
    state = const PostFeedState(loading: true);
    await _load(null, replace: true);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(loading: true, clearError: true);
    await _load(state.nextCursor, replace: false);
  }

  Future<void> _load(String? cursor, {required bool replace}) async {
    try {
      final page = await _fetch(cursor);
      if (!mounted) return;
      state = PostFeedState(
        items: replace ? page.items : [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e, hasMore: false);
    }
  }

  void prepend(Post post) =>
      state = state.copyWith(items: [post, ...state.items]);

  void replace(Post post) => state = state.copyWith(
    items: [for (final p in state.items) p.id == post.id ? post : p],
  );

  void remove(String postId) => state = state.copyWith(
    items: state.items.where((p) => p.id != postId).toList(),
  );
}

/// A community page's order: 'latest' or 'popular'. Key: community id.
final postSortProvider = StateProvider.autoDispose.family<String, String>(
  (ref, communityId) => 'latest',
);

/// Key: a community id, or '' for the Home feed. Reloads when the sort changes.
final postFeedProvider = StateNotifierProvider.autoDispose
    .family<PostFeedNotifier, PostFeedState, String>((ref, key) {
      final repo = ref.watch(communityRepositoryProvider);
      final sort = key.isEmpty ? 'latest' : ref.watch(postSortProvider(key));
      return PostFeedNotifier(
        (cursor) => repo.posts(
          communityId: key.isEmpty ? null : key,
          cursor: cursor,
          sort: sort,
        ),
      );
    });

/// A record, so equal filters share one provider entry.
typedef MemoriesQuery = ({String communityId, int? year, String? category});

/// The Memories gallery for one set of filters.
final memoriesProvider = StateNotifierProvider.autoDispose
    .family<PostFeedNotifier, PostFeedState, MemoriesQuery>((ref, query) {
      final repo = ref.watch(communityRepositoryProvider);
      return PostFeedNotifier((cursor) => repo.memories(query, cursor: cursor));
    });

final memoryYearsProvider = FutureProvider.autoDispose
    .family<List<int>, String>(
      (ref, communityId) =>
          ref.watch(communityRepositoryProvider).memoryYears(communityId),
    );

/// Photos and posts shared from an event. Key: event id.
final eventPostsProvider = StateNotifierProvider.autoDispose
    .family<PostFeedNotifier, PostFeedState, String>((ref, eventId) {
      final repo = ref.watch(communityRepositoryProvider);
      return PostFeedNotifier(
        (cursor) => repo.eventPosts(eventId, cursor: cursor),
      );
    });
