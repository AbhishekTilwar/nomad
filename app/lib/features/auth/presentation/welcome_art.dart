import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dusk gradient used by the welcome screen and the intro illustration.
const kDuskGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF2E2A8F),
    Color(0xFF5A4DD1),
    Color(0xFFB4638F),
    Color(0xFFF08A5D),
    Color(0xFFF6B27A),
  ],
  stops: [0, 0.32, 0.58, 0.82, 1],
);

/// Painted Mumbai skyline with the Bandra-Worli sea-link and the sea below.
/// Everything is vector so no photo asset is needed.
class SkylinePainter extends CustomPainter {
  const SkylinePainter({this.showBridge = true});
  final bool showBridge;

  // (x fraction, width fraction, height fraction of the skyline band)
  static const _far = <List<double>>[
    [0.00, 0.07, 0.34],
    [0.06, 0.05, 0.50],
    [0.10, 0.06, 0.40],
    [0.16, 0.04, 0.62],
    [0.20, 0.07, 0.45],
    [0.27, 0.05, 0.56],
    [0.31, 0.06, 0.36],
    [0.38, 0.05, 0.48],
  ];
  static const _near = <List<double>>[
    [0.00, 0.08, 0.30],
    [0.07, 0.06, 0.58],
    [0.13, 0.07, 0.42],
    [0.19, 0.05, 0.74],
    [0.24, 0.07, 0.50],
    [0.31, 0.06, 0.64],
    [0.37, 0.07, 0.38],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final seaTop = h * 0.78;
    final band = h * 0.62; // max skyline height above the sea line

    // Distant haze buildings.
    final far = Paint()
      ..color = const Color(0xFF3A2F7A).withValues(alpha: 0.55);
    for (final b in _far) {
      canvas.drawRect(
        Rect.fromLTWH(
          b[0] * w,
          seaTop - b[2] * band * 0.8,
          b[1] * w + 1,
          b[2] * band * 0.8,
        ),
        far,
      );
    }
    // Sea.
    final seaRect = Rect.fromLTRB(0, seaTop, w, h);
    canvas.drawRect(
      seaRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B2D70), Color(0xFF181540)],
        ).createShader(seaRect),
    );
    // Soft reflections.
    final glint = Paint()
      ..color = const Color(0xFFF6B27A).withValues(alpha: 0.28)
      ..strokeWidth = 1.5;
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final y = seaTop + 6 + rnd.nextDouble() * (h - seaTop - 8);
      final x = w * (0.45 + rnd.nextDouble() * 0.5);
      final len = 8 + rnd.nextDouble() * 26;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), glint);
    }

    // Near skyline (left).
    final near = Paint()..color = const Color(0xFF1E1A52);
    final lit = Paint()..color = const Color(0xFFFFC878).withValues(alpha: 0.8);
    for (final b in _near) {
      final bw = b[1] * w;
      final bh = b[2] * band;
      final r = Rect.fromLTWH(b[0] * w, seaTop - bh, bw + 1, bh);
      canvas.drawRect(r, near);
      // lit windows
      for (var y = r.top + 8; y < seaTop - 6; y += 11) {
        for (var x = r.left + 4; x < r.right - 4; x += 8) {
          if (rnd.nextDouble() > 0.72) {
            canvas.drawRect(Rect.fromLTWH(x, y, 2.2, 3.4), lit);
          }
        }
      }
    }
    // Shore strip.
    canvas.drawRect(
      Rect.fromLTRB(0, seaTop - 3, w * 0.42, seaTop + 3),
      Paint()..color = const Color(0xFF141238),
    );

    if (!showBridge) return;

    // Sea link: deck + cable-stayed tower.
    final deckY = seaTop - h * 0.045;
    final dark = const Color(0xFF14113A);
    final deck = Paint()
      ..color = dark
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.34, deckY + 6), Offset(w, deckY - 6), deck);
    final towerX = w * 0.72;
    final towerTop = deckY - h * 0.42;
    final towerPaint = Paint()..color = dark;
    final tower = Path()
      ..moveTo(towerX - 9, deckY)
      ..lineTo(towerX - 3, towerTop + 40)
      ..lineTo(towerX - 1.2, towerTop)
      ..lineTo(towerX + 1.2, towerTop)
      ..lineTo(towerX + 3, towerTop + 40)
      ..lineTo(towerX + 9, deckY)
      ..lineTo(towerX + 4, deckY)
      ..lineTo(towerX, towerTop + 70)
      ..lineTo(towerX - 4, deckY)
      ..close();
    canvas.drawPath(tower, towerPaint);
    // Cables: fan from the tower to both sides of the deck.
    final cable = Paint()
      ..color = dark.withValues(alpha: 0.9)
      ..strokeWidth = 1.1;
    double deckAt(double x) {
      final t = (x - w * 0.34) / (w - w * 0.34);
      return (deckY + 6) + ((deckY - 6) - (deckY + 6)) * t;
    }

    for (var i = 1; i <= 9; i++) {
      final k = i / 9;
      final anchor = Offset(towerX, towerTop + 22 + k * 22);
      final left = towerX - 16 - k * w * 0.26;
      final right = towerX + 16 + k * w * 0.26;
      canvas.drawLine(anchor, Offset(left, deckAt(left)), cable);
      if (right < w) {
        canvas.drawLine(anchor, Offset(right, deckAt(right)), cable);
      }
    }
    // Deck lights.
    final light = Paint()..color = const Color(0xFFFFD79A);
    for (var x = w * 0.36; x < w; x += 14) {
      canvas.drawCircle(Offset(x, deckAt(x) - 3), 1.1, light);
    }
    // Second, smaller tower for depth.
    final t2 = w * 0.42;
    final t2Top = deckY - h * 0.16;
    canvas.drawPath(
      Path()
        ..moveTo(t2 - 5, deckY + 4)
        ..lineTo(t2 - 0.8, t2Top)
        ..lineTo(t2 + 0.8, t2Top)
        ..lineTo(t2 + 5, deckY + 4)
        ..close(),
      towerPaint,
    );
  }

  @override
  bool shouldRepaint(SkylinePainter old) => old.showBridge != showBridge;
}

