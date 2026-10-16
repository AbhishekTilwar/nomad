import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/scenes/scene_kit.dart';

/// Our own banner library: one illustrated scene per kind of plan, used
/// whenever the host didn't add a cover photo (and as the loading/error
/// fallback for covers). All vector, so no image assets to ship.
enum PlanScene {
  trek,
  coffee,
  beach,
  camp,
  food,
  music,
  games,
  sports,
  art,
  photo,
  movie,
  network,
  travel,
  explore;

  /// Picks the scene from the plan's title first ("chai walk" is coffee), then
  /// from its category.
  static PlanScene of(String title, String category) {
    final t = title.toLowerCase();
    for (final e in _keywords.entries) {
      if (RegExp('\\b${e.key}').hasMatch(t)) return e.value;
    }
    return _byCategory[category] ?? PlanScene.explore;
  }

  static const _keywords = <String, PlanScene>{
    'trek': PlanScene.trek,
    'hike': PlanScene.trek,
    'trail': PlanScene.trek,
    'climb': PlanScene.trek,
    'fort': PlanScene.trek,
    'camp': PlanScene.camp,
    'bonfire': PlanScene.camp,
    'coffee': PlanScene.coffee,
    'chai': PlanScene.coffee,
    'cafe': PlanScene.coffee,
    'tea': PlanScene.coffee,
    'brunch': PlanScene.coffee,
    'breakfast': PlanScene.coffee,
    'beach': PlanScene.beach,
    'sunset': PlanScene.beach,
    'sunrise': PlanScene.beach,
    'promenade': PlanScene.beach,
    'marine': PlanScene.beach,
    'lake': PlanScene.beach,
    'picnic': PlanScene.beach,
    'food': PlanScene.food,
    'dinner': PlanScene.food,
    'lunch': PlanScene.food,
    'pizza': PlanScene.food,
    'street food': PlanScene.food,
    'music': PlanScene.music,
    'jam': PlanScene.music,
    'open mic': PlanScene.music,
    'karaoke': PlanScene.music,
    'concert': PlanScene.music,
    'board game': PlanScene.games,
    'game': PlanScene.games,
    'quiz': PlanScene.games,
    'cricket': PlanScene.sports,
    'badminton': PlanScene.sports,
    'football': PlanScene.sports,
    'volleyball': PlanScene.sports,
    'run': PlanScene.sports,
    'yoga': PlanScene.sports,
    'cycl': PlanScene.sports,
    'paint': PlanScene.art,
    'sketch': PlanScene.art,
    'art': PlanScene.art,
    'photo': PlanScene.photo,
    'film': PlanScene.movie,
    'movie': PlanScene.movie,
    'network': PlanScene.network,
    'startup': PlanScene.network,
    'mixer': PlanScene.network,
    'getaway': PlanScene.travel,
    'trip': PlanScene.travel,
  };

  static const _byCategory = <String, PlanScene>{
    'food': PlanScene.food,
    'outings': PlanScene.beach,
    'travel': PlanScene.travel,
    'hiking': PlanScene.trek,
    'games': PlanScene.games,
    'sports': PlanScene.sports,
    'photography': PlanScene.photo,
    'music': PlanScene.music,
    'movies': PlanScene.movie,
    'networking': PlanScene.network,
    'art': PlanScene.art,
    'explore': PlanScene.explore,
  };
}

/// A plan's banner: its cover photo if the host added one, otherwise the
/// illustrated scene for its kind. Fills whatever box it is given (rounded
/// rectangle, circle...), so clip it from outside.
class PlanBanner extends StatelessWidget {
  const PlanBanner({
    super.key,
    required this.title,
    required this.category,
    this.coverUrl,
    this.memCacheWidth,
  });

  final String title;
  final String category;
  final String? coverUrl;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final scene = ExcludeSemantics(
      child: CustomPaint(
        painter: PlanScenePainter(PlanScene.of(title, category)),
        child: const SizedBox.expand(),
      ),
    );
    final url = coverUrl;
    if (url == null || url.isEmpty) return scene;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
      placeholder: (_, _) => scene,
      errorWidget: (_, _, _) => scene,
    );
  }
}

/// Draws one [PlanScene] to fit its box. Compositions are centred so they
/// still read when cropped to a circle or a wide strip.
class PlanScenePainter extends CustomPainter {
  const PlanScenePainter(this.scene);
  final PlanScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final s = _Surface(canvas, size);
    switch (scene) {
      case PlanScene.trek:
        _trek(s);
      case PlanScene.coffee:
        _coffee(s);
      case PlanScene.beach:
        _beach(s);
      case PlanScene.camp:
        _camp(s);
      case PlanScene.food:
        _food(s);
      case PlanScene.music:
        _music(s);
      case PlanScene.games:
        _games(s);
      case PlanScene.sports:
        _sports(s);
      case PlanScene.art:
        _art(s);
      case PlanScene.photo:
        _photo(s);
      case PlanScene.movie:
        _movie(s);
      case PlanScene.network:
        _network(s);
      case PlanScene.travel:
        _travel(s);
      case PlanScene.explore:
        _explore(s);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlanScenePainter o) => o.scene != scene;
}

/// Drawing surface in fractions of the box, with a "unit" (the shorter side)
/// so props keep their proportions on wide and square boxes alike.
class _Surface {
  _Surface(this.c, this.size)
    : u = math.min(size.width, size.height),
      cx = size.width / 2,
      cy = size.height / 2;
  final Canvas c;
  final Size size;
  final double u;
  final double cx;
  final double cy;

  double get w => size.width;
  double get h => size.height;

  Paint fill(Color color) => Paint()..color = color;

