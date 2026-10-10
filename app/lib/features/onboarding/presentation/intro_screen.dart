import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/scenes/hero_scene.dart';
import '../application/intro_store.dart';

class _IntroPage {
  const _IntroPage(this.scene, this.title, this.body);
  final HeroSceneKind scene;
  final String title;
  final String body;
}

const _pages = <_IntroPage>[
  _IntroPage(
    HeroSceneKind.sunsetHills,
    'Real People,\nShared Adventures',
    'Join a global community of travelers,\ncreators and explorers.',
  ),
  _IntroPage(
    HeroSceneKind.cliffVillage,
    'Explore Activities\n& Meet Locals',
    'Join group activities, discover new\nplaces and make real connections.',
  ),
  _IntroPage(
    HeroSceneKind.campfire,
    'A Community\nThat Feels Like Home',
    'Chat, join rooms, share stories.\nYou\'re not just a traveler anymore.',
  ),
];

/// First-run three-page carousel: photo-style hero on top, white rounded
/// panel with title, description, dots and a navy action button. Skip and
/// Get Started both remember completion and go to the landing screen.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.store = const IntroStore()});

  final IntroStore store;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.store.markSeen();
    if (mounted) context.go('/welcome');
  }

  void _next() =>
      _controller.nextPage(duration: AppMotion.normal, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _PageBody(page: _pages[i]),
                    ),
                  ),
                  ColoredBox(
                    color: Colors.white,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Dots(index: _page, count: _pages.length),
                            const SizedBox(height: 18),
                            PrimaryButton(
                              backgroundColor: AppColors.navy,
                              label: last ? 'Get Started' : 'Next',
                              onPressed: last ? _finish : _next,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 4,
                child: SafeArea(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(64, 48),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                HeroScene(kind: page.scene),
                // Keeps the white Skip label legible over bright skies.
                const ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x59000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Panel overlaps the artwork by 24px.
          Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: t.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    page.body,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
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
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index ? AppColors.navy : AppColors.outline,
              ),
            ),
        ],
      ),
    ),
  );
}
