import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/app/app.dart';
import 'package:nomad_mingle/features/onboarding/application/intro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import 'chat/chat_test_support.dart' show FakeChatRepository;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> boot(WidgetTester t, FakeAuthRepository auth) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    NomadMingleApp(
      chat: FakeChatRepository(),
      auth: auth,
      profiles: FakeProfileRepository(),
      activities: FakeActivityRepository(),
    ),
  );
  await settle(t);
}

void main() {
  group('intro flag', () {
    test('defaults to unseen and persists once marked', () async {
      SharedPreferences.setMockInitialValues({});
      const store = IntroStore();
      expect(await store.hasSeen(), isFalse);
      await store.markSeen();
      expect(await store.hasSeen(), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(IntroStore.key),
        isTrue,
      );
    });
  });

  testWidgets(
    'first run: landing forwards to intro; Next x2 then Get Started',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      await boot(t, FakeAuthRepository());
      expect(find.text('Find Your People'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      await t.tap(find.text('Next'));
      await settle(t);
      expect(find.text('Make a Plan'), findsOneWidget);
      await t.tap(find.text('Next'));
      await settle(t);
      expect(find.text('Go Together'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Get Started'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Get Started'));
      await settle(t);
      expect(find.text('Continue with Email'), findsOneWidget);
      expect(await const IntroStore().hasSeen(), isTrue);
    },
  );

  testWidgets('intro pages can be swiped', (t) async {
    SharedPreferences.setMockInitialValues({});
    await boot(t, FakeAuthRepository());
    await t.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await settle(t);
    expect(find.text('Make a Plan'), findsOneWidget);
  });

  testWidgets('Skip marks intro seen and goes to landing', (t) async {
    SharedPreferences.setMockInitialValues({});
    await boot(t, FakeAuthRepository());
    await t.tap(find.text('Skip'));
    await settle(t);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(await const IntroStore().hasSeen(), isTrue);
  });

  testWidgets('intro is skipped once seen', (t) async {
    SharedPreferences.setMockInitialValues({IntroStore.key: true});
    await boot(t, FakeAuthRepository());
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Find Your People'), findsNothing);
    await t.tap(find.text('Continue with Email'));
    await settle(t);
    expect(find.text('Welcome back'), findsOneWidget);
    await t.tap(find.text('Sign Up'));
    await settle(t);
    expect(find.text('Create Your Account'), findsOneWidget);
  });

  group('sign up', () {
    Future<void> open(WidgetTester t, FakeAuthRepository auth) async {
      SharedPreferences.setMockInitialValues({IntroStore.key: true});
      await boot(t, auth);
      await t.tap(find.text('Continue with Email'));
      await settle(t);
      await t.tap(find.text('Sign Up'));
      await settle(t);
    }

    testWidgets('shows validation errors on an empty form', (t) async {
      await open(t, FakeAuthRepository());
      await t.tap(find.text('Create Account'));
      await settle(t);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
    });

    testWidgets('rejects a short password', (t) async {
      final auth = FakeAuthRepository();
      await open(t, auth);
      await t.enterText(find.byKey(const ValueKey('signup-email')), 'a@b.co');
      await t.enterText(find.byKey(const ValueKey('signup-password')), 'short');
      await t.tap(find.text('Create Account'));
      await settle(t);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('asks only for credentials; profile comes from onboarding', (
      t,
    ) async {
      await open(t, FakeAuthRepository());
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Date of birth'), findsNothing);
      expect(find.text('Select Location'), findsNothing);
      expect(find.textContaining('Interests'), findsNothing);
    });

    testWidgets('valid credentials register and go to email verification', (
      t,
    ) async {
      final auth = FakeAuthRepository();
      await open(t, auth);
      await t.enterText(find.byKey(const ValueKey('signup-email')), 'a@b.co');
      await t.enterText(
        find.byKey(const ValueKey('signup-password')),
        'longenough1',
      );
      await t.tap(find.text('Create Account'));
      await settle(t);
      expect(auth.currentUser?.email, 'a@b.co');
      expect(find.text('Verify your email'), findsOneWidget);
    });
  });

  testWidgets('auth screens lay out on a small phone without overflow', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await boot(t, FakeAuthRepository());
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    await settle(t);
    expect(t.takeException(), isNull);
    for (final label in ['Next', 'Next', 'Get Started']) {
      await t.tap(find.text(label));
      await settle(t);
      expect(t.takeException(), isNull);
    }
    expect(find.text('Continue with Email'), findsOneWidget);
    await t.tap(find.text('Continue with Email'));
    await settle(t);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('Forgot password?'));
    await settle(t);
    expect(find.text('Reset Password'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pageBack();
    await settle(t);
    await t.tap(find.text('Sign Up'));
    await settle(t);
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
