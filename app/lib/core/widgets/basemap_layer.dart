import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../config/map_config.dart';
import '../services/basemap_style.dart';

/// Simplified, soft-colored basemap (water, parks, major roads only).
/// Shows the raster [MapConfig] tiles while the style loads or if it fails.
class BasemapLayer extends StatelessWidget {
  const BasemapLayer({super.key, required this.config, this.onTileError});

  final MapConfig config;
  final VoidCallback? onTileError;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BasemapStyle?>(
      future: BasemapStyle.load(),
      builder: (context, snap) {
        final style = snap.data;
        if (style == null) {
          return TileLayer(
            urlTemplate: config.tileUrlTemplate,
            userAgentPackageName: config.userAgentPackageName,
            maxNativeZoom: config.maxZoom,
            errorTileCallback: onTileError == null
                ? null
                : (_, _, _) => onTileError!(),
          );
        }
        return VectorTileLayer(
          theme: style.theme,
          tileProviders: style.providers,
          layerMode: VectorTileLayerMode.vector,
          maximumZoom: 20,
          showTileDebugInfo: false,
        );
      },
    );
  }
}
