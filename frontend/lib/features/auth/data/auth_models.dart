/// Mirrors the backend UserDto — the logged-in user's own account details.
///
/// [username] and [fullName] are null on a freshly-created account: the
/// account exists the moment the email is verified, before onboarding has
/// collected anything else. The app treats "no username yet" as "onboarding
/// is not finished".
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.username,
    this.fullName,
    this.phone,
    this.city,
    this.profession,
    this.gender,
    this.dob,
    this.bio,
    this.profilePicUrl,
    this.currentStatus,
    this.isVerified = false,
  });

  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String? phone;
  final String? city;
  final String? profession;
  final String? gender;
  final String? dob;
  final String? bio;
  final String? profilePicUrl;
  final String? currentStatus;
  final bool isVerified;

  /// The onboarding profile step hasn't run yet.
  bool get needsOnboarding => username == null || username!.isEmpty;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String?,
      username: json['username'] as String?,
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
      city: json['city'] as String?,
      profession: json['profession'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
      bio: json['bio'] as String?,
      profilePicUrl: json['profilePicUrl'] as String?,
      currentStatus: json['currentStatus'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      user: AuthUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
