import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../auth/application/session_controller.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
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

/// Shown when Firebase isn't configured (no dart-defines and no emulator flag).
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: EmptyState(
        icon: Icons.settings_suggest_outlined,
        title: 'Firebase isn\'t configured',
        message:
            'Run with --dart-define=USE_EMULATOR=true for local development, or pass the FIREBASE_* values for your project. See README.md.',
      ),
    ),
  );
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
