import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_read_store.dart';

/// Drives the unread badge on the Explore app bar. Holds ONE lightweight listener (limit 1,
/// newest visible community message) and only between [start] and [stop]; the
/// `CommunityChatButton` calls these from initState/dispose so it exists only while Explore does.
///
/// Because only the newest message is observed, [count] is 0 or 1 ("something new"), not an exact
/// number. First run baselines to the newest message so nobody starts with a stale badge.
class CommunityUnreadController extends ChangeNotifier {
  CommunityUnreadController({
    required ChatRepository repository,
    required ChatReadStore store,
    required String? Function() uid,
  }) : _repo = repository,
       _store = store,
       _uid = uid;

  final ChatRepository _repo;
  final ChatReadStore _store;
  final String? Function() _uid;

  StreamSubscription<ChatMessage?>? _sub;
  ChatMessage? _newest;
  bool _unread = false;
  bool _disposed = false;

  bool get isListening => _sub != null;
  bool get hasUnread => _unread;
  int get count => _unread ? 1 : 0;

  Future<void> start() async {
    if (_sub != null) return;
    _store.addListener(_recompute);
    // Subscribe first so [isListening] is true immediately; markers load in the background.
    _sub = _repo.watchNewestCommunityMessage().listen((m) {
      _newest = m;
      _recompute();
      _baselineIfFirstRun();
    }, onError: (Object _) {});
    await _store.ensureLoaded();
    _recompute();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _store.removeListener(_recompute);
  }

  /// Marks the community chat as read up to the newest known message.
  Future<void> markRead() => _store.markRead(
    const ChatRoom.community().readKey,
    _newest?.createdAt ?? DateTime.now(),
  );

  void _baselineIfFirstRun() {
    final at = _newest?.createdAt;
    if (at != null && _store.lastRead('community') == null) {
      _store.ensureLoaded().then((_) {
        if (_store.lastRead('community') == null && !_disposed) {
          _store.markRead('community', at);
        }
      });
    }
  }

  void _recompute() {
    final next = _store.isUnread(
      'community',
      latest: _newest?.createdAt,
      senderId: _newest?.senderId,
      myUid: _uid(),
      baselineIfMissing: true,
    );
    if (next != _unread) {
      _unread = next;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
