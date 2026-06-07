import 'package:flutter/material.dart';

/// Mirrors the backend PersonDto. Replaces the old hard-coded AppPerson.
class Person {
  const Person({
    required this.id,
    required this.username,
    required this.initials,
    required this.name,
    required this.school,
    required this.detail,
    required this.city,
    required this.job,
    required this.currentStatus,
    required this.profilePicUrl,
    required this.online,
    required this.tags,
  });

  final String id;
  final String? username;
  final String initials;
  final String name;
  final String school;
  final String detail;
  final String? city;
  final String? job;
  final String currentStatus;
  final String? profilePicUrl;
  final bool online;
  final List<String> tags;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String?,
      initials: json['initials'] as String? ?? '?',
      name: json['name'] as String? ?? '',
      school: json['school'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      city: json['city'] as String?,
      job: json['job'] as String?,
      currentStatus: json['currentStatus'] as String? ?? 'STUDENT',
      profilePicUrl: json['profilePicUrl'] as String?,
      online: json['online'] as bool? ?? false,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  // Deterministic avatar colors derived from the name, so the UI keeps its
  // colourful avatars without the backend needing to store colors.
  Color get bg {
    final palette = _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
    return palette.$1;
  }

  Color get fg {
    final palette = _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
    return palette.$2;
  }
}

const _avatarPalette = <(Color, Color)>[
  (Color(0xFFFEE2E2), Color(0xFF991B1B)),
  (Color(0xFFD1FAE5), Color(0xFF065F46)),
  (Color(0xFFFEF3C7), Color(0xFF78350F)),
  (Color(0xFFEDE9FE), Color(0xFF4C1D95)),
  (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  (Color(0xFFFCE7F3), Color(0xFF9D174D)),
  (Color(0xFFCCFBF1), Color(0xFF065F46)),
  (Color(0xFFE0E7FF), Color(0xFF3730A3)),
];
