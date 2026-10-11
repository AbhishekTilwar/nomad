import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../auth/application/session_controller.dart';

/// Shown while the session loads: the logo animates in on the brand
/// background, with a quiet progress line underneath.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    // Fixed brand background (the logo image carries its own light backdrop).
    backgroundColor: AppColors.sand,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const Align(
          alignment: BrandMark.restAlignment,
          child: BrandMark(width: 260, animate: true),
        ),
        // Quiet progress line near the bottom, where the welcome actions
        // will appear.
        Align(
          alignment: const Alignment(0, 0.82),
          child: SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: const LinearProgressIndicator(
                minHeight: 3,
                semanticsLabel: 'Loading',
                backgroundColor: AppColors.primaryLight,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ProfileLoadErrorScreen extends StatelessWidget {
  const ProfileLoadErrorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorState(
                title: 'Couldn\'t load your account',
                message: s.error,
                onRetry: s.loadProfile,
              ),
            ),
            TextButton(onPressed: s.signOut, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}

class RestrictedScreen extends StatelessWidget {
  const RestrictedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Expanded(
            child: EmptyState(
              icon: Icons.gpp_maybe_outlined,
              title: 'Account unavailable',
              message:
                  'This account has been suspended for breaking our community guidelines. Contact support if you think this is a mistake.',
            ),
          ),
          TextButton(
            onPressed: () => context.read<SessionController>().signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

/// Shown when the build is missing its configuration: Firebase values, or (in
/// release) the address of the Nomad Mingle server.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final firebaseOk = AppConfig.isConfigured;
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.settings_suggest_outlined,
          title: firebaseOk
              ? 'Server address isn\'t set'
              : 'Firebase isn\'t configured',
          message: firebaseOk
              ? 'This build was made without API_BASE_URL, so it would try to reach a server on this phone. Rebuild with --dart-define=API_BASE_URL=https://<your-api>/api/v1. See docs/RELEASE_BUILD.md.'
              : 'Run with --dart-define=USE_EMULATOR=true for local development, or pass the FIREBASE_* values for your project. See README.md.',
        ),
      ),
    );
  }
}

class StaticTextScreen extends StatelessWidget {
  const StaticTextScreen({super.key, required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
    ),
  );
}

const kGuidelinesText =
    '''Be kind. Nomad Mingle is for meeting real people in real places.

• Treat everyone with respect. No harassment, hate or threats.
• Meet in public places and tell a friend where you're going.
• No spam, advertising or scams. Don't ask for money.
• Keep chats text-only and on topic.
• Don't share anyone's personal information without permission.
• Report anything that makes you uncomfortable. You can also block anyone.

Breaking these rules may lead to removal of messages, temporary muting or a permanent suspension.''';

const kPrivacyPlaceholder =
    'The privacy policy has not been finalised. It must be reviewed by a qualified adviser before launch (see docs/LAUNCH_CHECKLIST.md).\n\nSummary of what the app does today: we store your profile, your date of birth (private, used only to check you are 18+), and your activity and chat data. Your exact location is never published.';

const kTermsPlaceholder =
    'The terms of service have not been finalised. They must be reviewed by a qualified adviser before launch (see docs/LAUNCH_CHECKLIST.md).';