/// White map pin with a ring of "people" inside (welcome logo mark).
class PinMarkPainter extends CustomPainter {
  const PinMarkPainter({this.pinColor = Colors.white, required this.inkColor});
  final Color pinColor;
  final Color inkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w / 2;
    final c = Offset(r, r);
    final d = size.height - r;
    final a = math.acos(r / d);
    final rect = Rect.fromCircle(center: c, radius: r);
    final path = Path()
      ..moveTo(r, size.height)
      ..lineTo(
        c.dx + r * math.cos(math.pi / 2 + a),
        c.dy + r * math.sin(math.pi / 2 + a),
      )
      ..arcTo(rect, math.pi / 2 + a, 2 * math.pi - 2 * a, false)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 8, true);
    canvas.drawPath(path, Paint()..color = pinColor);
    canvas.drawCircle(c, r * 0.72, Paint()..color = inkColor);
    // Three people: head + shoulders.
    final p = Paint()..color = Colors.white;
    void person(Offset o, double s) {
      canvas.drawCircle(o.translate(0, -s * 0.9), s * 0.55, p);
      canvas.drawArc(
        Rect.fromCenter(
          center: o.translate(0, s * 0.9),
          width: s * 2.2,
          height: s * 1.9,
        ),
        math.pi,
        math.pi,
        true,
        p,
      );
    }

    person(c.translate(-r * 0.34, r * 0.05), r * 0.2);
    person(c.translate(r * 0.34, r * 0.05), r * 0.2);
    person(c.translate(0, r * 0.12), r * 0.26);
  }

  @override
  bool shouldRepaint(PinMarkPainter old) =>
      old.pinColor != pinColor || old.inkColor != inkColor;
}