  void sky(List<Color> colors, [List<double>? stops]) => paintSky(
    c,
    Offset.zero & size,
    colors,
    stops ?? [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)],
  );

  void glow(Offset at, double r, Color color, [double a = 0.8]) =>
      paintGlow(c, at, r, color, alpha: a);

  void circle(Offset at, double r, Color color) =>
      c.drawCircle(at, r, fill(color));

  void rrect(Rect r, double radius, Color color) => c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    fill(color),
  );

  void stroke(Path p, Color color, double width) => c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color,
  );

  void star(Offset at, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.38;
      final o = Offset(at.dx + math.cos(a) * rr, at.dy + math.sin(a) * rr);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    c.drawPath(p..close(), fill(color));
  }

  void cloud(Offset at, double r, Color color) {
    circle(at, r, color);
    circle(at.translate(r * 0.9, r * 0.25), r * 0.75, color);
    circle(at.translate(-r * 0.95, r * 0.3), r * 0.65, color);
    rrect(
      Rect.fromLTRB(
        at.dx - r * 1.6,
        at.dy + r * 0.25,
        at.dx + r * 1.65,
        at.dy + r,
      ),
      r * 0.4,
      color,
    );
  }

  /// A palm tree: curved trunk and a fan of fronds.
  void palm(Offset base, double hgt, Color color) {
    final top = Offset(base.dx + hgt * 0.18, base.dy - hgt);
    stroke(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx - hgt * 0.08,
          base.dy - hgt * 0.55,
          top.dx,
          top.dy,
        ),
      color,
      hgt * 0.05,
    );
    for (final a in [-2.7, -2.2, -1.7, -1.2, -0.7, -0.25]) {
      final len = hgt * 0.42;
      final end = Offset(
        top.dx + math.cos(a) * len,
        top.dy + math.sin(a) * len * 0.8 + len * 0.25,
      );
      stroke(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            top.dx + math.cos(a) * len * 0.6,
            top.dy + math.sin(a) * len * 0.9 - len * 0.1,
            end.dx,
            end.dy,
          ),
        color,
        hgt * 0.045,
      );
    }
  }
}

// ---------------------------------------------------------------- scenes

void _trek(_Surface s) {
  s.sky(
    const [Color(0xFF9CCBE8), Color(0xFFF7D9B0), Color(0xFFFFE9C9)],
    const [0, 0.65, 1],
  );
  s.glow(
    Offset(s.w * 0.74, s.h * 0.32),
    s.u * 0.7,
    const Color(0xFFFFD27A),
    0.9,
  );
  s.circle(Offset(s.w * 0.74, s.h * 0.32), s.u * 0.1, const Color(0xFFFFF3C4));
  s.c.drawPath(
    peaksPath(s.size, const [
      Offset(0, 0.62),
      Offset(0.2, 0.34),
      Offset(0.34, 0.5),
      Offset(0.52, 0.22),
      Offset(0.7, 0.5),
      Offset(0.86, 0.36),
      Offset(1, 0.58),
    ], bottom: 1),
    s.fill(const Color(0xFF7FA79B)),
  );
  // Snow on the tallest peak.
  s.c.drawPath(
    Path()
      ..moveTo(s.w * 0.52, s.h * 0.22)
      ..lineTo(s.w * 0.585, s.h * 0.36)
      ..lineTo(s.w * 0.545, s.h * 0.33)
      ..lineTo(s.w * 0.52, s.h * 0.4)
      ..lineTo(s.w * 0.49, s.h * 0.32)
      ..lineTo(s.w * 0.455, s.h * 0.36)
      ..close(),
    s.fill(Colors.white.withValues(alpha: 0.92)),
  );
  s.c.drawPath(
    ridgePath(s.size, const [
      Offset(0, 0.66),
      Offset(0.25, 0.56),
      Offset(0.5, 0.64),
      Offset(0.78, 0.55),
      Offset(1, 0.62),
    ]),
    s.fill(const Color(0xFF4E8A6B)),
  );
  s.c.drawPath(
    ridgePath(s.size, const [
      Offset(0, 0.82),
      Offset(0.3, 0.74),
      Offset(0.62, 0.8),
      Offset(1, 0.72),
    ]),
    s.fill(const Color(0xFF2F6B4F)),
  );
  for (final p in const [
    Offset(0.12, 0.78),
    Offset(0.2, 0.8),
    Offset(0.84, 0.74),
    Offset(0.92, 0.77),
  ]) {
    paintPine(
      s.c,
      Offset(s.w * p.dx, s.h * p.dy),
      s.u * 0.2,
      const Color(0xFF1E4B3A),
    );
  }
  paintStanding(
    s.c,
    Offset(s.cx, s.h * 0.84),
    s.u * 0.0036,
    const Color(0xFF14322A),
  );
}

