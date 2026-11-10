import 'package:apsbrat_frontend/core/models/person.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.person,
    required this.preview,
    required this.time,
    required this.unread,
    required this.unreadCount,
  });

  final String id;
  final Person person;
  final String? preview;
  final DateTime? time;
  final bool unread;
  final int unreadCount;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id']?.toString() ?? '',
    person: Person.fromJson(
      json['person'] as Map<String, dynamic>? ?? const {},
    ),
    preview: json['preview'] as String?,
    time: DateTime.tryParse(json['time']?.toString() ?? ''),
    unread: json['unread'] as bool? ?? false,
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.imageUrl,
    required this.mine,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;

  /// Can be empty when the message is just a photo.
  final String body;

  /// One optional photo ("/media/…").
  final String? imageUrl;
  final bool mine;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    conversationId: json['conversationId']?.toString() ?? '',
    senderId: json['senderId']?.toString() ?? '',
    body: json['body'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    mine: json['mine'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
  );
}
