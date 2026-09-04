import 'package:apsbrat_frontend/core/models/person.dart';

class FeedEvent {
  const FeedEvent({
    required this.id,
    required this.person,
    required this.type,
    required this.typeLabel,
    required this.title,
    required this.body,
    required this.meta,
    required this.createdAt,
  });

  final String id;
  final Person person;
  final String type;
  final String typeLabel;
  final String title;
  final String? body;
  final String? meta;
  final DateTime? createdAt;

  factory FeedEvent.fromJson(Map<String, dynamic> json) => FeedEvent(
    id: json['id']?.toString() ?? '',
    person: Person.fromJson(
      json['person'] as Map<String, dynamic>? ?? const {},
    ),
    type: json['type'] as String? ?? 'GENERAL',
    typeLabel: json['typeLabel'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String?,
    meta: json['meta'] as String?,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
  );
}

class BatchmateBanner {
  const BatchmateBanner({
    required this.count,
    required this.firstNames,
    required this.message,
  });

  final int count;
  final List<String> firstNames;
  final String message;

  factory BatchmateBanner.fromJson(Map<String, dynamic> json) =>
      BatchmateBanner(
        count: (json['count'] as num?)?.toInt() ?? 0,
        firstNames:
            (json['firstNames'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        message: json['message'] as String? ?? '',
      );
}
