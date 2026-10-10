import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../features/activities/data/activity_repository.dart';
import '../features/activities/models/activity.dart';
import '../features/create/presentation/create_activity_screen.dart';
import '../features/create/presentation/location_picker_screen.dart';
import '../features/explore/presentation/explore_controller.dart';

import '../features/activities/presentation/activity_detail_screen.dart';
import '../features/activities/presentation/manage_members_screen.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/explore/presentation/explore_screen.dart';
import '../features/onboarding/presentation/intro_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/memories_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/notifications_screen.dart';
import '../features/settings/settings_screens.dart';
import '../features/onboarding/presentation/add_photo_screen.dart';
import '../features/profile/presentation/public_profile_screen.dart';
import '../features/chat/presentation/activity_chat_screen.dart';
import '../features/chat/presentation/chats_list_screen.dart';
import '../features/chat/presentation/community_chat_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/shell/status_screens.dart';

/// Pure redirect rule, exported for unit tests.
String? redirectFor(SessionStatus status, String location) {
  const publicAuth = {
    '/welcome',
    '/intro',
    '/sign-in',
    '/register',
    '/forgot-password',
  };
  final isLegal = location.startsWith('/legal/');
  switch (status) {
    case SessionStatus.initializing:
    case SessionStatus.loadingProfile:
      return location == '/splash' ? null : '/splash';
    case SessionStatus.signedOut:
      return (publicAuth.contains(location) || isLegal) ? null : '/welcome';
    case SessionStatus.needsEmailVerification:
      return location == '/verify-email' ? null : '/verify-email';
    case SessionStatus.needsOnboarding:
      return location == '/onboarding' ? null : '/onboarding';
    case SessionStatus.needsPhoto:
      return location == '/add-photo' ? null : '/add-photo';
    case SessionStatus.profileError:
      return location == '/profile-error' ? null : '/profile-error';
    case SessionStatus.restricted:
      return location == '/restricted' ? null : '/restricted';
    case SessionStatus.ready:
      const gate = {
        '/splash',
        '/welcome',
        '/intro',
        '/sign-in',
        '/register',
        '/forgot-password',
        '/verify-email',
        '/onboarding',
        '/add-photo',
        '/profile-error',
        '/restricted',
      };
      return gate.contains(location) ? '/explore' : null;
  }
}

GoRouter buildRouter(
  SessionController session, {
  String initialLocation = '/splash',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: session,
    redirect: (_, state) => redirectFor(session.status, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailScreen(),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/profile-error',
        builder: (_, _) => const ProfileLoadErrorScreen(),
      ),
      GoRoute(path: '/restricted', builder: (_, _) => const RestrictedScreen()),
      GoRoute(
        path: '/legal/guidelines',
        builder: (_, _) => const StaticTextScreen(
          title: 'Community guidelines',
          body: kGuidelinesText,
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const StaticTextScreen(
          title: 'Privacy policy',
          body: kPrivacyPlaceholder,
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const StaticTextScreen(
          title: 'Terms of service',
          body: kTermsPlaceholder,
        ),
      ),
      GoRoute(
        path: '/create/pick-location',
        builder: (_, s) => LocationPickerScreen(initial: s.extra! as LatLng),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (_, _) => const NotificationPrefsScreen(),
      ),
      // Opened from the bell on the map (no longer a tab).
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/memories', builder: (_, _) => const MemoriesScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/location',
        builder: (_, _) => const LocationSwitchScreen(),
      ),
      GoRoute(path: '/safety', builder: (_, _) => const SafetyScreen()),
      GoRoute(
        path: '/profile/blocked',
        builder: (_, _) => const BlockedUsersScreen(),
      ),
      GoRoute(path: '/add-photo', builder: (_, _) => const AddPhotoScreen()),
      GoRoute(
        path: '/user/:uid',
        builder: (_, s) {
          final extra = (s.extra as Map?)?.cast<String, dynamic>();
          return PublicProfileScreen(
            uid: s.pathParameters['uid']!,
            fallbackName: extra?['name'] as String?,
            fallbackPhotoUrl: extra?['photoUrl'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/community',
        builder: (_, _) => const CommunityChatScreen(),
      ),
      GoRoute(
        path: '/activity/:id',
        builder: (_, s) =>
            ActivityDetailScreen(activityId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, s) =>
                CreateActivityScreen(editing: s.extra! as Activity),
          ),
          GoRoute(
            path: 'chat',
            builder: (_, s) =>
                ActivityChatScreen(activityId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'members',
            builder: (_, s) =>
                ManageMembersScreen(activityId: s.pathParameters['id']!),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => ChangeNotifierProvider(
          // Scoped to the signed-in shell so state never outlives the session.
          create: (_) => ExploreController(
            context.read<ActivityRepository>(),
            initialCity:
                context.read<SessionController>().profile?.city ?? 'mumbai',
          ),
          child: MainShell(shell: shell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (_, _) => const ExploreScreen(),
                routes: [
                  // Opened from the map's + button. Lives under /explore so it
                  // shares the shell's ExploreController (new plans appear on
                  // the map immediately).
                  GoRoute(
                    path: 'create',
                    builder: (_, _) => const CreateActivityScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (_, _) => const ChatsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