void _coffee(_Surface s) {
  s.sky(const [Color(0xFFF6E7D2), Color(0xFFEBCFA9)]);
  s.glow(Offset(s.cx, s.cy), s.u * 0.9, const Color(0xFFFFF4E0), 0.8);
  final u = s.u;
  final cx = s.cx;
  final cy = s.cy + u * 0.08;
  // Saucer.
  s.c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, cy + u * 0.26),
      width: u * 0.86,
      height: u * 0.2,
    ),
    s.fill(const Color(0xFFFFFFFF)),
  );
  s.c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, cy + u * 0.255),
      width: u * 0.62,
      height: u * 0.12,
    ),
    s.fill(const Color(0xFFE6DCCE)),
  );
  // Handle.
  s.stroke(
    Path()
      ..moveTo(cx + u * 0.27, cy - u * 0.02)
      ..cubicTo(
        cx + u * 0.5,
        cy - u * 0.04,
        cx + u * 0.5,
        cy + u * 0.2,
        cx + u * 0.24,
        cy + u * 0.18,
      ),
    const Color(0xFFFFFFFF),
    u * 0.07,
  );
  // Cup body.
  final body = Path()
    ..moveTo(cx - u * 0.31, cy - u * 0.08)
    ..lineTo(cx + u * 0.31, cy - u * 0.08)
    ..quadraticBezierTo(cx + u * 0.3, cy + u * 0.3, cx, cy + u * 0.3)
    ..quadraticBezierTo(
      cx - u * 0.3,
      cy + u * 0.3,
      cx - u * 0.31,
      cy - u * 0.08,
    )
    ..close();
  s.c.drawPath(body, s.fill(Colors.white));
  s.c.drawPath(
    Path()
      ..moveTo(cx - u * 0.31, cy + u * 0.02)
      ..quadraticBezierTo(cx, cy + u * 0.12, cx + u * 0.31, cy + u * 0.02)
      ..quadraticBezierTo(cx + u * 0.29, cy + u * 0.3, cx, cy + u * 0.3)
      ..quadraticBezierTo(
        cx - u * 0.29,
        cy + u * 0.3,
        cx - u * 0.31,
        cy + u * 0.02,
      )
      ..close(),
    s.fill(const Color(0xFF2E8B83).withValues(alpha: 0.9)),
  );
  // Coffee surface.
  s.c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, cy - u * 0.08),
      width: u * 0.62,
      height: u * 0.13,
    ),
    s.fill(const Color(0xFF7A4B2A)),
  );
  s.c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - u * 0.03, cy - u * 0.085),
      width: u * 0.34,
      height: u * 0.06,
    ),
    s.fill(const Color(0xFFC9966B)),
  );
  // Steam.
  for (final dx in const [-0.12, 0.0, 0.12]) {
    s.stroke(
      Path()
        ..moveTo(cx + u * dx, cy - u * 0.2)
        ..cubicTo(
          cx + u * (dx + 0.08),
          cy - u * 0.3,
          cx + u * (dx - 0.08),
          cy - u * 0.38,
          cx + u * dx,
          cy - u * 0.48,
        ),
      Colors.white.withValues(alpha: 0.85),
      u * 0.03,
    );
  }
  s.star(
    Offset(cx - u * 0.5, cy - u * 0.25),
    u * 0.04,
    const Color(0xFFE99A32),
  );
  s.star(
    Offset(cx + u * 0.52, cy - u * 0.3),
    u * 0.03,
    const Color(0xFFE99A32),
  );
}

void _beach(_Surface s) {
  s.sky(
    const [
      Color(0xFF6C5BA7),
      Color(0xFFE5779B),
      Color(0xFFFFB46B),
      Color(0xFFFFE0A3),
    ],
    const [0, 0.38, 0.62, 0.7],
  );
  final horizon = s.h * 0.68;
  s.glow(Offset(s.cx, horizon), s.u * 0.8, const Color(0xFFFFD08A), 0.9);
  s.circle(
    Offset(s.cx, horizon - s.u * 0.06),
    s.u * 0.17,
    const Color(0xFFFFF0B8),
  );
  // Sea.
  final sea = Rect.fromLTRB(0, horizon, s.w, s.h);
  s.c.drawRect(
    sea,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF3A06A), Color(0xFF8B5E9C), Color(0xFF3F3A7A)],
      ).createShader(sea),
  );
  paintShimmer(s.c, sea, const Color(0xFFFFE9B5), count: 16);
  // Distant hills + city line.
  s.c.drawPath(
    ridgePath(s.size, [
      const Offset(0, 0.66),
      const Offset(0.2, 0.62),
      const Offset(0.4, 0.665),
      const Offset(0.7, 0.63),
      const Offset(1, 0.665),
    ], bottom: 0.68),
    s.fill(const Color(0xFF5A4A8A).withValues(alpha: 0.75)),
  );
  s.palm(Offset(s.w * 0.16, s.h * 0.98), s.h * 0.62, const Color(0xFF2B2250));
  s.palm(Offset(s.w * 0.86, s.h * 1.0), s.h * 0.5, const Color(0xFF2B2250));
}

void _camp(_Surface s) {
  s.sky(
    const [Color(0xFF0F1C3C), Color(0xFF223B6B), Color(0xFF3D4F86)],
    const [0, 0.6, 1],
  );
  paintStars(s.c, s.size, 0.55, count: 36);
  s.circle(Offset(s.w * 0.78, s.h * 0.2), s.u * 0.09, const Color(0xFFFFF3CF));
  s.c.drawPath(
    peaksPath(s.size, const [
      Offset(0, 0.7),
      Offset(0.18, 0.5),
      Offset(0.36, 0.64),
      Offset(0.58, 0.44),
      Offset(0.8, 0.62),
      Offset(1, 0.52),
    ]),
    s.fill(const Color(0xFF1B2D55)),
  );
  s.c.drawPath(
    ridgePath(s.size, const [
      Offset(0, 0.82),
      Offset(0.4, 0.76),
      Offset(0.75, 0.8),
      Offset(1, 0.76),
    ]),
    s.fill(const Color(0xFF12203F)),
  );
  // Tent with a glowing doorway.
  final tx = s.w * 0.34;
  final ty = s.h * 0.86;
  final tw = s.u * 0.34;
  s.c.drawPath(
    Path()
      ..moveTo(tx - tw, ty)
      ..lineTo(tx, ty - tw * 1.05)
      ..lineTo(tx + tw, ty)
      ..close(),
    s.fill(const Color(0xFFE99A32)),
  );
  s.c.drawPath(
    Path()
      ..moveTo(tx - tw * 0.22, ty)
      ..lineTo(tx, ty - tw * 0.62)
      ..lineTo(tx + tw * 0.22, ty)
      ..close(),
    s.fill(const Color(0xFFFFE3A1)),
  );
  // Campfire.
  final fx = s.w * 0.68;
  s.glow(Offset(fx, ty - s.u * 0.1), s.u * 0.4, const Color(0xFFFF9A3C), 0.8);
  s.c.drawPath(
    Path()
      ..moveTo(fx - s.u * 0.07, ty)
      ..quadraticBezierTo(fx - s.u * 0.09, ty - s.u * 0.12, fx, ty - s.u * 0.25)
      ..quadraticBezierTo(fx + s.u * 0.09, ty - s.u * 0.12, fx + s.u * 0.07, ty)
      ..close(),
    s.fill(const Color(0xFFFF8A2B)),
  );
  s.c.drawPath(
    Path()
      ..moveTo(fx - s.u * 0.035, ty)
      ..quadraticBezierTo(fx - s.u * 0.04, ty - s.u * 0.07, fx, ty - s.u * 0.14)
      ..quadraticBezierTo(
        fx + s.u * 0.04,
        ty - s.u * 0.07,
        fx + s.u * 0.035,
        ty,
      )
      ..close(),
    s.fill(const Color(0xFFFFE27A)),
  );
  s.stroke(
    Path()
      ..moveTo(fx - s.u * 0.12, ty + s.u * 0.01)
      ..lineTo(fx + s.u * 0.12, ty - s.u * 0.01),
    const Color(0xFF4A2F1B),
    s.u * 0.035,
  );
}

