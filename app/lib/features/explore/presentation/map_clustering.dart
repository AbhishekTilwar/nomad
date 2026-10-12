import 'dart:ui' show Offset;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../activities/models/activity.dart';

/// One or more plans drawn as a single marker at the current zoom.
class MapCluster {
  MapCluster(this.items)
    : center = LatLng(
        items.fold<double>(0, (s, a) => s + a.latitude) / items.length,
        items.fold<double>(0, (s, a) => s + a.longitude) / items.length,
      );

  final List<Activity> items;
  final LatLng center;

  bool get isSingle => items.length == 1;
}

/// Groups plans that would overlap on screen. Works in projected pixels at the
/// camera's zoom, so clusters split apart as you zoom in. The selected plan is
/// never absorbed into a cluster.
List<MapCluster> clusterActivities(
  List<Activity> items,
  MapCamera camera, {
  String? keepSingleId,
}) {
  // Pins are ~60x76 px; merge any that would visibly overlap.
  final dx = camera.zoom >= 15 ? 28.0 : 72.0;
  final dy = camera.zoom >= 15 ? 32.0 : 84.0;
  final groups = <({Offset at, List<Activity> items})>[];
  final out = <MapCluster>[];
  for (final a in items) {
    if (a.id == keepSingleId) {
      out.add(MapCluster([a]));
      continue;
    }
    final p = camera.projectAtZoom(a.position);
    var placed = false;
    for (final g in groups) {
      if ((g.at.dx - p.dx).abs() < dx && (g.at.dy - p.dy).abs() < dy) {
        g.items.add(a);
        placed = true;
        break;
      }
    }
    if (!placed) groups.add((at: p, items: [a]));
  }
  for (final g in groups) {
    out.add(MapCluster(g.items));
  }
  return out;
}
