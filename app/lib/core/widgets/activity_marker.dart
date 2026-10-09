import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/category_style.dart';

/// Teardrop map pin (as in the design): category-coloured with a white centre
/// holding the category icon. Selected pins grow; full plans turn grey.
class ActivityMarker extends StatelessWidget {
  const ActivityMarker({
    super.key,
    required this.category,
    this.selected = false,
    this.full = false,
  });

  final String category;
  final bool selected;
  final bool full;

  static const double width = 36;
  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    final color = full ? Colors.grey.shade600 : CategoryStyle.color(category);
    return AnimatedScale(
      scale: selected ? 1.25 : 1,
      duration: AppMotion.fast,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            CustomPaint(
              size: const Size(36, 46),
              painter: _PinPainter(color, selected),
            ),
            Positioned(
              top: 9,
              child: Icon(CategoryStyle.icon(category), size: 15, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.color, this.selected);
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final c = Offset(r, r);
    final path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r - 1))
      ..moveTo(r - 9, r + 12)
      ..quadraticBezierTo(r - 3, r + 18, r, s.height - 1)
      ..quadraticBezierTo(r + 3, r + 18, r + 9, r + 12)
      ..close();
    canvas.drawShadow(path, Colors.black54, 3, true);
    canvas.drawPath(path, Paint()..color = color);
    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PinPainter o) =>
      o.color != color || o.selected != selected;
}
