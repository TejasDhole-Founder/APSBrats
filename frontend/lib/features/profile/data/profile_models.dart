class SchoolHistory {
  const SchoolHistory({
    required this.id,
    required this.schoolName,
    required this.classFrom,
    required this.classTo,
    required this.section,
    required this.batchStart,
    required this.batchEnd,
    required this.isPrimary,
    this.schoolId,
    this.stream,
  });

  final String id;
  final String? schoolId;
  final String? schoolName;
  final int classFrom;
  final int classTo;
  final String section;
  final int batchStart;
  final int batchEnd;
  final bool isPrimary;

  /// Stream code for Class 11/12 entries, else null.
  final String? stream;

  factory SchoolHistory.fromJson(Map<String, dynamic> json) => SchoolHistory(
    id: json['id']?.toString() ?? '',
    schoolId: json['schoolId']?.toString(),
    schoolName: json['schoolName'] as String?,
    classFrom: (json['classFrom'] as num?)?.toInt() ?? 0,
    classTo: (json['classTo'] as num?)?.toInt() ?? 0,
    section: json['section'] as String? ?? '',
    batchStart: (json['batchStart'] as num?)?.toInt() ?? 0,
    batchEnd: (json['batchEnd'] as num?)?.toInt() ?? 0,
    isPrimary: json['isPrimary'] as bool? ?? false,
    stream: json['stream'] as String?,
  );
}

class SocialLink {
  const SocialLink({required this.platform, required this.handle, this.label});
  final String platform;
  final String handle;
  final String? label;

  factory SocialLink.fromJson(Map<String, dynamic> json) => SocialLink(
    platform: json['platform'] as String? ?? '',
    handle: json['handle'] as String? ?? '',
    label: json['label'] as String?,
  );
}

/// The one privacy switch. Private hides phone + socials from other users.
class PrivacySettings {
  const PrivacySettings({required this.isPrivate, required this.discoverable});

  final bool isPrivate;
  final bool discoverable;

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        isPrivate: json['isPrivate'] as bool? ?? false,
        discoverable: json['discoverable'] as bool? ?? true,
      );
}

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.bio,
    required this.city,
    required this.profession,
    required this.phone,
    required this.profilePicUrl,
    required this.isVerified,
    required this.isPrivate,
    required this.currentStatus,
    required this.schools,
    required this.socials,
    required this.batchmatesCount,
    required this.schoolsCount,
    required this.connectedCount,
    this.mutualCount = 0,
  });

  final String id;
  final String? username;
  final String fullName;
  final String? bio;
  final String? city;
  final String? profession;

  /// Null when the owner is Private and you are not them.
  final String? phone;
  final String? profilePicUrl;
  final bool isVerified;
  final bool isPrivate;
  final String currentStatus;
  final List<SchoolHistory> schools;
  final List<SocialLink> socials;
  final int batchmatesCount;
  final int schoolsCount;
  final int connectedCount;

  /// Connections I share with this person (0 on my own profile).
  final int mutualCount;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id']?.toString() ?? '',
    username: json['username'] as String?,
    fullName: json['fullName'] as String? ?? '',
    bio: json['bio'] as String?,
    city: json['city'] as String?,
    profession: json['profession'] as String?,
    phone: json['phone'] as String?,
    profilePicUrl: json['profilePicUrl'] as String?,
    isVerified: json['isVerified'] as bool? ?? false,
    isPrivate: json['isPrivate'] as bool? ?? false,
    mutualCount: (json['mutualCount'] as num?)?.toInt() ?? 0,
    currentStatus: json['currentStatus'] as String? ?? 'STUDENT',
    schools:
        (json['schools'] as List?)
            ?.map((e) => SchoolHistory.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    socials:
        (json['socials'] as List?)
            ?.map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    batchmatesCount: (json['batchmatesCount'] as num?)?.toInt() ?? 0,
    schoolsCount: (json['schoolsCount'] as num?)?.toInt() ?? 0,
    connectedCount: (json['connectedCount'] as num?)?.toInt() ?? 0,
  );
}
