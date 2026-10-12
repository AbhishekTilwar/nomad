import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomad_mingle/core/api/api_client.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';

Future<AppException> failWith(
  Map<String, dynamic> error, {
  int status = 400,
}) async {
  final api = ApiClient(
    tokenProvider: ({bool forceRefresh = false}) async => 't',
    baseUrl: 'https://example.test/api/v1',
    client: MockClient(
      (_) async => http.Response(jsonEncode({'error': error}), status),
    ),
  );
  try {
    await api.get('/users/me');
  } on AppException catch (e) {
    return e;
  }
  fail('expected an AppException');
}

void main() {
  test(
    'validation errors name the field instead of "Validation failed"',
    () async {
      final e = await failWith({
        'code': 'validation_failed',
        'message': 'Validation failed',
        'details': [
          {
            'path': 'displayName',
            'message': 'Too big: expected string to have <=40 characters',
          },
        ],
      });
      expect(
        e.message,
        'Name: Too big: expected string to have <=40 characters',
      );
    },
  );

  test('an unrecognised field says the server may need updating', () async {
    final e = await failWith({
      'code': 'validation_failed',
      'message': 'Validation failed',
      'details': [
        {'path': '', 'message': 'Unrecognized key: "gender"'},
      ],
    });
    expect(e.message, contains('Unrecognized key: "gender"'));
    expect(e.message, contains('server may need updating'));
  });

  test(
    'a validation error without details falls back to the server message',
    () async {
      final e = await failWith({
        'code': 'validation_failed',
        'message': 'Validation failed',
      });
      expect(e.message, 'Validation failed');
    },
  );
}
