import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/core/widgets/community_message_bubble.dart';
import 'package:nomad_mingle/core/widgets/empty_state.dart';
import 'package:nomad_mingle/core/widgets/error_state.dart';
import 'package:nomad_mingle/features/activities/data/activity_repository.dart';
import 'package:nomad_mingle/features/activities/data/my_activities_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/auth/application/session_controller.dart';
import 'package:nomad_mingle/features/auth/data/auth_repository.dart';
import 'package:nomad_mingle/features/chat/application/chat_controller.dart';
import 'package:nomad_mingle/features/chat/application/chat_read_store.dart';
import 'package:nomad_mingle/features/chat/application/community_unread_controller.dart';
import 'package:nomad_mingle/features/chat/data/chat_repository.dart';
import 'package:nomad_mingle/features/chat/presentation/activity_chat_screen.dart';
import 'package:nomad_mingle/features/chat/presentation/chat_view.dart';
import 'package:nomad_mingle/features/chat/presentation/chats_list_screen.dart';
import 'package:nomad_mingle/features/chat/presentation/community_chat_button.dart';
import 'package:nomad_mingle/features/chat/presentation/community_chat_screen.dart';
import 'package:nomad_mingle/features/profile/data/user_profile.dart';
import 'package:nomad_mingle/features/safety/data/safety_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import 'chat_test_support.dart';