void _food(_Surface s) {
  s.sky(const [Color(0xFFFFE2BC), Color(0xFFFFC98B)]);
  s.glow(Offset(s.cx, s.cy), s.u * 0.9, const Color(0xFFFFF1D6), 0.8);
  final u = s.u;
  final cx = s.cx;
  final cy = s.cy + u * 0.08;
  // Chopsticks.
  s.stroke(
    Path()
      ..moveTo(cx + u * 0.12, cy - u * 0.36)
      ..lineTo(cx + u * 0.42, cy - u * 0.04),
    const Color(0xFF8B4A24),
    u * 0.028,
  );
  s.stroke(
    Path()
      ..moveTo(cx + u * 0.2, cy - u * 0.38)
      ..lineTo(cx + u * 0.46, cy - u * 0.1),
    const Color(0xFFB0682F),
    u * 0.028,
  );
  // Noodles heap.
  s.c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, cy - u * 0.04),
      width: u * 0.64,
      height: u * 0.3,
    ),
    s.fill(const Color(0xFFFFD66B)),
  );
  for (var i = 0; i < 5; i++) {
    s.stroke(
      Path()
        ..moveTo(cx - u * 0.26 + i * u * 0.02, cy - u * 0.04 + i * u * 0.015)
        ..cubicTo(
          cx - u * 0.1,
          cy - u * 0.2 + i * u * 0.02,
          cx + u * 0.1,
          cy + u * 0.1 - i * u * 0.01,
          cx + u * 0.26 - i * u * 0.02,
          cy - u * 0.05 + i * u * 0.01,
        ),
      const Color(0xFFF2B53D),
      u * 0.018,
    );
  }
  // Egg and greens.
  s.c.drawOval(
    Rect.fromCenter(
      center: Offset(cx - u * 0.12, cy - u * 0.1),
      width: u * 0.2,
      height: u * 0.14,
    ),
    s.fill(Colors.white),
  );
  s.circle(
    Offset(cx - u * 0.12, cy - u * 0.1),
    u * 0.04,
    const Color(0xFFFFA928),
  );
  s.circle(
    Offset(cx + u * 0.1, cy - u * 0.12),
    u * 0.035,
    const Color(0xFF4CAF50),
  );
  s.circle(
    Offset(cx + u * 0.17, cy - u * 0.07),
    u * 0.028,
    const Color(0xFF4CAF50),
  );
  // Bowl.
  final bowl = Path()
    ..moveTo(cx - u * 0.38, cy - u * 0.02)
    ..lineTo(cx + u * 0.38, cy - u * 0.02)
    ..quadraticBezierTo(cx + u * 0.34, cy + u * 0.34, cx, cy + u * 0.34)
    ..quadraticBezierTo(
      cx - u * 0.34,
      cy + u * 0.34,
      cx - u * 0.38,
      cy - u * 0.02,
    )
    ..close();
  s.c.drawPath(bowl, s.fill(const Color(0xFFD9532B)));
  s.c.drawPath(
    Path()
      ..moveTo(cx - u * 0.37, cy + u * 0.07)
      ..quadraticBezierTo(cx, cy + u * 0.16, cx + u * 0.37, cy + u * 0.07)
      ..lineTo(cx + u * 0.355, cy + u * 0.11)
      ..quadraticBezierTo(cx, cy + u * 0.2, cx - u * 0.355, cy + u * 0.11)
      ..close(),
    s.fill(const Color(0xFFFFE9C9)),
  );
  for (final dx in const [-0.1, 0.06]) {
    s.stroke(
      Path()
        ..moveTo(cx + u * dx, cy - u * 0.2)
        ..cubicTo(
          cx + u * (dx + 0.07),
          cy - u * 0.28,
          cx + u * (dx - 0.07),
          cy - u * 0.34,
          cx + u * dx,
          cy - u * 0.42,
        ),
      Colors.white.withValues(alpha: 0.8),
      u * 0.026,
    );
  }
}

