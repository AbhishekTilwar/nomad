import 'package:flutter/material.dart';

/// WhatsApp-style chat wallpaper: a soft warm tint with a faint tiled doodle
/// of travel icons. Painted once (no repaints while messages scroll).
class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key, required this.child});
  final Widget child;

  static const _light = Color(0xFFEFE8DD);
  static const _dark = Color(0xFF0E1621);

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
                painter: _DoodlePainter(
                  color: (dark ? Colors.white : const Color(0xFF6B5B45))
                      .withValues(alpha: dark ? 0.05 : 0.09),
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

class _DoodlePainter extends CustomPainter {
  const _DoodlePainter({required this.color});
  final Color color;

  static const _icons = <IconData>[
    Icons.flight_takeoff,
    Icons.landscape_outlined,
    Icons.local_cafe_outlined,
    Icons.camera_alt_outlined,
    Icons.explore_outlined,
    Icons.directions_walk,
    Icons.luggage_outlined,
    Icons.music_note_outlined,
    Icons.favorite_border,
    Icons.map_outlined,
    Icons.wb_sunny_outlined,
    Icons.restaurant_outlined,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 64.0;
    var n = 0;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      final odd = (y / cell).floor().isOdd;
      for (var x = odd ? -cell / 2 : 0.0; x < size.width + cell; x += cell) {
        final icon = _icons[(n * 5 + (y ~/ cell)) % _icons.length];
        n++;
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 22,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(x + cell / 2, y + cell / 2);
        canvas.rotate(((n % 7) - 3) * 0.12);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.color != color;
}
