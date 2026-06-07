import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<List<Conversation>> conversations() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.conversations);
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Conversation> openWith(String userId) async {
    final res = await _dio.post<dynamic>(ApiEndpoints.conversationWith(userId));
    return Conversation.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.conversationMessages(conversationId));
    final list = (res.data['data'] as List?) ?? const [];
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> send(String conversationId, String body) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.conversationMessages(conversationId),
      data: {'body': body},
    );
    return ChatMessage.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationId) async {
    await _dio.post<dynamic>(ApiEndpoints.conversationRead(conversationId));
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));

final conversationsProvider = FutureProvider<List<Conversation>>((ref) => ref.watch(chatRepositoryProvider).conversations());
final conversationMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, id) => ref.watch(chatRepositoryProvider).messages(id));
