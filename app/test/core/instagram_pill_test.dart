import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/widgets/instagram_pill.dart';

void main() {
  testWidgets(
    'pill gradient is visible on an opaque panel (regression: Ink hid it)',
    (t) async {
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Mirrors the public profile: an opaque panel inside a Scaffold.
            body: Container(
              color: Colors.white,
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.all(20),
              child: RepaintBoundary(
                key: key,
                child: InstagramPill(handle: 'asha_r', onTap: () {}),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await t.runAsync(() async {
        final image = await boundary.toImage();
        return (
          image.width,
          await image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
      });
      final (w, data) = bytes!;
      // A pixel in the pill's left padding (clear of the icon and text).
      const x = 5, y = 12;
      final i = (y * w + x) * 4;
      final r = data!.getUint8(i);
      final g = data.getUint8(i + 1);
      final a = data.getUint8(i + 3);
      // Old Ink version: the gradient was painted outside this subtree, so the
      // pixel here is fully transparent.
      expect(a, 255, reason: 'pill must paint its own opaque background');
      expect(r, greaterThan(100));
      expect(g, lessThan(120), reason: 'purple end of the gradient');
    },
  );
}
