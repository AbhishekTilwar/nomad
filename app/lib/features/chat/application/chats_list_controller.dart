import 'package:flutter/foundation.dart';

import '../../../core/utils/app_exception.dart';
import '../../activities/data/my_activities_repository.dart';
import 'chat_read_store.dart';

enum ChatsListStatus { loading, ready, error }

/// Backs the Chats tab: activities I host or joined, newest conversation first.
/// Loads up to 50 hosted + 50 joined (the API page cap); no further paging.
class ChatsListController extends ChangeNotifier {
  ChatsListController({
    required MyActivitiesRepository repository,
    required ChatReadStore store,
    required this.myUid,
    Future<Set<String>> Function()? blockedIds,
  }) : _repo = repository,
       _store = store,
       _blockedIds = blockedIds {
    _store.addListener(_onStore);
  }

  final MyActivitiesRepository _repo;
  final ChatReadStore _store;
  final String myUid;
  final Future<Set<String>> Function()? _blockedIds;

  ChatsListStatus _status = ChatsListStatus.loading;
  String? _error;
  List<MyActivity> _items = const [];
  Set<String> _blocked = const {};
  bool _disposed = false;

  ChatsListStatus get status => _status;
  String? get error => _error;
  List<MyActivity> get items => _items;

  /// Last message to preview, or null when none / the sender is blocked.
  ActivityLastMessage? previewFor(MyActivity a) {
    final m = a.lastMessage;
    return m == null || _blocked.contains(m.senderId) ? null : m;
  }

  bool isUnread(MyActivity a) {
    final m = previewFor(a);
    return _store.isUnread(
      'activity:${a.activity.id}',
      latest: m?.createdAt,
      senderId: m?.senderId,
      myUid: myUid,
    );
  }

  Future<void> load() async {
    _status = ChatsListStatus.loading;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        _repo.list(MyActivitiesRole.hosted, limit: 50),
        _repo.list(MyActivitiesRole.joined, limit: 50),
        _store.ensureLoaded(),
        _loadBlocked(),
      ]);
      final byId = <String, MyActivity>{};
      for (final page in [results[0], results[1]]) {
        for (final a in (page as MyActivitiesPage).items) {
          byId[a.activity.id] = a;
        }
      }
      DateTime key(MyActivity a) =>
          a.lastMessage?.createdAt ?? a.activity.startAt;
      _items = byId.values.toList()..sort((a, b) => key(b).compareTo(key(a)));
      _status = ChatsListStatus.ready;
    } on AppException catch (e) {
      _error = e.message;
      _status = ChatsListStatus.error;
    } catch (_) {
      _error = 'Couldn\'t load your chats. Please try again.';
      _status = ChatsListStatus.error;
    }
    _notify();
  }

  Future<void> _loadBlocked() async {
    try {
      _blocked = await _blockedIds?.call() ?? const {};
    } catch (_) {
      // Best effort.
    }
  }

  void _onStore() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_onStore);
    super.dispose();
  }
}