void _music(_Surface s) {
  s.sky(
    const [Color(0xFF3B2A78), Color(0xFFB0408F), Color(0xFFFF8A5B)],
    const [0, 0.65, 1],
  );
  s.glow(Offset(s.cx, s.cy), s.u * 0.8, const Color(0xFFFFB3D0), 0.45);
  final u = s.u;
  s.c.save();
  s.c.translate(s.cx, s.cy + u * 0.04);
  s.c.rotate(-0.55);
  final wood = s.fill(const Color(0xFFE0903F));
  // Neck and head.
  s.rrect(
    Rect.fromLTWH(-u * 0.025, -u * 0.62, u * 0.05, u * 0.5),
    u * 0.01,
    const Color(0xFF5B3418),
  );
  s.rrect(
    Rect.fromLTWH(-u * 0.045, -u * 0.7, u * 0.09, u * 0.12),
    u * 0.02,
    const Color(0xFF3F2410),
  );
  // Body: two lobes.
  s.c.drawCircle(Offset(0, -u * 0.02), u * 0.17, wood);
  s.c.drawCircle(Offset(0, u * 0.17), u * 0.22, wood);
  s.circle(Offset(0, u * 0.06), u * 0.065, const Color(0xFF2A1608));
  s.circle(
    Offset(0, u * 0.06),
    u * 0.095,
    const Color(0xFFB86C26).withValues(alpha: 0.5),
  );
  s.rrect(
    Rect.fromLTWH(-u * 0.07, u * 0.27, u * 0.14, u * 0.025),
    u * 0.01,
    const Color(0xFF5B3418),
  );
  for (var i = -2; i <= 2; i++) {
    s.c.drawLine(
      Offset(i * u * 0.008, -u * 0.58),
      Offset(i * u * 0.008, u * 0.28),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 0.8,
    );
  }
  s.c.restore();
  // Floating notes.
  void note(Offset at, double k, Color color) {
    s.c.drawOval(
      Rect.fromCenter(center: at, width: k * 1.3, height: k),
      s.fill(color),
    );
    s.c.drawLine(
      at.translate(k * 0.6, 0),
      at.translate(k * 0.6, -k * 2.4),
      Paint()
        ..color = color
        ..strokeWidth = k * 0.2,
    );
    s.c.drawLine(
      at.translate(k * 0.6, -k * 2.4),
      at.translate(k * 1.3, -k * 1.8),
      Paint()
        ..color = color
        ..strokeWidth = k * 0.2,
    );
  }

  note(Offset(s.cx - u * 0.42, s.cy - u * 0.12), u * 0.07, Colors.white);
  note(
    Offset(s.cx + u * 0.4, s.cy - u * 0.28),
    u * 0.06,
    const Color(0xFFFFE27A),
  );
  note(Offset(s.cx + u * 0.34, s.cy + u * 0.2), u * 0.05, Colors.white);
}

void _die(
  _Surface s,
  Offset at,
  double k,
  double angle,
  Color color,
  List<int> pips,
) {
  s.c.save();
  s.c.translate(at.dx, at.dy);
  s.c.rotate(angle);
  s.rrect(
    Rect.fromCenter(center: Offset.zero, width: k, height: k),
    k * 0.18,
    color,
  );
  const grid = {
    1: [Offset(0, 0)],
    2: [Offset(-1, -1), Offset(1, 1)],
    3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
    4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
    5: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(0, 0),
      Offset(-1, 1),
      Offset(1, 1),
    ],
    6: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, 1),
      Offset(1, 1),
    ],
  };
  for (final p in grid[pips.first]!) {
    s.circle(
      Offset(p.dx * k * 0.24, p.dy * k * 0.24),
      k * 0.075,
      const Color(0xFF2A1A4A),
    );
  }
  s.c.restore();
}

void _games(_Surface s) {
  s.sky(const [Color(0xFF1D8F8A), Color(0xFF5B4BB5)]);
  s.glow(Offset(s.cx, s.cy), s.u * 0.8, const Color(0xFF9EF0E0), 0.35);
  final u = s.u;
  // Cards fanned behind.
  for (final a in const [-0.35, 0.0, 0.35]) {
    s.c.save();
    s.c.translate(s.cx, s.cy + u * 0.3);
    s.c.rotate(a);
    s.rrect(
      Rect.fromLTWH(-u * 0.14, -u * 0.62, u * 0.28, u * 0.4),
      u * 0.03,
      Colors.white,
    );
    s.circle(
      Offset(0, -u * 0.42),
      u * 0.045,
      a == 0 ? const Color(0xFFD9532B) : const Color(0xFF2A1A4A),
    );
    s.c.restore();
  }
  _die(
    s,
    Offset(s.cx - u * 0.2, s.cy + u * 0.14),
    u * 0.34,
    -0.3,
    const Color(0xFFFFFFFF),
    const [5],
  );
  _die(
    s,
    Offset(s.cx + u * 0.22, s.cy + u * 0.2),
    u * 0.3,
    0.38,
    const Color(0xFFFFD66B),
    const [3],
  );
  s.star(
    Offset(s.cx - u * 0.45, s.cy - u * 0.15),
    u * 0.04,
    const Color(0xFFFFE27A),
  );
  s.star(Offset(s.cx + u * 0.46, s.cy - u * 0.2), u * 0.035, Colors.white);
}

void _sports(_Surface s) {
  s.sky(const [Color(0xFFBCE3F5), Color(0xFFE7F5D8)], const [0, 0.55]);
  final u = s.u;
  s.glow(Offset(s.w * 0.8, s.h * 0.2), u * 0.5, const Color(0xFFFFF0A8), 0.9);
  // Field with lane stripes.
  s.c.drawPath(
    ridgePath(s.size, const [
      Offset(0, 0.62),
      Offset(0.5, 0.6),
      Offset(1, 0.62),
    ]),
    s.fill(const Color(0xFF5BAA4B)),
  );
  for (var i = 0; i < 4; i++) {
    final y = s.h * (0.7 + i * 0.075);
    s.c.drawRect(
      Rect.fromLTRB(0, y, s.w, y + s.h * 0.035),
      s.fill(Colors.white.withValues(alpha: 0.22)),
    );
  }
  // Shuttle/ball: a ball with panels, with a motion trail.
  final bx = s.cx;
  final by = s.cy - u * 0.02;
  for (var i = 1; i <= 3; i++) {
    s.circle(
      Offset(bx - u * 0.14 * i, by + u * 0.08 * i),
      u * (0.2 - i * 0.04),
      Colors.white.withValues(alpha: 0.28 - i * 0.07),
    );
  }
  s.circle(Offset(bx, by), u * 0.22, Colors.white);
  s.c.drawCircle(
    Offset(bx, by),
    u * 0.22,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.012
      ..color = const Color(0xFF2A3A4A),
  );
  final pent = Path();
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 5;
    final o = Offset(
      bx + math.cos(a) * u * 0.085,
      by + math.sin(a) * u * 0.085,
    );
    i == 0 ? pent.moveTo(o.dx, o.dy) : pent.lineTo(o.dx, o.dy);
  }
  s.c.drawPath(pent..close(), s.fill(const Color(0xFF2A3A4A)));
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 5;
    s.c.drawLine(
      Offset(bx + math.cos(a) * u * 0.085, by + math.sin(a) * u * 0.085),
      Offset(bx + math.cos(a) * u * 0.21, by + math.sin(a) * u * 0.21),
      Paint()
        ..color = const Color(0xFF2A3A4A)
        ..strokeWidth = u * 0.012,
    );
  }
}

