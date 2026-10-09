import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nomad_mingle/app/router.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/application/signup_draft.dart';
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
    expect(s.status, SessionStatus.ready);
    expect(repo.lastDob, DateTime(1998, 1, 1));
    s.dispose();
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
      expect(redirectFor(SessionStatus.signedOut, '/legal/terms'), isNull);
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

  group('sign-up draft', () {
    final draft = SignupDraft(
      name: 'Asha Rao',
      dateOfBirth: DateTime(1998, 4, 2),
      city: 'mumbai',
      interests: const ['food', 'travel', 'music'],
    );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('password user without a profile gets one from the draft', () async {
      await const SignupDraftStore().save(draft);
      final repo = FakeProfileRepository();
      final s = SessionController(
        auth: FakeAuthRepository(_pwUser),
        profiles: repo,
      );
      await pump();
      await pump();
      expect(s.status, SessionStatus.ready);
      expect(s.profile?.displayName, 'Asha Rao');
      expect(s.profile?.city, 'mumbai');
      expect(repo.lastDob, DateTime(1998, 4, 2));
      expect(await const SignupDraftStore().load(), isNull);
      s.dispose();
    });

    test(
      'Google user keeps the onboarding flow and draft is ignored',
      () async {
        await const SignupDraftStore().save(draft);
        final s = SessionController(
          auth: FakeAuthRepository(
            const AuthUser(uid: 'g', email: 'g@x.com', emailVerified: true),
          ),
          profiles: FakeProfileRepository(),
        );
        await pump();
        await pump();
        expect(s.status, SessionStatus.needsOnboarding);
        s.dispose();
      },
    );

    test('invalid (under-18) draft is discarded, onboarding shown', () async {
      await const SignupDraftStore().save(
        SignupDraft(
          name: 'Kid',
          dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 10)),
          city: 'pune',
          interests: const ['food'],
        ),
      );
      final s = SessionController(
        auth: FakeAuthRepository(_pwUser),
        profiles: FakeProfileRepository(),
      );
      await pump();
      await pump();
      expect(s.status, SessionStatus.needsOnboarding);
      expect(await const SignupDraftStore().load(), isNull);
      s.dispose();
    });

    test('draft never contains a password and round-trips', () async {
      final raw = draft.encode();
      expect(raw.toLowerCase().contains('password'), isFalse);
      final back = SignupDraft.decode(raw)!;
      expect(back.dateOfBirth, DateTime(1998, 4, 2));
      expect(back.interests, ['food', 'travel', 'music']);
      expect(SignupDraft.decode('garbage'), isNull);
    });
  });
}
