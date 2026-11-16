import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replays responses recorded from the real backend (test/fixtures/connections), so the
/// repositories are checked against what the server actually sends, not against what we
/// remember it sends. Re-record by running the backend and the capture script.
class _Replay implements HttpClientAdapter {
  _Replay(this.routes);

  /// "GET /connections" -> fixture file name (without .json).
  final Map<String, String> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final file = routes['${options.method} ${options.path}'];
    if (file == null) {
      return ResponseBody.fromString(
        '{"success":false}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      File('test/fixtures/connections/$file.json').readAsStringSync(),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/connections/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final ids =
      (jsonDecode(File('test/fixtures/connections/ids.json').readAsStringSync())
              as Map<String, dynamic>)
          .cast<String, String>();

  ConnectionRepository connections(Map<String, String> routes) =>
      ConnectionRepository(Dio()..httpClientAdapter = _Replay(routes));

  group('connection endpoints the app already calls', () {
    test('friends list parses into people', () async {
      final repo = connections({'GET /connections': 'connections_list'});
      final people = await repo.batchmates();
      expect(people.map((p) => p.id), [ids['friend1'], ids['friend2']]);
      expect(people.every((p) => p.name.isNotEmpty), isTrue);
    });

    test('requests waiting for me and requests I sent parse', () async {
      final repo = connections({
        'GET /connections/pending': 'connections_pending',
        'GET /connections/sent': 'connections_sent',
      });
      expect((await repo.pending()).map((p) => p.id), [ids['requester']]);
      expect((await repo.sent()).map((p) => p.id), [ids['target']]);
    });

    test('mutual connections parse', () async {
      final repo = connections({
        'GET /connections/${ids['friend1']}/mutual': 'connections_mutual',
      });
      expect((await repo.mutual(ids['friend1']!)).map((p) => p.id), [
        ids['friend2'],
      ]);
    });

    test('status values are the strings the app switches on', () async {
      final repo = connections({
        'GET /connections/${ids['friend1']}/status': 'status_connected',
        'GET /connections/${ids['requester']}/status': 'status_pending_in',
        'GET /connections/${ids['target']}/status': 'status_pending_out',
        'GET /connections/${ids['stranger']}/status': 'status_none',
      });
      expect(await repo.statusWith(ids['friend1']!), 'CONNECTED');
      expect(await repo.statusWith(ids['requester']!), 'PENDING_IN');
      expect(await repo.statusWith(ids['target']!), 'PENDING_OUT');
      expect(await repo.statusWith(ids['stranger']!), 'NONE');
    });

    test('request, accept and end complete with the new response bodies', () async {
      final repo = connections({
        'POST /connections/${ids['stranger']}': 'request_response',
        'PUT /connections/${ids['requester']}/accept': 'accept_response',
        'DELETE /connections/${ids['friend2']}': 'end_response',
      });
      await repo.request(ids['stranger']!);
      await repo.accept(ids['requester']!);
      await repo.end(ids['friend2']!);
    });

    test('profile parses without the removed batchmates count', () async {
      final repo = ProfileRepository(
        Dio()
          ..httpClientAdapter = _Replay({
            'GET /profiles/${ids['friend1']}': 'profile_friend1',
            'GET /profiles/${ids['me']}': 'profile_me',
          }),
      );
      final friend = await repo.byId(ids['friend1']!);
      expect(friend.id, ids['friend1']);
      expect(friend.connectedCount, greaterThanOrEqualTo(1));
      expect(
        (_fixture('profile_friend1')['data'] as Map).containsKey('batchmatesCount'),
        isFalse,
      );
      expect((await repo.byId(ids['me']!)).id, ids['me']);
    });
  });

  group('what changed on the server', () {
    test('the request response now says PENDING or ACCEPTED', () {
      final data = _fixture('request_response')['data'] as Map<String, dynamic>;
      expect(data['status'], anyOf('PENDING', 'ACCEPTED'));
      expect(_fixture('request_response')['success'], isTrue);
    });

    test('the end response still carries the new status', () {
      final data = _fixture('end_response')['data'] as Map<String, dynamic>;
      expect(data['status'], 'REMOVED');
    });

    test('accept still answers with no data', () {
      expect(_fixture('accept_response')['data'], isNull);
    });
  });

  group('new endpoints (not called by the app yet): shape only', () {
    test('pages carry items, nextCursor and hasMore', () {
      for (final name in ['page_connections', 'page_pending', 'page_sent', 'mutual_page']) {
        final data = _fixture(name)['data'] as Map<String, dynamic>;
        expect(data.keys, containsAll(['items', 'nextCursor', 'hasMore']), reason: name);
        expect((data['items'] as List).length, 1, reason: name);
      }
    });

    test('mutual count and history', () {
      expect((_fixture('mutual_count')['data'] as Map)['count'], 1);
      final history = _fixture('history')['data'] as List;
      expect(history.map((e) => (e as Map)['type']), ['REQUESTED', 'ACCEPTED']);
      expect((history.first as Map).keys, containsAll(['id', 'type', 'actorId', 'createdAt']));
      expect((history.first as Map).containsKey('metadata'), isFalse);
    });
  });
}
