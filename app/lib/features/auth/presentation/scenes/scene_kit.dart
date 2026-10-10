import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small drawing helpers shared by the hero scene painters. Everything is
/// vector so no photo assets are needed.

/// Fills [rect] with a vertical gradient.
void paintSky(
  Canvas canvas,
  Rect rect,
  List<Color> colors,
  List<double> stops,
) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(rect),
  );
}

/// Soft radial glow (sun, fire, haze).
void paintGlow(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double alpha = 1,
}) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.35, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

/// Smooth ridge line through fractional [pts] (x,y in 0..1 of [size]),
/// closed down to [bottom] (fraction of height).
Path ridgePath(Size size, List<Offset> pts, {double bottom = 1}) {
  final p = Offset(size.width, size.height);
  final o = [for (final q in pts) Offset(q.dx * p.dx, q.dy * p.dy)];
  final path = Path()..moveTo(o.first.dx, size.height * bottom);
  path.lineTo(o.first.dx, o.first.dy);
  for (var i = 0; i < o.length - 1; i++) {
    final mid = Offset(
      (o[i].dx + o[i + 1].dx) / 2,
      (o[i].dy + o[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(o[i].dx, o[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(o.last.dx, o.last.dy);
  path.lineTo(o.last.dx, size.height * bottom);
  path.close();
  return path;
}

/// Sharp peaked ridge (mountains) through fractional points.
Path peaksPath(Size size, List<Offset> pts, {double bottom = 1}) {
  final path = Path()..moveTo(pts.first.dx * size.width, size.height * bottom);
  for (final q in pts) {
    path.lineTo(q.dx * size.width, q.dy * size.height);
  }
  path.lineTo(pts.last.dx * size.width, size.height * bottom);
  path.close();
  return path;
}

/// A simple stacked-triangle pine with its base centred at [base].
void paintPine(Canvas canvas, Offset base, double h, Color color) {
  final paint = Paint()..color = color;
  final w = h * 0.42;
  for (var i = 0; i < 3; i++) {
    final top = base.dy - h + i * h * 0.24;
    final bot = base.dy - h * 0.18 * (2 - i) - h * 0.04;
    final half = w * (0.55 + i * 0.22) / 2 * 2;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, top)
        ..lineTo(base.dx + half / 1.6, bot)
        ..lineTo(base.dx - half / 1.6, bot)
        ..close(),
      paint,
    );
  }
}

/// Seated person seen from behind/side. [base] is bottom-centre; [k] is the
/// scale (1 ~ 46px tall).
void paintSeated(
  Canvas canvas,
  Offset base,
  double k,
  Color color, {
  bool backpack = false,
  Color? rim,
  bool faceLeft = false,
}) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  if (faceLeft) canvas.scale(-1, 1);
  final paint = Paint()..color = color;
  // Hips and legs folded forward.
  canvas.drawRRect(
    RRect.fromLTRBR(-11 * k, -13 * k, 15 * k, 0, Radius.circular(6 * k)),
    paint,
  );
  canvas.drawOval(Rect.fromLTRB(4 * k, -17 * k, 22 * k, -4 * k), paint);
  // Torso.
  canvas.drawRRect(
    RRect.fromLTRBR(-9 * k, -33 * k, 9 * k, -8 * k, Radius.circular(8 * k)),
    paint,
  );
  if (backpack) {
    canvas.drawRRect(
      RRect.fromLTRBR(
        -17 * k,
        -32 * k,
        -5 * k,
        -12 * k,
        Radius.circular(5 * k),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        -15 * k,
        -36 * k,
        -8 * k,
        -31 * k,
        Radius.circular(3 * k),
      ),
      paint,
    );
  }
  // Head.
  canvas.drawCircle(Offset(1 * k, -39 * k), 6 * k, paint);
  if (rim != null) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(1 * k, -39 * k), radius: 6 * k),
      -math.pi / 2.4,
      math.pi / 1.6,
      false,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * k,
    );
  }
  canvas.restore();
}

/// Standing backpacker seen from behind. [base] is bottom-centre of the feet.
void paintStanding(
  Canvas canvas,
  Offset base,
  double k,
  Color color, {
  bool backpack = true,
}) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  final paint = Paint()..color = color;
  // Legs.
  canvas.drawRRect(
    RRect.fromLTRBR(-8 * k, -30 * k, -1 * k, 0, Radius.circular(3 * k)),
    paint,
  );
  canvas.drawRRect(
    RRect.fromLTRBR(1 * k, -30 * k, 8 * k, 0, Radius.circular(3 * k)),
    paint,
  );
  // Torso.
  canvas.drawRRect(
    RRect.fromLTRBR(-10 * k, -62 * k, 10 * k, -26 * k, Radius.circular(9 * k)),
    paint,
  );
  // Arms.
  canvas.drawRRect(
    RRect.fromLTRBR(-14 * k, -58 * k, -8 * k, -34 * k, Radius.circular(3 * k)),
    paint,
  );
  canvas.drawRRect(
    RRect.fromLTRBR(8 * k, -58 * k, 14 * k, -34 * k, Radius.circular(3 * k)),
    paint,
  );
  if (backpack) {
    canvas.drawRRect(
      RRect.fromLTRBR(
        -14 * k,
        -64 * k,
        14 * k,
        -32 * k,
        Radius.circular(8 * k),
      ),
      paint,
    );
    // Rolled mat on top.
    canvas.drawRRect(
      RRect.fromLTRBR(
        -12 * k,
        -69 * k,
        12 * k,
        -63 * k,
        Radius.circular(3 * k),
      ),
      paint,
    );
  }
  // Head.
  canvas.drawCircle(Offset(0, -73 * k), 7 * k, paint);
  canvas.restore();
}

/// Deterministic star field in the top [fraction] of the canvas.
void paintStars(Canvas canvas, Size size, double fraction, {int count = 40}) {
  final rnd = math.Random(7);
  final p = Paint();
  for (var i = 0; i < count; i++) {
    final x = rnd.nextDouble() * size.width;
    final y = rnd.nextDouble() * size.height * fraction;
    p.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.55);
    canvas.drawCircle(Offset(x, y), 0.6 + rnd.nextDouble() * 0.9, p);
  }
}

/// Horizontal shimmer strokes on water.
void paintShimmer(Canvas canvas, Rect water, Color color, {int count = 14}) {
  final rnd = math.Random(3);
  final p = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.6;
  for (var i = 0; i < count; i++) {
    final t = (i + rnd.nextDouble()) / count;
    final y = water.top + water.height * (0.05 + t * 0.9);
    final w = 14 + rnd.nextDouble() * 50 * (0.4 + t);
    final x = water.left + rnd.nextDouble() * (water.width - w);
    p.color = color.withValues(alpha: 0.08 + 0.16 * (1 - t));
    canvas.drawLine(Offset(x, y), Offset(x + w, y), p);
  }
}
