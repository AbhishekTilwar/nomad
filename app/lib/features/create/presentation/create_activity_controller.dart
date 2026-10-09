import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/models/activity.dart';

/// Form state + validation for hosting a plan. Pure Dart so it is unit-tested.
class CreateActivityController extends ChangeNotifier {
  CreateActivityController(this._repo, {required this.city, this.editing}) {
    final a = editing;
    if (a != null) {
      title = a.title;
      description = a.description;
      category = a.category;
      startAt = a.startAt;
      durationMinutes = _nearestDuration(
        a.endAt.difference(a.startAt).inMinutes,
      );
      venueName = a.venueName;
      location = a.position;
      capacity = a.capacity;
      costType = a.costType;
      costDescription = a.costDescription;
      approvalRequired = a.approvalRequired;
      isPrivate = a.isPrivate;
      safetyNotes = a.safetyNotes;
      cancellationPolicy = a.cancellationPolicy;
      coverImageUrl = a.coverImageUrl;
    }
  }

  final ActivityRepository _repo;
  final String city;

  /// Non-null when the host is editing an existing plan.
  final Activity? editing;
  bool get isEditing => editing != null;

  /// Duration choices offered by the form (minutes).
  static const durations = [60, 120, 180, 240, 360, 600];
  static int _nearestDuration(int minutes) => durations.reduce(
    (a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b,
  );

  String title = '';
  String description = '';
  String? category;
  DateTime? startAt;
  int durationMinutes = 120;
  String venueName = '';
  LatLng? location;
  int capacity = 8;
  CostType costType = CostType.free;
  String costDescription = '';
  bool approvalRequired = false;
  bool isPrivate = false;
  String safetyNotes = '';
  String cancellationPolicy = '';
  String? coverImageUrl;

  bool submitting = false;
  String? submitError;
  Map<String, String> errors = const {};

  DateTime? get endAt => startAt?.add(Duration(minutes: durationMinutes));

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  /// Returns field-keyed errors; empty means valid. [now] is injectable for tests.
  Map<String, String> validate({DateTime? now}) {
    final e = <String, String>{};
    void add(String key, String? msg) {
      if (msg != null) e[key] = msg;
    }

    add('title', Validators.activityTitle(title));
    add('description', Validators.activityDescription(description));
    if (category == null) e['category'] = 'Choose a category.';
    // When editing, an unchanged start time isn't re-checked against "now"
    // (the plan may start soon; other fields must still be editable).
    if (!(isEditing && startAt == editing!.startAt)) {
      add('startAt', Validators.startTime(startAt, now: now));
    }
    final venue = venueName.trim();
    if (venue.length < 2) {
      e['venueName'] = 'Add the venue or meeting spot name.';
    }
    if (venue.length > 100) e['venueName'] = 'Venue name is too long.';
    if (location == null) e['location'] = 'Pick the spot on the map.';
    add('capacity', Validators.capacity(capacity));
    if (costType == CostType.paid && costDescription.trim().isEmpty) {
      e['costDescription'] =
          'Describe the expected cost (e.g. "about ₹500 each").';
    }
    if (costDescription.length > 200) {
      e['costDescription'] = 'Keep it under 200 characters.';
    }
    if (safetyNotes.length > 500) {
      e['safetyNotes'] = 'Keep it under 500 characters.';
    }
    if (cancellationPolicy.length > 500) {
      e['cancellationPolicy'] = 'Keep it under 500 characters.';
    }
    return e;
  }

  bool runValidation({DateTime? now}) {
    errors = validate(now: now);
    notifyListeners();
    return errors.isEmpty;
  }

  ActivityDraft buildDraft() => ActivityDraft(
    title: title,
    description: description,
    category: category!,
    city: city,
    venueName: venueName,
    latitude: location!.latitude,
    longitude: location!.longitude,
    startAt: startAt!,
    endAt: endAt!,
    capacity: capacity,
    costType: costType,
    costDescription: costType == CostType.free ? '' : costDescription,
    approvalRequired: approvalRequired,
    isPrivate: isPrivate,
    safetyNotes: safetyNotes,
    cancellationPolicy: cancellationPolicy,
    coverImageUrl: coverImageUrl,
  );

  /// Publishes (or saves edits) once; duplicate taps are ignored while in flight.
  Future<Activity?> submit({DateTime? now}) async {
    if (submitting) return null;
    if (!runValidation(now: now)) return null;
    submitting = true;
    submitError = null;
    notifyListeners();
    try {
      final draft = buildDraft();
      return isEditing
          ? await _repo.update(editing!.id, draft)
          : await _repo.create(draft);
    } on AppException catch (e) {
      submitError = e.message;
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
