import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/core/widgets/report_action_sheet.dart';
import 'package:nomad_mingle/features/activities/data/activity_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/chat/application/chat_controller.dart';
import 'package:nomad_mingle/features/chat/application/chat_read_store.dart';
import 'package:nomad_mingle/features/chat/data/chat_repository.dart';
import 'package:nomad_mingle/features/chat/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import 'chat_test_support.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeChatRepository repo;
  late FakeSafetyRepository safety;
  late DateTime now;
  var ids = 0;

  setUp(() {
    repo = FakeChatRepository();
    safety = FakeSafetyRepository();
    now = DateTime(2026, 10, 10, 12);
    ids = 0;
  });

  CommunityChatController community({ChatReadStore? store}) =>
      CommunityChatController(
        repository: repo,
        safety: safety,
        currentUid: 'me',
        currentName: 'Me',
        readStore: store,
        idGenerator: () => 'client-id-${++ids}',
        clock: () => now,
      );

  Future<CommunityChatController> started() async {
    final c = community();
    await c.start();
    repo.emitWindow([
      msg('m3', 'bob', 'third', minutesAgo: 1),
      msg('m2', 'amy', 'second', minutesAgo: 2),
      msg('m1', 'bob', 'first', minutesAgo: 3),
    ]);
    await settle();
    addTearDown(c.dispose);
    return c;
  }

  test('loading then ready, newest first', () async {
    final c = community();
    addTearDown(c.dispose);
    await c.start();
    expect(c.status, ChatStatus.loading);
    repo.emitWindow([
      msg('m2', 'bob', 'b'),
      msg('m1', 'bob', 'a', minutesAgo: 5),
    ]);
    await settle();
    expect(c.status, ChatStatus.ready);
    expect(c.messages.map((m) => m.id), ['m2', 'm1']);
  });

  test('blocked senders are filtered out and block adds immediately', () async {
    repo.blocked = {'amy'};
    final c = await started();
    expect(c.messages.map((m) => m.id), ['m3', 'm1']);
    await c.block(c.messages.first);
    expect(safety.blockedUids, ['bob']);
    expect(repo.markedBlocked, ['bob']);
    expect(c.messages, isEmpty);
  });

  test('blocklist failure does not prevent loading', () async {
    repo.blockedError = const AppException('x');
    final c = await started();
    expect(c.messages, hasLength(3));
  });

  test('stream error surfaces error state; start() retries', () async {
    final c = community();
    addTearDown(c.dispose);
    await c.start();
    repo.emitWindowError(Exception('boom'));
    await settle();
    expect(c.status, ChatStatus.error);
    expect(c.error, isNotEmpty);
    await c.start();
    repo.emitWindow([msg('m1', 'bob', 'hi')]);
    await settle();
    expect(c.status, ChatStatus.ready);
  });

  group('pagination', () {
    test(
      'appends older pages without duplicates and stops at the end',
      () async {
        final c = community();
        addTearDown(c.dispose);
        await c.start();
        repo.emitWindow(
          [
            for (var i = 30; i >= 1; i--)
              msg('m$i', 'bob', 't$i', minutesAgo: 100 - i),
          ],
          mayHaveMore: true,
          cursor: 'oldest-live',
        );
        await settle();
        expect(c.hasMoreOlder, isTrue);
        repo.olderPages.add(
          ChatPage([
            // m1 is already in the live window: must not duplicate.
            msg('m1', 'bob', 't1', minutesAgo: 99),
            msg('o2', 'bob', 'old2', minutesAgo: 120),
            msg('o1', 'bob', 'old1', minutesAgo: 121),
          ], cursor: 'oldest-older'),
        );
        await c.loadOlder();
        expect(repo.olderCursorsRequested, ['oldest-live']);
        final idsList = c.messages.map((m) => m.id).toList();
        expect(idsList.length, 32);
        expect(idsList.toSet().length, 32);
        expect(idsList.take(2), ['m30', 'm29']);
        expect(idsList.last, 'o1');
        expect(c.hasMoreOlder, isFalse);
        await c.loadOlder(); // no-op
        expect(repo.olderCursorsRequested, hasLength(1));
      },
    );

    test(
      'a window update keeps loaded older pages and uses the older cursor next',
      () async {
        final c = community();
        addTearDown(c.dispose);
        await c.start();
        List<ChatMessage> window(int top) => [
          for (var i = top; i > top - 30; i--)
            msg('m$i', 'bob', 't$i', minutesAgo: 200 - i),
        ];
        repo.emitWindow(window(30), mayHaveMore: true, cursor: 'c1');
        await settle();
        repo.olderPages.add(
          ChatPage(
            [msg('o1', 'bob', 'old', minutesAgo: 300)],
            cursor: 'c-old',
            hasMore: true,
          ),
        );
        await c.loadOlder();
        // a new message arrives; m1 slides out of the window but must stay visible
        repo.emitWindow(window(31), mayHaveMore: true, cursor: 'c2');
        await settle();
        final ids2 = c.messages.map((m) => m.id).toList();
        expect(ids2, containsAll(['m31', 'm1', 'o1']));
        expect(ids2.toSet().length, ids2.length);
        repo.olderPages.add(const ChatPage([]));
        await c.loadOlder();
        expect(repo.olderCursorsRequested.last, 'c-old');
      },
    );

    test('older load failure is reported and retryable', () async {
      final c = community();
      addTearDown(c.dispose);
      await c.start();
      repo.emitWindow([msg('m1', 'bob', 'a')], mayHaveMore: true);
      await settle();
      repo.olderError = Exception('net');
      await c.loadOlder();
      expect(c.olderError, isNotNull);
      expect(c.hasMoreOlder, isTrue);
      repo.olderError = null;
      repo.olderPages.add(ChatPage([msg('o1', 'bob', 'old', minutesAgo: 9)]));
      await c.loadOlder();
      expect(c.olderError, isNull);
      expect(c.messages.map((m) => m.id), ['m1', 'o1']);
    });
  });

  test('moderated (hidden) message disappears from the live window', () async {
    final c = await started();
    repo.emitWindow([
      msg('m3', 'bob', 'third', minutesAgo: 1),
      msg('m1', 'bob', 'first', minutesAgo: 3),
    ]);
    await settle();
    expect(c.messages.map((m) => m.id), ['m3', 'm1']);
  });

  group('sending', () {
    test(
      'optimistic pending then reconciled with the live message, no duplicate',
      () async {
        final c = await started();
        final done = c.send('  hello  ');
        expect(c.messages.first.pending, isTrue);
        expect(c.messages.first.text, 'hello');
        expect(c.messages.first.id, startsWith('local_'));
        await done;
        expect(repo.sent.single.text, 'hello');
        expect(repo.sent.single.cid, 'client-id-1');
        // API response already put the message in; live listener then delivers the same doc.
        expect(c.messages.where((m) => m.text == 'hello'), hasLength(1));
        repo.emitWindow([
          msg('me_client-id-1', 'me', 'hello', minutesAgo: 0),
          ...c.messages.where((m) => m.id.startsWith('m')),
        ]);
        await settle();
        expect(c.messages.where((m) => m.text == 'hello'), hasLength(1));
        expect(c.messages.any((m) => m.pending || m.failed), isFalse);
      },
    );

    test(
      'pending is removed when the live listener delivers it before the API returns',
      () async {
        final c = await started();
        repo.onSend = (text, cid) async {
          repo.emitWindow([
            msg('me_$cid', 'me', text),
            msg('m3', 'bob', 'third', minutesAgo: 1),
          ]);
          await settle();
          return ChatMessage(
            id: 'me_$cid',
            senderId: 'me',
            senderName: 'Me',
            text: text,
            createdAt: now,
          );
        };
        await c.send('race');
        expect(c.messages.where((m) => m.text == 'race'), hasLength(1));
        expect(c.messages.first.pending, isFalse);
      },
    );

    test(
      'failure keeps the text as a failed message; retry reuses clientMessageId',
      () async {
        final c = await started();
        repo.onSend = (_, _) async => throw const AppException(
          'offline',
          code: 'offline',
          retryable: true,
        );
        await c.send('keep me');
        final failed = c.messages.first;
        expect(failed.failed, isTrue);
        expect(failed.text, 'keep me');
        expect(c.sendError, 'offline');
        repo.onSend = null;
        await c.retry(failed.id);
        expect(repo.sent.map((s) => s.cid).toSet(), {'client-id-1'});
        expect(repo.sent, hasLength(2));
        expect(c.messages.any((m) => m.failed || m.pending), isFalse);
        expect(c.messages.first.text, 'keep me');
        expect(c.sendError, isNull);
      },
    );

    test('unexpected exception also produces a failed message', () async {
      final c = await started();
      repo.onSend = (_, _) async => throw StateError('weird');
      await c.send('x1');
      expect(c.messages.first.failed, isTrue);
      expect(c.sendError, isNotNull);
    });

    test('discard removes a failed message', () async {
      final c = await started();
      repo.onSend = (_, _) async => throw const AppException('nope');
      await c.send('bye');
      c.discard(c.messages.first.id);
      expect(c.messages.any((m) => m.text == 'bye'), isFalse);
      expect(c.sendError, isNull);
    });

    test(
      '429 shows retryAfterSeconds, disables the composer, then re-enables',
      () async {
        final c = await started();
        repo.onSend = (_, _) async => throw rateLimited(42);
        await c.send('too fast');
        expect(c.sendError, contains('42'));
        expect(c.messages.first.failed, isTrue);
        expect(c.composerDisabledReason, contains('Slow down'));
        // retry during cooldown does not hit the server
        await c.retry(c.messages.first.id);
        expect(repo.sent, hasLength(1));
        now = now.add(const Duration(seconds: 43));
        expect(c.composerDisabledReason, isNull);
        repo.onSend = null;
        await c.retry(c.messages.first.id);
        expect(repo.sent, hasLength(2));
        expect(c.messages.any((m) => m.failed), isFalse);
      },
    );

    test('duplicate_message 429 uses a specific message', () async {
      final c = await started();
      repo.onSend = (_, _) async =>
          throw rateLimited(20, reason: 'duplicate_message');
      await c.send('same');
      expect(c.sendError, contains('already sent'));
      expect(c.sendError, contains('20'));
    });

    test('blank text is ignored', () async {
      final c = await started();
      await c.send('   ');
      expect(repo.sent, isEmpty);
    });
  });

  group('community restrictions', () {
    test('muted until a date disables composer with a reason', () async {
      repo.viewer = CommunityViewer(
        canPost: false,
        muted: true,
        mutedUntil: DateTime(2026, 10, 12, 9),
      );
      final c = await started();
      expect(c.composerDisabledReason, contains('muted'));
      await c.send('hello');
      expect(repo.sent, isEmpty);
    });

    test('cooldown and canPost=false', () async {
      repo.viewer = CommunityViewer(
        canPost: false,
        cooldownUntil: now.add(const Duration(minutes: 5)),
      );
      var c = await started();
      expect(c.composerDisabledReason, contains('cooldown'));
      repo.viewer = const CommunityViewer(canPost: false);
      c = await started();
      expect(c.composerDisabledReason, contains('unavailable'));
    });

    test(
      'viewer failure leaves the composer enabled (server enforces)',
      () async {
        repo.viewerError = const AppException('x');
        final c = await started();
        expect(c.composerDisabledReason, isNull);
      },
    );
  });

  group('activity chat', () {
    ActivityChatController activityChat(FakeActivityRepository acts) =>
        ActivityChatController(
          repository: repo,
          safety: safety,
          activities: acts,
          activityId: 'a1',
          currentUid: 'me',
          currentName: 'Me',
          idGenerator: () => 'client-id-${++ids}',
          clock: () => now,
        );

    test('header info from activity and approved members', () async {
      final acts = FakeActivityRepository([sampleActivity()]);
      acts.memberList = const [
        ActivityMember(
          userId: 'h1',
          displayName: 'Riya',
          status: MembershipStatus.approved,
          role: 'host',
        ),
        ActivityMember(
          userId: 'u2',
          displayName: 'Dev',
          status: MembershipStatus.approved,
          role: 'participant',
        ),
        ActivityMember(
          userId: 'u3',
          displayName: 'Req',
          status: MembershipStatus.requested,
          role: 'participant',
        ),
      ];
      final c = activityChat(acts);
      addTearDown(c.dispose);
      await c.start();
      await settle();
      expect(c.title, 'Sunday brunch at Kala Ghoda');
      expect(c.subtitle, '2 members');
      expect(c.headerAvatars.map((p) => p.displayName), ['Riya', 'Dev']);
      expect(c.readOnlyBanner, isNull);
      expect(c.composerDisabledReason, isNull);
    });

    test('cancelled/completed activity is read-only', () async {
      for (final s in [ActivityStatus.cancelled, ActivityStatus.completed]) {
        final c = activityChat(
          FakeActivityRepository([sampleActivity(status: s)]),
        );
        addTearDown(c.dispose);
        await c.start();
        await settle();
        expect(c.readOnlyBanner, contains('read-only'));
        expect(c.composerDisabledReason, isNotNull);
        await c.send('hi');
        expect(repo.sent, isEmpty);
      }
    });

    test('meta failure does not block messages', () async {
      final acts = FakeActivityRepository([])..error = const AppException('x');
      final c = activityChat(acts);
      addTearDown(c.dispose);
      await c.start();
      repo.emitWindow([msg('m1', 'bob', 'a')]);
      await settle();
      expect(c.status, ChatStatus.ready);
      expect(c.title, 'Activity chat');
    });
  });

  test('report sends message context', () async {
    final c = await started();
    await c.report(
      c.messages.first,
      const ReportResult(ReportReason.spam, 'ads'),
    );
    expect(safety.reports.single, {
      'targetType': 'message',
      'targetId': 'm3',
      'reason': 'spam',
      'details': 'ads',
      'context': {'roomType': 'community'},
    });
  });

  test('dispose cancels the Firestore listener', () async {
    final c = community();
    await c.start();
    repo.emitWindow([msg('m1', 'bob', 'a')]);
    await settle();
    expect(repo.windowActive, isTrue);
    c.dispose();
    await settle();
    expect(repo.windowActive, isFalse);
  });

  test('opening the chat marks it read in the store', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ChatReadStore(uid: () => 'me');
    final c = community(store: store);
    addTearDown(c.dispose);
    await c.start();
    final newest = DateTime(2026, 10, 10, 11);
    repo.emitWindow([msg('m1', 'bob', 'a', at: newest)]);
    await settle();
    await settle();
    expect(store.lastRead('community'), newest);
  });
}
