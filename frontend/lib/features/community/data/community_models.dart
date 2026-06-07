import 'package:apsbrat_frontend/core/models/person.dart';

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.badge,
    required this.type,
    required this.members,
    required this.online,
    required this.lastSender,
    required this.lastMessage,
    required this.time,
    required this.avatars,
    required this.unreadCount,
    required this.autoJoinLabel,
    required this.isYourSection,
    required this.isYourSchool,
  });

  final String id;
  final String name;
  final String? badge;
  final String type;
  final int members;
  final int online;
  final String? lastSender;
  final String? lastMessage;
  final DateTime? time;
  final List<Person> avatars;
  final int unreadCount;
  final String? autoJoinLabel;
  final bool isYourSection;
  final bool isYourSchool;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        badge: json['badge'] as String?,
        type: json['type'] as String? ?? 'SECTION',
        members: (json['members'] as num?)?.toInt() ?? 0,
        online: (json['online'] as num?)?.toInt() ?? 0,
        lastSender: json['lastSender'] as String?,
        lastMessage: json['lastMessage'] as String?,
        time: DateTime.tryParse(json['time']?.toString() ?? ''),
        avatars: (json['avatars'] as List?)?.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        autoJoinLabel: json['autoJoinLabel'] as String?,
        isYourSection: json['isYourSection'] as bool? ?? false,
        isYourSchool: json['isYourSchool'] as bool? ?? false,
      );
}

class DiscoverCommunity {
  const DiscoverCommunity({required this.id, required this.name, required this.memberCount, required this.subtitle});

  final String id;
  final String name;
  final String memberCount;
  final String? subtitle;

  factory DiscoverCommunity.fromJson(Map<String, dynamic> json) => DiscoverCommunity(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        memberCount: json['memberCount'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
      );
}

class CommunityMessage {
  const CommunityMessage({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.body,
    required this.mine,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final Person sender;
  final String body;
  final bool mine;
  final DateTime? createdAt;

  factory CommunityMessage.fromJson(Map<String, dynamic> json) => CommunityMessage(
        id: json['id']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? '',
        sender: Person.fromJson(json['sender'] as Map<String, dynamic>? ?? const {}),
        body: json['body'] as String? ?? '',
        mine: json['mine'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
