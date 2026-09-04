import 'package:dio/dio.dart';

// The backend always wraps payloads in { success, data, message, error }.
// These helpers unwrap `data` so repositories stay one-liners.

List<T> dataList<T>(Response<dynamic> res, T Function(Map<String, dynamic>) fromJson) {
  final list = (res.data['data'] as List?) ?? const [];
  return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
}

Map<String, dynamic> dataMap(Response<dynamic> res) =>
    (res.data['data'] as Map<String, dynamic>?) ?? const {};
