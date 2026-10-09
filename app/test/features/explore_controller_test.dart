import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/discover/presentation/discover_controller.dart'
    show DateFilter;
import 'package:nomad_mingle/features/explore/presentation/explore_controller.dart';

import '../support/fakes.dart';

class RecordingRepo extends FakeActivityRepository {
  RecordingRepo([super.activities]);
  final calls = <({double lat, double lng, double radius})>[];
  @override
  Future<List<Activity>> forMap({
    required double lat,
    required double lng,
    required double radiusKm,
    String? category,
  }) async {
    calls.add((lat: lat, lng: lng, radius: radiusKm));
    return activities;
  }
}

Future<void> pump([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('initial load queries around the city centre', () async {
    final repo = RecordingRepo([sampleActivity()]);
    final c = ExploreController(repo, initialCity: 'pune');
    await pump();
    expect(repo.calls.single.lat, closeTo(18.52, 0.01));
    expect(c.items, hasLength(1));
    c.dispose();
  });

  test(
    'a just-posted plan appears immediately, is selected and focused, even before the server lists it',
    () async {
      final repo = RecordingRepo(); // server (index) doesn't return it yet
      final c = ExploreController(repo, initialCity: 'mumbai');
      await pump();
      final posted = sampleActivity(id: 'new1', title: 'Fresh plan');
      final tick = c.focusTick;
      c.showPosted(posted);
      expect(c.items.first.id, 'new1');
      expect(c.selectedId, 'new1');
      expect(c.view, ExploreView.map);
      expect(c.focusTick, tick + 1);
      expect(c.focusPoint, posted.position);
      await pump();
      expect(
        c.items.any((a) => a.id == 'new1'),
        isTrue,
        reason: 'kept after refresh',
      );
      expect(repo.calls.last.lat, posted.latitude);
      c.dispose();
    },
  );

  test('showPosted clears filters that would hide the new plan', () async {
    final c = ExploreController(RecordingRepo(), initialCity: 'mumbai');
    await pump();
    c.toggleCategory('hiking');
    c.setFreeOnly(true);
    c.showPosted(sampleActivity(id: 'x')); // category food
    expect(c.visible.any((a) => a.id == 'x'), isTrue);
    c.dispose();
  });

  test('server result replaces duplicates of the posted plan', () async {
    final posted = sampleActivity(id: 'dup');
    final c = ExploreController(RecordingRepo([posted]), initialCity: 'mumbai');
    await pump();
    c.showPosted(posted);
    await pump();
    expect(c.items.where((a) => a.id == 'dup'), hasLength(1));
    c.dispose();
  });

  test(
    'viewport changes are debounced and tiny moves do not refetch',
    () async {
      final repo = RecordingRepo();
      final c = ExploreController(
        repo,
        initialCity: 'mumbai',
        viewportDebounce: const Duration(milliseconds: 20),
      );
      await pump();
      final before = repo.calls.length;
      // tiny pan (~1 km) -> ignored
      c.onViewportChanged(const LatLng(19.085, 72.88), 25);
      await pump(80);
      expect(repo.calls.length, before);
      // big pan (~120 km to Pune) -> one request despite many events
      c.onViewportChanged(const LatLng(18.9, 73.5), 25);
      c.onViewportChanged(const LatLng(18.6, 73.8), 25);
      c.onViewportChanged(const LatLng(18.52, 73.85), 25);
      await pump(120);
      expect(repo.calls.length, before + 1);
      expect(repo.calls.last.lat, closeTo(18.52, 0.01));
      c.dispose();
    },
  );

  test('radius sent to API is clamped to the backend maximum', () async {
    final repo = RecordingRepo();
    final c = ExploreController(
      repo,
      initialCity: 'mumbai',
      viewportDebounce: const Duration(milliseconds: 10),
    );
    await pump();
    c.onViewportChanged(const LatLng(15, 75), 900);
    await pump(60);
    expect(repo.calls.last.radius, 100);
    c.dispose();
  });

  test('date filter hides plans outside the window', () async {
    final now = DateTime(2026, 10, 7, 10); // Wednesday
    final soon = sampleActivity(id: 'soon');
    final far = Activity.fromJson({
      'id': 'far',
      'title': 'Later',
      'category': 'food',
      'latitude': 19.0,
      'longitude': 72.8,
      'startAt': now.add(const Duration(days: 20)).toUtc().toIso8601String(),
      'spotsLeft': 3,
    });
    final c = ExploreController(
      RecordingRepo([soon, far]),
      initialCity: 'mumbai',
      clock: () => now,
    );
    await pump();
    c.applyFilters(
      categories: {},
      date: DateFilter.week,
      cityId: 'mumbai',
      radiusKm: 25,
    );
    expect(c.visible.map((a) => a.id), isNot(contains('far')));
    c.dispose();
  });

  test('applyFilters with a new city refocuses the map', () async {
    final c = ExploreController(RecordingRepo(), initialCity: 'mumbai');
    await pump();
    final tick = c.focusTick;
    c.applyFilters(
      categories: {},
      date: DateFilter.any,
      cityId: 'pune',
      radiusKm: 25,
    );
    expect(c.cityId, 'pune');
    expect(c.focusTick, tick + 1);
    c.dispose();
  });
}
