import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomad_mingle/core/services/image_upload_service.dart';
import 'package:nomad_mingle/features/activities/data/activity_repository.dart';
import 'package:nomad_mingle/features/activities/presentation/activity_detail_screen.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

Future<(SessionController, FakeActivityRepository)> pumpDetail(
  WidgetTester t, {
  required String? photoUrl,
}) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final repo = FakeActivityRepository([sampleActivity()]);
  final session = SessionController(
    auth: FakeAuthRepository(
      const AuthUser(uid: 'u1', email: 'a@b.co', emailVerified: true),
    ),
    profiles: FakeProfileRepository(
      profile: UserProfile(
        uid: 'u1',
        displayName: 'Asha',
        city: 'mumbai',
        photoUrl: photoUrl,
        profileCompleted: true,
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  final router = GoRouter(
    // Same as the real app: the router listens to the session, which
    // notifies when the profile (and so the photo) changes.
    refreshListenable: session,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ActivityDetailScreen(activityId: 'a1'),
      ),
    ],
  );
  await t.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ActivityRepository>.value(value: repo),
        Provider<ImageUploadService>.value(value: _Images()),
        ChangeNotifierProvider<SessionController>.value(value: session),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  return (session, repo);
}

void main() {
  testWidgets('joining without a photo asks for one first', (t) async {
    final (_, repo) = await pumpDetail(t, photoUrl: null);
    await t.tap(find.text('Join'));
    await t.pumpAndSettle();
    expect(find.text('Add a photo first'), findsOneWidget);
    expect(repo.joined, isEmpty);
    await t.tap(find.text('Add photo'));
    await t.pumpAndSettle();
    expect(find.text('Add a profile photo'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing); // standalone: no skip
  });

  testWidgets('adding the photo carries on with the join', (t) async {
    final (_, repo) = await pumpDetail(t, photoUrl: null);
    await t.tap(find.text('Join'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add photo'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('photo-tile')));
    await t.pumpAndSettle();
    await t.tap(find.text('Choose from gallery'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(repo.joined, ['a1']);
  });

  testWidgets('declining the photo prompt does not join', (t) async {
    final (_, repo) = await pumpDetail(t, photoUrl: null);
    await t.tap(find.text('Join'));
    await t.pumpAndSettle();
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(repo.joined, isEmpty);
  });

  testWidgets('members with a photo join straight away', (t) async {
    final (_, repo) = await pumpDetail(
      t,
      photoUrl: 'https://example.com/me.jpg',
    );
    await t.tap(find.text('Join'));
    await t.pumpAndSettle();
    expect(find.text('Add a photo first'), findsNothing);
    expect(repo.joined, ['a1']);
  });
}

class _Images implements ImageUploadService {
  @override
  Future<String?> pickAndUpload(
    String uid,
    ImageKind kind, {
    bool camera = false,
  }) async => 'https://example.com/me.jpg';
}
