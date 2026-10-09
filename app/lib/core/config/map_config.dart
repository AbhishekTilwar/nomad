import 'package:latlong2/latlong.dart';

/// Tile provider configuration, replaceable without touching map widgets.
///
/// Production: pass a provider-specific template with
/// `--dart-define=MAP_TILE_URL=...`. The default is the public OpenStreetMap
/// server, which is for development/testing only and is NOT an unlimited
/// production service (see https://operations.osmfoundation.org/policies/tiles/).
class MapConfig {
  const MapConfig({
    required this.tileUrlTemplate,
    required this.attribution,
    this.userAgentPackageName = 'in.nomadmingle.app',
    this.maxZoom = 19,
    this.subdomains = const [],
  });

  factory MapConfig.fromEnvironment() => const MapConfig(
    tileUrlTemplate: String.fromEnvironment(
      'MAP_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    attribution: String.fromEnvironment(
      'MAP_ATTRIBUTION',
      defaultValue: '© OpenStreetMap contributors',
    ),
  );

  final String tileUrlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final int maxZoom;
  final List<String> subdomains;

  static const defaultZoom = 12.0;

  /// Launch cities. Adding a city = adding an entry (also see backend).
  static const cities = <CityInfo>[
    CityInfo('mumbai', 'Mumbai', LatLng(19.0760, 72.8777)),
    CityInfo('pune', 'Pune', LatLng(18.5204, 73.8567)),
  ];

  static CityInfo cityById(String? id) =>
      cities.firstWhere((c) => c.id == id, orElse: () => cities.first);
}

class CityInfo {
  const CityInfo(this.id, this.name, this.center);
  final String id;
  final String name;
  final LatLng center;
}
