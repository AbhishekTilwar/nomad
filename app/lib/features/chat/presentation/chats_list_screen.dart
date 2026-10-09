import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../application/chat_read_store.dart';
import '../application/chats_list_controller.dart';
import '../data/chat_repository.dart';
import 'chat_header.dart';
import 'chat_identity.dart';

/// The Chats tab: activities I host or have joined, with last message, time and unread dot.
class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  late final ChatsListController _c;

  @override
  void initState() {
    super.initState();
    final chat = context.read<ChatRepository>();
    _c = ChatsListController(
      repository: context.read<MyActivitiesRepository>(),
      store: context.read<ChatReadStore>(),
      myUid: ChatIdentity.of(context).uid,
      blockedIds: chat.blockedIds,
    )..load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          switch (_c.status) {
            case ChatsListStatus.loading:
              return LoadingSkeleton.list();
            case ChatsListStatus.error:
              return ErrorState(
                title: 'Couldn\'t load your chats',
                message: _c.error,
                onRetry: _c.load,
              );
            case ChatsListStatus.ready:
              if (_c.items.isEmpty) {
                return EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No chats yet',
                  message:
                      'Join or host an activity and its group chat will show up here.',
                  actionLabel: 'Find activities',
                  onAction: () => context.go('/discover'),
                );
              }
              return RefreshIndicator(
                onRefresh: _c.load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _c.items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 88),
                  itemBuilder: (context, i) => _ChatRow(
                    item: _c.items[i],
                    preview: _c.previewFor(_c.items[i]),
                    unread: _c.isUnread(_c.items[i]),
                    myUid: _c.myUid,
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.item,
    required this.preview,
    required this.unread,
    required this.myUid,
  });
  final MyActivity item;
  final ActivityLastMessage? preview;
  final bool unread;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = item.activity;
    final people = item.participants.isNotEmpty
        ? item.participants
        : [
            ParticipantPreview(
              uid: a.hostId,
              displayName: a.hostDisplayName,
              photoUrl: a.hostPhotoUrl,
            ),
          ];
    final ended = a.status != ActivityStatus.scheduled;
    final subtitle = preview == null
        ? (ended
              ? (a.status == ActivityStatus.cancelled
                    ? 'Cancelled'
                    : 'Completed')
              : 'No messages yet')
        : '${preview!.senderId == myUid ? 'You' : preview!.senderName}: ${preview!.text}';
    final when = preview?.createdAt ?? a.startAt;
    return ListTile(
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      onTap: () => context.push('/activity/${a.id}/chat'),
      leading: SizedBox(
        width: 56,
        child: Align(
          alignment: Alignment.centerLeft,
          child: OverlappedAvatars(people: people, size: 36),
        ),
      ),
      title: Text(
        a.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.textTheme.titleMedium?.copyWith(
          fontWeight: unread ? FontWeight.w800 : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.textTheme.bodyMedium?.copyWith(
          color: unread
              ? t.colorScheme.onSurface
              : t.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.chatTime(when),
            style: t.textTheme.bodySmall?.copyWith(
              color: unread
                  ? t.colorScheme.primary
                  : t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (unread)
            Container(
              key: ValueKey('unread-${a.id}'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: t.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}
