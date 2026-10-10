import 'package:latlong2/latlong.dart';

/// Tile provider configuration, replaceable without touching map widgets.
///
/// Production: pass a provider-specific template with
/// `--dart-define=MAP_TILE_URL=...`. The default is CARTO Voyager without
/// labels: soft colors and low detail. Its free tier is for non-commercial use,
/// so switch to a paid/self-hosted provider before a commercial launch.
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
      defaultValue:
          'https://basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png',
    ),
    attribution: String.fromEnvironment(
      'MAP_ATTRIBUTION',
      defaultValue: '© OpenStreetMap contributors © CARTO',
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
