import 'dart:convert';

import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, String> _disk = {};
int _calls = 0;
String _serverCity = 'Delhi';

/// Pretends to be the backend: GET /users/me answers with the current city.
class _FakeServer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    _calls++;
    final body = jsonEncode({
      'success': true,
      'data': {'id': 'user-1', 'city': _serverCity},
    });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _disk
      ..clear()
      ..['user_id'] = 'user-1';
    _calls = 0;
    _serverCity = 'Delhi';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map?;
            final key = args?['key'] as String?;
            switch (call.method) {
              case 'read':
                return _disk[key];
              case 'write':
                _disk[key!] = args!['value'] as String;
              case 'delete':
                _disk.remove(key);
            }
            return null;
          },
        );
  });

  ProviderContainer app() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeServer();
    final c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'first launch: fetched from the server and saved on the device',
    () async {
      final me = await app().read(meProvider.future);
      expect(me?.city, 'Delhi');
      expect(_disk['cache_me_user-1'], contains('Delhi'));
    },
  );

  test(
    'next launch: device copy shows instantly, fresh copy swaps in',
    () async {
      _disk['cache_me_user-1'] = jsonEncode({'id': 'user-1', 'city': 'Pune'});
      final c = app();
      c.listen(meProvider, (_, __) {});

      expect((await c.read(meProvider.future))?.city, 'Pune');
      await pumpEventQueue();
      expect(c.read(meProvider).valueOrNull?.city, 'Delhi');
      expect(_calls, 1);
    },
  );

  test(
    'after an edit the server is asked directly, not the old copy',
    () async {
      _disk['cache_me_user-1'] = jsonEncode({'id': 'user-1', 'city': 'Pune'});
      final c = app();
      c.listen(meProvider, (_, __) {});
      await c.read(meProvider.future);
      await pumpEventQueue();

      _serverCity = 'Mumbai';
      c.invalidate(meProvider);
      expect((await c.read(meProvider.future))?.city, 'Mumbai');
    },
  );
}
