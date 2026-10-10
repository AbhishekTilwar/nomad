import 'package:flutter/material.dart';

import 'scene_painters.dart';

/// Which illustration to show.
enum HeroSceneKind {
  /// Mountain lake at dusk with a seated hiker (landing screen).
  lakeDusk,

  /// Sunset hills with three friends on a rock (onboarding 1).
  sunsetHills,

  /// White cliff village, sea and a standing backpacker (onboarding 2).
  cliffVillage,

  /// Campfire circle by a lake at dusk (onboarding 3).
  campfire,
}

/// Full-bleed decorative hero art. Fills its parent. To use real photos
/// later, replace the body with `Image.asset(path, fit: BoxFit.cover)`; no
/// caller needs to change.
class HeroScene extends StatelessWidget {
  const HeroScene({super.key, required this.kind});

  final HeroSceneKind kind;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.expand(
        child: CustomPaint(painter: scenePainterFor(kind), isComplex: true),
      ),
    );
  }
}
