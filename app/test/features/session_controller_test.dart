import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nomad_mingle/app/router.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';

import '../support/fakes.dart';

const _pwUser = AuthUser(
  uid: 'u1',
  email: 'a@b.co',
  emailVerified: true,
  usesPassword: true,
);
const _completed = UserProfile(
  uid: 'u1',
  displayName: 'Asha',
  city: 'pune',
  profileCompleted: true,
);

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts initializing then signedOut with no user', () async {
    final auth = FakeAuthRepository();
    final s = SessionController(auth: auth, profiles: FakeProfileRepository());
    expect(s.status, SessionStatus.initializing);
    await pump();
    expect(s.status, SessionStatus.signedOut);
    s.dispose();
  });

  test('persisted session with completed profile becomes ready', () async {
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: FakeProfileRepository(profile: _completed),
    );
    await pump();
    expect(s.status, SessionStatus.ready);
    expect(s.profile?.displayName, 'Asha');
    s.dispose();
  });

  test('no profile -> onboarding, then completeOnboarding -> ready', () async {
    final repo = FakeProfileRepository();
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: repo,
    );
    await pump();
    expect(s.status, SessionStatus.needsOnboarding);
    await s.completeOnboarding(
      displayName: 'Asha',
      dateOfBirth: DateTime(1998, 1, 1),
      city: 'pune',
      bio: '',
      interests: ['food'],
      preferredActivityTypes: const [],
    );
    // Brand-new profile with no photo gets the one-time "add a photo" step.
    expect(s.status, SessionStatus.needsPhoto);
    s.finishPhotoPrompt();
    // ...then the optional story / hometown step, then done.
    expect(s.status, SessionStatus.needsProfileExtras);
    s.finishProfileExtras();
    expect(s.status, SessionStatus.ready);
    expect(repo.lastDob, DateTime(1998, 1, 1));
    s.dispose();
  });

  test(
    'new profile that already has a photo skips to the extras step',
    () async {
      final s = SessionController(
        auth: FakeAuthRepository(_pwUser),
        profiles: FakeProfileRepository(),
      );
      await pump();
      await s.completeOnboarding(
        displayName: 'Asha',
        dateOfBirth: DateTime(1998, 1, 1),
        city: 'pune',
        bio: '',
        interests: ['food'],
        preferredActivityTypes: const [],
        photoUrl: 'https://example.com/me.jpg',
      );
      expect(s.status, SessionStatus.needsProfileExtras);
      s.dispose();
    },
  );

  test('existing users with no photo are not nagged on sign-in', () async {
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: FakeProfileRepository(profile: _completed),
    );
    await pump();
    expect(s.status, SessionStatus.ready);
    s.dispose();
  });

  test('finishPhotoPrompt is a no-op outside the photo step', () async {
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: FakeProfileRepository(profile: _completed),
    );
    await pump();
    s.finishPhotoPrompt();
    expect(s.status, SessionStatus.ready);
    s.dispose();
  });

  test(
    'router sends needsPhoto to /add-photo and frees ready users from it',
    () {
      expect(redirectFor(SessionStatus.needsPhoto, '/explore'), '/add-photo');
      expect(redirectFor(SessionStatus.needsPhoto, '/add-photo'), isNull);
      expect(redirectFor(SessionStatus.ready, '/add-photo'), '/explore');
    },
  );

  test('router sends needsProfileExtras to /about-you only', () {
    expect(
      redirectFor(SessionStatus.needsProfileExtras, '/explore'),
      '/about-you',
    );
    expect(redirectFor(SessionStatus.needsProfileExtras, '/about-you'), isNull);
    expect(redirectFor(SessionStatus.ready, '/about-you'), '/explore');
  });

  test('unverified password user is held at email verification', () async {
    final auth = FakeAuthRepository(
      const AuthUser(
        uid: 'u1',
        email: 'a@b.co',
        emailVerified: false,
        usesPassword: true,
      ),
    );
    final s = SessionController(
      auth: auth,
      profiles: FakeProfileRepository(profile: _completed),
    );
    await pump();
    expect(s.status, SessionStatus.needsEmailVerification);
    expect(await s.refreshEmailVerification(), isFalse);
    auth.verified = true;
    expect(await s.refreshEmailVerification(), isTrue);
    expect(s.status, SessionStatus.ready);
    s.dispose();
  });

  test('Google users are not asked to verify', () async {
    final s = SessionController(
      auth: FakeAuthRepository(
        const AuthUser(uid: 'g', email: 'g@x.com', emailVerified: true),
      ),
      profiles: FakeProfileRepository(profile: _completed),
    );
    await pump();
    expect(s.status, SessionStatus.ready);
    s.dispose();
  });

  test('profile fetch failure -> profileError, retry recovers', () async {
    final repo = FakeProfileRepository(profile: _completed)
      ..fetchError = const AppException(
        'offline',
        code: 'offline',
        retryable: true,
      );
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: repo,
    );
    await pump();
    expect(s.status, SessionStatus.profileError);
    expect(s.error, 'offline');
    repo.fetchError = null;
    await s.loadProfile();
    expect(s.status, SessionStatus.ready);
    s.dispose();
  });

  test('expired session (unauthenticated) signs the user out', () async {
    final repo = FakeProfileRepository()
      ..fetchError = const AppException('expired', code: 'unauthenticated');
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: repo,
    );
    await pump();
    await pump();
    expect(s.status, SessionStatus.signedOut);
    s.dispose();
  });

  test('suspended account is restricted', () async {
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: FakeProfileRepository(
        profile: const UserProfile(
          uid: 'u1',
          displayName: 'X',
          city: 'pune',
          profileCompleted: true,
          accountStatus: 'suspended',
        ),
      ),
    );
    await pump();
    expect(s.status, SessionStatus.restricted);
    s.dispose();
  });

  test('sign out returns to signedOut and clears profile', () async {
    final s = SessionController(
      auth: FakeAuthRepository(_pwUser),
      profiles: FakeProfileRepository(profile: _completed),
    );
    await pump();
    await s.signOut();
    await pump();
    expect(s.status, SessionStatus.signedOut);
    expect(s.profile, isNull);
    s.dispose();
  });

  group('router redirects', () {
    test('signed out users are sent to welcome except on auth routes', () {
      expect(redirectFor(SessionStatus.signedOut, '/explore'), '/welcome');
      expect(redirectFor(SessionStatus.signedOut, '/sign-in'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/intro'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/register'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/welcome'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/forgot-password'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/legal/terms'), isNull);
      expect(redirectFor(SessionStatus.signedOut, '/legal/privacy'), isNull);
    });
    test('ready users cannot linger on auth screens', () {
      expect(redirectFor(SessionStatus.ready, '/welcome'), '/explore');
      expect(redirectFor(SessionStatus.ready, '/intro'), '/explore');
      expect(redirectFor(SessionStatus.ready, '/chats'), isNull);
    });
    test('onboarding and verification gates', () {
      expect(
        redirectFor(SessionStatus.needsOnboarding, '/explore'),
        '/onboarding',
      );
      expect(
        redirectFor(SessionStatus.needsEmailVerification, '/explore'),
        '/verify-email',
      );
      expect(redirectFor(SessionStatus.initializing, '/welcome'), '/splash');
    });
  });

  group('profile setup is identical for every sign-in method', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    for (final entry in {
      'email': _pwUser,
      'google': const AuthUser(uid: 'g', email: 'g@x.com', emailVerified: true),
    }.entries) {
      test('${entry.key} user without a profile gets onboarding', () async {
        final s = SessionController(
          auth: FakeAuthRepository(entry.value),
          profiles: FakeProfileRepository(),
        );
        await pump();
        await pump();
        expect(s.status, SessionStatus.needsOnboarding);
        s.dispose();
      });
    }
  });
}
