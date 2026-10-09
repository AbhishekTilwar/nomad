import 'package:flutter/foundation.dart';

import '../../../core/utils/app_exception.dart';
import '../data/activity_repository.dart';
import '../models/activity.dart';

class ActivityDetailController extends ChangeNotifier {
  ActivityDetailController(this._repo, this.id) {
    load();
  }

  final ActivityRepository _repo;
  final String id;

  Activity? activity;
  bool loading = true;
  String? loadError;
  bool busy = false;
  bool _disposed = false;

  /// Transient message for a snackbar; the UI reads then clears it.
  String? actionMessage;

  Future<void> load() async {
    loading = activity == null;
    loadError = null;
    _notify();
    try {
      activity = await _repo.get(id);
    } on AppException catch (e) {
      loadError = e.message;
    }
    loading = false;
    _notify();
  }

  /// Runs a mutating action with duplicate-tap protection, then re-reads the
  /// activity: the server is authoritative for counts and membership state.
  Future<void> _act(Future<String?> Function() body) async {
    if (busy) return;
    busy = true;
    actionMessage = null;
    _notify();
    try {
      actionMessage = await body();
    } on AppException catch (e) {
      actionMessage = e.message;
    }
    try {
      activity = await _repo.get(id);
    } on AppException {
      // keep the previous snapshot; the action result message still shows
    }
    busy = false;
    _notify();
  }

  Future<void> join() => _act(() async {
    final status = await _repo.join(id);
    return status == MembershipStatus.requested
        ? 'Request sent. The host will review it.'
        : 'You\'re in!';
  });

  Future<void> leave() => _act(() async {
    await _repo.leave(id);
    return 'You left this plan.';
  });

  Future<void> cancelActivity() => _act(() async {
    await _repo.cancel(id);
    return 'Plan cancelled.';
  });

  String? takeMessage() {
    final m = actionMessage;
    actionMessage = null;
    return m;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
