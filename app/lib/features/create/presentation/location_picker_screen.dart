import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/primary_button.dart';

/// Full-screen map where the host drops a pin. Returns the chosen [LatLng].
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, required this.initial});
  final LatLng initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _cfg = MapConfig.fromEnvironment();
  late LatLng _picked = widget.initial;

  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final r = await context.read<LocationService>().current();
    if (!mounted) return;
    if (r.position != null) {
      setState(() => _picked = r.position!);
      _map.move(r.position!, 16);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(locationMessage(r.outcome))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose the spot')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 15,
              onTap: (_, p) => setState(() => _picked = p),
            ),
            children: [
              TileLayer(
                urlTemplate: _cfg.tileUrlTemplate,
                userAgentPackageName: _cfg.userAgentPackageName,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 48,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution(_cfg.attribution)],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tap the map to drop the pin on the meeting spot.',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Use my location',
                      icon: const Icon(Icons.my_location),
                      onPressed: _useMyLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: PrimaryButton(
            label: 'Use this location',
            onPressed: () => context.pop(_picked),
          ),
        ),
      ),
    );
  }
}
