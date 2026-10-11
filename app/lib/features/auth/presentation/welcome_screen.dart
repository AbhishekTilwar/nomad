import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../onboarding/application/intro_store.dart';
import 'google_sign_in_button.dart';
import 'welcome_backdrop.dart';

/// Landing screen: the logo on the brand background with the two entry
/// actions beneath it. On a first launch it forwards to the intro
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
      // Fixed brand background: the logo image carries its own light backdrop.
      backgroundColor: AppColors.sand,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _ready
              ? _Content(googleBusy: _googleBusy, onBusy: _setBusy)
              : const SizedBox.expand(),
        ),
      ),
    );
  }

  void _setBusy(bool v) {
    if (mounted) setState(() => _googleBusy = v);
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.googleBusy, required this.onBusy});

  final bool googleBusy;
  final ValueChanged<bool> onBusy;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      // Let the logo's hand-over from the splash land first, then bring in
      // the actions.
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reveal = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Stack(
      fit: StackFit.expand,
      children: [
        const WelcomeBackdrop(),
        // Same spot as on the splash (both relative to the full screen), so
        // the hand-over keeps the logo still.
        const Align(
          alignment: BrandMark.restAlignment,
          child: BrandMark(width: 260),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: FadeTransition(
                opacity: reveal,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(reveal),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GoogleSignInButton(onBusyChanged: widget.onBusy),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Continue with Email',
                        onPressed: widget.googleBusy
                            ? null
                            : () => context.push('/sign-in'),
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
      ],
    );
  }
}

class _LegalCaption extends StatelessWidget {
  const _LegalCaption();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted, fontSize: 12);
    final link = base?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.ink,
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
