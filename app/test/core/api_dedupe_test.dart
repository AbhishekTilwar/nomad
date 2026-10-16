import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomad_mingle/core/api/api_client.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';

void main() {
  late List<Uri> sent;
  late Completer<void> gate;
  late int status;
  late ApiClient api;

  setUp(() {
    sent = [];
    gate = Completer();
    status = 200;
    api = ApiClient(
      tokenProvider: ({bool forceRefresh = false}) async => 'secret-token',
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((req) async {
        sent.add(req.url);
        await gate.future;
        return http.Response(
          jsonEncode(
            status == 200
                ? {'data': <String, dynamic>{}}
                : {
                    'error': {'code': 'x', 'message': 'no'},
                  },
          ),
          status,
        );
      }),
    );
  });

  test('identical concurrent GETs share one request', () async {
    final a = api.get('/users/me/activities', query: {'role': 'hosted'});
    final b = api.get('/users/me/activities', query: {'role': 'hosted'});
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([a, b]);
    expect(sent, hasLength(1));
  });

  test('different queries are not merged', () async {
    final a = api.get('/users/me/activities', query: {'role': 'hosted'});
    final b = api.get('/users/me/activities', query: {'role': 'joined'});
    gate.complete();
    await Future.wait([a, b]);
    expect(sent, hasLength(2));
  });

  test('query key order and null values do not matter', () async {
    final a = api.get('/x', query: {'a': 1, 'b': 2, 'c': null});
    final b = api.get('/x', query: {'b': 2, 'a': 1});
    gate.complete();
    await Future.wait([a, b]);
    expect(sent, hasLength(1));
  });

  test('a GET after the first finished goes to the server again', () async {
    gate.complete();
    await api.get('/users/me');
    await api.get('/users/me');
    expect(sent, hasLength(2));
  });

  test('a failed GET is not remembered', () async {
    status = 400;
    gate.complete();
    await expectLater(api.get('/users/me'), throwsA(isA<AppException>()));
    status = 200;
    await api.get('/users/me');
    expect(sent, hasLength(2));
  });

  test('writes are never merged', () async {
    final a = api.post('/activities/abcdefghijklmnopqrst/join');
    final b = api.post('/activities/abcdefghijklmnopqrst/join');
    gate.complete();
    await Future.wait([a, b]);
    expect(sent, hasLength(2));
  });

  test('counts requests by shape without ids, queries or tokens', () async {
    gate.complete();
    await api.get('/activities/abcdefghijklmnopqrst');
    await api.get('/activities/zyxwvutsrqponmlkjihg');
    await api.get('/users/me/activities', query: {'role': 'hosted'});
    expect(api.requestCounts, {
      'GET /activities/:id': 2,
      'GET /users/me/activities': 1,
    });
    expect(api.requestCounts.keys.join(), isNot(contains('secret')));
  });
}
