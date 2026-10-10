import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chat wallpaper: a near-white indigo wash with faint topographic contour
/// lines (a trail-map motif that fits Nomad Mingle) and a sprinkle of tiny
/// stars. Painted once, so scrolling messages never repaint it.
class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key, required this.child});
  final Widget child;

  static const _light = Color(0xFFF8F9FF);
  static const _dark = Color(0xFF141622);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? _dark : _light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TopoPainter(
                  line:
                      (dark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          .withValues(alpha: dark ? 0.10 : 0.07),
                  dot: (dark ? Colors.white : const Color(0xFF4F46E5))
                      .withValues(alpha: dark ? 0.10 : 0.10),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _TopoPainter extends CustomPainter {
  const _TopoPainter({required this.line, required this.dot});
  final Color line;
  final Color dot;

  // Deterministic "hills": centre as a fraction of the canvas, base radius
  // in logical px, and a phase so no two look alike.
  static const _hills = <(double, double, double, double)>[
    (0.15, 0.10, 150, 0.4),
    (0.88, 0.28, 190, 1.7),
    (0.20, 0.52, 170, 2.9),
    (0.80, 0.74, 200, 4.1),
    (0.30, 0.95, 160, 5.3),
  ];

  Path _ring(Offset c, double r, double phase) {
    final path = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      // Layered sines give an organic, hand-drawn contour.
      final wobble =
          1 +
          0.10 * math.sin(a * 3 + phase) +
          0.06 * math.sin(a * 5 - phase * 1.3) +
          0.03 * math.sin(a * 9 + phase * 2);
      final p = Offset(
        c.dx + math.cos(a) * r * wobble * 1.15,
        c.dy + math.sin(a) * r * wobble * 0.85,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = line;
    for (final (fx, fy, radius, phase) in _hills) {
      final c = Offset(size.width * fx, size.height * fy);
      for (var r = radius; r > 18; r -= 22) {
        canvas.drawPath(_ring(c, r, phase + r * 0.004), stroke);
      }
    }

    // Tiny four-point stars / dots on a loose deterministic scatter.
    final fill = Paint()..color = dot;
    final rnd = math.Random(7);
    final count = (size.width * size.height / 14000).clamp(12, 80).toInt();
    for (var i = 0; i < count; i++) {
      final p = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      if (i % 4 == 0) {
        final s = 3.0 + rnd.nextDouble() * 2;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - s)
            ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
            ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s),
          fill,
        );
      } else {
        canvas.drawCircle(p, 1.2, fill);
      }
    }
  }

  @override
  bool shouldRepaint(_TopoPainter old) => old.line != line || old.dot != dot;
}
