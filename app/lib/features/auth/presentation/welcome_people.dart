import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Optional real photos for the welcome map (see
/// `assets/images/welcome/README.md`). Returns the ones that exist; a missing
/// or undecodable file is skipped, and with none the painter falls back to
/// illustrated avatars.
class WelcomePeople {
  const WelcomePeople._();

  static const assetNames = [
    'assets/images/welcome/person_1.jpg',
    'assets/images/welcome/person_2.jpg',
    'assets/images/welcome/person_3.jpg',
    'assets/images/welcome/person_4.jpg',
    'assets/images/welcome/person_5.jpg',
    'assets/images/welcome/person_6.jpg',
  ];

  static Future<List<ui.Image>> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final out = <ui.Image>[];
    for (final name in assetNames) {
      try {
        final data = await b.load(name);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 128, // plenty for a ~20 px avatar on a dense screen
        );
        out.add((await codec.getNextFrame()).image);
      } catch (_) {
        // Not provided (or unreadable): use the illustrated avatar instead.
      }
    }
    return out;
  }
}
