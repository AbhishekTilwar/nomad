import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// OpenFreeMap "bright" style (free, no key), re-coloured into a warm,
/// lively street map: tinted land use, green parks, blue water and rivers,
/// colour-coded roads, buildings, road names, neighbourhood names and
/// landmark labels. Noise (tunnels, paths, boundaries, shields, rail yards)
/// is removed.
class BasemapStyle {
  BasemapStyle(this.theme, this.providers, this.sprites);

  final Theme theme;
  final TileProviders providers;
  final SpriteStyle? sprites;

  static const _styleUrl = 'https://tiles.openfreemap.org/styles/bright';

  /// Layers dropped by id prefix or fragment.
  static const _dropPrefixes = [
    'landcover-glacier',
    'landcover-ice',
    'tunnel',
    'ferry',
    'cablecar',
    'boundary',
    'road_oneway',
    'road_pier',
    'road_area_pier',
    'railway-service',
    'railway-transit-hatching',
    'railway-hatching',
    'highway-path',
    'highway-name-path',
    'highway-shield',
    'road_shield',
    'bridge-path',
    'bridge-railway',
    'building-top',
    'waterway_tunnel',
    'waterway_line_label',
    'water_name_line_label',
    'label_country',
    'poi_transit',
    'aeroway-taxiway',
  ];

  static const _fills = {
    'background': '#f6f1e7',
    'landuse-residential': '#f1ebdf',
    'landuse-suburb': '#f1ebdf',
    'landuse-commercial': '#f7e5dd',
    'landuse-industrial': '#e9e5ef',
    'landuse-cemetery': '#d7e9cd',
    'landuse-hospital': '#fbe1e1',
    'landuse-school': '#f6ebc8',
    'landuse-railway': '#ece6dc',
    'park': '#cdeab0',
    'landcover-grass-park': '#cdeab0',
    'landcover-grass': '#d7edbb',
    'landcover-wood': '#bddfa0',
    'landcover-sand': '#f7e9bd',
    'water': '#a8d8f5',
    'water-intermittent': '#bfe2f7',
    'building': '#eadfce',
    'aeroway-area': '#ebe6f0',
    'highway-area': '#ffffff',
  };

  static const _fillsDark = {
    'background': '#18211f',
    'landuse-residential': '#1c2624',
    'landuse-suburb': '#1c2624',
    'landuse-commercial': '#2a2423',
    'landuse-industrial': '#232230',
    'landuse-cemetery': '#1d3427',
    'landuse-hospital': '#352225',
    'landuse-school': '#302c1d',
    'landuse-railway': '#202826',
    'park': '#1f3b2c',
    'landcover-grass-park': '#1f3b2c',
    'landcover-grass': '#1d3527',
    'landcover-wood': '#1a3224',
    'landcover-sand': '#34301f',
    'water': '#16364a',
    'water-intermittent': '#1a3c52',
    'building': '#27312f',
    'aeroway-area': '#232830',
    'highway-area': '#34403d',
  };

  /// Road class → (fill, casing, width multiplier) on the dark map.
  static (String, String, double)? _roadDark(String id) {
    if (id.contains('motorway')) return ('#b98648', '#7a5424', 1.5);
    if (id.contains('trunk') || id.contains('primary')) {
      return ('#8f7047', '#5d4829', 1.3);
    }
    if (id.contains('secondary') || id.contains('tertiary')) {
      return ('#5f5a47', '#3e3b30', 1.1);
    }
    if (id.contains('minor') || id.contains('link')) {
      return ('#46514e', '#2b3331', 0.8);
    }
    return null;
  }

  /// Road class → (fill, casing, width multiplier).
  static (String, String, double)? _road(String id) {
    if (id.contains('motorway')) return ('#f9b878', '#e09a54', 1.5);
    if (id.contains('trunk') || id.contains('primary')) {
      return ('#fcd9a0', '#e8bb76', 1.3);
    }
    if (id.contains('secondary') || id.contains('tertiary')) {
      return ('#fff7dc', '#e8dfc0', 1.1);
    }
    if (id.contains('minor') || id.contains('link')) {
      return ('#ffffff', '#e0d9cc', 0.8);
    }
    return null;
  }

  /// Builds a fresh style (new tile providers every time: a layer disposes its
  /// providers, so a style object must not be shared between layers). Null
  /// when it can't be fetched (offline); callers fall back to raster tiles.
  static Future<BasemapStyle?> load({bool dark = false}) => _fetch(dark);

  static Future<BasemapStyle?> _fetch(bool dark) async {
    try {
      final res = await http
          .get(Uri.parse(_styleUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      json['layers'] = [
        for (final l in json['layers'] as List)
          if (_keep((l as Map<String, dynamic>)['id'] as String)) _recolor(l, dark),
      ];
      final base = await StyleReader(uri: _styleUrl).read();
      return BasemapStyle(
        ThemeReader().read(json),
        base.providers,
        base.sprites,
      );
    } catch (e) {
      debugPrint('Basemap style unavailable: $e');
      return null;
    }
  }

  static Map<String, dynamic> _recolor(
    Map<String, dynamic> layer,
    bool dark,
  ) {
    final id = layer['id'] as String;
    final type = layer['type'] as String;
    final paint = Map<String, dynamic>.from((layer['paint'] ?? {}) as Map);

    if (dark && type == 'symbol') {
      // Light text with a dark halo so names stay readable on the dark map.
      paint['text-color'] = id.startsWith('water') ? '#7fb4d6' : '#d5dedb';
      paint['text-halo-color'] = dark ? '#18211f' : '#ffffff';
      paint['icon-opacity'] = 0.85;
      return {...layer, 'paint': paint};
    }

    final fill = (dark ? _fillsDark : _fills)[id];
    if (fill != null && (type == 'fill' || type == 'background')) {
      paint[type == 'background' ? 'background-color' : 'fill-color'] = fill;
      return {...layer, 'paint': paint};
    }
    if (type == 'line' && id.startsWith('waterway')) {
      paint['line-color'] = dark ? '#16364a' : '#a8d8f5';
      return {...layer, 'paint': paint};
    }
    if (type == 'line' && id.startsWith('railway')) {
      paint['line-color'] = dark ? '#2e3a37' : '#cfc8bb';
      return {...layer, 'paint': paint};
    }
    if (type == 'line' && id.contains(RegExp('highway|bridge'))) {
      final road = dark ? _roadDark(id) : _road(id);
      if (road == null) return layer;
      final (fillColor, casingColor, k) = road;
      final casing = id.contains('casing');
      paint['line-color'] = casing ? casingColor : fillColor;
      paint['line-width'] = [
        'interpolate',
        ['exponential', 1.2],
        ['zoom'],
        8,
        (casing ? 0.8 : 0.4) * k,
        11,
        (casing ? 1.6 : 0.9) * k,
        14,
        (casing ? 5.0 : 3.2) * k,
        20,
        (casing ? 20.0 : 15.0) * k,
      ];
      paint.remove('line-gap-width');
      return {...layer, 'paint': paint};
    }
    return layer;
  }

  static bool _keep(String id) => !_dropPrefixes.any(id.startsWith);
}
