class ApiResponse<T> {
  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.error,
  });

  final bool success;
  final String? message;
  final T? data;
  final String? error;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? parser,
  ) {
    return ApiResponse<T>(
      success: (json['success'] as bool?) ?? false,
      message: json['message'] as String?,
      error: json['error'] as String?,
      data: parser != null ? parser(json['data']) : json['data'] as T?,
    );
  }
}
