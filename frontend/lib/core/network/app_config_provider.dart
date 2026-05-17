import 'package:apsbrat_frontend/core/constants/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_config_provider.g.dart';

@riverpod
String apiBaseUrl(Ref ref) {
  return Env.baseUrl;
}