void _art(_Surface s) {
  s.sky(const [Color(0xFFFDE4EC), Color(0xFFF9C5D5)]);
  final u = s.u;
  s.glow(Offset(s.cx, s.cy), u * 0.8, Colors.white, 0.7);
  // Palette blob with a thumb hole.
  final cx = s.cx;
  final cy = s.cy + u * 0.02;
  final pal = Path()
    ..moveTo(cx - u * 0.38, cy)
    ..cubicTo(
      cx - u * 0.4,
      cy - u * 0.34,
      cx + u * 0.1,
      cy - u * 0.42,
      cx + u * 0.36,
      cy - u * 0.18,
    )
    ..cubicTo(
      cx + u * 0.5,
      cy - u * 0.02,
      cx + u * 0.26,
      cy + u * 0.1,
      cx + u * 0.18,
      cy + u * 0.1,
    )
    ..cubicTo(
      cx + u * 0.06,
      cy + u * 0.1,
      cx + u * 0.08,
      cy + u * 0.3,
      cx - u * 0.1,
      cy + u * 0.3,
    )
    ..cubicTo(
      cx - u * 0.3,
      cy + u * 0.3,
      cx - u * 0.37,
      cy + u * 0.16,
      cx - u * 0.38,
      cy,
    )
    ..close();
  s.c.drawShadow(pal, Colors.black54, 4, true);
  s.c.drawPath(pal, s.fill(const Color(0xFFF3D3A6)));
  s.circle(
    Offset(cx - u * 0.12, cy + u * 0.12),
    u * 0.045,
    const Color(0xFFFDE4EC),
  );
  for (final d in [
    (Offset(-0.26, -0.1), const Color(0xFFD9532B)),
    (Offset(-0.12, -0.24), const Color(0xFFFFC107)),
    (Offset(0.06, -0.27), const Color(0xFF2E8B83)),
    (Offset(0.22, -0.18), const Color(0xFF7B4FB5)),
    (Offset(0.28, -0.04), const Color(0xFF2F6FBF)),
  ]) {
    s.circle(Offset(cx + u * d.$1.dx, cy + u * d.$1.dy), u * 0.055, d.$2);
  }
  // Brush.
  s.c.save();
  s.c.translate(cx + u * 0.3, cy + u * 0.28);
  s.c.rotate(-0.9);
  s.rrect(
    Rect.fromLTWH(-u * 0.018, -u * 0.5, u * 0.036, u * 0.4),
    u * 0.012,
    const Color(0xFF8B5A2B),
  );
  s.rrect(
    Rect.fromLTWH(-u * 0.026, -u * 0.12, u * 0.052, u * 0.06),
    u * 0.01,
    const Color(0xFFB8B8C0),
  );
  s.c.drawPath(
    Path()
      ..moveTo(-u * 0.026, -u * 0.06)
      ..quadraticBezierTo(0, u * 0.1, u * 0.026, -u * 0.06)
      ..close(),
    s.fill(const Color(0xFFD9532B)),
  );
  s.c.restore();
}

void _photo(_Surface s) {
  s.sky(const [Color(0xFF51647A), Color(0xFF8DA4B8)]);
  final u = s.u;
  s.glow(Offset(s.cx, s.cy), u * 0.8, const Color(0xFFD7E6F2), 0.45);
  final cx = s.cx;
  final cy = s.cy + u * 0.04;
  s.rrect(
    Rect.fromCenter(
      center: Offset(cx - u * 0.18, cy - u * 0.27),
      width: u * 0.2,
      height: u * 0.1,
    ),
    u * 0.03,
    const Color(0xFF2B3744),
  );
  s.rrect(
    Rect.fromCenter(center: Offset(cx, cy), width: u * 0.84, height: u * 0.54),
    u * 0.08,
    const Color(0xFF2B3744),
  );
  s.rrect(
    Rect.fromCenter(
      center: Offset(cx, cy - u * 0.13),
      width: u * 0.84,
      height: u * 0.2,
    ),
    u * 0.08,
    const Color(0xFFE8ECEF),
  );
  s.rrect(
    Rect.fromCenter(
      center: Offset(cx + u * 0.28, cy - u * 0.2),
      width: u * 0.1,
      height: u * 0.06,
    ),
    u * 0.02,
    const Color(0xFFFFC107),
  );
  s.circle(Offset(cx, cy + u * 0.03), u * 0.22, const Color(0xFFE8ECEF));
  s.circle(Offset(cx, cy + u * 0.03), u * 0.18, const Color(0xFF1B2530));
  s.circle(Offset(cx, cy + u * 0.03), u * 0.13, const Color(0xFF2F6FBF));
  s.circle(Offset(cx, cy + u * 0.03), u * 0.07, const Color(0xFF0F1822));
  s.circle(
    Offset(cx - u * 0.05, cy - u * 0.02),
    u * 0.03,
    Colors.white.withValues(alpha: 0.85),
  );
  s.star(
    Offset(cx + u * 0.46, cy - u * 0.34),
    u * 0.05,
    const Color(0xFFFFE27A),
  );
}

