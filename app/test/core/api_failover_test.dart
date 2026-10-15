import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomad_mingle/core/api/api_client.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';

const primary = 'https://primary.test/api/v1';
const backup = 'https://backup.test/api/v1';

http.Response ok(Object data) => http.Response('{"data":$data}', 200);
http.Response placeholder() => http.Response(
  '<!doctype html><title>Placeholder | Cloud Run</title>',
  200,
  headers: {'content-type': 'text/html'},
);

class Harness {
  Harness(this.respond, {this.now}) {
    api = ApiClient(
      tokenProvider: ({bool forceRefresh = false}) async => 't',
      baseUrl: primary,
      backupBaseUrl: backup,
      primaryTimeout: const Duration(milliseconds: 50),
      timeout: const Duration(milliseconds: 500),
      clock: () => now ?? DateTime(2026),
      client: MockClient((r) async {
        hits.add('${r.method} ${r.url.host}');
        return respond(r);
      }),
    );
  }
  final Future<http.Response> Function(http.Request) respond;
  DateTime? now;
  final hits = <String>[];
  late final ApiClient api;
}

void main() {
  test('a healthy primary is used and the backup is never touched', () async {
    final h = Harness((r) async => ok('"a"'));
    expect((await h.api.get('/x')).data, 'a');
    expect(h.hits, ['GET primary.test']);
  });

  test(
    'an HTML placeholder page on the primary fails over to the backup',
    () async {
      final h = Harness(
        (r) async => r.url.host == 'primary.test' ? placeholder() : ok('"b"'),
      );
      expect((await h.api.get('/x')).data, 'b');
      expect(h.hits, ['GET primary.test', 'GET backup.test']);
    },
  );

  test('a refused connection and gateway errors fail over', () async {
    var n = 0;
    final h = Harness((r) async {
      if (r.url.host == 'backup.test') return ok('"b"');
      n++;
      if (n == 1) throw const SocketException('refused');
      return http.Response('bad gateway', 502);
    });
    expect((await h.api.get('/x')).data, 'b');
    h.now = DateTime(2026).add(const Duration(minutes: 10)); // primary retried
    expect((await h.api.get('/y')).data, 'b');
    expect(h.hits.where((x) => x.endsWith('primary.test')).length, 2);
  });

  test(
    'after a failover the backup is used straight away for a while',
    () async {
      var primaryUp = false;
      final h = Harness((r) async {
        if (r.url.host == 'primary.test') {
          return primaryUp ? ok('"p"') : placeholder();
        }
        return ok('"b"');
      });
      await h.api.get('/x');
      h.hits.clear();
      await h.api.get('/y');
      expect(h.hits, ['GET backup.test']); // no wasted trip to the primary
      // After the sticky window the primary is tried again and wins back.
      primaryUp = true;
      h.now = DateTime(2026).add(const Duration(minutes: 5));
      expect((await h.api.get('/z')).data, 'p');
      expect(h.api.activeBaseUrl, primary);
    },
  );

  test('a slow primary read falls back to the backup', () async {
    final h = Harness((r) async {
      if (r.url.host == 'primary.test') {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      return ok('"b"');
    });
    expect((await h.api.get('/x')).data, 'b');
    expect(h.hits, ['GET primary.test', 'GET backup.test']);
  });

  test('a write that times out is NOT repeated on the backup', () async {
    final h = Harness((r) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return ok('"b"');
    });
    await expectLater(
      h.api.post('/x', body: {'a': 1}),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'timeout')),
    );
    expect(h.hits, ['POST primary.test']);
  });

  test(
    'a write that never reached the primary does go to the backup',
    () async {
      final h = Harness((r) async {
        if (r.url.host == 'primary.test') {
          throw const SocketException('refused');
        }
        return ok('"b"');
      });
      expect((await h.api.post('/x', body: {'a': 1})).data, 'b');
      expect(h.hits, ['POST primary.test', 'POST backup.test']);
    },
  );

  test(
    'real API errors (401 / 4xx JSON) are not mistaken for an outage',
    () async {
      final h = Harness(
        (r) async =>
            http.Response('{"error":{"code":"forbidden","message":"No"}}', 403),
      );
      await expectLater(h.api.get('/x'), throwsA(isA<AppException>()));
      expect(h.hits, ['GET primary.test']);
    },
  );

  test('both servers down reports one clear error', () async {
    final h = Harness((r) async => throw const SocketException('down'));
    await expectLater(
      h.api.get('/x'),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'offline')),
    );
    expect(h.hits, ['GET primary.test', 'GET backup.test']);
  });

  test('without a backup nothing changes', () async {
    final hits = <String>[];
    final api = ApiClient(
      tokenProvider: ({bool forceRefresh = false}) async => 't',
      baseUrl: primary,
      backupBaseUrl: '',
      client: MockClient((r) async {
        hits.add(r.url.host);
        return placeholder();
      }),
    );
    // An HTML body with no backup still surfaces as a normal failure.
    await expectLater(api.get('/x'), throwsA(isA<AppException>()));
    expect(hits, ['primary.test']);
  });
}
