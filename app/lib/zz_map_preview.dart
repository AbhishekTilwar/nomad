import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'core/config/map_config.dart';
import 'core/widgets/basemap_layer.dart';

void main() => runApp(
  MaterialApp(
    home: Scaffold(
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(19.0760, 72.8777),
          initialZoom: 13,
        ),
        children: [BasemapLayer(config: MapConfig.fromEnvironment())],
      ),
    ),
  ),
);