void _movie(_Surface s) {
  s.sky(const [Color(0xFF3A1230), Color(0xFF8E2A3E)]);
  final u = s.u;
  s.glow(Offset(s.cx, s.cy), u * 0.8, const Color(0xFFFF9A6B), 0.35);
  final cx = s.cx;
  final cy = s.cy + u * 0.06;
  // Clapperboard.
  s.rrect(
    Rect.fromCenter(
      center: Offset(cx, cy + u * 0.08),
      width: u * 0.74,
      height: u * 0.46,
    ),
    u * 0.04,
    const Color(0xFF1F1A24),
  );
  for (var i = 0; i < 3; i++) {
    s.rrect(
      Rect.fromLTWH(
        cx - u * 0.3 + i * u * 0.2,
        cy + u * 0.08,
        u * 0.1,
        u * 0.025,
      ),
      u * 0.01,
      const Color(0xFF5C5566),
    );
  }
  s.c.save();
  s.c.translate(cx - u * 0.37, cy - u * 0.15);
  s.c.rotate(-0.22);
  s.rrect(
    Rect.fromLTWH(0, -u * 0.1, u * 0.74, u * 0.1),
    u * 0.02,
    const Color(0xFF1F1A24),
  );
  for (var i = 0; i < 5; i++) {
    s.c.drawPath(
      Path()
        ..moveTo(u * 0.04 + i * u * 0.145, -u * 0.1)
        ..lineTo(u * 0.1 + i * u * 0.145, -u * 0.1)
        ..lineTo(u * 0.06 + i * u * 0.145, 0)
        ..lineTo(u * 0.0 + i * u * 0.145, 0)
        ..close(),
      s.fill(Colors.white),
    );
  }
  s.c.restore();
  s.rrect(
    Rect.fromLTWH(cx - u * 0.37, cy - u * 0.15, u * 0.74, u * 0.1),
    u * 0.02,
    const Color(0xFF1F1A24),
  );
  for (var i = 0; i < 5; i++) {
    s.c.drawPath(
      Path()
        ..moveTo(cx - u * 0.33 + i * u * 0.145, cy - u * 0.15)
        ..lineTo(cx - u * 0.27 + i * u * 0.145, cy - u * 0.15)
        ..lineTo(cx - u * 0.31 + i * u * 0.145, cy - u * 0.05)
        ..lineTo(cx - u * 0.37 + i * u * 0.145, cy - u * 0.05)
        ..close(),
      s.fill(Colors.white),
    );
  }
  s.star(Offset(cx, cy + u * 0.08), u * 0.08, const Color(0xFFFFC107));
  s.star(
    Offset(cx - u * 0.5, cy - u * 0.28),
    u * 0.04,
    const Color(0xFFFFE27A),
  );
  s.star(Offset(cx + u * 0.5, cy - u * 0.3), u * 0.035, Colors.white);
}

void _person(_Surface s, Offset head, double r, Color color) {
  s.circle(head, r, color);
  s.c.drawPath(
    Path()
      ..moveTo(head.dx - r * 1.7, head.dy + r * 3.1)
      ..quadraticBezierTo(
        head.dx - r * 1.7,
        head.dy + r * 1.35,
        head.dx,
        head.dy + r * 1.35,
      )
      ..quadraticBezierTo(
        head.dx + r * 1.7,
        head.dy + r * 1.35,
        head.dx + r * 1.7,
        head.dy + r * 3.1,
      )
      ..close(),
    s.fill(color),
  );
}

void _network(_Surface s) {
  s.sky(const [Color(0xFF1F5F8B), Color(0xFF2E8B83)]);
  final u = s.u;
  s.glow(Offset(s.cx, s.cy), u * 0.8, const Color(0xFF9EE6E0), 0.35);
  final a = Offset(s.cx - u * 0.3, s.cy + u * 0.02);
  final b = Offset(s.cx, s.cy - u * 0.12);
  final c = Offset(s.cx + u * 0.3, s.cy + u * 0.02);
  for (final l in [(a, b), (b, c), (a, c)]) {
    s.c.drawLine(
      l.$1,
      l.$2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = u * 0.012,
    );
  }
  _person(s, a, u * 0.075, const Color(0xFFFFE3B3));
  _person(s, b, u * 0.09, Colors.white);
  _person(s, c, u * 0.075, const Color(0xFFFFC27A));
  // Speech bubbles.
  s.rrect(
    Rect.fromLTWH(s.cx - u * 0.52, s.cy - u * 0.34, u * 0.26, u * 0.16),
    u * 0.05,
    Colors.white.withValues(alpha: 0.92),
  );
  s.rrect(
    Rect.fromLTWH(s.cx + u * 0.26, s.cy - u * 0.28, u * 0.26, u * 0.16),
    u * 0.05,
    const Color(0xFFFFD66B),
  );
  for (final dx in const [-0.46, -0.4, -0.34]) {
    s.circle(
      Offset(s.cx + u * dx, s.cy - u * 0.26),
      u * 0.016,
      const Color(0xFF1F5F8B),
    );
  }
  for (final dx in const [0.32, 0.38, 0.44]) {
    s.circle(
      Offset(s.cx + u * dx, s.cy - u * 0.2),
      u * 0.016,
      const Color(0xFF8A5A00),
    );
  }
}

