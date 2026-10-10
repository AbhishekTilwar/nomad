import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/map_config.dart';
import '../../../core/utils/app_exception.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/models/activity.dart';
import '../../discover/presentation/discover_controller.dart' show DateFilter;
import '../../social/data/social_repository.dart';

enum ExploreView { map, list }

enum LoadState { loading, loaded, error }

class ExploreController extends ChangeNotifier {
  ExploreController(
    this._repo, {
    required String initialCity,
    this.viewportDebounce = const Duration(milliseconds: 600),
    DateTime Function()? clock,
  }) : _cityId = initialCity,
       _now = clock ?? DateTime.now {
    _areaCenter = city.center;
    load();
  }

  final ActivityRepository _repo;
  final Duration viewportDebounce;
  final DateTime Function() _now;

  String _cityId;
  ExploreView view = ExploreView.map;
  LoadState state = LoadState.loading;
  String? error;
  List<Activity> items = const [];
  final Set<String> categories = {};
  bool freeOnly = false;
  DateFilter dateFilter = DateFilter.any;

  /// Search radius when the map hasn't been panned (km).
  double radiusKm = 25;
  String? selectedId;

  /// The map asks for location once per session when first shown.
  bool autoLocateDone = false;
  LatLng? userLocation;

  /// Bumped when something asks the map widget to move (city switch, a plan
  /// was just posted, recenter). The map listens and animates to [focusPoint].
  int focusTick = 0;
  LatLng? focusPoint;
  double? focusZoom;

  late LatLng _areaCenter;
  double _areaRadiusKm = 25;
  Timer? _debounce;
  bool _disposed = false;
  int _requestSeq = 0;

  String get cityId => _cityId;
  CityInfo get city => MapConfig.cityById(_cityId);
  LatLng get center => userLocation ?? city.center;

  Activity? get selected {
    for (final a in items) {
      if (a.id == selectedId) return a;
    }
    return null;
  }

  bool get hasActiveFilters =>
      categories.isNotEmpty || freeOnly || dateFilter != DateFilter.any;

  /// Items after the filters the map endpoint doesn't cover.
  List<Activity> get visible {
    final n = _now();
    final today = DateTime(n.year, n.month, n.day);
    return items.where((a) {
      if (freeOnly && !a.isFree) return false;
      if (categories.isNotEmpty && !categories.contains(a.category)) {
        return false;
      }
      switch (dateFilter) {
        case DateFilter.any:
          break;
        case DateFilter.today:
          if (a.startAt.isAfter(today.add(const Duration(days: 1)))) {
            return false;
          }
        case DateFilter.week:
          if (a.startAt.isAfter(today.add(const Duration(days: 7)))) {
            return false;
          }
        case DateFilter.weekend:
          final w = a.startAt.weekday;
          final soon = a.startAt.isBefore(today.add(const Duration(days: 8)));
          if (!(soon && (w == DateTime.saturday || w == DateTime.sunday))) {
            return false;
          }
      }
      return true;
    }).toList();
  }

  void setView(ExploreView v) {
    view = v;
    notifyListeners();
  }

  void setCity(String id) {
    if (id == _cityId) return;
    _cityId = id;
    selectedId = null;
    userLocation = null;
    _areaCenter = city.center;
    _areaRadiusKm = radiusKm;
    _focus(city.center, MapConfig.defaultZoom);
    load();
  }

  /// How many opted-in travelers are near the user (null until known/if the
  /// lookup fails). Drives the "N+ nearby" pill.
  int? nearbyCount;

  Future<void> loadNearby(SocialRepository social, LatLng p) async {
    try {
      final list = await social.travelers(lat: p.latitude, lng: p.longitude);
      nearbyCount = list.length;
      notifyListeners();
    } on AppException {
      // Keep the pill as a plain "Nearby" button.
    }
  }

  /// "Nearby", "3 nearby", "10+ nearby", "100+ nearby".
  String get nearbyLabel {
    final n = nearbyCount;
    if (n == null || n == 0) return 'Nearby';
    if (n >= 100) return '100+ nearby';
    if (n >= 10) return '${n ~/ 10 * 10}+ nearby';
    return '$n nearby';
  }

  void setUserLocation(LatLng p) {
    userLocation = p;
    _areaCenter = p;
    _areaRadiusKm = radiusKm;
    _focus(p, MapConfig.defaultZoom);
    load();
  }

  void toggleCategory(String c) {
    categories.contains(c) ? categories.remove(c) : categories.add(c);
    notifyListeners();
  }

  void clearCategories() {
    categories.clear();
    notifyListeners();
  }

  void setFreeOnly(bool v) {
    freeOnly = v;
    notifyListeners();
  }

  void applyFilters({
    required Set<String> categories,
    required DateFilter date,
    required String cityId,
    required double radiusKm,
    bool? freeOnly,
  }) {
    this.categories
      ..clear()
      ..addAll(categories);
    dateFilter = date;
    if (freeOnly != null) this.freeOnly = freeOnly;
    final cityChanged = cityId != _cityId;
    final radiusChanged = radiusKm != this.radiusKm;
    this.radiusKm = radiusKm;
    if (cityChanged) {
      setCity(cityId);
    } else if (radiusChanged) {
      _areaRadiusKm = radiusKm;
      load();
    } else {
      notifyListeners();
    }
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void _focus(LatLng p, double zoom) {
    focusPoint = p;
    focusZoom = zoom;
    focusTick++;
  }

  /// Called (debounced) when the user pans/zooms the map. Reloads only when the
  /// viewport moved meaningfully, to avoid refetching on tiny movements.
  void onViewportChanged(LatLng center, double radiusKm) {
    _debounce?.cancel();
    _debounce = Timer(viewportDebounce, () {
      final r = radiusKm.clamp(2.0, 100.0);
      const dist = Distance();
      final moved = dist.as(LengthUnit.Kilometer, _areaCenter, center);
      final grew = r > _areaRadiusKm * 1.25;
      if (moved < _areaRadiusKm * 0.35 && !grew) return;
      _areaCenter = center;
      _areaRadiusKm = r;
      load();
    });
  }

  /// A plan the user just published: show it immediately, jump the map to it
  /// and refresh from the server so counts/ids are authoritative.
  void showPosted(Activity a) {
    items = [a.copyWith(), ...items.where((x) => x.id != a.id)];
    view = ExploreView.map;
    categories.clear();
    freeOnly = false;
    dateFilter = DateFilter.any;
    selectedId = a.id;
    _areaCenter = a.position;
    _areaRadiusKm = radiusKm;
    _focus(a.position, 15);
    notifyListeners();
    load(keepSelection: true);
  }

  Future<void> load({bool keepSelection = false}) async {
    final seq = ++_requestSeq; // ignore out-of-order responses
    state = items.isEmpty ? LoadState.loading : state;
    error = null;
    notifyListeners();
    try {
      final result = await _repo.forMap(
        lat: _areaCenter.latitude,
        lng: _areaCenter.longitude,
        radiusKm: _areaRadiusKm,
      );
      if (seq != _requestSeq || _disposed) return;
      // Keep a just-posted plan visible even if the index hasn't caught up.
      final keep = keepSelection ? selected : null;
      items = [
        ?keep != null && !result.any((a) => a.id == keep.id) ? keep : null,
        ...result,
      ];
      state = LoadState.loaded;
    } on AppException catch (e) {
      if (seq != _requestSeq || _disposed) return;
      error = e.message;
      state = LoadState.error;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
