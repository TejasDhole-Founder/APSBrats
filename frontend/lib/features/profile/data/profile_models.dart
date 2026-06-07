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
  });

  final String id;
  final String? schoolName;
  final int classFrom;
  final int classTo;
  final String section;
  final int batchStart;
  final int batchEnd;
  final bool isPrimary;

  factory SchoolHistory.fromJson(Map<String, dynamic> json) => SchoolHistory(
        id: json['id']?.toString() ?? '',
        schoolName: json['schoolName'] as String?,
        classFrom: (json['classFrom'] as num?)?.toInt() ?? 0,
        classTo: (json['classTo'] as num?)?.toInt() ?? 0,
        section: json['section'] as String? ?? '',
        batchStart: (json['batchStart'] as num?)?.toInt() ?? 0,
        batchEnd: (json['batchEnd'] as num?)?.toInt() ?? 0,
        isPrimary: json['isPrimary'] as bool? ?? false,
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

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.bio,
    required this.city,
    required this.profession,
    required this.profilePicUrl,
    required this.isVerified,
    required this.currentStatus,
    required this.schools,
    required this.socials,
    required this.batchmatesCount,
    required this.schoolsCount,
    required this.connectedCount,
  });

  final String id;
  final String? username;
  final String fullName;
  final String? bio;
  final String? city;
  final String? profession;
  final String? profilePicUrl;
  final bool isVerified;
  final String currentStatus;
  final List<SchoolHistory> schools;
  final List<SocialLink> socials;
  final int batchmatesCount;
  final int schoolsCount;
  final int connectedCount;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id']?.toString() ?? '',
        username: json['username'] as String?,
        fullName: json['fullName'] as String? ?? '',
        bio: json['bio'] as String?,
        city: json['city'] as String?,
        profession: json['profession'] as String?,
        profilePicUrl: json['profilePicUrl'] as String?,
        isVerified: json['isVerified'] as bool? ?? false,
        currentStatus: json['currentStatus'] as String? ?? 'STUDENT',
        schools: (json['schools'] as List?)?.map((e) => SchoolHistory.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        socials: (json['socials'] as List?)?.map((e) => SocialLink.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        batchmatesCount: (json['batchmatesCount'] as num?)?.toInt() ?? 0,
        schoolsCount: (json['schoolsCount'] as num?)?.toInt() ?? 0,
        connectedCount: (json['connectedCount'] as num?)?.toInt() ?? 0,
      );
}
