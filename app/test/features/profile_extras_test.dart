import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';
import 'package:nomad_mingle/features/onboarding/presentation/profile_extras_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Future<(SessionController, FakeProfileRepository)> pumpScreen(
  WidgetTester t,
) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final repo = FakeProfileRepository();
  final session = SessionController(
    auth: FakeAuthRepository(
      const AuthUser(
        uid: 'u1',
        email: 'a@b.co',
        emailVerified: true,
        usesPassword: true,
      ),
    ),
    profiles: repo,
  );
  await t.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
    await session.completeOnboarding(
      displayName: 'Asha',
      dateOfBirth: DateTime(1998, 1, 1),
      city: 'pune',
      bio: '',
      interests: ['food'],
      preferredActivityTypes: const [],
      photoUrl: 'https://example.com/me.jpg',
    );
  });
  await t.pumpWidget(
    ChangeNotifierProvider<SessionController>.value(
      value: session,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ProfileExtrasScreen(),
      ),
    ),
  );
  return (session, repo);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a profile with a photo goes straight to the extras step', (
    t,
  ) async {
    final (session, _) = await pumpScreen(t);
    expect(session.status, SessionStatus.needsProfileExtras);
    expect(find.text('Tell your story'), findsOneWidget);
  });

  testWidgets('bio + Instagram are saved, and country comes from the city', (
    t,
  ) async {
    final (session, repo) = await pumpScreen(t);
    await t.enterText(find.byType(TextField).first, 'Love trekking');
    await t.enterText(find.byType(TextField).last, '@asha.walks');
    await t.pump();
    await t.tap(find.text('Finish'));
    await t.pumpAndSettle();

    expect(repo.lastBio, 'Love trekking');
    expect(repo.lastInstagram, 'asha.walks');
    // pumpScreen creates a Pune profile; Pune is in India. No second question.
    expect(repo.lastCountry, 'IN');
    expect(find.text('Where\'s home?'), findsNothing);
    expect(session.status, SessionStatus.ready);
  });

  testWidgets('an invalid Instagram handle shows an error and blocks Finish', (
    t,
  ) async {
    await pumpScreen(t);
    await t.enterText(find.byType(TextField).last, 'bad handle!');
    await t.pump();
    expect(find.textContaining('letters, numbers'), findsOneWidget);
    final done = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Finish'),
    );
    expect(done.onPressed, isNull);
  });

  testWidgets(
    'Skip drops the typed story but still saves the derived country',
    (t) async {
      final (session, repo) = await pumpScreen(t);
      await t.enterText(find.byType(TextField).first, 'will be discarded');
      await t.tap(find.text('Skip'));
      await t.pumpAndSettle();
      expect(repo.lastBio, isNull);
      expect(repo.lastInstagram, isNull);
      expect(repo.lastCountry, 'IN');
      expect(session.status, SessionStatus.ready);
    },
  );

  test(
    'profile completion counts photo, bio, Instagram, hometown, interests, gallery',
    () {
      const empty = UserProfile(uid: 'u', displayName: 'A', city: 'pune');
      expect(empty.completionPercent, 0);
      const half = UserProfile(
        uid: 'u',
        displayName: 'A',
        city: 'pune',
        photoUrl: 'https://x/y.jpg',
        bio: 'hi',
        countryCode: 'IN',
      );
      expect(half.completionPercent, 50);
      const full = UserProfile(
        uid: 'u',
        displayName: 'A',
        city: 'pune',
        photoUrl: 'https://x/y.jpg',
        bio: 'hi',
        countryCode: 'IN',
        instagram: 'a',
        interests: ['food', 'art', 'music'],
        photos: ['https://x/y.jpg'],
      );
      expect(full.completionPercent, 100);
    },
  );
}
