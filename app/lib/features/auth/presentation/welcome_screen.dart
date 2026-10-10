import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../onboarding/application/intro_store.dart';
import 'welcome_art.dart';

/// Splash-style landing: dusk skyline, brand, tagline and the two entry
/// actions.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.intro = const IntroStore()});

  final IntroStore intro;

  Future<void> _getStarted(BuildContext context) async {
    final seen = await intro.hasSeen();
    if (!context.mounted) return;
    context.push(seen ? '/register' : '/intro');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: kDuskGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 520,
              child: ExcludeSemantics(
                child: CustomPaint(painter: SkylinePainter()),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Semantics(
                          label: 'Nomad Mingle logo',
                          child: const CustomPaint(
                            size: Size(76, 96),
                            painter: PinMarkPainter(
                              inkColor: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nomad Mingle',
                          textAlign: TextAlign.center,
                          style: t.displaySmall?.copyWith(
                            color: Colors.white, // 32 / 700 per type scale
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Find your people.\nMake a plan. Go together.',
                          textAlign: TextAlign.center,
                          style: t.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const Spacer(flex: 5),
                        FilledButton(
                          onPressed: () => _getStarted(context),
                          child: const Text('Get Started'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.2,
                            ),
                          ),
                          onPressed: () => context.push('/sign-in'),
                          child: const Text('I already have an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
