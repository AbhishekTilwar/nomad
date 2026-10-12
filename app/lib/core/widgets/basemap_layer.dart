import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../config/map_config.dart';
import '../services/basemap_style.dart';

/// Warm, colourful street basemap (land use, parks, water, roads, buildings,
/// area names and landmarks).
/// Shows the raster [MapConfig] tiles while the style loads or if it fails.
class BasemapLayer extends StatefulWidget {
  const BasemapLayer({
    super.key,
    required this.config,
    this.onTileError,
    this.bundledTiles,
  });

  final MapConfig config;
  final VoidCallback? onTileError;

  /// Asset template (`assets/map/{z}/{x}/{y}.png`, zoom 12 only) drawn under
  /// the raster tiles so an area still shows a map when offline.
  final String? bundledTiles;

  @override
  State<BasemapLayer> createState() => _BasemapLayerState();
}

class _BasemapLayerState extends State<BasemapLayer> {
  Future<BasemapStyle?>? _style;
  bool? _dark;
  Timer? _retry;
  int _attempts = 0;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _load(bool dark) {
    _retry?.cancel();
    final f = BasemapStyle.load(dark: dark);
    _style = f;
    f.then((style) {
      if (!mounted || style != null || _style != f) return;
      // Couldn't fetch the style (slow or offline): keep the raster fallback
      // showing and try again shortly, a few times.
      if (_attempts++ >= 5) return;
      _retry = Timer(Duration(seconds: 4 * _attempts), () {
        if (mounted) setState(() => _load(dark));
      });
    });
  }

  MapConfig get config => widget.config;
  VoidCallback? get onTileError => widget.onTileError;
  String? get bundledTiles => widget.bundledTiles;

  @override
  Widget build(BuildContext context) {
    // One style per brightness, fetched only when the phone switches themes
    // (not on every rebuild).
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_dark != dark) {
      _dark = dark;
      _attempts = 0;
      _load(dark);
    }
    return FutureBuilder<BasemapStyle?>(
      key: ValueKey(dark),
      future: _style,
      builder: (context, snap) {
        final style = snap.data;
        if (style == null) {
          final live = TileLayer(
            urlTemplate: config.tileUrlTemplate,
            userAgentPackageName: config.userAgentPackageName,
            maxNativeZoom: config.maxZoom,
            errorTileCallback: onTileError == null
                ? null
                : (_, _, _) => onTileError!(),
          );
          if (bundledTiles == null) return live;
          return Stack(
            children: [
              TileLayer(
                urlTemplate: bundledTiles,
                tileProvider: AssetTileProvider(),
                minNativeZoom: 12,
                maxNativeZoom: 12,
                errorTileCallback: (_, _, _) {},
              ),
              live,
            ],
          );
        }
        return VectorTileLayer(
          theme: style.theme,
          tileProviders: style.providers,
          sprites: style.sprites,
          layerMode: VectorTileLayerMode.vector,
          maximumZoom: 20,
          showTileDebugInfo: false,
        );
      },
    );
  }
}
