import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomad_mingle/app/app.dart';
import 'package:nomad_mingle/core/services/image_upload_service.dart';
import 'package:nomad_mingle/core/services/location_service.dart';
import 'package:nomad_mingle/core/services/translation_service.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/onboarding/application/intro_store.dart';
import 'package:nomad_mingle/features/profile/data/public_profile.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';
import 'package:nomad_mingle/features/social/data/social_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import 'chat/chat_test_support.dart'
    show FakeChatRepository, FakeMyActivitiesRepository, FakeSafetyRepository;

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
  bio: 'Hi there',
  instagram: 'asha_r',
  interests: ['food', 'hiking'],
  profileCompleted: true,
  photos: ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
);

class _Images implements ImageUploadService {
  final kinds = <ImageKind>[];
  @override
  Future<String?> pickAndUpload(
    String uid,
    ImageKind kind, {
    bool camera = false,
  }) async {
    kinds.add(kind);
    return 'https://example.com/new${kinds.length}.jpg';
  }
}

class _Location implements LocationService {
  int calls = 0;
  @override
  Future<LocationResult> current() async {
    calls++;
    return LocationResult(
      LocationOutcome.granted,
      const LatLng(18.5204, 73.8567),
    );
  }

  @override
  Future<void> openSettings() async {}
}

class _Translate implements TranslationService {
  @override
  Future<TranslationResult> translate(
    String text, {
    String? targetLanguage,
  }) async => TranslationResult('translated: $text', sourceLanguage: 'fr');
}

class _Social implements SocialRepository {
  final sent = <String>[];
  @override
  Future<Friendship> sendFriendRequest(String uid) async {
    sent.add(uid);
    return Friendship.requestSent;
  }

  @override
  Future<void> acceptFriendRequest(String uid) async {}
  @override
  Future<void> removeFriend(String uid) async {}
  @override
  Future<List<Traveler>> travelers({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async => const [
    Traveler(
      uid: 'trav1',
      displayName: 'Ivan K',
      countryCode: 'NZ',
      distanceKm: 7,
    ),
  ];
  @override
  Future<void> setLocation({
    required double lat,
    required double lng,
    required bool discoverable,
  }) async {}
}

class _PublicProfiles implements PublicProfileRepository {
  @override
  Future<PublicProfile> fetch(String uid) async => PublicProfile(
    uid: uid,
    displayName: 'Sarah Johnson',
    city: 'mumbai',
    ageRange: '25-34',
    countryCode: 'GB',
    instagram: 'sarahj',
    emailVerified: true,
    interests: const ['hiking', 'food'],
    bio: 'Digital nomad.',
    photos: const ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
  );
}

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

late _Images _images;
late _Location _location;
late _Social _social;

Future<void> pumpSignedIn(WidgetTester t) async {
  usePhone(t);
  _images = _Images();
  _location = _Location();
  _social = _Social();
  await t.pumpWidget(
    NomadMingleApp(
      chat: FakeChatRepository(),
      auth: FakeAuthRepository(_user),
      profiles: FakeProfileRepository(profile: _profile),
      activities: FakeActivityRepository([sampleActivity()]),
      myActivities: FakeMyActivitiesRepository(),
      publicProfiles: _PublicProfiles(),
      safety: FakeSafetyRepository(),
      images: _images,
      location: _location,
      translation: _Translate(),
      social: _social,
    ),
  );
  await settle(t);
}

GoRouter routerOf(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(Scaffold).first));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({IntroStore.key: true}));

  testWidgets('bottom bar: Map, Chat, Notifications, Profile (no Create)', (
    t,
  ) async {
    await pumpSignedIn(t);
    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.map((d) => (d as NavigationDestination).label), [
      'Map',
      'Chat',
      'Notifications',
      'Profile',
    ]);
  });

  testWidgets('map asks for location on open and has a + create button', (
    t,
  ) async {
    await pumpSignedIn(t);
    expect(_location.calls, greaterThanOrEqualTo(1));
    expect(find.byTooltip('Create a plan'), findsOneWidget);
    await t.tap(find.byTooltip('Create a plan'));
    await settle(t);
    expect(find.text('Create a Meetup'), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    await settle(t);
    expect(find.byTooltip('Create a plan'), findsOneWidget);
  });

  testWidgets('chat tab pins Mingle Community; tab switching works', (t) async {
    await pumpSignedIn(t);
    await t.tap(find.text('Chat'));
    await settle(t);
    expect(find.text('Mingle Community'), findsOneWidget);
    await t.tap(find.text('Profile'));
    await settle(t);
    expect(find.text('Asha Rao'), findsWidgets);
    expect(find.text('@asha_r'), findsOneWidget);
    expect(find.text('My Photos'), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-photo-0')), findsOneWidget);
    await t.tap(find.text('Map'));
    await settle(t);
    expect(find.byTooltip('Create a plan'), findsOneWidget);
  });

  testWidgets('map header: travelers sheet lists nearby members', (t) async {
    await pumpSignedIn(t);
    await t.tap(find.byTooltip('Travelers nearby'));
    await settle(t);
    expect(find.text('Ivan K'), findsOneWidget);
    expect(find.text('Show me here'), findsOneWidget);
  });

  testWidgets('routes: every screen builds without errors', (t) async {
    await pumpSignedIn(t);
    final routes = <String, String?>{
      '/explore': null,
      '/chats': null,
      '/profile': 'My Photos',
      '/profile/edit': 'Photos',
      '/profile/notifications': null,
      '/profile/blocked': null,
      '/memories': 'Memories',
      '/settings': null,
      '/location': null,
      '/safety': null,
      '/legal/guidelines': null,
      '/legal/privacy': null,
      '/legal/terms': null,
      '/community': null,
      '/user/other': 'Sarah Johnson',
      '/activity/a1': null,
      '/explore/create': 'Create a Meetup',
    };
    for (final e in routes.entries) {
      routerOf(t).go(e.key);
      await settle(t);
      expect(t.takeException(), isNull, reason: 'route ${e.key}');
      expect(find.byType(Scaffold), findsWidgets, reason: 'route ${e.key}');
      if (e.value != null) {
        expect(find.text(e.value!), findsWidgets, reason: 'route ${e.key}');
      }
    }
  });

  testWidgets(
    'public profile: cover/photos strip, flag, instagram, add friend',
    (t) async {
      await pumpSignedIn(t);
      routerOf(t).go('/user/other');
      await settle(t);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.byKey(const ValueKey('gallery-photo-1')), findsOneWidget);
      expect(find.text('@sarahj'), findsOneWidget);
      expect(find.text('Add Friend'), findsOneWidget);
      await t.tap(find.text('Add Friend'));
      await settle(t);
      expect(_social.sent, ['other']);
      await t.tap(find.byKey(const ValueKey('gallery-photo-0')));
      await settle(t);
      expect(find.text('1 / 2'), findsOneWidget);
    },
  );

  testWidgets('edit profile: add a gallery photo and save it', (t) async {
    await pumpSignedIn(t);
    routerOf(t).go('/profile/edit');
    await settle(t);
    expect(find.byKey(const ValueKey('edit-photo-1')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('add-gallery-photo')));
    await t.tap(find.byKey(const ValueKey('add-gallery-photo')));
    await settle(t);
    await t.tap(find.text('Choose from gallery'));
    await settle(t);
    expect(_images.kinds, [ImageKind.gallery]);
    expect(find.byKey(const ValueKey('edit-photo-2')), findsOneWidget);
  });
}
