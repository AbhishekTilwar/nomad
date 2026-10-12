import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "You are here": a small radar. A soft sweep rotates around the dot, two
/// rings pulse outward, and the centre breathes. Purely decorative, so it never
/// intercepts taps meant for pins underneath.
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key, this.color});

  final Color? color;

  /// Marker box; the radar itself fills it, the dot sits in the middle.
  static const double size = 52;

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Semantics(
        label: 'Your location',
        child: SizedBox(
          width: UserLocationMarker.size,
          height: UserLocationMarker.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _RadarPainter(color: color, t: _c.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.color, required this.t});
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;

    // Faint range disc.
    canvas.drawCircle(c, r - 1, Paint()..color = color.withValues(alpha: 0.08));

    // Rotating sweep: a wedge that fades out behind a bright leading edge.
    final angle = t * math.pi * 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r - 2);
    canvas.drawCircle(
      Offset.zero,
      r - 2,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.38),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(r - 2, 0),
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.7),
    );
    canvas.restore();

    // Two staggered pulse rings.
    for (final k in const [0.0, 0.5]) {
      final p = (t + k) % 1;
      canvas.drawCircle(
        c,
        5 + (r - 6) * Curves.easeOut.transform(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.45 * (1 - p)),
      );
    }

    // The dot: white ring, soft shadow, gentle breathing.
    final breathe = 1 + 0.08 * math.sin(t * math.pi * 4);
    canvas.drawCircle(
      c.translate(0, 1),
      7 * breathe,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(c, 6.5 * breathe, Paint()..color = Colors.white);
    canvas.drawCircle(c, 4.5 * breathe, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RadarPainter o) => o.t != t || o.color != color;
}
