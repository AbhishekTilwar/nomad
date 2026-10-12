import 'package:flutter/foundation.dart';

import '../../../core/utils/app_exception.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../data/social_repository.dart';

/// Plans I host that have people waiting for approval.
class JoinRequestGroup {
  const JoinRequestGroup(this.activity, this.people);
  final Activity activity;
  final List<ActivityMember> people;
}

/// Everything waiting on me: incoming friend requests and join requests for
/// the plans I host. Backs the Requests screen and the badge on the Chats tab.
class RequestsController extends ChangeNotifier {
  RequestsController({
    required SocialRepository social,
    required MyActivitiesRepository mine,
    required ActivityRepository activities,
  }) : _social = social,
       _mine = mine,
       _activities = activities;

  final SocialRepository _social;
  final MyActivitiesRepository _mine;
  final ActivityRepository _activities;

  /// Hosted plans checked for join requests (nearest first).
  static const _hostedScan = 10;

  bool loading = true;
  String? error;
  List<FriendEntry> friendRequests = const [];
  List<JoinRequestGroup> joinRequests = const [];
  bool _disposed = false;

  int get count =>
      friendRequests.length +
      joinRequests.fold(0, (n, g) => n + g.people.length);

  Future<void> load() async {
    loading = friendRequests.isEmpty && joinRequests.isEmpty;
    error = null;
    _notify();
    try {
      final results = await Future.wait([_social.friendRequests(), _joins()]);
      friendRequests = results[0] as List<FriendEntry>;
      joinRequests = results[1] as List<JoinRequestGroup>;
    } on AppException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Couldn\'t load your requests.';
    }
    loading = false;
    _notify();
  }

  Future<List<JoinRequestGroup>> _joins() async {
    final page = await _mine.list(MyActivitiesRole.hosted, limit: _hostedScan);
    final groups = await Future.wait([
      for (final m in page.items.where(
        (m) => m.activity.status == ActivityStatus.scheduled,
      ))
        _activities
            .members(m.activity.id)
            .then(
              (all) => JoinRequestGroup(m.activity, [
                for (final x in all)
                  if (x.status == MembershipStatus.requested) x,
              ]),
            )
            .catchError((_) => JoinRequestGroup(m.activity, const [])),
    ]);
    return [
      for (final g in groups)
        if (g.people.isNotEmpty) g,
    ];
  }

  Future<void> acceptFriend(FriendEntry f) async {
    await _social.acceptFriendRequest(f.uid);
    friendRequests = [
      for (final x in friendRequests)
        if (x.uid != f.uid) x,
    ];
    _notify();
  }

  Future<void> declineFriend(FriendEntry f) async {
    await _social.removeFriend(f.uid);
    friendRequests = [
      for (final x in friendRequests)
        if (x.uid != f.uid) x,
    ];
    _notify();
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
