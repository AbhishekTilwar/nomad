import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// OpenFreeMap "bright" style (free, no key) trimmed to a low-detail look:
/// landcover, water, and major roads. Buildings, POIs, labels, minor roads,
/// paths and rail are removed.
class BasemapStyle {
  BasemapStyle(this.theme, this.providers);

  final Theme theme;
  final TileProviders providers;

  static const _styleUrl = 'https://tiles.openfreemap.org/styles/bright';

  static const _keepPrefixes = [
    'background',
    'landcover-grass',
    'landcover-wood',
    'landcover-sand',
    'park',
    'water',
    'highway-motorway',
    'highway-trunk',
    'highway-primary',
    'highway-secondary-tertiary',
    'bridge-motorway',
    'bridge-trunk-primary',
    'bridge-secondary-tertiary',
    // Basic labels: places, neighbourhoods and water.
    'label_city',
    'label_town',
    'label_village',
    'label_other',
    'label_state',
    'water_name',
  ];

  static const _dropContains = ['link', 'waterway', 'line_label', 'shield'];

  static Future<BasemapStyle?>? _cached;

  /// Null when the style can't be fetched (offline); callers fall back to
  /// raster tiles. A failed load is retried on the next call.
  static Future<BasemapStyle?> load() {
    return _cached ??= _fetch().then((s) {
      if (s == null) _cached = null;
      return s;
    });
  }

  static Future<BasemapStyle?> _fetch() async {
    try {
      final res = await http
          .get(Uri.parse(_styleUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      json['layers'] = [
        for (final l in json['layers'] as List)
          if (_keep((l as Map<String, dynamic>)['id'] as String)) _soften(l),
      ];
      final base = await StyleReader(uri: _styleUrl).read();
      return BasemapStyle(ThemeReader().read(json), base.providers);
    } catch (e) {
      debugPrint('Basemap style unavailable: $e');
      return null;
    }
  }

  /// Roads become thin and white (casings pale gray) for a calm look.
  static Map<String, dynamic> _soften(Map<String, dynamic> layer) {
    final id = layer['id'] as String;
    if (layer['type'] != 'line' || !id.contains(RegExp('highway|bridge'))) {
      return layer;
    }
    final casing = id.contains('casing');
    final paint = Map<String, dynamic>.from(layer['paint'] as Map);
    paint['line-color'] = casing ? '#dedbd5' : '#ffffff';
    paint['line-width'] = [
      'interpolate',
      ['exponential', 1.2],
      ['zoom'],
      8,
      casing ? 1.0 : 0.6,
      14,
      casing ? 4.0 : 2.6,
      20,
      casing ? 16.0 : 12.0,
    ];
    paint.remove('line-gap-width');
    return {...layer, 'paint': paint};
  }

  static bool _keep(String id) =>
      _keepPrefixes.any(id.startsWith) && !_dropContains.any(id.contains);
}
