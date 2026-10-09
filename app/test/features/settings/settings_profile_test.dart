import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomad_mingle/core/api/api_client.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/features/activities/data/my_activities_repository.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';
import 'package:nomad_mingle/features/profile/presentation/profile_screen.dart';
import 'package:nomad_mingle/features/settings/settings_screens.dart';
import 'package:provider/provider.dart';

import '../../support/fakes.dart';
import '../chat/chat_test_support.dart';

Future<SessionController> makeSession() async {
  final session = SessionController(
    auth: FakeAuthRepository(
      const AuthUser(
        uid: 'me',
        email: 'm@x.com',
        emailVerified: true,
        displayName: 'Me',
      ),
    ),
    profiles: FakeProfileRepository(
      profile: const UserProfile(
        uid: 'me',
        displayName: 'Rahul Verma',
        city: 'mumbai',
        bio: 'Coffee, travel and football.',
        interests: ['food', 'travel', 'sports'],
        profileCompleted: true,
      ),
    ),
  );
  addTearDown(session.dispose);
  return session;
}

Future<void> pumpScreen(
  WidgetTester t,
  Widget screen, {
  required SessionController session,
  ApiClient? api,
  MyActivitiesRepository? mine,
}) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('settings page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: session),
        if (api != null) Provider<ApiClient>.value(value: api),
        if (mine != null) Provider<MyActivitiesRepository>.value(value: mine),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

ApiClient apiFor(Future<http.Response> Function(http.Request) h) => ApiClient(
  tokenProvider: ({bool forceRefresh = false}) async => 't',
  client: MockClient(h),
  baseUrl: 'https://api.test',
);

void main() {
  group('SettingsScreen', () {
    testWidgets('loads initial push state and toggling PUTs all four prefs', (
      t,
    ) async {
      final session = await makeSession();
      final puts = <Map<String, dynamic>>[];
      final api = apiFor((r) async {
        if (r.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': {
                'uid': 'me',
                'private': {
                  'notificationPrefs': {
                    'joinRequests': false,
                    'approvals': false,
                    'activityUpdates': false,
                    'reminders': false,
                  },
                },
              },
            }),
            200,
          );
        }
        puts.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'data': {}}), 200);
      });
      await pumpScreen(t, const SettingsScreen(), session: session, api: api);

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);

      await t.tap(find.byType(Switch));
      await t.pump();
      await t.pump();
      expect(puts, hasLength(1));
      expect(puts.single, {
        'joinRequests': true,
        'approvals': true,
        'activityUpdates': true,
        'reminders': true,
      });
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('toggle reverts and shows the error when the API fails', (
      t,
    ) async {
      final session = await makeSession();
      final api = apiFor((r) async {
        if (r.method == 'GET') return http.Response('{}', 500);
        return http.Response(
          jsonEncode({
            'error': {'code': 'boom', 'message': 'Nope'},
          }),
          400,
        );
      });
      await pumpScreen(t, const SettingsScreen(), session: session, api: api);
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue); // default
      await t.tap(find.byType(Switch));
      await t.pump();
      await t.pump();
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Nope'), findsOneWidget);
    });
  });

  group('LocationSwitchScreen / SafetyScreen', () {
    testWidgets('location: both cities, check on current, skyline copy', (
      t,
    ) async {
      final session = await makeSession();
      await pumpScreen(t, const LocationSwitchScreen(), session: session);
      expect(find.text('Mumbai'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byKey(const ValueKey('skyline')), findsOneWidget);
      expect(find.text('Two cities. Same vibe.'), findsOneWidget);
      expect(find.text('Meetups in Mumbai & Pune'), findsOneWidget);
    });

    testWidgets('safety: items and bottom panel', (t) async {
      final session = await makeSession();
      await pumpScreen(t, const SafetyScreen(), session: session);
      for (final s in [
        'Email-verified members',
        'Report & Block',
        'In-App Moderation',
        'Emergency Support',
        'Your safety matters.',
        'We\'re building a safer community together.',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    });
  });

  group('ProfileScreen', () {
    testWidgets('shows stats from hosted + joined + past, and upcoming plans', (
      t,
    ) async {
      final session = await makeSession();
      final mine = FakeMyActivitiesRepository()
        ..byRole[MyActivitiesRole.hosted] = [
          MyActivity(activity: sampleActivity(id: 'h', isHost: true)),
        ]
        ..byRole[MyActivitiesRole.joined] = [
          MyActivity(
            activity: sampleActivity(id: 'j1', title: 'Trek to Kalsubai'),
          ),
          MyActivity(activity: sampleActivity(id: 'j2')),
        ]
        ..byRole[MyActivitiesRole.past] = [
          MyActivity(activity: sampleActivity(id: 'p1', isHost: true)),
          MyActivity(activity: sampleActivity(id: 'p2')),
        ];
      await pumpScreen(t, const ProfileScreen(), session: session, mine: mine);

      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Mumbai'), findsWidgets);
      expect(find.text('Meetups hosted'), findsOneWidget);
      Text stat(String k) => t.widget<Text>(
        find
            .descendant(
              of: find.byKey(ValueKey(k)),
              matching: find.byType(Text),
            )
            .first,
      );
      expect(stat('stat-hosted').data, '2');
      expect(stat('stat-joined').data, '3');
      expect(stat('stat-interests').data, '3');
      expect(find.text('Upcoming Meetups'), findsOneWidget);
      expect(find.text('Trek to Kalsubai'), findsOneWidget);

      await t.tap(find.byTooltip('Settings'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('settings page'), findsOneWidget);
    });

    testWidgets('stats failure is quiet (dashes, interests still shown)', (
      t,
    ) async {
      final session = await makeSession();
      final mine = FakeMyActivitiesRepository()..error = Exception('x');
      await pumpScreen(t, const ProfileScreen(), session: session, mine: mine);
      final hosted = find.descendant(
        of: find.byKey(const ValueKey('stat-hosted')),
        matching: find.text('–'),
      );
      expect(hosted, findsOneWidget);
      expect(find.byKey(const ValueKey('upcoming-empty')), findsOneWidget);
    });
  });
}
