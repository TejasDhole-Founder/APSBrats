import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Server-driven gate the app fetches on launch. Compare [minSupportedBuild]
/// against the running build number to decide whether to force an update.
class AppRemoteConfig {
  const AppRemoteConfig({
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.maintenance,
    required this.message,
  });

  final int minSupportedBuild;
  final int latestBuild;
  final bool maintenance;
  final String message;

  factory AppRemoteConfig.fromJson(Map<String, dynamic> json) {
    return AppRemoteConfig(
      minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt() ?? 1,
      latestBuild: (json['latestBuild'] as num?)?.toInt() ?? 1,
      maintenance: json['maintenance'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  bool requiresUpdate(int currentBuild) => currentBuild < minSupportedBuild;
}

final appRemoteConfigProvider = FutureProvider<AppRemoteConfig>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<dynamic>(ApiEndpoints.appConfig);
  return AppRemoteConfig.fromJson((res.data['data'] as Map<String, dynamic>?) ?? const {});
});