/// pumpAndSettle never settles while a loading skeleton is pulsing; pump a bounded time instead.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late FakeChatRepository repo;
  late FakeSafetyRepository safety;
  late ChatReadStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeChatRepository();
    safety = FakeSafetyRepository();
    store = ChatReadStore(uid: () => 'me');
  });

  ChatController controller() => CommunityChatController(
    repository: repo,
    safety: safety,
    currentUid: 'me',
    currentName: 'Me',
    readStore: store,
    idGenerator: () => 'client-id-1',
  );

  Future<ChatController> pumpView(
    WidgetTester t, {
    List<dynamic>? messages,
    bool mayHaveMore = false,
    Widget Function(Widget child)? wrap,
  }) async {
    final c = controller();
    addTearDown(c.dispose);
    await c.start();
    Widget view = Scaffold(
      body: ChatView(controller: c, introText: 'Welcome'),
    );
    await t.pumpWidget(MaterialApp(theme: AppTheme.light, home: view));
    if (messages != null) {
      repo.emitWindow(messages.cast(), mayHaveMore: mayHaveMore);
    }
    await t.pump();
    await t.pump();
    return c;
  }

  testWidgets('shows a loading skeleton before the first window', (t) async {
    await pumpView(t);
    expect(find.bySemanticsLabel('Loading messages'), findsOneWidget);
  });

  testWidgets(
    'renders messages: mine primary-filled, others with sender name',
    (t) async {
      await pumpView(
        t,
        messages: [
          msg('m2', 'me', 'my message', minutesAgo: 1),
          msg('m1', 'bob', 'bobs message', minutesAgo: 2, name: 'Bob Rao'),
        ],
      );
      expect(find.text('my message'), findsOneWidget);
      expect(find.text('bobs message'), findsOneWidget);
      expect(
        find.text('Bob Rao'),
        findsOneWidget,
      ); // sender name only on others
      expect(find.text('Me'), findsNothing);
      final bubbles = t
          .widgetList<CommunityMessageBubble>(
            find.byType(CommunityMessageBubble),
          )
          .toList();
      expect(bubbles.firstWhere((b) => b.message.id == 'm2').isMine, isTrue);
      expect(bubbles.firstWhere((b) => b.message.id == 'm1').isMine, isFalse);
      // mine is filled with the primary colour
      final mineDeco =
          t
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(CommunityMessageBubble).first,
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(mineDeco.color, AppTheme.light.colorScheme.primary);
      expect(find.text('Today'), findsOneWidget);
      expect(
        find.text('Welcome'),
        findsOneWidget,
      ); // system line at the start of the chat
    },
  );

  testWidgets('empty state', (t) async {
    await pumpView(t, messages: []);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('error state with retry', (t) async {
    final c = await pumpView(t);
    repo.emitWindowError(Exception('x'));
    await t.pump();
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byTooltip('Send message'), findsNothing);
    await t.tap(find.text('Try again'));
    await t.pump();
    await t.pump();
    await t.pump();
    repo.emitWindow([msg('m1', 'bob', 'back online')]);
    await t.pump();
    await t.pump();
    expect(c.status, ChatStatus.ready);
    expect(find.text('back online'), findsOneWidget);
  });

  testWidgets('muted user: composer disabled with the reason', (t) async {
    repo.viewer = CommunityViewer(
      canPost: false,
      muted: true,
      mutedUntil: DateTime(2030, 1, 1, 9),
    );
    await pumpView(t, messages: [msg('m1', 'bob', 'hi')]);
    await t.pump();
    expect(find.byKey(const ValueKey('composer-disabled')), findsOneWidget);
    expect(find.textContaining('muted until'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'send: clears composer; failure shows failed bubble + error; tap retries',
    (t) async {
      final c = await pumpView(t, messages: [msg('m1', 'bob', 'hi')]);
      repo.onSend = (_, _) async => throw rateLimited(30);
      await t.enterText(find.byType(TextField), 'my draft');
      await t.pump();
      await t.tap(find.byTooltip('Send message'));
      await t.pump();
      await t.pump();
      expect(find.text('my draft'), findsOneWidget); // kept, as a failed bubble
      expect(find.text('Failed to send'), findsOneWidget);
      expect(find.byKey(const ValueKey('send-error')), findsOneWidget);
      expect(find.textContaining('30s'), findsWidgets);
      expect(find.byKey(const ValueKey('composer-disabled')), findsOneWidget);
      // Stop the cooldown ticker before the test ends.
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('send: a failed message can be retried by tapping it', (t) async {
    await pumpView(t, messages: [msg('m1', 'bob', 'hi')]);
    repo.onSend = (_, _) async =>
        throw const AppException('Server hiccup', code: 'internal');
    await t.enterText(find.byType(TextField), 'retry me');
    await t.pump();
    await t.tap(find.byTooltip('Send message'));
    await t.pump();
    await t.pump();
    expect(find.text('Failed to send'), findsOneWidget);
    expect(find.text('Server hiccup'), findsOneWidget);
    repo.onSend = null;
    await t.tap(find.text('retry me'));
    await t.pump();
    await t.pump();
    expect(find.text('Failed to send'), findsNothing);
    expect(repo.sent.map((s) => s.cid).toSet(), {'client-id-1'});
    expect(find.text('retry me'), findsOneWidget);
  });

  testWidgets('report flow from long-press action sheet', (t) async {
    await pumpView(
      t,
      messages: [
        msg('m1', 'bob', 'spammy ad', minutesAgo: 1, name: 'Bob Rao'),
        msg('m0', 'me', 'mine', minutesAgo: 2),
      ],
    );
    await t.longPress(find.text('spammy ad'));
    await t.pumpAndSettle();
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Block Bob Rao'), findsOneWidget);
    await t.tap(find.text('Report message'));
    await t.pumpAndSettle();
    await t.tap(find.text('Spam or advertising'));
    await t.pump();
    await t.ensureVisible(find.text('Submit report'));
    await t.pump();
    await t.tap(find.text('Submit report'));
    await t.pumpAndSettle();
    expect(safety.reports.single['targetId'], 'm1');
    expect(safety.reports.single['reason'], 'spam');
    expect(safety.reports.single['context'], {'roomType': 'community'});
    expect(find.textContaining('Report sent'), findsOneWidget);
  });

  testWidgets('no action sheet on my own messages', (t) async {
    await pumpView(t, messages: [msg('m0', 'me', 'mine')]);
    await t.longPress(find.text('mine'));
    await t.pumpAndSettle();
    expect(find.text('Report message'), findsNothing);
  });

  testWidgets('block flow hides that sender immediately', (t) async {
    await pumpView(
      t,
      messages: [
        msg('m1', 'bob', 'rude words', minutesAgo: 1, name: 'Bob Rao'),
        msg('m2', 'amy', 'nice words', minutesAgo: 2),
      ],
    );
    await t.longPress(find.text('rude words'));
    await t.pumpAndSettle();
    await t.tap(find.text('Block Bob Rao'));
    await t.pumpAndSettle();
    await t.tap(find.text('Block'));
    await t.pumpAndSettle();
    expect(safety.blockedUids, ['bob']);
    expect(find.text('rude words'), findsNothing);
    expect(find.text('nice words'), findsOneWidget);
  });

  testWidgets(
    'scrolling up loads older messages and appends without duplicates',
    (t) async {
      final c = await pumpView(
        t,
        messages: [
          for (var i = 30; i >= 1; i--)
            msg('m$i', 'bob', 'msg number $i', minutesAgo: 100 - i),
        ],
        mayHaveMore: true,
      );
      repo.olderPages.add(
        ChatPage([
          msg(
            'm1',
            'bob',
            'msg number 1',
            minutesAgo: 99,
          ), // duplicate of live window
          msg('o1', 'bob', 'older message', minutesAgo: 500),
        ]),
      );
      expect(repo.olderCursorsRequested, isEmpty);
      await t.fling(find.byType(ListView), const Offset(0, 4000), 4000);
      await t.pumpAndSettle();
      expect(repo.olderCursorsRequested, hasLength(1));
      final ids = c.messages.map((m) => m.id).toList();
      expect(ids.length, 31);
      expect(ids.toSet().length, 31);
      expect(find.text('older message'), findsOneWidget);
    },
  );

  group('screens', () {
    Future<void> pumpApp(
      WidgetTester t, {
      required String start,
      FakeActivityRepository? activities,
      FakeMyActivitiesRepository? mine,
    }) async {
      final session = SessionController(
        auth: FakeAuthRepository(
          const AuthUser(
            uid: 'me',
            email: 'm@x.com',
            emailVerified: true,
            displayName: 'Me',
          ),
        ),
        profiles: FakeProfileRepository(
          profile: const UserProfile(
            uid: 'me',
            displayName: 'Me',
            city: 'mumbai',
            profileCompleted: true,
          ),
        ),
      );
      addTearDown(session.dispose);
      final communityUnread = CommunityUnreadController(
        repository: repo,
        store: store,
        uid: () => 'me',
      );
      addTearDown(communityUnread.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/explore',
            builder: (_, _) => const Scaffold(body: Text('explore')),
          ),
          GoRoute(
            path: '/discover',
            builder: (_, _) => const Scaffold(body: Text('discover')),
          ),
          GoRoute(
            path: '/community',
            builder: (_, _) => const CommunityChatScreen(),
          ),
          GoRoute(path: '/chats', builder: (_, _) => const ChatsListScreen()),
          GoRoute(
            path: '/legal/guidelines',
            builder: (_, _) => const Scaffold(body: Text('guidelines page')),
          ),
          GoRoute(
            path: '/activity/:id/chat',
            builder: (_, s) =>
                ActivityChatScreen(activityId: s.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ChatRepository>.value(value: repo),
            Provider<SafetyRepository>.value(value: safety),
            Provider<ActivityRepository>.value(
              value: activities ?? FakeActivityRepository([sampleActivity()]),
            ),
            Provider<MyActivitiesRepository>.value(
              value: mine ?? FakeMyActivitiesRepository(),
            ),
            ChangeNotifierProvider<ChatReadStore>.value(value: store),
            ChangeNotifierProvider<CommunityUnreadController>.value(
              value: communityUnread,
            ),
            ChangeNotifierProvider<SessionController>.value(value: session),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await t.pump();
      await t.pump();
      router.go(start);
      await settle(t);
    }

    testWidgets('community screen: title, close, guidelines, listener disposed', (
      t,
    ) async {
      await pumpApp(t, start: '/community');
      repo.emitWindow([msg('m1', 'bob', 'hello community')]);
      await t.pump();
      await t.pump();
      expect(find.text('Mingle Community'), findsOneWidget);
      expect(find.text('hello community'), findsOneWidget);
      expect(repo.windowActive, isTrue);

      await t.tap(find.byTooltip('More options'));
      await settle(t);
      await t.tap(find.text('Community guidelines'));
      await settle(t);
      expect(find.text('guidelines page'), findsOneWidget);
      // listener stays while the chat is still in the stack; leaving it disposes it
      GoRouter.of(t.element(find.text('guidelines page'))).go('/explore');
      await settle(t);
      expect(repo.windowActive, isFalse);
    });

    testWidgets('community screen close button leaves the chat', (t) async {
      await pumpApp(t, start: '/community');
      await t.tap(find.byTooltip('Close'));
      await settle(t);
      expect(find.text('explore'), findsOneWidget);
      expect(repo.windowActive, isFalse);
    });

    testWidgets('activity screen: members header and read-only banner', (
      t,
    ) async {
      final acts = FakeActivityRepository([
        sampleActivity(status: ActivityStatus.cancelled),
      ]);
      acts.memberList = const [
        ActivityMember(
          userId: 'h1',
          displayName: 'Riya Shah',
          status: MembershipStatus.approved,
          role: 'host',
        ),
        ActivityMember(
          userId: 'u2',
          displayName: 'Dev Patel',
          status: MembershipStatus.approved,
          role: 'participant',
        ),
      ];
      await pumpApp(t, start: '/activity/a1/chat', activities: acts);
      repo.emitWindow([msg('m1', 'u2', 'see you there', name: 'Dev Patel')]);
      await t.pump();
      await t.pump();
      expect(find.text('Sunday brunch at Kala Ghoda'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('composer-disabled')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('chats list: previews, unread dot, tap opens activity chat', (
      t,
    ) async {
      final mine = FakeMyActivitiesRepository();
      mine.byRole[MyActivitiesRole.joined] = [
        MyActivity(
          activity: sampleActivity(id: 'a1', title: 'Brunch club'),
          participants: const [
            ParticipantPreview(uid: 'h1', displayName: 'Riya Shah'),
            ParticipantPreview(uid: 'u2', displayName: 'Dev Patel'),
          ],
          lastMessage: ActivityLastMessage(
            text: 'Who is bringing snacks?',
            senderName: 'Dev Patel',
            senderId: 'u2',
            createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
          ),
        ),
      ];
      mine.byRole[MyActivitiesRole.hosted] = [
        MyActivity(
          activity: sampleActivity(id: 'a2', title: 'Hike plans'),
          lastMessage: ActivityLastMessage(
            text: 'See you all',
            senderName: 'Me',
            senderId: 'me',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
        ),
      ];
      await pumpApp(t, start: '/chats', mine: mine);
      // Community is pinned above every plan chat.
      expect(
        t.getTopLeft(find.text('Mingle Community')).dy,
        lessThan(t.getTopLeft(find.text('Brunch club')).dy),
      );
      expect(find.text('Brunch club'), findsOneWidget);
      expect(find.text('Dev Patel: Who is bringing snacks?'), findsOneWidget);
      expect(find.text('You: See you all'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-a1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('unread-a2')),
        findsNothing,
      ); // my own message
      await t.tap(find.text('Brunch club'));
      await settle(t);
      expect(find.byTooltip('Back'), findsOneWidget); // activity chat opened
      // opening the chat marks it read -> back on the list the dot is gone
      repo.emitWindow([msg('m1', 'u2', 'Who is bringing snacks?')]);
      await t.pump();
      await t.pump();
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byKey(const ValueKey('unread-a1')), findsNothing);
    });

    testWidgets('chats list: empty and error states', (t) async {
      await pumpApp(t, start: '/chats');
      expect(find.text('No plan chats yet'), findsOneWidget);
      // Community stays pinned even with no plan chats.
      expect(find.text('Mingle Community'), findsOneWidget);
      final failing = FakeMyActivitiesRepository()
        ..error = const AppException('Server down');
      await pumpApp(t, start: '/chats', mine: failing);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Server down'), findsOneWidget);
    });
  });

  group('CommunityChatButton', () {
    testWidgets('starts listener, shows badge on unread, stops on dispose', (
      t,
    ) async {
      final unread = CommunityUnreadController(
        repository: repo,
        store: store,
        uid: () => 'me',
      );
      addTearDown(unread.dispose);
      var taps = 0;
      Widget app(bool show) =>
          ChangeNotifierProvider<CommunityUnreadController>.value(
            value: unread,
            child: MaterialApp(
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    if (show) CommunityChatButton(onPressed: () => taps++),
                  ],
                ),
              ),
            ),
          );
      await t.pumpWidget(app(true));
      await t.pump();
      expect(repo.newestActive, isTrue);
      expect(find.byType(Badge), findsOneWidget);
      expect(t.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      repo.emitNewest(msg('m1', 'bob', 'a', at: DateTime(2026, 1, 1)));
      await t.pump();
      repo.emitNewest(msg('m2', 'bob', 'b', at: DateTime(2026, 1, 2)));
      await t.pump();
      await t.pump();
      expect(t.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      await t.tap(find.byType(CommunityChatButton));
      expect(taps, 1);
      await t.pumpWidget(app(false));
      await t.pump();
      expect(repo.newestActive, isFalse);
    });
  });
}
