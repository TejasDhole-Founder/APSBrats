import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CareerRepository {
  CareerRepository(this._dio);
  final Dio _dio;

  /// Autocomplete. `type` is COMPANY or INSTITUTION.
  Future<List<OrgOption>> searchOrganizations(String type, String query) async {
    if (query.trim().length < 2) return const [];
    final res = await _dio.get<dynamic>(
      ApiEndpoints.organizationsSearch,
      queryParameters: {'type': type, 'q': query.trim()},
    );
    return dataList(res, OrgOption.fromJson);
  }

  Future<List<CareerEntry>> forUser(String userId) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.userCareer(userId));
    return dataList(res, CareerEntry.fromJson);
  }

  /// Creates the entry, or updates it when the draft has an id.
  Future<CareerEntry> save(CareerDraft draft) async {
    final res = draft.id == null
        ? await _dio.post<dynamic>(ApiEndpoints.career, data: draft.toRequest())
        : await _dio.put<dynamic>(
            ApiEndpoints.careerEntry(draft.id!),
            data: draft.toRequest(),
          );
    return CareerEntry.fromJson(dataMap(res));
  }

  Future<void> delete(String id) async {
    await _dio.delete<dynamic>(ApiEndpoints.careerEntry(id));
  }
}

final careerRepositoryProvider = Provider<CareerRepository>(
  (ref) => CareerRepository(ref.watch(dioProvider)),
);

/// Someone else's Journey (hidden entries are already filtered by the server).
final careerProvider = FutureProvider.family<List<CareerEntry>, String>(
  (ref, userId) => ref.watch(careerRepositoryProvider).forUser(userId),
);

/// The logged-in user's own Journey: shown from the device copy at once and
/// refreshed in the background, like the rest of the profile.
final myCareerProvider = FutureProvider<List<CareerEntry>>((ref) async {
  final userId = await ref.watch(authRepositoryProvider).currentUserId();
  if (userId == null || userId.isEmpty) return const [];
  return localFirst(
    ref,
    name: 'career',
    path: ApiEndpoints.userCareer(userId),
    userId: userId,
    parse: (d) => [
      for (final e in (d as List?) ?? const [])
        CareerEntry.fromJson(e as Map<String, dynamic>),
    ],
  );
});
