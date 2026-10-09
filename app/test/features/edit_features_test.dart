import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/create/presentation/create_activity_controller.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';

import '../support/fakes.dart';

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('editing a plan', () {
    test('prefills every field from the existing activity', () {
      final a = sampleActivity(capacity: 9, approvalRequired: true);
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
        editing: a,
      );
      expect(c.isEditing, isTrue);
      expect(c.title, a.title);
      expect(c.capacity, 9);
      expect(c.approvalRequired, isTrue);
      expect(c.location, a.position);
      expect(c.category, 'food');
      expect(CreateActivityController.durations, contains(c.durationMinutes));
    });

    test('submit PATCHes the same id (does not create a new plan)', () async {
      final repo = FakeActivityRepository();
      final a = sampleActivity(id: 'abc');
      final c = CreateActivityController(repo, city: 'mumbai', editing: a);
      c.update(() => c.title = 'Renamed brunch plan');
      final saved = await c.submit();
      expect(saved?.title, 'Renamed brunch plan');
      expect(repo.updatedId, 'abc');
      expect(repo.updatedDraft?.title, 'Renamed brunch plan');
      expect(repo.createCalls, 0);
    });

    test(
      'an unchanged start time soon from now does not block other edits',
      () async {
        final soon = DateTime.now().add(const Duration(minutes: 10));
        final a = Activity.fromJson({
          'id': 'soon',
          'title': 'Starting very soon plan',
          'description': 'A description that is long enough.',
          'category': 'food',
          'hostId': 'h',
          'hostDisplayName': 'H',
          'city': 'mumbai',
          'venueName': 'Cafe',
          'latitude': 19.0,
          'longitude': 72.8,
          'startAt': soon.toUtc().toIso8601String(),
          'endAt': soon.add(const Duration(hours: 2)).toUtc().toIso8601String(),
          'capacity': 6,
          'participantCount': 1,
          'costType': 'free',
          'approvalRequired': false,
          'status': 'scheduled',
          'viewer': {'isHost': true},
        });
        final c = CreateActivityController(
          FakeActivityRepository(),
          city: 'mumbai',
          editing: a,
        );
        expect(c.validate().containsKey('startAt'), isFalse);
        // …but moving it to the past is still rejected.
        c.update(
          () => c.startAt = DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(c.validate().containsKey('startAt'), isTrue);
      },
    );

    test('creating (not editing) still enforces the 30-minute rule', () {
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
      );
      c.startAt = DateTime.now().add(const Duration(minutes: 10));
      expect(c.validate().containsKey('startAt'), isTrue);
    });
  });

  group('profile photo', () {
    const user = AuthUser(
      uid: 'u1',
      email: 'a@b.co',
      emailVerified: true,
      usesPassword: true,
    );
    const profile = UserProfile(
      uid: 'u1',
      displayName: 'Asha',
      city: 'pune',
      profileCompleted: true,
      photoUrl: 'https://example.com/old.jpg',
    );

    test('saving a newly uploaded photo sends its URL', () async {
      final repo = FakeProfileRepository(profile: profile);
      final s = SessionController(
        auth: FakeAuthRepository(user),
        profiles: repo,
      );
      await pump();
      await s.updateProfile(photoUrl: 'https://example.com/new.jpg');
      expect(repo.lastPhotoUrl, 'https://example.com/new.jpg');
      expect(repo.lastRemovePhoto, isFalse);
      expect(s.profile?.photoUrl, 'https://example.com/new.jpg');
      s.dispose();
    });

    test('removing the photo clears it', () async {
      final repo = FakeProfileRepository(profile: profile);
      final s = SessionController(
        auth: FakeAuthRepository(user),
        profiles: repo,
      );
      await pump();
      await s.updateProfile(removePhoto: true);
      expect(repo.lastRemovePhoto, isTrue);
      expect(s.profile?.photoUrl, isNull);
      s.dispose();
    });

    test('editing other fields leaves the photo untouched', () async {
      final repo = FakeProfileRepository(profile: profile);
      final s = SessionController(
        auth: FakeAuthRepository(user),
        profiles: repo,
      );
      await pump();
      await s.updateProfile(bio: 'New bio');
      expect(repo.lastPhotoUrl, isNull);
      expect(s.profile?.photoUrl, 'https://example.com/old.jpg');
      s.dispose();
    });
  });
}
