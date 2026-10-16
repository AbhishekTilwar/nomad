import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomad_mingle/app/app.dart';
import 'package:nomad_mingle/core/services/image_upload_service.dart';
import 'package:nomad_mingle/core/services/location_service.dart';
import 'package:nomad_mingle/core/services/translation_service.dart';
import 'package:nomad_mingle/features/activities/data/my_activities_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/onboarding/application/intro_store.dart';
import 'package:nomad_mingle/features/shell/main_shell.dart';
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
  Future<LocationResult> currentIfPermitted() => current();

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
  Future<List<FriendEntry>> friends() async => const [];
  @override
  Future<List<FriendEntry>> friendRequests() async => const [];
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

/// Holds every plan list back until [gate] completes.
class _GatedMyActivities extends FakeMyActivitiesRepository {
  _GatedMyActivities(this.gate);
  final Future<void> gate;
  @override
  Future<MyActivitiesPage> list(
    MyActivitiesRole role, {
    String? cursor,
    int limit = 20,
  }) async {
    await gate;
    return super.list(role, cursor: cursor, limit: limit);
  }
}

late _Images _images;
late _Location _location;
late _Social _social;

Future<void> pumpSignedIn(
  WidgetTester t, {
  FakeMyActivitiesRepository? mine,
}) async {
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
      myActivities: mine ?? FakeMyActivitiesRepository(),
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

  testWidgets('bottom bar: Map, Chat, Profile only', (t) async {
    await pumpSignedIn(t);
    final bar = t.widget<FloatingNavBar>(find.byType(FloatingNavBar));
    expect(bar.items.map((i) => i.label), ['Map', 'Chat', 'Profile']);
  });

  testWidgets('map header: nearby pill, bell, list toggle, no community icon', (
    t,
  ) async {
    await pumpSignedIn(t);
    expect(find.byTooltip('Mingle Community'), findsNothing);
    expect(find.text('1 nearby'), findsOneWidget);
    expect(find.byKey(const ValueKey('view-toggle')), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    await t.tap(find.text('Browse'));
    await settle(t);
    expect(find.text('Map'), findsWidgets);
  });

  testWidgets('floating nav bar overlays content; map controls clear it', (
    t,
  ) async {
    await pumpSignedIn(t);
    final nav = t.getRect(find.byType(FloatingNavBar));
    final fab = t.getRect(find.byTooltip('Create a plan'));
    final toggle = t.getRect(find.byKey(const ValueKey('view-toggle')));
    expect(fab.bottom, lessThan(nav.top));
    expect(toggle.bottom, lessThan(nav.top));
    // The map extends underneath the bar (content visible behind it).
    final shell = t.getRect(find.byType(Scaffold).first);
    expect(nav.bottom, lessThanOrEqualTo(shell.bottom));
    final body = t.getRect(find.byType(FlutterMap));
    expect(body.bottom, greaterThan(nav.top));
  });

  testWidgets('map asks for location on open and has a + create button', (
    t,
  ) async {
    await pumpSignedIn(t);
    expect(_location.calls, greaterThanOrEqualTo(1));
    expect(find.byTooltip('Create a plan'), findsOneWidget);
    await t.tap(find.byTooltip('Create a plan'));
    await settle(t);
    // The + button opens the stepped "host a plan" drawer over the map.
    expect(find.text('Host a plan'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await settle(t);
    expect(find.text('Host a plan'), findsNothing);
    expect(find.byTooltip('Create a plan'), findsOneWidget);
  });

  testWidgets('chat tab pins Mingle Community; tab switching works', (t) async {
    await pumpSignedIn(t);
    await t.tap(find.byKey(const ValueKey('nav-Chat')));
    await settle(t);
    expect(find.text('Mingle Community'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-Profile')));
    await settle(t);
    expect(find.text('Asha Rao'), findsWidgets);
    expect(find.text('@asha_r'), findsOneWidget);
    expect(find.text('My plans'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-Map')));
    await settle(t);
    expect(find.byTooltip('Create a plan'), findsOneWidget);
  });

  testWidgets('chats: filters and Community show while plans still load', (
    t,
  ) async {
    final gate = Completer<void>();
    await pumpSignedIn(t, mine: _GatedMyActivities(gate.future));
    await t.tap(find.byKey(const ValueKey('nav-Chat')));
    await t.pump(const Duration(milliseconds: 300));
    // Plans are still loading: skeleton rows, but the static UI is real.
    expect(find.bySemanticsLabel('Loading chats'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Mingle Community'), findsOneWidget);
    gate.complete();
    await settle(t);
    expect(find.bySemanticsLabel('Loading chats'), findsNothing);
    expect(find.text('Mingle Community'), findsOneWidget);
  });

  testWidgets('chats: filters, search and the + invite button', (t) async {
    await pumpSignedIn(t);
    await t.tap(find.byKey(const ValueKey('nav-Chat')));
    await settle(t);
    // Filter chips: Plans hides the pinned community chat, All brings it back.
    expect(find.text('Unread'), findsOneWidget);
    await t.tap(find.text('Plans'));
    await settle(t);
    expect(find.text('Mingle Community'), findsNothing);
    await t.tap(find.text('All'));
    await settle(t);
    expect(find.text('Mingle Community'), findsOneWidget);
    // Search narrows the list.
    await t.tap(find.byKey(const ValueKey('chats-search')));
    await settle(t);
    await t.enterText(find.byType(TextField), 'zzz');
    await settle(t);
    expect(find.text('Mingle Community'), findsNothing);
    expect(find.text('No matching chats'), findsOneWidget);
    await t.tap(find.byTooltip('Close search'));
    await settle(t);
    // + opens Invite friends.
    await t.tap(find.byKey(const ValueKey('chats-invite')));
    await settle(t);
    expect(find.text('Invite friends'), findsWidgets);
    expect(find.text('Share on WhatsApp'), findsOneWidget);
  });

  testWidgets('map header: travelers sheet lists nearby members', (t) async {
    await pumpSignedIn(t);
    await t.tap(find.text('1 nearby'));
    await settle(t);
    expect(find.text('Ivan K'), findsOneWidget);
    expect(find.text('Show me here'), findsOneWidget);
  });

  testWidgets('bottom sheets cover the floating nav bar, not sit under it', (
    t,
  ) async {
    await pumpSignedIn(t);
    await t.tap(find.text('1 nearby'));
    await settle(t);
    expect(find.text('Show me here'), findsOneWidget);
    // The sheet is above the bar, so a tap where the bar's Chat tab is lands
    // on the sheet: it stays open and no tab switch happens behind it.
    await t.tap(find.byKey(const ValueKey('nav-Chat')), warnIfMissed: false);
    await settle(t);
    expect(find.text('Show me here'), findsOneWidget);
    expect(find.byKey(const ValueKey('chats-invite')), findsNothing);
  });

  testWidgets('map stays clear of per-plan banners, even with plans joined', (
    t,
  ) async {
    final mine = FakeMyActivitiesRepository()
      ..byRole[MyActivitiesRole.joined] = [
        MyActivity(
          activity: sampleActivity(
            id: 'later',
            title: 'Later hike',
            membership: MembershipStatus.approved,
          ),
        ),
        MyActivity(
          activity: sampleActivity(
            id: 'other',
            title: 'Other walk',
            membership: MembershipStatus.approved,
          ),
        ),
      ];
    await pumpSignedIn(t, mine: mine);
    expect(find.textContaining('Later hike'), findsNothing);
    expect(find.textContaining('Other walk'), findsNothing);
    expect(find.byIcon(Icons.event_available), findsNothing);
  });

  testWidgets('routes: every screen builds without errors', (t) async {
    await pumpSignedIn(t);
    final routes = <String, String?>{
      '/explore': null,
      '/chats': null,
      '/profile': 'My plans',
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
      '/explore/create': 'Create a Plan',
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
