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
    _refreshErrors();
    notifyListeners();
  }

  /// For text fields: applies [change] and, only if errors are showing, drops
  /// the ones that are now fixed (so typing doesn't rebuild the form otherwise).
  void edit(void Function() change) {
    change();
    if (errors.isEmpty) return;
    _refreshErrors();
    notifyListeners();
  }

  /// Keeps only the shown errors that still apply, with up-to-date messages.
  void _refreshErrors() {
    if (errors.isEmpty) return;
    final all = validate();
    errors = {
      for (final k in errors.keys)
        if (all.containsKey(k)) k: all[k]!,
    };
  }

  /// Returns field-keyed errors; empty means valid. [now] is injectable for tests.
  Map<String, String> validate({DateTime? now}) {
    final e = <String, String>{};
    void add(String key, String? msg) {
      if (msg != null) e[key] = msg;
    }

    add('title', Validators.activityTitle(title));
    // Description is optional; only the upper bound applies when given.
    if (description.trim().length > 1000) {
      e['description'] = 'Description can be at most 1000 characters.';
    }
    if (category == null) e['category'] = 'Choose a category.';
    // When editing, an unchanged start time isn't re-checked against "now"
    // (the plan may start soon; other fields must still be editable).
    if (!(isEditing && startAt == editing!.startAt)) {
      add('startAt', Validators.startTime(startAt, now: now));
    }
    // Venue name is optional (the pinned location is what matters); a blank
    // one is sent as [fallbackVenue] because the server wants a name.
    if (venueName.trim().length > 100) {
      e['venueName'] = 'Venue name is too long.';
    }
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

  /// Which validation keys belong to each step of the form.
  static const stepFields = <List<String>>[
    ['category', 'title', 'description'],
    ['startAt', 'venueName', 'location'],
    ['capacity', 'costDescription'],
    ['safetyNotes', 'cancellationPolicy'],
  ];

  /// Validates only the fields on [step] (so "Next" doesn't nag about steps
  /// the host hasn't reached). Shows those errors; true when the step is ok.
  bool validateStep(int step, {DateTime? now}) {
    final all = validate(now: now);
    errors = {
      for (final k in stepFields[step])
        if (all.containsKey(k)) k: all[k]!,
    };
    notifyListeners();
    return errors.isEmpty;
  }

  /// The earliest step that has an entry in [errs], or null if none.
  static int? firstStepWithError(Map<String, String> errs) {
    for (var i = 0; i < stepFields.length; i++) {
      if (stepFields[i].any(errs.containsKey)) return i;
    }
    return null;
  }

  bool runValidation({DateTime? now}) {
    errors = validate(now: now);
    notifyListeners();
    return errors.isEmpty;
  }

  /// Stand-in venue name when the host leaves it blank.
  static const fallbackVenue = 'Pinned location';

  ActivityDraft buildDraft() => ActivityDraft(
    title: title,
    description: description,
    category: category!,
    city: city,
    venueName: venueName.trim().isEmpty ? fallbackVenue : venueName,
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
