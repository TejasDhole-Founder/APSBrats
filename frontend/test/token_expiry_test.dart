import 'dart:convert';

import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, dynamic> payload) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.sig';
}

void main() {
  int inSeconds(int s) =>
      DateTime.now().add(Duration(seconds: s)).millisecondsSinceEpoch ~/ 1000;

  test('reads how long an access token is still valid', () {
    final left = accessTokenTimeLeft(_jwt({'exp': inSeconds(600)}));
    expect(left, isNotNull);
    expect(left!.inSeconds, inInclusiveRange(595, 600));
  });

  test('an expired token has negative time left', () {
    expect(accessTokenTimeLeft(_jwt({'exp': inSeconds(-5)}))!.isNegative, isTrue);
  });

  test('a token that is not a readable JWT gives null', () {
    expect(accessTokenTimeLeft(''), isNull);
    expect(accessTokenTimeLeft('abc'), isNull);
    expect(accessTokenTimeLeft('a.b.c'), isNull);
    expect(accessTokenTimeLeft(_jwt({'sub': 'x'})), isNull);
  });
}
