import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/services/image_upload_service.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/onboarding/presentation/add_photo_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

class FakeImages implements ImageUploadService {
  String? url = 'https://example.com/me.jpg';
  Object? error;
  final calls = <({ImageKind kind, bool camera})>[];
  @override
  Future<String?> pickAndUpload(
    String uid,
    ImageKind kind, {
    bool camera = false,
  }) async {
    calls.add((kind: kind, camera: camera));
    if (error != null) throw error!;
    return url;
  }
}

Future<(FakeImages, SessionController, FakeProfileRepository)> pumpScreen(
  WidgetTester t,
) async {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final images = FakeImages();
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
  // Real async work (stream + shared_preferences) must run outside FakeAsync.
  await t.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
    await session.completeOnboarding(
      displayName: 'Asha',
      dateOfBirth: DateTime(1998, 1, 1),
      city: 'pune',
      bio: '',
      interests: ['food'],
      preferredActivityTypes: const [],
    );
  });
  await t.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ImageUploadService>.value(value: images),
        ChangeNotifierProvider<SessionController>.value(value: session),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const AddPhotoScreen()),
    ),
  );
  return (images, session, repo);
}

Future<void> choose(WidgetTester t, String option) async {
  await t.tap(find.byKey(const Key('photo-tile')));
  await t.pumpAndSettle();
  await t.tap(find.text(option));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Take photo uses the camera, saves the URL to the profile, then Continue leaves the step',
    (t) async {
      final (images, session, repo) = await pumpScreen(t);
      expect(session.status, SessionStatus.needsPhoto);
      await choose(t, 'Take photo');
      await t.pumpAndSettle();
      expect(images.calls.single, (kind: ImageKind.avatar, camera: true));
      expect(repo.lastPhotoUrl, 'https://example.com/me.jpg');
      expect(find.text('Looking good!'), findsOneWidget);
      await t.tap(find.text('Continue'));
      await t.pump();
      expect(session.status, SessionStatus.needsProfileExtras);
    },
  );

  testWidgets('Choose from gallery uses the gallery', (t) async {
    final (images, _, _) = await pumpScreen(t);
    await choose(t, 'Choose from gallery');
    await t.pumpAndSettle();
    expect(images.calls.single.camera, isFalse);
  });

  testWidgets('onboarding: the photo can be skipped for now', (t) async {
    final (images, session, _) = await pumpScreen(t);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(images.calls, isEmpty);
    expect(session.status, SessionStatus.needsPhoto);
    await t.tap(find.text('Skip for now'));
    await t.pump();
    expect(session.status, SessionStatus.needsProfileExtras);
    expect(session.profile?.photoUrl, isNull);
  });

  testWidgets('Skip disappears once a photo is chosen', (t) async {
    await pumpScreen(t);
    await choose(t, 'Take photo');
    await t.pumpAndSettle();
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('first photo also seeds the gallery', (t) async {
    final (_, _, repo) = await pumpScreen(t);
    await choose(t, 'Take photo');
    await t.pumpAndSettle();
    expect(repo.profile!.photos, ['https://example.com/me.jpg']);
  });

  testWidgets('upload failure shows the message and keeps the step open', (
    t,
  ) async {
    final (images, session, _) = await pumpScreen(t);
    images.error = const AppException(
      'That photo is too large. Pick one under 5 MB.',
    );
    await choose(t, 'Choose from gallery');
    await t.pumpAndSettle();
    expect(find.textContaining('too large'), findsOneWidget);
    expect(session.status, SessionStatus.needsPhoto);
  });
}
