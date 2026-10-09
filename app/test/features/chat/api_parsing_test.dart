import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomad_mingle/core/api/api_client.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/activities/data/my_activities_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/chat/data/chat_repository.dart';

ApiClient clientFor(Future<http.Response> Function(http.Request) h) =>
    ApiClient(
      tokenProvider: ({bool forceRefresh = false}) async => 't',
      client: MockClient(h),
      baseUrl: 'https://api.test/api/v1',
    );

Map<String, dynamic> activityJson(String id) => {
  'id': id,
  'title': 'Brunch',
  'hostId': 'h1',
  'latitude': 18.9,
  'longitude': 72.8,
  'startAt': '2026-10-12T05:00:00.000Z',
  'endAt': '2026-10-12T07:00:00.000Z',
  'capacity': 6,
  'participantCount': 2,
  'status': 'scheduled',
  'viewer': {'membershipStatus': 'approved', 'isHost': true, 'role': 'host'},
};

void main() {
  test('429 maps retryAfterSeconds and reason onto AppException', () async {
    final api = clientFor(
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'rate_limited',
            'message': 'slow down',
            'details': {'reason': 'rate_limit', 'retryAfterSeconds': 42},
          },
        }),
        429,
      ),
    );
    try {
      await api.post('/community/messages', body: {'text': 'x'});
      fail('should throw');
    } on AppException catch (e) {
      expect(e.code, 'rate_limited');
      expect(e.retryAfterSeconds, 42);
      expect(e.reason, 'rate_limit');
    }
  });

  test('409 read_only reason is exposed', () async {
    final api = clientFor(
      (_) async => http.Response(
        jsonEncode({
          'error': {
            'code': 'conflict',
            'message': 'read-only',
            'details': {'reason': 'read_only'},
          },
        }),
        409,
      ),
    );
    await expectLater(
      api.get('/x'),
      throwsA(
        isA<AppException>().having((e) => e.reason, 'reason', 'read_only'),
      ),
    );
  });

  test(
    'ApiMyActivitiesRepository sends role/limit/cursor and parses rows',
    () async {
      late Uri seen;
      final repo = ApiMyActivitiesRepository(
        clientFor((r) async {
          seen = r.url;
          return http.Response(
            jsonEncode({
              'data': [
                {
                  ...activityJson('a1'),
                  'lastMessage': {
                    'text': 'hi',
                    'createdAt': '2026-10-10T10:00:00.000Z',
                    'senderName': 'Dev',
                    'senderId': 'u2',
                  },
                  'participants': [
                    {'uid': 'h1', 'displayName': 'Riya', 'photoUrl': null},
                  ],
                },
                activityJson('a2'),
              ],
              'nextCursor': 'abc',
            }),
            200,
          );
        }),
      );
      final page = await repo.list(
        MyActivitiesRole.hosted,
        cursor: 'c1',
        limit: 10,
      );
      expect(seen.path, '/api/v1/users/me/activities');
      expect(seen.queryParameters, {
        'role': 'hosted',
        'limit': '10',
        'cursor': 'c1',
      });
      expect(page.nextCursor, 'abc');
      expect(page.items.first.activity.isHost, isTrue);
      expect(page.items.first.activity.membership, MembershipStatus.approved);
      expect(page.items.first.lastMessage?.senderId, 'u2');
      expect(page.items.first.participants.single.displayName, 'Riya');
      expect(page.items.last.lastMessage, isNull);
      expect(page.items.last.participants, isEmpty);
    },
  );

  test('CommunityViewer.fromJson', () {
    final v = CommunityViewer.fromJson({
      'room': {'name': 'Mingle Community'},
      'viewer': {
        'canPost': false,
        'muted': true,
        'mutedUntil': '2026-10-11T00:00:00.000Z',
        'cooldownUntil': null,
        'accountStatus': 'muted',
        'limits': {'maxLength': 400},
      },
    });
    expect(v.canPost, isFalse);
    expect(v.muted, isTrue);
    expect(v.mutedUntil, isNotNull);
    expect(v.cooldownUntil, isNull);
    expect(v.maxLength, 400);
  });
}
