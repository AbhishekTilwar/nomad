import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/app_exception.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/models/activity.dart';

enum DateFilter { any, today, weekend, week }

enum DiscoverSort { date, proximity, relevance }

/// List-first discovery with server-side pagination (opaque cursor), debounced
/// keyword search and filters. A fresh request supersedes any in-flight one.
class DiscoverController extends ChangeNotifier {
  DiscoverController(
    this._repo,
    this._location, {
    required this.city,
    this.debounce = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    refresh();
  }

  final ActivityRepository _repo;
  final LocationService _location;
  final String city;
  final Duration debounce;
  final DateTime Function() _now;

  String keyword = '';
  String? category;
  bool freeOnly = false;
  bool spotsOnly = false;
  DateFilter dateFilter = DateFilter.any;
  double? radiusKm; // needs a location fix
  DiscoverSort sort = DiscoverSort.date;
  LatLng? userLocation;
  String? locationNotice;

  List<Activity> items = const [];
  String? nextCursor;
  bool loading = true;
  bool loadingMore = false;
  String? error;
  String? loadMoreError;

  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  bool get hasMore => nextCursor != null;
  bool get hasActiveFilters =>
      category != null ||
      freeOnly ||
      spotsOnly ||
      dateFilter != DateFilter.any ||
      radiusKm != null ||
      keyword.isNotEmpty;

  /// Computes the [from]/[to] window for the selected date chip.
  (DateTime?, DateTime?) get dateRange {
    final n = _now();
    final startOfToday = DateTime(n.year, n.month, n.day);
    switch (dateFilter) {
      case DateFilter.any:
        return (null, null);
      case DateFilter.today:
        return (n, startOfToday.add(const Duration(days: 1)));
      case DateFilter.week:
        return (n, startOfToday.add(const Duration(days: 7)));
      case DateFilter.weekend:
        // Next Saturday 00:00 → Monday 00:00 (or "now" if already the weekend).
        final daysToSat = (DateTime.saturday - n.weekday) % 7;
        var sat = startOfToday.add(Duration(days: daysToSat));
        if (n.weekday == DateTime.sunday) {
          sat = startOfToday.subtract(const Duration(days: 1));
        }
        final mon = sat.add(const Duration(days: 2));
        return (n.isAfter(sat) ? n : sat, mon);
    }
  }

  ActivityQuery _query({String? cursor}) {
    final (from, to) = dateRange;
    final k = keyword.trim();
    final usingLocation = userLocation != null;
    return ActivityQuery(
      city: usingLocation && radiusKm != null ? null : city,
      category: category,
      keyword: k.isEmpty ? null : k,
      freeOnly: freeOnly,
      from: from,
      to: to,
      minSpots: spotsOnly ? 1 : null,
      lat: usingLocation && (radiusKm != null || sort == DiscoverSort.proximity)
          ? userLocation!.latitude
          : null,
      lng: usingLocation && (radiusKm != null || sort == DiscoverSort.proximity)
          ? userLocation!.longitude
          : null,
      radiusKm: radiusKm,
      sort: sort.name,
      cursor: cursor,
    );
  }

  /// Debounced keyword entry.
  void setKeyword(String v) {
    keyword = v;
    _timer?.cancel();
    _timer = Timer(debounce, refresh);
  }

  Future<void> setCategory(String? c) => _change(() => category = c);
  Future<void> setFreeOnly(bool v) => _change(() => freeOnly = v);
  Future<void> setSpotsOnly(bool v) => _change(() => spotsOnly = v);
  Future<void> setDateFilter(DateFilter f) => _change(() => dateFilter = f);

  Future<void> setSort(DiscoverSort s) async {
    if (s == DiscoverSort.proximity && !await _ensureLocation()) return;
    await _change(() => sort = s);
  }

  Future<void> setRadius(double? km) async {
    if (km != null && !await _ensureLocation()) return;
    await _change(() => radiusKm = km);
  }

  Future<void> clearFilters() => _change(() {
    category = null;
    freeOnly = false;
    spotsOnly = false;
    dateFilter = DateFilter.any;
    radiusKm = null;
    keyword = '';
    if (sort == DiscoverSort.proximity && userLocation == null) {
      sort = DiscoverSort.date;
    }
  });

  Future<bool> _ensureLocation() async {
    if (userLocation != null) return true;
    final r = await _location.current();
    if (r.position == null) {
      locationNotice = locationMessage(r.outcome);
      _notify();
      return false;
    }
    userLocation = r.position;
    return true;
  }

  Future<void> _change(void Function() mutate) {
    mutate();
    locationNotice = null;
    return refresh();
  }

  Future<void> refresh() async {
    _timer?.cancel();
    final seq = ++_seq;
    loading = true;
    error = null;
    loadMoreError = null;
    _notify();
    try {
      final page = await _repo.list(_query());
      if (seq != _seq) return;
      items = _withDistance(page.items);
      nextCursor = page.nextCursor;
    } on AppException catch (e) {
      if (seq != _seq) return;
      error = e.message;
      items = const [];
      nextCursor = null;
    }
    loading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || nextCursor == null) return;
    final seq = _seq;
    loadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final page = await _repo.list(_query(cursor: nextCursor));
      if (seq != _seq) return; // filters changed while paging
      final seen = items.map((a) => a.id).toSet();
      items = [
        ...items,
        ..._withDistance(page.items.where((a) => !seen.contains(a.id))),
      ];
      nextCursor = page.nextCursor;
    } on AppException catch (e) {
      if (seq == _seq) loadMoreError = e.message;
    }
    if (seq == _seq) loadingMore = false;
    _notify();
  }

  /// Fills `distanceKm` client-side when the API didn't (device location only,
  /// never uploaded).
  List<Activity> _withDistance(Iterable<Activity> list) {
    final me = userLocation;
    if (me == null) return list.toList();
    const dist = Distance();
    return [
      for (final a in list)
        a.distanceKm != null
            ? a
            : a.copyWith(
                distanceKm: dist.as(LengthUnit.Kilometer, me, a.position),
              ),
    ];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
