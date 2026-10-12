import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Name and photo of a member as they are *now*.
class UserSummary {
  const UserSummary(this.name, this.photoUrl);
  final String name;
  final String? photoUrl;
}

/// Current name/photo by uid, read from the public `users/{uid}` doc.
///
/// Chat messages carry the photo the sender had when they wrote them, so old
/// messages would keep showing a stale picture; conversation lists only know
/// a uid. Widgets use this to show the latest details, falling back to what
/// they already have while it loads (or if it can't be read).
class UserPhotoCache {
  UserPhotoCache._();
  static final instance = UserPhotoCache._();

  static const _ttl = Duration(minutes: 10);

  final _summaries = <String, ValueNotifier<UserSummary?>>{};
  final _fetchedAt = <String, DateTime>{};
  final _inFlight = <String>{};

  /// Notifier holding the latest known details for [uid] (null until
  /// resolved). Triggers a refresh when stale.
  ValueNotifier<UserSummary?> watch(String uid) {
    final n = _summaries.putIfAbsent(uid, () => ValueNotifier(null));
    final at = _fetchedAt[uid];
    if (uid.isNotEmpty &&
        (at == null || DateTime.now().difference(at) > _ttl) &&
        _inFlight.add(uid)) {
      _fetch(uid, n);
    }
    return n;
  }

  Future<void> _fetch(String uid, ValueNotifier<UserSummary?> n) async {
    try {
      final snap = await FirebaseFirestore.instance.doc('users/$uid').get();
      final d = snap.data();
      if (snap.exists && d != null && d['accountStatus'] != 'deleted') {
        n.value = UserSummary(
          d['displayName'] as String? ?? 'Member',
          d['photoUrl'] as String?,
        );
        _fetchedAt[uid] = DateTime.now();
      }
    } catch (e) {
      debugPrint('Profile lookup failed for $uid: $e');
    } finally {
      _inFlight.remove(uid);
    }
  }
}
