import 'package:flutter/material.dart';

import 'hero_scene.dart';
import 'scene_kit.dart';

CustomPainter scenePainterFor(HeroSceneKind kind) => switch (kind) {
  HeroSceneKind.lakeDusk => const LakeDuskPainter(),
  HeroSceneKind.sunsetHills => const SunsetHillsPainter(),
  HeroSceneKind.cliffVillage => const CliffVillagePainter(),
  HeroSceneKind.campfire => const CampfirePainter(),
};

const _ink = Color(0xFF0E1622);

/// (a) Mountain lake at dusk with a seated hiker, lower-left.
class LakeDuskPainter extends CustomPainter {
  const LakeDuskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.60;
    paintSky(
      canvas,
      Offset.zero & size,
      const [
        Color(0xFF1F3F73),
        Color(0xFF4F79B5),
        Color(0xFFB9A9B8),
        Color(0xFFF4A66A),
      ],
      const [0, 0.3, 0.52, 0.62],
    );
    paintStars(canvas, size, 0.25, count: 28);
    paintGlow(
      canvas,
      Offset(w * 0.68, horizon - h * 0.04),
      w * 0.7,
      const Color(0xFFFFB878),
      alpha: 0.75,
    );

    // Far snowy peaks.
    final far = [
      const Offset(0, 0.50),
      const Offset(0.14, 0.40),
      const Offset(0.26, 0.47),
      const Offset(0.42, 0.33),
      const Offset(0.56, 0.46),
      const Offset(0.72, 0.38),
      const Offset(0.88, 0.47),
      const Offset(1, 0.43),
    ];
    canvas.drawPath(
      peaksPath(size, far, bottom: 0.62),
      Paint()..color = const Color(0xFF6C84AE),
    );
    // Snow caps on the three tallest peaks.
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (final c in [
      const Offset(0.14, 0.40),
      const Offset(0.42, 0.33),
      const Offset(0.72, 0.38),
    ]) {
      final top = Offset(c.dx * w, c.dy * h);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(top.dx + w * 0.055, top.dy + h * 0.055)
          ..lineTo(top.dx + w * 0.02, top.dy + h * 0.045)
          ..lineTo(top.dx, top.dy + h * 0.065)
          ..lineTo(top.dx - w * 0.025, top.dy + h * 0.042)
          ..lineTo(top.dx - w * 0.055, top.dy + h * 0.057)
          ..close(),
        snow,
      );
    }
    // Mid mountains in blue haze.
    canvas.drawPath(
      ridgePath(size, const [
        Offset(0, 0.56),
        Offset(0.2, 0.50),
        Offset(0.45, 0.56),
        Offset(0.7, 0.51),
        Offset(1, 0.55),
      ], bottom: 0.62),
      Paint()..color = const Color(0xFF3D5A87),
    );
    // Forested slopes either side.
    final slopeL = ridgePath(size, const [
      Offset(0, 0.46),
      Offset(0.16, 0.54),
      Offset(0.34, 0.62),
      Offset(0.5, 0.66),
    ], bottom: 0.7);
    final forest = Paint()..color = const Color(0xFF1B3B3A);
    canvas.drawPath(slopeL, forest);
    final slopeR = ridgePath(size, const [
      Offset(0.5, 0.66),
      Offset(0.7, 0.60),
      Offset(0.88, 0.52),
      Offset(1, 0.46),
    ], bottom: 0.7);
    canvas.drawPath(slopeR, forest);
    final pine = const Color(0xFF12292A);
    for (var i = 0; i < 9; i++) {
      final x = w * (0.02 + i * 0.045);
      paintPine(
        canvas,
        Offset(x, h * (0.55 + i * 0.012)),
        h * (0.09 - i * 0.003),
        pine,
      );
    }
    for (var i = 0; i < 8; i++) {
      final x = w * (0.98 - i * 0.045);
      paintPine(
        canvas,
        Offset(x, h * (0.54 + i * 0.012)),
        h * (0.095 - i * 0.004),
        pine,
      );
    }

    // Lake with mirrored sky and reflections.
    final lake = Rect.fromLTRB(0, horizon, w, h);
    paintSky(
      canvas,
      lake,
      const [
        Color(0xFFE59A68),
        Color(0xFF7C86A8),
        Color(0xFF223B63),
        Color(0xFF14233C),
      ],
      const [0, 0.25, 0.7, 1],
    );
    canvas.save();
    canvas.clipRect(lake);
    canvas.translate(0, horizon * 2);
    canvas.scale(1, -1);
    canvas.drawPath(
      peaksPath(size, far, bottom: 0.62),
      Paint()..color = const Color(0xFF3D5A87).withValues(alpha: 0.35),
    );
    canvas.restore();
    paintShimmer(canvas, lake, const Color(0xFFFFD9A8));

    // Foreground rock + seated hiker, lower-left.
    final rock = Path()
      ..moveTo(-w * 0.05, h)
      ..lineTo(-w * 0.05, h * 0.84)
      ..quadraticBezierTo(w * 0.08, h * 0.77, w * 0.2, h * 0.80)
      ..quadraticBezierTo(w * 0.34, h * 0.83, w * 0.42, h * 0.90)
      ..quadraticBezierTo(w * 0.46, h * 0.95, w * 0.5, h)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF0B121C));
    paintSeated(
      canvas,
      Offset(w * 0.2, h * 0.805),
      w / 360 * 1.25,
      _ink,
      backpack: true,
      rim: const Color(0xFFF4A66A),
    );
    // Bottom vignette keeps the buttons legible.
    paintSky(
      canvas,
      Rect.fromLTRB(0, h * 0.7, w, h),
      [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
      const [0, 1],
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// (b) Sunset over hills with three friends seated on a rock.
class SunsetHillsPainter extends CustomPainter {
  const SunsetHillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sun = Offset(w * 0.5, h * 0.55);
    paintSky(
      canvas,
      Offset.zero & size,
      const [
        Color(0xFF4A3B73),
        Color(0xFFB45F7E),
        Color(0xFFF59A5F),
        Color(0xFFFFD08A),
      ],
      const [0, 0.35, 0.65, 0.85],
    );
    paintStars(canvas, size, 0.18, count: 14);
    paintGlow(canvas, sun, w * 0.8, const Color(0xFFFFE0A0), alpha: 0.9);
    canvas.drawCircle(sun, w * 0.075, Paint()..color = const Color(0xFFFFF1C8));

    // Thin clouds.
    final cloud = Paint()
      ..color = const Color(0xFFFFC9A0).withValues(alpha: 0.4);
    for (final c in [
      Rect.fromLTWH(w * 0.05, h * 0.28, w * 0.4, 8),
      Rect.fromLTWH(w * 0.55, h * 0.36, w * 0.38, 7),
      Rect.fromLTWH(w * 0.2, h * 0.44, w * 0.3, 6),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(c, const Radius.circular(6)),
        cloud,
      );
    }
    // Hills, far to near.
    final layers = <(List<Offset>, Color)>[
      (
        const [
          Offset(0, 0.60),
          Offset(0.25, 0.54),
          Offset(0.55, 0.60),
          Offset(0.8, 0.55),
          Offset(1, 0.58),
        ],
        const Color(0xFF9B5A78),
      ),
      (
        const [
          Offset(0, 0.66),
          Offset(0.3, 0.60),
          Offset(0.6, 0.67),
          Offset(1, 0.61),
        ],
        const Color(0xFF6E4468),
      ),
      (
        const [
          Offset(0, 0.72),
          Offset(0.22, 0.69),
          Offset(0.5, 0.75),
          Offset(0.78, 0.70),
          Offset(1, 0.74),
        ],
        const Color(0xFF45324F),
      ),
    ];
    for (final l in layers) {
      canvas.drawPath(ridgePath(size, l.$1), Paint()..color = l.$2);
    }
    // Foreground rock.
    final rock = Path()
      ..moveTo(-w * 0.05, h)
      ..lineTo(-w * 0.05, h * 0.86)
      ..quadraticBezierTo(w * 0.2, h * 0.80, w * 0.5, h * 0.82)
      ..quadraticBezierTo(w * 0.85, h * 0.80, w * 1.05, h * 0.87)
      ..lineTo(w * 1.05, h)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF1F1830));
    final k = w / 360;
    final y = h * 0.835;
    paintSeated(
      canvas,
      Offset(w * 0.36, y + 2 * k),
      k * 1.35,
      _ink,
      rim: const Color(0xFFFFB078),
    );
    paintSeated(
      canvas,
      Offset(w * 0.5, y),
      k * 1.5,
      _ink,
      rim: const Color(0xFFFFB078),
    );
    paintSeated(
      canvas,
      Offset(w * 0.64, y + 3 * k),
      k * 1.3,
      _ink,
      faceLeft: true,
      rim: const Color(0xFFFFB078),
    );
    // Birds.
    final bird = Paint()
      ..color = _ink.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final b in [
      Offset(w * 0.2, h * 0.2),
      Offset(w * 0.27, h * 0.17),
      Offset(w * 0.78, h * 0.24),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(b.dx - 6, b.dy)
          ..quadraticBezierTo(b.dx - 3, b.dy - 5, b.dx, b.dy)
          ..quadraticBezierTo(b.dx + 3, b.dy - 5, b.dx + 6, b.dy),
        bird,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// (c) White cliff village above the sea, standing backpacker.
class CliffVillagePainter extends CustomPainter {
  const CliffVillagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final seaTop = h * 0.56;
    paintSky(
      canvas,
      Offset.zero & size,
      const [Color(0xFF4FA8E8), Color(0xFF9ED4F5), Color(0xFFEAF6FC)],
      const [0, 0.45, 0.56],
    );
    paintGlow(
      canvas,
      Offset(w * 0.78, h * 0.22),
      w * 0.5,
      Colors.white,
      alpha: 0.7,
    );
    // Clouds.
    final cl = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (final c in [Offset(w * 0.2, h * 0.16), Offset(w * 0.62, h * 0.30)]) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.3, height: 14),
        cl,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(18, -8),
          width: w * 0.18,
          height: 16,
        ),
        cl,
      );
    }
    // Sea.
    final sea = Rect.fromLTRB(0, seaTop, w, h);
    paintSky(
      canvas,
      sea,
      const [Color(0xFF7FD0E8), Color(0xFF1F8FC4), Color(0xFF0E5E9A)],
      const [0, 0.4, 1],
    );
    paintShimmer(canvas, sea, Colors.white, count: 12);
    // Distant island.
    canvas.drawPath(
      ridgePath(size, const [
        Offset(0.55, 0.56),
        Offset(0.7, 0.51),
        Offset(0.88, 0.56),
      ], bottom: 0.56),
      Paint()..color = const Color(0xFF8FB3C7),
    );
    // Cliff (right side, descending to the sea) in warm stone.
    final cliff = ridgePath(size, const [
      Offset(0.0, 0.68),
      Offset(0.12, 0.62),
      Offset(0.3, 0.64),
      Offset(0.5, 0.60),
      Offset(0.78, 0.70),
      Offset(1, 0.86),
    ], bottom: 1);
    canvas.drawPath(cliff, Paint()..color = const Color(0xFFD9C7AE));
    // Village: white cubes with blue domes stepping down the cliff.
    final white = Paint()..color = Colors.white;
    final shade = Paint()..color = const Color(0xFFDCE7EE);
    final dome = Paint()..color = const Color(0xFF2A6CC4);
    final cubes = <Rect>[
      Rect.fromLTWH(w * 0.03, h * 0.585, w * 0.12, h * 0.07),
      Rect.fromLTWH(w * 0.14, h * 0.55, w * 0.1, h * 0.085),
      Rect.fromLTWH(w * 0.26, h * 0.575, w * 0.13, h * 0.07),
      Rect.fromLTWH(w * 0.4, h * 0.545, w * 0.1, h * 0.075),
      Rect.fromLTWH(w * 0.5, h * 0.58, w * 0.12, h * 0.065),
      Rect.fromLTWH(w * 0.62, h * 0.625, w * 0.1, h * 0.06),
      Rect.fromLTWH(w * 0.76, h * 0.69, w * 0.09, h * 0.06),
    ];
    for (var i = 0; i < cubes.length; i++) {
      final c = cubes[i];
      canvas.drawRect(c, white);
      canvas.drawRect(
        Rect.fromLTWH(
          c.left,
          c.bottom - c.height * 0.25,
          c.width,
          c.height * 0.25,
        ),
        shade,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          c.left + c.width * 0.62,
          c.top + c.height * 0.3,
          c.width * 0.16,
          c.height * 0.3,
        ),
        Paint()..color = const Color(0xFF3B78C4),
      );
      if (i.isEven) {
        canvas.drawArc(
          Rect.fromLTWH(
            c.left + c.width * 0.18,
            c.top - c.height * 0.3,
            c.width * 0.5,
            c.height * 0.6,
          ),
          3.14159,
          3.14159,
          true,
          dome,
        );
      }
    }
    // Bell tower.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.455, h * 0.49, w * 0.035, h * 0.06),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.45, h * 0.49)
        ..lineTo(w * 0.4725, h * 0.465)
        ..lineTo(w * 0.495, h * 0.49)
        ..close(),
      dome,
    );
    // Foreground grassy bank + standing backpacker.
    final bank = Path()
      ..moveTo(-w * 0.05, h)
      ..lineTo(-w * 0.05, h * 0.86)
      ..quadraticBezierTo(w * 0.25, h * 0.80, w * 0.55, h * 0.86)
      ..quadraticBezierTo(w * 0.85, h * 0.90, w * 1.05, h * 0.95)
      ..lineTo(w * 1.05, h)
      ..close();
    canvas.drawPath(bank, Paint()..color = const Color(0xFF3F5E3C));
    paintStanding(
      canvas,
      Offset(w * 0.34, h * 0.9),
      w / 360 * 1.35,
      const Color(0xFF16212D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// (d) Campfire circle by a lake at dusk.
class CampfirePainter extends CustomPainter {
  const CampfirePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.58;
    final k = w / 360;
    paintSky(
      canvas,
      Offset.zero & size,
      const [
        Color(0xFF141C3D),
        Color(0xFF3B3A7A),
        Color(0xFFB4557F),
        Color(0xFFF08A5A),
      ],
      const [0, 0.3, 0.52, 0.6],
    );
    paintStars(canvas, size, 0.35, count: 50);
    // Moon.
    canvas.drawCircle(
      Offset(w * 0.8, h * 0.14),
      11 * k,
      Paint()..color = const Color(0xFFFFF4D6),
    );
    paintGlow(
      canvas,
      Offset(w * 0.8, h * 0.14),
      50 * k,
      const Color(0xFFFFF4D6),
      alpha: 0.35,
    );
    // Far hills.
    canvas.drawPath(
      ridgePath(size, const [
        Offset(0, 0.55),
        Offset(0.2, 0.50),
        Offset(0.45, 0.56),
        Offset(0.7, 0.50),
        Offset(1, 0.54),
      ], bottom: 0.6),
      Paint()..color = const Color(0xFF3A2C5E),
    );
    // Lake.
    final lake = Rect.fromLTRB(0, horizon, w, h);
    paintSky(
      canvas,
      lake,
      const [Color(0xFFD9764F), Color(0xFF5A3F78), Color(0xFF1B1F3F)],
      const [0, 0.35, 1],
    );
    paintShimmer(canvas, lake, const Color(0xFFFFC08A), count: 10);
    // Dark shore / ground.
    final ground = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.3, h * 0.67, w * 0.5, h * 0.70)
      ..quadraticBezierTo(w * 0.8, h * 0.66, w, h * 0.72)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF120F22));
    // Pines at the edges.
    const pine = Color(0xFF0B0A18);
    for (var i = 0; i < 4; i++) {
      paintPine(
        canvas,
        Offset(w * (0.03 + i * 0.05), h * 0.72),
        h * (0.2 - i * 0.02),
        pine,
      );
      paintPine(
        canvas,
        Offset(w * (0.97 - i * 0.05), h * 0.72),
        h * (0.19 - i * 0.02),
        pine,
      );
    }
    // Fire glow lighting the circle.
    final fire = Offset(w * 0.5, h * 0.84);
    paintGlow(canvas, fire, w * 0.65, const Color(0xFFFF8A3D), alpha: 0.55);
    // Seated silhouettes around the fire.
    const rim = Color(0xFFFFB066);
    paintSeated(canvas, Offset(w * 0.16, h * 0.86), k * 1.25, _ink, rim: rim);
    paintSeated(canvas, Offset(w * 0.30, h * 0.80), k * 1.0, _ink, rim: rim);
    paintSeated(
      canvas,
      Offset(w * 0.70, h * 0.80),
      k * 1.0,
      _ink,
      faceLeft: true,
      rim: rim,
    );
    paintSeated(
      canvas,
      Offset(w * 0.84, h * 0.86),
      k * 1.25,
      _ink,
      faceLeft: true,
      rim: rim,
    );
    paintSeated(canvas, Offset(w * 0.5, h * 0.74), k * 0.8, _ink, rim: rim);
    // Logs and flames.
    final log = Paint()
      ..color = const Color(0xFF2A1A12)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5 * k;
    canvas.drawLine(
      fire.translate(-22 * k, 4 * k),
      fire.translate(18 * k, -2 * k),
      log,
    );
    canvas.drawLine(
      fire.translate(-18 * k, -2 * k),
      fire.translate(22 * k, 4 * k),
      log,
    );
    Path flame(double s) => Path()
      ..moveTo(fire.dx, fire.dy - 46 * k * s)
      ..cubicTo(
        fire.dx + 14 * k * s,
        fire.dy - 22 * k * s,
        fire.dx + 20 * k * s,
        fire.dy - 12 * k * s,
        fire.dx + 10 * k * s,
        fire.dy,
      )
      ..lineTo(fire.dx - 10 * k * s, fire.dy)
      ..cubicTo(
        fire.dx - 20 * k * s,
        fire.dy - 12 * k * s,
        fire.dx - 12 * k * s,
        fire.dy - 24 * k * s,
        fire.dx,
        fire.dy - 46 * k * s,
      )
      ..close();
    canvas.drawPath(flame(1), Paint()..color = const Color(0xFFFF7A2A));
    canvas.drawPath(flame(0.72), Paint()..color = const Color(0xFFFFB02E));
    canvas.drawPath(flame(0.4), Paint()..color = const Color(0xFFFFF0A8));
    // Embers.
    final ember = Paint()..color = const Color(0xFFFFC27A);
    for (final e in [
      const Offset(-10, -62),
      const Offset(8, -76),
      const Offset(-2, -92),
      const Offset(14, -58),
    ]) {
      canvas.drawCircle(fire.translate(e.dx * k, e.dy * k), 1.4 * k, ember);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
