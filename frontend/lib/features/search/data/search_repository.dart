import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/community/data/community_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchResult {
  const SearchResult({required this.people, required this.communities});
  final List<Person> people;
  final List<DiscoverCommunity> communities;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        people: (json['people'] as List?)?.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        communities:
            (json['communities'] as List?)?.map((e) => DiscoverCommunity.fromJson(e as Map<String, dynamic>)).toList() ??
                const [],
      );
}

class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchResult> search(String query) async {
    final res = await _dio.get<dynamic>(ApiEndpoints.search, queryParameters: {'q': query});
    return SearchResult.fromJson(dataMap(res));
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) => SearchRepository(ref.watch(dioProvider)));

final searchProvider = FutureProvider.family<SearchResult, String>((ref, q) {
  if (q.trim().isEmpty) return Future.value(const SearchResult(people: [], communities: []));
  return ref.watch(searchRepositoryProvider).search(q);
});