void _travel(_Surface s) {
  s.sky(
    const [Color(0xFF4FA3E0), Color(0xFFA8DAF5), Color(0xFFFFE8C2)],
    const [0, 0.65, 1],
  );
  final u = s.u;
  s.circle(Offset(s.w * 0.8, s.h * 0.2), u * 0.12, const Color(0xFFFFE27A));
  s.cloud(Offset(s.w * 0.2, s.h * 0.3), u * 0.09, Colors.white);
  s.cloud(
    Offset(s.w * 0.78, s.h * 0.62),
    u * 0.07,
    Colors.white.withValues(alpha: 0.9),
  );
  // Plane with a dotted trail.
  final px = s.cx + u * 0.08;
  final py = s.cy - u * 0.2;
  final trail = Path()
    ..moveTo(s.w * 0.08, s.h * 0.62)
    ..cubicTo(
      s.w * 0.3,
      s.h * 0.62,
      s.w * 0.36,
      s.h * 0.3,
      px - u * 0.14,
      py + u * 0.03,
    );
  s.c.drawPath(
    trail,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.012
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round
      ..maskFilter = null,
  );
  s.c.save();
  s.c.translate(px, py);
  s.c.rotate(-0.4);
  s.c.drawPath(
    Path()
      ..moveTo(-u * 0.14, 0)
      ..quadraticBezierTo(0, -u * 0.045, u * 0.15, 0)
      ..quadraticBezierTo(0, u * 0.045, -u * 0.14, 0)
      ..close(),
    s.fill(Colors.white),
  );
  s.c.drawPath(
    Path()
      ..moveTo(-u * 0.02, 0)
      ..lineTo(-u * 0.1, -u * 0.12)
      ..lineTo(-u * 0.05, -u * 0.12)
      ..lineTo(u * 0.05, 0)
      ..lineTo(-u * 0.05, u * 0.12)
      ..lineTo(-u * 0.1, u * 0.12)
      ..close(),
    s.fill(const Color(0xFFE5EEF5)),
  );
  s.c.restore();
  // Suitcase.
  final cx = s.cx;
  final cy = s.h * 0.74;
  s.stroke(
    Path()
      ..moveTo(cx - u * 0.05, cy - u * 0.14)
      ..lineTo(cx - u * 0.05, cy - u * 0.2)
      ..lineTo(cx + u * 0.05, cy - u * 0.2)
      ..lineTo(cx + u * 0.05, cy - u * 0.14),
    const Color(0xFF8B3A1D),
    u * 0.022,
  );
  s.rrect(
    Rect.fromCenter(center: Offset(cx, cy), width: u * 0.42, height: u * 0.28),
    u * 0.04,
    const Color(0xFFD9532B),
  );
  s.rrect(
    Rect.fromCenter(
      center: Offset(cx - u * 0.12, cy),
      width: u * 0.03,
      height: u * 0.28,
    ),
    0,
    const Color(0xFFF0A184),
  );
  s.rrect(
    Rect.fromCenter(
      center: Offset(cx + u * 0.12, cy),
      width: u * 0.03,
      height: u * 0.28,
    ),
    0,
    const Color(0xFFF0A184),
  );
  s.star(Offset(cx, cy), u * 0.045, const Color(0xFFFFE27A));
}

void _explore(_Surface s) {
  s.sky(const [Color(0xFFD7EFE9), Color(0xFFF7E8C8)]);
  final u = s.u;
  s.glow(Offset(s.cx, s.cy), u * 0.8, Colors.white, 0.7);
  // Dotted route and pin.
  final route = Path()
    ..moveTo(s.w * 0.1, s.h * 0.82)
    ..cubicTo(
      s.w * 0.3,
      s.h * 0.55,
      s.w * 0.15,
      s.h * 0.4,
      s.cx - u * 0.1,
      s.cy + u * 0.18,
    );
  s.stroke(route, const Color(0xFF2E8B83).withValues(alpha: 0.7), u * 0.018);
  final cx = s.cx;
  final cy = s.cy;
  // Compass.
  s.circle(Offset(cx, cy), u * 0.38, const Color(0xFF0F4C45));
  s.circle(Offset(cx, cy), u * 0.33, const Color(0xFFFFF7E3));
  for (var i = 0; i < 24; i++) {
    final a = i * math.pi / 12;
    final long = i % 6 == 0;
    s.c.drawLine(
      Offset(cx + math.cos(a) * u * 0.3, cy + math.sin(a) * u * 0.3),
      Offset(
        cx + math.cos(a) * u * (long ? 0.24 : 0.27),
        cy + math.sin(a) * u * (long ? 0.24 : 0.27),
      ),
      Paint()
        ..color = const Color(0xFF0F4C45)
        ..strokeWidth = u * (long ? 0.014 : 0.008),
    );
  }
  s.c.save();
  s.c.translate(cx, cy);
  s.c.rotate(0.6);
  s.c.drawPath(
    Path()
      ..moveTo(0, -u * 0.22)
      ..lineTo(u * 0.05, 0)
      ..lineTo(-u * 0.05, 0)
      ..close(),
    s.fill(const Color(0xFFD9532B)),
  );
  s.c.drawPath(
    Path()
      ..moveTo(0, u * 0.22)
      ..lineTo(u * 0.05, 0)
      ..lineTo(-u * 0.05, 0)
      ..close(),
    s.fill(const Color(0xFF0F4C45)),
  );
  s.c.restore();
  s.circle(Offset(cx, cy), u * 0.025, const Color(0xFFE99A32));
  // Map pin.
  final pin = Offset(s.w * 0.82, s.h * 0.3);
  s.c.drawPath(
    Path()
      ..moveTo(pin.dx, pin.dy + u * 0.14)
      ..cubicTo(
        pin.dx - u * 0.14,
        pin.dy,
        pin.dx - u * 0.1,
        pin.dy - u * 0.12,
        pin.dx,
        pin.dy - u * 0.12,
      )
      ..cubicTo(
        pin.dx + u * 0.1,
        pin.dy - u * 0.12,
        pin.dx + u * 0.14,
        pin.dy,
        pin.dx,
        pin.dy + u * 0.14,
      )
      ..close(),
    s.fill(const Color(0xFFE99A32)),
  );
  s.circle(Offset(pin.dx, pin.dy - u * 0.03), u * 0.035, Colors.white);
}
