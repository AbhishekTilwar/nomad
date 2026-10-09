import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/features/chat/application/chat_read_store.dart';
import 'package:nomad_mingle/features/chat/application/community_unread_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_test_support.dart';

Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeChatRepository repo;
  late ChatReadStore store;
  late CommunityUnreadController unread;
  final t0 = DateTime(2026, 10, 10, 12);

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    repo = FakeChatRepository();
    store = ChatReadStore(uid: () => 'me');
    unread = CommunityUnreadController(
      repository: repo,
      store: store,
      uid: () => 'me',
    );
    addTearDown(unread.dispose);
  }

  test('no listener until start(); stop() cancels it', () async {
    await boot();
    expect(repo.newestListens, 0);
    await unread.start();
    await unread.start(); // idempotent: still ONE listener
    expect(repo.newestListens, 1);
    expect(repo.newestActive, isTrue);
    unread.stop();
    await settle();
    expect(repo.newestActive, isFalse);
    expect(unread.isListening, isFalse);
  });

  test('first run baselines to the newest message (no stale badge)', () async {
    await boot();
    await unread.start();
    repo.emitNewest(msg('m1', 'bob', 'old', at: t0));
    await settle();
    expect(unread.hasUnread, isFalse);
    expect(unread.count, 0);
    expect(store.lastRead('community'), t0);
  });

  test(
    'newer message from someone else is unread; markRead clears it',
    () async {
      await boot();
      await unread.start();
      repo.emitNewest(msg('m1', 'bob', 'old', at: t0));
      await settle();
      repo.emitNewest(
        msg('m2', 'bob', 'new', at: t0.add(const Duration(minutes: 5))),
      );
      await settle();
      expect(unread.hasUnread, isTrue);
      expect(unread.count, 1);
      var notified = 0;
      unread.addListener(() => notified++);
      await unread.markRead();
      await settle();
      expect(unread.hasUnread, isFalse);
      expect(notified, greaterThan(0));
    },
  );

  test('my own newest message is never unread', () async {
    await boot();
    await unread.start();
    repo.emitNewest(msg('m1', 'bob', 'old', at: t0));
    await settle();
    repo.emitNewest(
      msg('m2', 'me', 'mine', at: t0.add(const Duration(minutes: 1))),
    );
    await settle();
    expect(unread.hasUnread, isFalse);
  });

  test('last-read persists across app restarts (shared_preferences)', () async {
    await boot();
    await store.markRead('community', t0);
    final saved = (await SharedPreferences.getInstance()).getInt(
      'chat_last_read_me_community',
    );
    expect(saved, t0.millisecondsSinceEpoch);

    // "restart": new store/controller over the same prefs
    repo = FakeChatRepository();
    store = ChatReadStore(uid: () => 'me');
    unread = CommunityUnreadController(
      repository: repo,
      store: store,
      uid: () => 'me',
    );
    addTearDown(unread.dispose);
    await unread.start();
    repo.emitNewest(
      msg('m9', 'bob', 'newer', at: t0.add(const Duration(hours: 1))),
    );
    await settle();
    expect(unread.hasUnread, isTrue);
    repo.emitNewest(
      msg(
        'm0',
        'bob',
        'older than read',
        at: t0.subtract(const Duration(hours: 1)),
      ),
    );
    await settle();
    expect(unread.hasUnread, isFalse);
  });

  test('markers are per user and only move forward', () async {
    SharedPreferences.setMockInitialValues({});
    var uid = 'a';
    final s = ChatReadStore(uid: () => uid);
    await s.markRead('community', t0);
    await s.markRead('community', t0.subtract(const Duration(hours: 1)));
    expect(s.lastRead('community'), t0);
    uid = 'b';
    expect(s.lastRead('community'), isNull);
  });

  test('activity unread rules', () {
    SharedPreferences.setMockInitialValues({});
    final s = ChatReadStore(uid: () => 'me');
    expect(s.isUnread('activity:a1', latest: null), isFalse);
    // never opened and someone else spoke: unread
    expect(
      s.isUnread('activity:a1', latest: t0, senderId: 'bob', myUid: 'me'),
      isTrue,
    );
    expect(
      s.isUnread('activity:a1', latest: t0, senderId: 'me', myUid: 'me'),
      isFalse,
    );
  });
}
