import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationOutcome { granted, denied, deniedForever, serviceOff, error }

class LocationResult {
  const LocationResult(this.outcome, [this.position]);
  final LocationOutcome outcome;
  final LatLng? position;
}

/// Foreground, one-shot location only. We never request background location,
/// never track continuously, and never upload the result.
abstract class LocationService {
  Future<LocationResult> current();
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationOutcome.serviceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.deniedForever);
      }
      if (perm == LocationPermission.denied) {
        return const LocationResult(LocationOutcome.denied);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // city-block accuracy is enough
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult(
        LocationOutcome.granted,
        LatLng(p.latitude, p.longitude),
      );
    } catch (_) {
      return const LocationResult(LocationOutcome.error);
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}

String locationMessage(LocationOutcome o) {
  switch (o) {
    case LocationOutcome.denied:
      return 'Location permission is off. You can still browse by city.';
    case LocationOutcome.deniedForever:
      return 'Location is blocked for Nomad Mingle. Enable it in system settings to see distances.';
    case LocationOutcome.serviceOff:
      return 'Turn on device location to see plans near you.';
    case LocationOutcome.error:
      return 'Couldn\'t get your location. Try again.';
    case LocationOutcome.granted:
      return '';
  }
}
