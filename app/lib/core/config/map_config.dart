import 'package:latlong2/latlong.dart';

/// Tile provider configuration, replaceable without touching map widgets.
///
/// Production: pass a provider-specific template with
/// `--dart-define=MAP_TILE_URL=...`. The default is Esri's Light Gray
/// Canvas: muted colors and low detail. Check Esri's terms before a commercial
/// launch, or switch to a paid/self-hosted provider.
class MapConfig {
  const MapConfig({
    required this.tileUrlTemplate,
    required this.attribution,
    this.userAgentPackageName = 'in.nomadmingle.app',
    this.maxZoom = 16,
    this.subdomains = const [],
  });

  factory MapConfig.fromEnvironment() => const MapConfig(
    tileUrlTemplate: String.fromEnvironment(
      'MAP_TILE_URL',
      defaultValue:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    ),
    attribution: String.fromEnvironment(
      'MAP_ATTRIBUTION',
      defaultValue: 'Tiles © Esri',
    ),
  );

  final String tileUrlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final int maxZoom;
  final List<String> subdomains;

  static const defaultZoom = 11.0;

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
