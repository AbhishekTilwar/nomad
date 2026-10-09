import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../auth/presentation/welcome_art.dart';
import '../application/intro_store.dart';

/// First-run, two-page carousel. Completing it (Get Started or Login) is
/// remembered so it is only shown once.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.store = const IntroStore()});

  final IntroStore store;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish(String route) async {
    await widget.store.markSeen();
    if (mounted) context.pushReplacement(route);
  }

  void _next() =>
      _pages.nextPage(duration: AppMotion.normal, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final last = _page == 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _page == 0
                          ? IconButton(
                              tooltip: 'Back',
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                              ),
                              onPressed: () => context.pop(),
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [_DiscoverPage(), _FeaturesPage()],
                  ),
                ),
                _Dots(index: _page, count: 2),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PrimaryButton(
                    label: last ? 'Get Started' : 'Next',
                    onPressed: last ? () => _finish('/register') : _next,
                  ),
                ),
                SizedBox(
                  height: 64,
                  child: last
                      ? AuthSwitchRow(
                          prompt: 'Already have an account?',
                          action: 'Login',
                          onPressed: () => _finish('/sign-in'),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Page ${index + 1} of $count',
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index ? AppColors.primary : AppColors.outline,
              ),
            ),
        ],
      ),
    ),
  );
}

class _DiscoverPage extends StatelessWidget {
  const _DiscoverPage();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Expanded(child: _IllustrationCard()),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Discover Meetups Near You',
              textAlign: TextAlign.center,
              style: t.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Find interesting people, join local plans and make new friends — in Mumbai & Pune.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Painted stand-in for the hero photo: dusk skyline with overlapping avatars
/// and floating plan chips.
class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard();

  static const _avatars = <(Color, IconData)>[
    (Color(0xFFEE7A5B), Icons.person),
    (Color(0xFF4F46E5), Icons.face_3),
    (Color(0xFF14746F), Icons.face),
    (Color(0xFFC2408A), Icons.face_2),
    (Color(0xFFB7791F), Icons.person_2),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Illustration of friends meeting up',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: kDuskGradient),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: SkylinePainter()),
                ),
                const Align(
                  alignment: Alignment(-0.78, -0.62),
                  child: _FloatChip(icon: Icons.restaurant, label: 'Brunch'),
                ),
                const Align(
                  alignment: Alignment(0.8, -0.38),
                  child: _FloatChip(icon: Icons.hiking, label: 'Trek'),
                ),
                Align(
                  alignment: const Alignment(0, 0.52),
                  child: SizedBox(
                    height: 64,
                    width: 64.0 + 4 * 40,
                    child: Stack(
                      children: [
                        for (var i = 0; i < _avatars.length; i++)
                          Positioned(
                            left: i * 40.0,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _avatars[i].$1,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                _avatars[i].$2,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: AppShadows.card,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.ink),
        ),
      ],
    ),
  );
}

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  static const _rows = <(IconData, String, String)>[
    (
      Icons.explore_outlined,
      'Explore Interests',
      'From food to trekking, games to art — find what you love.',
    ),
    (
      Icons.event_available_outlined,
      'Join or Create Plans',
      'See what\'s happening nearby or start your own meetup.',
    ),
    (
      Icons.chat_bubble_outline,
      'Chat & Connect',
      'Meet, chat, and build meaningful relationships.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        children: [
          for (final r in _rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.tint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(r.$1, color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$2, style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          r.$3,
                          style: t.bodyMedium?.copyWith(
                            color: AppColors.inkMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ],
      ),
    );
  }
}
