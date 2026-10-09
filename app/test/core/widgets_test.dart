import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/core/widgets/activity_card.dart';
import 'package:nomad_mingle/core/widgets/chat_input.dart';
import 'package:nomad_mingle/core/widgets/community_message_bubble.dart';
import 'package:nomad_mingle/core/widgets/empty_state.dart';
import 'package:nomad_mingle/core/widgets/error_state.dart';
import 'package:nomad_mingle/core/widgets/join_activity_button.dart';
import 'package:nomad_mingle/core/widgets/user_avatar.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/chat/models/chat_message.dart';

import '../support/fakes.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('ActivityCard', () {
    testWidgets('renders title, host, venue and spots', (t) async {
      await t.pumpWidget(wrap(ActivityCard(activity: sampleActivity())));
      expect(find.text('Sunday brunch at Kala Ghoda'), findsOneWidget);
      expect(find.textContaining('Riya Shah'), findsWidgets);
      expect(find.textContaining('Kala Ghoda Cafe'), findsOneWidget);
      expect(find.text('4 spots left'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
    });
    testWidgets('shows Full and Cancelled states', (t) async {
      await t.pumpWidget(
        wrap(
          ActivityCard(activity: sampleActivity(capacity: 2, participants: 2)),
        ),
      );
      expect(find.text('Full'), findsOneWidget);
      await t.pumpWidget(
        wrap(
          ActivityCard(
            activity: sampleActivity(status: ActivityStatus.cancelled),
          ),
        ),
      );
      expect(find.text('Cancelled'), findsOneWidget);
    });
    testWidgets('tap invokes callback', (t) async {
      var taps = 0;
      await t.pumpWidget(
        wrap(ActivityCard(activity: sampleActivity(), onTap: () => taps++)),
      );
      await t.tap(find.byType(ActivityCard));
      expect(taps, 1);
    });
  });

  group('joinUiStateFor', () {
    test('maps every state', () {
      expect(joinUiStateFor(sampleActivity()), JoinUiState.join);
      expect(
        joinUiStateFor(sampleActivity(approvalRequired: true)),
        JoinUiState.requestToJoin,
      );
      expect(
        joinUiStateFor(sampleActivity(membership: MembershipStatus.requested)),
        JoinUiState.requested,
      );
      expect(
        joinUiStateFor(sampleActivity(membership: MembershipStatus.approved)),
        JoinUiState.joined,
      );
      expect(joinUiStateFor(sampleActivity(isHost: true)), JoinUiState.hosting);
      expect(
        joinUiStateFor(sampleActivity(capacity: 2, participants: 2)),
        JoinUiState.full,
      );
      expect(
        joinUiStateFor(sampleActivity(status: ActivityStatus.cancelled)),
        JoinUiState.cancelled,
      );
      expect(
        joinUiStateFor(sampleActivity(status: ActivityStatus.completed)),
        JoinUiState.completed,
      );
    });
    test('a joined member of a full activity stays Joined, not Full', () {
      expect(
        joinUiStateFor(
          sampleActivity(
            capacity: 2,
            participants: 2,
            membership: MembershipStatus.approved,
          ),
        ),
        JoinUiState.joined,
      );
    });
    test('cancelled wins over membership', () {
      expect(
        joinUiStateFor(
          sampleActivity(
            status: ActivityStatus.cancelled,
            membership: MembershipStatus.approved,
          ),
        ),
        JoinUiState.cancelled,
      );
    });
  });

  group('JoinActivityButton', () {
    testWidgets('join is tappable; full/cancelled/completed are disabled', (
      t,
    ) async {
      var joins = 0;
      await t.pumpWidget(
        wrap(
          JoinActivityButton(state: JoinUiState.join, onJoin: () => joins++),
        ),
      );
      await t.tap(find.text('Join'));
      expect(joins, 1);
      for (final (state, label) in [
        (JoinUiState.full, 'Full'),
        (JoinUiState.cancelled, 'Cancelled'),
        (JoinUiState.completed, 'Completed'),
      ]) {
        await t.pumpWidget(
          wrap(JoinActivityButton(state: state, onJoin: () => joins++)),
        );
        await t.tap(find.text(label));
        expect(joins, 1, reason: '$label must not trigger join');
      }
    });
    testWidgets('loading disables tapping', (t) async {
      var joins = 0;
      await t.pumpWidget(
        wrap(
          JoinActivityButton(
            state: JoinUiState.join,
            onJoin: () => joins++,
            loading: true,
          ),
        ),
      );
      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(joins, 0);
    });
    testWidgets('labels for requested / joined / request', (t) async {
      await t.pumpWidget(
        wrap(JoinActivityButton(state: JoinUiState.requested, onJoin: null)),
      );
      expect(find.textContaining('Requested'), findsOneWidget);
      await t.pumpWidget(
        wrap(JoinActivityButton(state: JoinUiState.joined, onJoin: null)),
      );
      expect(find.textContaining('Joined'), findsOneWidget);
      await t.pumpWidget(
        wrap(
          JoinActivityButton(state: JoinUiState.requestToJoin, onJoin: () {}),
        ),
      );
      expect(find.text('Request to join'), findsOneWidget);
    });
  });

  group('CommunityMessageBubble', () {
    final msg = ChatMessage(
      id: 'm1',
      senderId: 'u2',
      senderName: 'Dev Patel',
      text: 'Anyone up for a trek this weekend?',
      createdAt: DateTime(2026, 10, 9, 18, 30),
    );
    testWidgets('others: shows name, text and time', (t) async {
      await t.pumpWidget(
        wrap(CommunityMessageBubble(message: msg, isMine: false)),
      );
      expect(find.text('Dev Patel'), findsOneWidget);
      expect(find.text('Anyone up for a trek this weekend?'), findsOneWidget);
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.byKey(const ValueKey('sent-ticks')), findsNothing);
      final deco =
          t
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(CommunityMessageBubble),
                          matching: find.byType(Container),
                        )
                        .last,
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, Colors.white);
      expect(deco.border, isNotNull);
    });
    testWidgets('mine: indigo bubble, no avatar, double ticks when sent', (
      t,
    ) async {
      await t.pumpWidget(
        wrap(CommunityMessageBubble(message: msg, isMine: true)),
      );
      expect(find.byType(UserAvatar), findsNothing);
      expect(find.byKey(const ValueKey('sent-ticks')), findsOneWidget);
    });
    testWidgets('mine: hides sender name; pending shows Sending', (t) async {
      final pending = ChatMessage(
        id: 'p',
        senderId: 'me',
        senderName: 'Me',
        text: 'hi',
        createdAt: null,
        pending: true,
      );
      await t.pumpWidget(
        wrap(CommunityMessageBubble(message: pending, isMine: true)),
      );
      expect(find.text('Me'), findsNothing);
      expect(find.text('Sending…'), findsOneWidget);
    });
    testWidgets('long press and avatar tap callbacks fire', (t) async {
      var pressed = 0, avatar = 0;
      await t.pumpWidget(
        wrap(
          CommunityMessageBubble(
            message: msg,
            isMine: false,
            onLongPress: () => pressed++,
            onAvatarTap: () => avatar++,
          ),
        ),
      );
      await t.longPress(find.text('Anyone up for a trek this weekend?'));
      await t.tap(find.byType(UserAvatar));
      expect(pressed, 1);
      expect(avatar, 1);
    });
  });

  group('ChatInput', () {
    testWidgets('send disabled for empty, sends trimmed text and clears', (
      t,
    ) async {
      final sent = <String>[];
      await t.pumpWidget(wrap(ChatInput(onSend: (s) async => sent.add(s))));
      await t.tap(find.byTooltip('Send message'));
      await t.pump();
      expect(sent, isEmpty);
      await t.enterText(find.byType(TextField), '  hello  ');
      await t.pump();
      await t.tap(find.byTooltip('Send message'));
      await t.pump();
      expect(sent, ['hello']);
      expect(find.text('hello'), findsNothing);
    });
    testWidgets('over-length message cannot be sent', (t) async {
      final sent = <String>[];
      await t.pumpWidget(wrap(ChatInput(onSend: (s) async => sent.add(s))));
      await t.enterText(find.byType(TextField), 'a' * 501);
      await t.pump();
      await t.tap(find.byTooltip('Send message'));
      await t.pump();
      expect(sent, isEmpty);
      expect(find.text('Too long'), findsOneWidget);
    });
    testWidgets('keeps text when send fails', (t) async {
      await t.pumpWidget(
        wrap(ChatInput(onSend: (s) async => throw Exception('x'))),
      );
      await t.enterText(find.byType(TextField), 'keep me');
      await t.pump();
      await t.tap(find.byTooltip('Send message'));
      await t.pump();
      expect(find.text('keep me'), findsOneWidget);
    });
    testWidgets('disabled shows reason, no field', (t) async {
      await t.pumpWidget(
        wrap(
          ChatInput(
            onSend: (_) async {},
            enabled: false,
            disabledReason: 'You are muted.',
          ),
        ),
      );
      expect(find.text('You are muted.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Empty & error states', () {
    testWidgets('EmptyState action', (t) async {
      var n = 0;
      await t.pumpWidget(
        wrap(
          EmptyState(
            icon: Icons.event,
            title: 'Nothing here',
            actionLabel: 'Create',
            onAction: () => n++,
          ),
        ),
      );
      await t.tap(find.text('Create'));
      expect(n, 1);
    });
    testWidgets('ErrorState retry', (t) async {
      var n = 0;
      await t.pumpWidget(
        wrap(ErrorState(message: 'No internet', onRetry: () => n++)),
      );
      expect(find.text('No internet'), findsOneWidget);
      await t.tap(find.text('Try again'));
      expect(n, 1);
    });
  });
}
