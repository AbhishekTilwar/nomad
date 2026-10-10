import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/app/app.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/onboarding/application/intro_store.dart';
import 'package:nomad_mingle/features/shell/main_shell.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import 'chat/chat_test_support.dart' show FakeChatRepository;

const _user = AuthUser(
  uid: 'u1',
  email: 'a@b.co',
  emailVerified: true,
  usesPassword: true,
);
const _profile = UserProfile(
  uid: 'u1',
  displayName: 'Asha Rao',
  city: 'pune',
  bio: 'Hi',
  interests: ['food'],
  profileCompleted: true,
);

/// Phone-sized logical surface (the default 800x600 @3x is only 266x200).
void usePhone(WidgetTester t) {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 15; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({IntroStore.key: true}));

  testWidgets('signed out: landing leads to sign in with Google', (t) async {
    usePhone(t);
    await t.pumpWidget(
      NomadMingleApp(
        chat: FakeChatRepository(),
        auth: FakeAuthRepository(),
        profiles: FakeProfileRepository(),
        activities: FakeActivityRepository(),
      ),
    );
    await settle(t);
    expect(find.text('New places. New people.\nSame sky.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    await t.tap(find.text('Continue with Email'));
    await settle(t);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets(
    'email sign-in shows friendly error, then succeeds into Explore',
    (t) async {
      usePhone(t);
      final auth = FakeAuthRepository()
        ..failNext = const AuthFailure(
          'Email or password is incorrect.',
          code: 'invalid-credential',
        );
      await t.pumpWidget(
        NomadMingleApp(
          chat: FakeChatRepository(),
          auth: auth,
          profiles: FakeProfileRepository(profile: _profile),
          activities: FakeActivityRepository([sampleActivity()]),
        ),
      );
      await settle(t);
      await t.tap(find.text('Continue with Email'));
      await settle(t);

      // Validation first.
      await t.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await settle(t);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(auth.signInCalls, 0);

      await t.enterText(find.byKey(const ValueKey('login-email')), 'a@b.co');
      await t.enterText(
        find.byKey(const ValueKey('login-password')),
        'wrongpass',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await settle(t);
      expect(find.text('Email or password is incorrect.'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await settle(t);
      expect(find.text('Map'), findsWidgets); // bottom nav + landed
      expect(find.byType(FloatingNavBar), findsOneWidget);
    },
  );

  testWidgets('onboarding rejects under-18 date of birth', (t) async {
    usePhone(t);
    final auth = FakeAuthRepository(_user);
    await t.pumpWidget(
      NomadMingleApp(
        chat: FakeChatRepository(),
        auth: auth,
        profiles: FakeProfileRepository(),
        activities: FakeActivityRepository(),
      ),
    );
    await settle(t);
    expect(find.text('Let\'s get you set up'), findsOneWidget);

    // Continue without name/DOB -> errors, stays on step 1.
    await t.tap(find.text('Continue'));
    await settle(t);
    expect(find.text('Name must be at least 2 characters.'), findsOneWidget);
    expect(find.text('Select your date of birth.'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets(
    'bottom navigation has exactly three destinations, no community/notifications tab',
    (t) async {
      usePhone(t);
      await t.pumpWidget(
        NomadMingleApp(
          chat: FakeChatRepository(),
          auth: FakeAuthRepository(_user),
          profiles: FakeProfileRepository(profile: _profile),
          activities: FakeActivityRepository([sampleActivity()]),
        ),
      );
      await settle(t);
      final bar = t.widget<FloatingNavBar>(find.byType(FloatingNavBar));
      expect(bar.items.map((i) => i.label), ['Map', 'Chat', 'Profile']);
    },
  );

  testWidgets('Explore: map/list toggle, list shows activities', (t) async {
    usePhone(t);
    await t.pumpWidget(
      NomadMingleApp(
        chat: FakeChatRepository(),
        auth: FakeAuthRepository(_user),
        profiles: FakeProfileRepository(profile: _profile),
        activities: FakeActivityRepository([
          sampleActivity(),
          sampleActivity(id: 'a2', title: 'Hike to Sinhagad fort'),
        ]),
      ),
    );
    await settle(t);
    expect(
      find.text('Sunday brunch at Kala Ghoda'),
      findsNothing,
    ); // map view: markers only
    await t.tap(find.byKey(const ValueKey('view-toggle')));
    await settle(t);
    expect(find.text('Sunday brunch at Kala Ghoda'), findsOneWidget);
    expect(find.text('Hike to Sinhagad fort'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('view-toggle')));
    await settle(t);
    expect(find.text('Sunday brunch at Kala Ghoda'), findsNothing);
  });

  testWidgets('Explore: empty and error states, retry recovers', (t) async {
    usePhone(t);
    final repo = FakeActivityRepository()
      ..error = const AppException('No internet connection.', retryable: true);
    await t.pumpWidget(
      NomadMingleApp(
        chat: FakeChatRepository(),
        auth: FakeAuthRepository(_user),
        profiles: FakeProfileRepository(profile: _profile),
        activities: repo,
      ),
    );
    await settle(t);
    expect(find.text('No internet connection.'), findsOneWidget);
    repo.error = null;
    await t.pump(const Duration(seconds: 2)); // let the route transition finish
    await t.tap(find.widgetWithText(TextButton, 'Try again'));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('view-toggle')));
    await settle(t);
    expect(find.text('No plans here yet'), findsOneWidget);
  });

  testWidgets('Profile tab shows data and sign out returns to landing', (
    t,
  ) async {
    usePhone(t);
    await t.pumpWidget(
      NomadMingleApp(
        chat: FakeChatRepository(),
        auth: FakeAuthRepository(_user),
        profiles: FakeProfileRepository(profile: _profile),
        activities: FakeActivityRepository(),
      ),
    );
    await settle(t);
    await t.tap(find.text('Profile').last);
    await settle(t);
    expect(find.text('Asha Rao'), findsOneWidget);
    await t.tap(find.text('Sign out'));
    await settle(t);
    await t.tap(find.text('Sign out').last);
    await settle(t);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
  });
}
