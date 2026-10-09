import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-read timestamps per chat (`community`, `activity:<id>`), persisted in shared_preferences
/// and namespaced by the signed-in uid. Notifies listeners whenever a marker moves forward.
class ChatReadStore extends ChangeNotifier {
  ChatReadStore({String? Function()? uid, Future<SharedPreferences>? prefs})
    : _uid = uid ?? (() => null),
      _prefsFuture = prefs;

  final String? Function() _uid;
  Future<SharedPreferences>? _prefsFuture;
  final Map<String, int> _cache = {};
  bool _loaded = false;
  String? _loadedFor;

  String _key(String chat) => 'chat_last_read_${_uid() ?? 'anon'}_$chat';

  Future<SharedPreferences> get _prefs =>
      _prefsFuture ??= SharedPreferences.getInstance();

  /// Loads all markers for the current user into memory. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    final uid = _uid();
    if (_loaded && _loadedFor == uid) return;
    final p = await _prefs;
    _cache.clear();
    final prefix = 'chat_last_read_${uid ?? 'anon'}_';
    for (final k in p.getKeys()) {
      if (k.startsWith(prefix)) {
        final v = p.getInt(k);
        if (v != null) _cache[k] = v;
      }
    }
    _loaded = true;
    _loadedFor = uid;
    notifyListeners();
  }

  /// Null when never read/baselined (or not loaded yet).
  DateTime? lastRead(String chat) {
    final v = _cache[_key(chat)];
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  /// Moves the marker forward (never backwards).
  Future<void> markRead(String chat, DateTime at) async {
    await ensureLoaded();
    final k = _key(chat);
    final ms = at.millisecondsSinceEpoch;
    if ((_cache[k] ?? -1) >= ms) return;
    _cache[k] = ms;
    notifyListeners();
    await (await _prefs).setInt(k, ms);
  }

  /// True when [latest] is newer than the marker and not sent by [myUid].
  /// With no marker: unread unless [baselineIfMissing] (then treated as read).
  bool isUnread(
    String chat, {
    required DateTime? latest,
    String? senderId,
    String? myUid,
    bool baselineIfMissing = false,
  }) {
    if (latest == null) return false;
    if (senderId != null && senderId == myUid) return false;
    final r = lastRead(chat);
    if (r == null) return !baselineIfMissing;
    return latest.isAfter(r);
  }
}
