import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/network/paged_result.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<List<Conversation>> conversations() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.conversations);
    return dataList(res, Conversation.fromJson);
  }

  Future<Conversation> openWith(String userId) async {
    final res = await _dio.post<dynamic>(ApiEndpoints.conversationWith(userId));
    return Conversation.fromJson(dataMap(res));
  }

  Future<PagedResult<ChatMessage>> messages(String conversationId, {String? cursor, int limit = 30}) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.conversationMessages(conversationId),
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = dataMap(res);
    if (data.isEmpty) {
      return PagedResult.empty<ChatMessage>();
    }
    return PagedResult.fromJson(data, ChatMessage.fromJson);
  }

  Future<ChatMessage> send(String conversationId, String body) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.conversationMessages(conversationId),
      data: {'body': body},
    );
    return ChatMessage.fromJson(dataMap(res));
  }

  Future<void> markRead(String conversationId) async {
    await _dio.post<dynamic>(ApiEndpoints.conversationRead(conversationId));
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));

final conversationsProvider = FutureProvider<List<Conversation>>((ref) => ref.watch(chatRepositoryProvider).conversations());
final conversationMessagesProvider =
    FutureProvider.family<PagedResult<ChatMessage>, String>((ref, id) => ref.watch(chatRepositoryProvider).messages(id));
