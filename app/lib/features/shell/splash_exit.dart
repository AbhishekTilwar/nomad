import 'package:flutter/material.dart';

/// Plays the splash's exit: as the screen is replaced (its route animation
/// runs backwards) or covered (the secondary animation runs forwards), the
/// logo lifts, grows slightly and fades out. Skipped for reduced motion.
class SplashExit extends StatelessWidget {
  const SplashExit({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (_, child) {
        // 0 = fully shown, 1 = gone.
        final out =
            (1 - animation.value).clamp(0.0, 1.0) > secondaryAnimation.value
            ? 1 - animation.value
            : secondaryAnimation.value;
        final t = Curves.easeInCubic.transform(out.clamp(0.0, 1.0));
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset(0, -36 * t),
            child: Transform.scale(scale: 1 + 0.14 * t, child: child),
          ),
        );
      },
      child: child,
    );
  }
}
