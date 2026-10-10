import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/theme/app_theme.dart';
import '../features/activities/data/activity_repository.dart';
import '../core/services/image_upload_service.dart';
import '../core/services/location_service.dart';
import '../core/services/translation_service.dart';
import '../features/social/data/social_repository.dart';
import '../features/auth/application/session_controller.dart';
import '../features/safety/data/safety_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/public_profile.dart';
import 'router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/activities/data/my_activities_repository.dart';
import '../features/chat/application/chat_read_store.dart';
import '../features/chat/application/community_unread_controller.dart';
import '../features/chat/data/chat_repository.dart';

/// Wires repositories and controllers. Tests can inject fakes through the
/// constructor parameters.
class NomadMingleApp extends StatefulWidget {
  const NomadMingleApp({
    super.key,
    required this.auth,
    this.profiles,
    this.activities,
    this.safety,
    this.location,
    this.images,
    this.chat,
    this.myActivities,
    this.publicProfiles,
    this.translation,
    this.social,
  });

  final AuthRepository auth;
  final ProfileRepository? profiles;
  final ActivityRepository? activities;
  final SafetyRepository? safety;
  final LocationService? location;
  final ImageUploadService? images;
  final ChatRepository? chat;
  final MyActivitiesRepository? myActivities;
  final PublicProfileRepository? publicProfiles;
  final TranslationService? translation;
  final SocialRepository? social;

  @override
  State<NomadMingleApp> createState() => _NomadMingleAppState();
}

class _NomadMingleAppState extends State<NomadMingleApp> {
  late final ApiClient _api = ApiClient(
    tokenProvider: ({bool forceRefresh = false}) =>
        widget.auth.idToken(forceRefresh: forceRefresh),
  );
  late final ProfileRepository _profiles =
      widget.profiles ?? ApiProfileRepository(_api);
  late final ActivityRepository _activities =
      widget.activities ?? ApiActivityRepository(_api);
  late final SessionController _session = SessionController(
    auth: widget.auth,
    profiles: _profiles,
  );
  late final GoRouter _router = buildRouter(_session);

  @override
  void dispose() {
    _session.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: widget.auth),
        Provider<ApiClient>.value(value: _api),
        Provider<ActivityRepository>.value(value: _activities),
        Provider<PublicProfileRepository>(
          create: (ctx) =>
              widget.publicProfiles ??
              ApiPublicProfileRepository(ctx.read<ApiClient>()),
        ),
        Provider<TranslationService>.value(
          value: widget.translation ?? MlKitTranslationService(),
        ),
        Provider<SocialRepository>.value(
          value: widget.social ?? ApiSocialRepository(_api),
        ),
        Provider<SafetyRepository>.value(
          value: widget.safety ?? ApiSafetyRepository(_api),
        ),
        Provider<LocationService>.value(
          value: widget.location ?? GeolocatorLocationService(),
        ),
        // Lazy: constructing the real service touches Firebase Storage.
        Provider<ImageUploadService>(
          create: (_) => widget.images ?? FirebaseImageUploadService(),
        ),
        ChangeNotifierProvider<SessionController>.value(value: _session),
        // Chat providers sit above the router: /community and
        // /activity/:id/chat are top-level routes layered over the shell.
        Provider<ChatRepository>(
          create: (ctx) =>
              widget.chat ??
              FirestoreChatRepository(
                firestore: FirebaseFirestore.instance,
                api: ctx.read<ApiClient>(),
              ),
        ),
        Provider<MyActivitiesRepository>(
          create: (ctx) =>
              widget.myActivities ??
              ApiMyActivitiesRepository(ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<ChatReadStore>(
          create: (ctx) =>
              ChatReadStore(uid: () => ctx.read<SessionController>().user?.uid),
        ),
        ChangeNotifierProvider<CommunityUnreadController>(
          create: (ctx) => CommunityUnreadController(
            repository: ctx.read<ChatRepository>(),
            store: ctx.read<ChatReadStore>(),
            uid: () => ctx.read<SessionController>().user?.uid,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Nomad Mingle',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _router,
      ),
    );
  }
}
