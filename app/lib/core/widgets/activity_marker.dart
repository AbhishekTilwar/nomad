import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/category_style.dart';

/// Map pin: category-colored circle with icon; selected markers grow and gain a ring.
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

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final color = full ? Colors.grey.shade600 : CategoryStyle.color(category);
    return AnimatedScale(
      scale: selected ? 1.2 : 1,
      duration: AppMotion.fast,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: selected ? 3 : 2),
              boxShadow: AppShadows.card,
            ),
            child: Icon(
              CategoryStyle.icon(category),
              size: 18,
              color: Colors.white,
            ),
          ),
          CustomPaint(size: const Size(10, 7), painter: _Tip(color)),
        ],
      ),
    );
  }
}

class _Tip extends CustomPainter {
  _Tip(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Tip old) => old.color != color;
}
