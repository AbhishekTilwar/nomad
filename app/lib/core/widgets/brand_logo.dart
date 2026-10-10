import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Brand lock-up: a line-art mountain-peaks mark above a handwritten-script
/// "Nomad Mingle" wordmark (font family `NomadScript`).
///
/// [size] is the wordmark font size; the icon scales with it. Set [onDark]
/// for white-on-photo use, otherwise the logo is dark navy.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 44,
    this.showWordmark = true,
    this.onDark = false,
  });

  final bool onDark;
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppColors.navy;
    final iconW = size * 1.15;
    return Semantics(
      label: 'Nomad Mingle',
      image: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(iconW, iconW * 0.62),
              painter: PeaksIconPainter(color: color),
            ),
            if (showWordmark)
              Text(
                'Nomad Mingle',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'NomadScript',
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                  color: color,
                  height: 1.1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two overlapping mountain peaks drawn as a line icon.
class PeaksIconPainter extends CustomPainter {
  const PeaksIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.045).clamp(1.5, 3.0)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // Back (tall) peak.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, h * 0.96)
        ..lineTo(w * 0.40, h * 0.06)
        ..lineTo(w * 0.62, h * 0.55),
      stroke,
    );
    // Front (shorter) peak with a snow-line zigzag.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, h * 0.96)
        ..lineTo(w * 0.66, h * 0.30)
        ..lineTo(w * 0.94, h * 0.96)
        ..close(),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.55, h * 0.52)
        ..lineTo(w * 0.62, h * 0.60)
        ..lineTo(w * 0.68, h * 0.50)
        ..lineTo(w * 0.75, h * 0.60),
      stroke,
    );
  }

  @override
  bool shouldRepaint(PeaksIconPainter old) => old.color != color;
}
