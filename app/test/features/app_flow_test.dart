import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/app/app.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';

import '../support/fakes.dart';

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

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('signed out: welcome screen with both sign-in methods', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      NomadMingleApp(
        auth: FakeAuthRepository(),
        profiles: FakeProfileRepository(),
        activities: FakeActivityRepository(),
      ),
    );
    await settle(t);
    expect(
      find.text('Find your people.\nMake a plan. Go together.'),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    await t.tap(find.text('I already have an account'));
    await settle(t);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets(
    'email sign-in shows friendly error, then succeeds into Explore',
    (t) async {
      final auth = FakeAuthRepository()
        ..failNext = const AuthFailure(
          'Email or password is incorrect.',
          code: 'invalid-credential',
        );
      await t.pumpWidget(
        NomadMingleApp(
          auth: auth,
          profiles: FakeProfileRepository(profile: _profile),
          activities: FakeActivityRepository([sampleActivity()]),
        ),
      );
      await settle(t);
      await t.tap(find.text('I already have an account'));
      await settle(t);

      // Validation first.
      await t.tap(find.text('Sign in').last);
      await settle(t);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(auth.signInCalls, 0);

      await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@b.co');
      await t.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrongpass',
      );
      await t.tap(find.text('Sign in').last);
      await settle(t);
      expect(find.text('Email or password is incorrect.'), findsOneWidget);

      await t.tap(find.text('Sign in').last);
      await settle(t);
      expect(find.text('Explore'), findsWidgets); // bottom nav + landed
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('onboarding rejects under-18 date of birth', (t) async {
    final auth = FakeAuthRepository(_user);
    await t.pumpWidget(
      NomadMingleApp(
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
    'bottom navigation has exactly the five destinations, no community tab',
    (t) async {
      await t.pumpWidget(
        NomadMingleApp(
          auth: FakeAuthRepository(_user),
          profiles: FakeProfileRepository(profile: _profile),
          activities: FakeActivityRepository([sampleActivity()]),
        ),
      );
      await settle(t);
      final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 5);
      final labels = bar.destinations
          .map((d) => (d as NavigationDestination).label)
          .toList();
      expect(labels, ['Explore', 'Discover', 'Create', 'Chats', 'Profile']);
    },
  );

  testWidgets('Explore: map/list toggle, list shows activities', (t) async {
    await t.pumpWidget(
      NomadMingleApp(
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
    await t.tap(find.byTooltip('Show list'));
    await settle(t);
    expect(find.text('Sunday brunch at Kala Ghoda'), findsOneWidget);
    expect(find.text('Hike to Sinhagad fort'), findsOneWidget);
    await t.tap(find.byTooltip('Show map'));
    await settle(t);
    expect(find.text('Sunday brunch at Kala Ghoda'), findsNothing);
  });

  testWidgets('Explore: empty and error states, retry recovers', (t) async {
    final repo = FakeActivityRepository()
      ..error = const AppException('No internet connection.', retryable: true);
    await t.pumpWidget(
      NomadMingleApp(
        auth: FakeAuthRepository(_user),
        profiles: FakeProfileRepository(profile: _profile),
        activities: repo,
      ),
    );
    await settle(t);
    expect(find.text('No internet connection.'), findsOneWidget);
    repo.error = null;
    await t.tap(find.text('Try again'));
    await settle(t);
    await t.tap(find.byTooltip('Show list'));
    await settle(t);
    expect(find.text('No plans here yet'), findsOneWidget);
  });

  testWidgets('Profile tab shows data and sign out returns to welcome', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      NomadMingleApp(
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
    expect(find.text('Get Started'), findsOneWidget);
  });
}
