import 'dart:convert';

import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the half-finished registration on the device so it survives closing
/// the app. It lives in secure storage (encrypted, and wiped by logout along
/// with the login tokens) because it holds personal details.
class OnboardingDraftStore {
  OnboardingDraftStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'onboarding_draft';

  Future<void> save(OnboardingFlowState state) async {
    final userId = await _storage.read(key: kUserIdKey);
    // Not signed in: nobody to resume for.
    if (userId == null || userId.isEmpty) return;
    await _storage.write(
      key: _key,
      value: jsonEncode({'userId': userId, 'state': state.toJson()}),
    );
  }

  /// The saved draft for the currently signed-in account, or null. A draft that
  /// belongs to someone else, or is unreadable, is deleted instead of used.
  Future<OnboardingFlowState?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final userId = await _storage.read(key: kUserIdKey);
      if (saved['userId'] != userId) {
        await clear();
        return null;
      }
      return OnboardingFlowState.fromJson(
        saved['state'] as Map<String, dynamic>,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}
