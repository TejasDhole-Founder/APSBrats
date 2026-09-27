import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/network/api_response.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Header numbers for the people screen and the bell badge.
class CircleSummary {
  const CircleSummary({
    required this.friends,
    required this.incomingRequests,
    required this.sentRequests,
    required this.classmates,
    required this.schoolmates,
    required this.hasSection,
  });

  final int friends;
  final int incomingRequests;
  final int sentRequests;
  final int classmates;
  final int schoolmates;

  /// False when none of my school entries has a section, so classmates
  /// cannot be matched yet.
  final bool hasSection;

  static const empty = CircleSummary(
    friends: 0,
    incomingRequests: 0,
    sentRequests: 0,
    classmates: 0,
    schoolmates: 0,
    hasSection: true,
  );

  factory CircleSummary.fromJson(Map<String, dynamic> json) => CircleSummary(
    friends: (json['friends'] as num?)?.toInt() ?? 0,
    incomingRequests: (json['incomingRequests'] as num?)?.toInt() ?? 0,
    sentRequests: (json['sentRequests'] as num?)?.toInt() ?? 0,
    classmates: (json['classmates'] as num?)?.toInt() ?? 0,
    schoolmates: (json['schoolmates'] as num?)?.toInt() ?? 0,
    hasSection: json['hasSection'] as bool? ?? true,
  );
}

/// Results per page on the people screen (matches the API default).
const kCirclePageSize = 30;

/// One page of classmates or schoolmates. A record, so equal requests share
/// one provider entry.
typedef CirclePage = ({String? entryId, bool batchOnly, int page});

class CircleRepository {
  CircleRepository(this._dio);
  final Dio _dio;

  Future<CircleSummary> summary() async {
    final res = await _dio.get<dynamic>(ApiEndpoints.circleSummary);
    return CircleSummary.fromJson(dataMap(res));
  }

  Future<List<Person>> classmates(CirclePage q) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.circleClassmates,
      queryParameters: {
        if (q.entryId != null) 'entryId': q.entryId,
        'page': q.page,
        'size': kCirclePageSize,
      },
    );
    return dataList(res, Person.fromJson);
  }

  Future<List<Person>> schoolmates(CirclePage q) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.circleSchoolmates,
      queryParameters: {
        if (q.entryId != null) 'entryId': q.entryId,
        'batchOnly': q.batchOnly,
        'page': q.page,
        'size': kCirclePageSize,
      },
    );
    return dataList(res, Person.fromJson);
  }
}

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => CircleRepository(ref.watch(dioProvider)),
);

final circleSummaryProvider = FutureProvider<CircleSummary>(
  (ref) => ref.watch(circleRepositoryProvider).summary(),
);

final classmatesProvider = FutureProvider.family<List<Person>, CirclePage>(
  (ref, q) => ref.watch(circleRepositoryProvider).classmates(q),
);

final schoolmatesProvider = FutureProvider.family<List<Person>, CirclePage>(
  (ref, q) => ref.watch(circleRepositoryProvider).schoolmates(q),
);
