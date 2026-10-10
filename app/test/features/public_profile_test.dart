import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/public_profile.dart';
import 'package:nomad_mingle/features/profile/presentation/public_profile_screen.dart';
import 'package:nomad_mingle/features/safety/data/safety_repository.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import 'chat/chat_test_support.dart' show FakeSafetyRepository;

class FakePublicProfiles implements PublicProfileRepository {
  PublicProfile? profile;
  Object? error;
  final fetched = <String>[];
  @override
  Future<PublicProfile> fetch(String uid) async {
    fetched.add(uid);
    if (error != null) throw error!;
    return profile ??
        PublicProfile(
          uid: uid,
          displayName: 'Sarah Johnson',
          city: 'mumbai',
          ageRange: '25-29',
          emailVerified: true,
          interests: const ['hiking', 'photography', 'food'],
          bio: 'Digital nomad, coffee lover.',
          hosted: 3,
          attended: 12,
        );
  }
}

Future<(FakePublicProfiles, FakeSafetyRepository, SessionController)>
pumpProfile(
  WidgetTester t, {
  String uid = 'other',
  FakePublicProfiles? repo,
}) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final profiles = repo ?? FakePublicProfiles();
  final safety = FakeSafetyRepository();
  final session = SessionController(
    auth: FakeAuthRepository(
      const AuthUser(
        uid: 'me',
        email: 'a@b.co',
        emailVerified: true,
        usesPassword: true,
      ),
    ),
    profiles: FakeProfileRepository(),
  );
  final router = GoRouter(
    initialLocation: '/user/$uid',
    routes: [
      GoRoute(
        path: '/explore',
        builder: (_, _) => const Scaffold(body: Text('explore')),
      ),
      GoRoute(
        path: '/user/:uid',
        builder: (_, s) => PublicProfileScreen(
          uid: s.pathParameters['uid']!,
          fallbackName: 'Sarah',
        ),
      ),
    ],
  );
  await t.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PublicProfileRepository>.value(value: profiles),
        Provider<SafetyRepository>.value(value: safety),
        ChangeNotifierProvider<SessionController>.value(value: session),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  return (profiles, safety, session);
}

void main() {
  testWidgets(
    'shows name, verified badge, age/city, interests, bio and stats',
    (t) async {
      final (repo, _, _) = await pumpProfile(t);
      expect(repo.fetched, ['other']);
      expect(find.text('Sarah Johnson'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.textContaining('25-29'), findsOneWidget);
      expect(find.textContaining('Mumbai'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('About me'), findsOneWidget);
      expect(find.text('Digital nomad, coffee lover.'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Attended'), findsOneWidget);
    },
  );

  testWidgets('never shows date of birth or distance/location', (t) async {
    await pumpProfile(t);
    expect(find.textContaining('km away'), findsNothing);
    expect(find.textContaining('born'), findsNothing);
  });

  testWidgets('error state offers retry', (t) async {
    final repo = FakePublicProfiles()
      ..error = const AppException('No internet connection.');
    await pumpProfile(t, repo: repo);
    expect(find.text('No internet connection.'), findsOneWidget);
    repo.error = null;
    await t.tap(find.text('Try again'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Sarah Johnson'), findsOneWidget);
  });

  testWidgets('report and block are available for others', (t) async {
    final (_, safety, _) = await pumpProfile(t);
    await t.tap(find.byTooltip('More'));
    await t.pumpAndSettle();
    await t.tap(find.text('Block member'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Block'));
    await t.pumpAndSettle();
    expect(safety.blockedUids, contains('other'));
  });

  testWidgets('own profile hides report/block and offers Edit profile', (
    t,
  ) async {
    await pumpProfile(t, uid: 'me');
    expect(find.byTooltip('More'), findsNothing);
    expect(find.text('Edit profile'), findsOneWidget);
  });
}
