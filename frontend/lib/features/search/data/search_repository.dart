import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchResult {
  const SearchResult({required this.people});
  final List<Person> people;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    people:
        (json['people'] as List?)
            ?.map((e) => Person.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// One global people search: free text plus optional filters.
/// A record, so equal queries share one provider entry (and one request).
typedef PeopleQuery = ({
  String q,
  String? schoolId,
  int? batch,
  int? classTo,
  String? section,
  String? stream,
  String? status,
  String? city,

  /// True = only people who attended one of my schools (cheap, default).
  bool mine,
  int page,
});

/// Results per request; the list shows "Show more" when a page is full.
const kPeoplePageSize = 30;

const PeopleQuery kEveryoneQuery = (
  q: '',
  schoolId: null,
  batch: null,
  classTo: null,
  section: null,
  stream: null,
  status: null,
  city: null,
  mine: true,
  page: 0,
);

class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchResult> search(String query) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.search,
      queryParameters: {'q': query},
    );
    return SearchResult.fromJson(dataMap(res));
  }

  Future<List<Person>> searchPeople(PeopleQuery query) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.peopleSearch,
      queryParameters: {
        'q': query.q,
        if (query.schoolId != null) 'schoolId': query.schoolId,
        if (query.batch != null) 'batch': query.batch,
        if (query.classTo != null) 'classTo': query.classTo,
        if (query.section != null) 'section': query.section,
        if (query.stream != null) 'stream': query.stream,
        if (query.status != null) 'status': query.status,
        if (query.city != null) 'city': query.city,
        'mine': query.mine,
        'page': query.page,
        'size': kPeoplePageSize,
      },
    );
    return dataList(res, Person.fromJson);
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(dioProvider)),
);

final searchProvider = FutureProvider.family<SearchResult, String>((ref, q) {
  if (q.trim().isEmpty) return Future.value(const SearchResult(people: []));
  return ref.watch(searchRepositoryProvider).search(q);
});

final peopleSearchProvider = FutureProvider.family<List<Person>, PeopleQuery>(
  (ref, query) => ref.watch(searchRepositoryProvider).searchPeople(query),
);
