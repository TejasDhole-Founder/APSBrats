/// Answer from a pre-registration uniqueness check (username, phone).
/// [message] explains why it is not available; null when it is.
class Availability {
  const Availability({required this.available, this.message});

  final bool available;
  final String? message;

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
    available: json['available'] as bool? ?? false,
    message: json['message'] as String?,
  );
}
