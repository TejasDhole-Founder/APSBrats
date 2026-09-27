/// Mirrors the backend NotificationDto.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.actorInitials,
    this.refType,
    this.refId,
    this.actionable = false,
  });

  final String id;

  /// JOIN · CONNECTION_REQUEST · CONNECTION_ACCEPTED · MESSAGE · GENERAL
  final String type;
  final String title;
  final String? body;
  final bool read;
  final DateTime? createdAt;

  /// The person the notification is about (for the avatar and profile link).
  final String? actorId;
  final String? actorName;
  final String? actorInitials;

  /// What it points at: CONNECTION · USER · COMMUNITY · CONVERSATION.
  final String? refType;
  final String? refId;

  /// True while a connection request can still be accepted or declined.
  final bool actionable;

  bool get isRequest => type == 'CONNECTION_REQUEST';

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? 'GENERAL',
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        actorId: json['actorId']?.toString(),
        actorName: json['actorName'] as String?,
        actorInitials: json['actorInitials'] as String?,
        refType: json['refType'] as String?,
        refId: json['refId']?.toString(),
        actionable: json['actionable'] as bool? ?? false,
      );
}
