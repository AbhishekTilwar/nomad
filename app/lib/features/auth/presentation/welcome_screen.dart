import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../onboarding/application/intro_store.dart';
import 'google_sign_in_button.dart';
import 'scenes/hero_scene.dart';

/// Landing screen: full-bleed lake-at-dusk scene, brand lock-up, tagline and
/// the two entry actions. On a first launch it forwards to the intro
/// carousel (which returns here when finished).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.intro = const IntroStore()});

  final IntroStore intro;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _ready = false;
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    _checkIntro();
  }

  Future<void> _checkIntro() async {
    final seen = await widget.intro.hasSeen();
    if (!mounted) return;
    if (seen) {
      setState(() => _ready = true);
    } else {
      context.go('/intro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const HeroScene(kind: HeroSceneKind.lakeDusk),
              // Darken the sky slightly so the white logo always reads.
              const ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              if (_ready) _Content(googleBusy: _googleBusy, onBusy: _setBusy),
            ],
          ),
        ),
      ),
    );
  }

  void _setBusy(bool v) {
    if (mounted) setState(() => _googleBusy = v);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.googleBusy, required this.onBusy});

  final bool googleBusy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(size: 44, onDark: true)),
                    const SizedBox(height: 12),
                    Text(
                      'New places. New people.\nSame sky.',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    GoogleSignInButton(onWhite: true, onBusyChanged: onBusy),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        side: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      onPressed: googleBusy
                          ? null
                          : () => context.push('/sign-in'),
                      child: const Text('Continue with Email'),
                    ),
                    const SizedBox(height: 4),
                    const _LegalCaption(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalCaption extends StatelessWidget {
  const _LegalCaption();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 12);
    final link = base?.copyWith(
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
    );
    Widget tap(String label, String route) => InkWell(
      onTap: () => context.push(route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Center(widthFactor: 1, child: Text(label, style: link)),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing, you agree to our ', style: base),
        tap('Terms', '/legal/terms'),
        Text(' & ', style: base),
        tap('Privacy', '/legal/privacy'),
      ],
    );
  }
}
