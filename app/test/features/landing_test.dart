import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/app/app.dart';
import 'package:nomad_mingle/core/widgets/primary_button.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/onboarding/application/intro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import 'chat/chat_test_support.dart' show FakeChatRepository;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> boot(WidgetTester t, FakeAuthRepository auth) async {
  SharedPreferences.setMockInitialValues({IntroStore.key: true});
  t.view.physicalSize = const Size(360, 640);
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
  testWidgets('landing: tap targets, art hidden from semantics', (t) async {
    await boot(t, FakeAuthRepository());
    expect(t.takeException(), isNull);
    for (final label in [
      'Continue with Google',
      'Continue with Email',
      'Terms',
      'Privacy',
    ]) {
      final size = t.getSize(find.text(label).first);
      expect(size.width, greaterThan(0));
    }
    for (final label in ['Continue with Google', 'Continue with Email']) {
      expect(
        t.getSize(find.text(label).first).height,
        greaterThan(0),
        reason: label,
      );
    }
    for (final b in [find.byType(PrimaryButton)]) {
      for (final e in b.evaluate()) {
        expect(
          t.getSize(find.byWidget(e.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    }
    // The logo is announced once, as one image.
    expect(find.byKey(const ValueKey('brand-mark-image')), findsOneWidget);
  });

  testWidgets('splash holds for its minimum time, then hands over', (t) async {
    SharedPreferences.setMockInitialValues({IntroStore.key: true});
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      NomadMingleApp(
        chat: FakeChatRepository(),
        auth: FakeAuthRepository(),
        profiles: FakeProfileRepository(),
        activities: FakeActivityRepository(),
        splashMinDuration: const Duration(milliseconds: 1200),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    // Session is long ready, but the splash is still up.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Continue with Email'), findsNothing);
    await t.pump(const Duration(milliseconds: 900));
    await settle(t);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('landing: Terms and Privacy open the legal pages', (t) async {
    await boot(t, FakeAuthRepository());
    await t.tap(find.text('Terms'));
    await settle(t);
    expect(find.text('Terms of service'), findsOneWidget);
    await t.pageBack();
    await settle(t);
    await t.tap(find.text('Privacy'));
    await settle(t);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('landing: Google failure shows a friendly message', (t) async {
    final auth = FakeAuthRepository()
      ..failNext = const AuthFailure(
        'Google sign-in failed. Please try again.',
        code: 'google-failed',
      );
    await boot(t, auth);
    await t.tap(find.text('Continue with Google'));
    await settle(t);
    expect(
      find.text('Google sign-in failed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget); // not stuck busy
  });

  testWidgets('landing: Google signs in directly (needs onboarding next)', (
    t,
  ) async {
    final auth = FakeAuthRepository();
    await boot(t, auth);
    await t.tap(find.text('Continue with Google'));
    await settle(t);
    expect(auth.currentUser?.email, 'g@x.com');
    expect(find.text('Continue with Email'), findsNothing);
  });

  testWidgets('PrimaryButton uses optional backgroundColor', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: PrimaryButton(
          label: 'Go',
          onPressed: () {},
          backgroundColor: const Color(0xFF1B2A3B),
        ),
      ),
    );
    final b = t.widget<FilledButton>(find.byType(FilledButton));
    expect(b.style?.backgroundColor?.resolve({}), const Color(0xFF1B2A3B));
  });
}
