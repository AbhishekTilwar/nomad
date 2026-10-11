import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../application/chat_read_store.dart';
import '../application/community_unread_controller.dart';
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

enum _ChatFilter { all, unread, plans }

class _ChatsListScreenState extends State<ChatsListScreen> {
  late final ChatsListController _c;
  final _search = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;
  bool _searching = false;

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
    _search.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: Icon(Icons.search),
                ),
              )
            : Text('Chats', style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          if (_searching)
            IconButton.outlined(
              tooltip: 'Close search',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searching = false;
                _search.clear();
              }),
            )
          else ...[
            IconButton.outlined(
              key: const ValueKey('chats-search'),
              tooltip: 'Search chats',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.outlined(
              key: const ValueKey('chats-invite'),
              tooltip: 'Invite friends',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/invite'),
            ),
          ],
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
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
              final q = _search.text.trim().toLowerCase();
              final items = [
                for (final i in _c.items)
                  if ((_filter != _ChatFilter.unread || _c.isUnread(i)) &&
                      (q.isEmpty || i.activity.title.toLowerCase().contains(q)))
                    i,
              ];
              final showCommunity =
                  _filter != _ChatFilter.plans &&
                  (q.isEmpty || 'mingle community'.contains(q));
              return Column(
                children: [
                  _FilterRow(
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                  if (showCommunity)
                    _PinnedCommunityTile(
                      onlyUnread: _filter == _ChatFilter.unread,
                    ),
                  Expanded(
                    child: items.isEmpty
                        ? _emptyFor(context, q)
                        : RefreshIndicator(
                            onRefresh: _c.load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: 20,
                                endIndent: 20,
                              ),
                              itemBuilder: (context, i) => _ChatRow(
                                item: items[i],
                                preview: _c.previewFor(items[i]),
                                unread: _c.isUnread(items[i]),
                                myUid: _c.myUid,
                              ),
                            ),
                          ),
                  ),
                ],
              );
          }
        },
      ),
    );
  }

  Widget _emptyFor(BuildContext context, String q) {
    if (q.isNotEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No matching chats',
      );
    }
    if (_filter == _ChatFilter.unread) {
      return const EmptyState(
        icon: Icons.mark_chat_read_outlined,
        title: 'No unread chats',
        message: 'You\'re all caught up.',
      );
    }
    return EmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No plan chats yet',
      message: 'Join or host an activity and its group chat will show up here.',
      actionLabel: 'Find activities',
      onAction: () => context.go('/explore'),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});
  final _ChatFilter value;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _ChatFilter.all: 'All',
      _ChatFilter.unread: 'Unread',
      _ChatFilter.plans: 'Plans',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          for (final f in _ChatFilter.values) ...[
            AppChip(
              label: labels[f]!,
              selected: value == f,
              style: AppChipStyle.tinted,
              onSelected: (_) => onChanged(f),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
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
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
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
              fontSize: 11,
              color: t.colorScheme.onSurfaceVariant,
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

/// Mingle Community, always pinned above the plan chats.
class _PinnedCommunityTile extends StatefulWidget {
  const _PinnedCommunityTile({this.onlyUnread = false});

  /// Hide the tile unless it has unread messages (Unread filter).
  final bool onlyUnread;

  @override
  State<_PinnedCommunityTile> createState() => _PinnedCommunityTileState();
}

class _PinnedCommunityTileState extends State<_PinnedCommunityTile> {
  late final CommunityUnreadController _unread = context
      .read<CommunityUnreadController>();

  @override
  void initState() {
    super.initState();
    _unread.start(); // idempotent; the listener is shared with the map header
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: _unread,
      builder: (context, _) {
        final unread = _unread.hasUnread;
        if (widget.onlyUnread && !unread) return const SizedBox.shrink();
        return Material(
          color: AppColors.tint,
          child: ListTile(
            minTileHeight: 72,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            onTap: () => context.push('/community'),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: t.colorScheme.primary,
              child: const Icon(Icons.forum, color: Colors.white),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    'Mingle Community',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.push_pin,
                  size: 14,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            subtitle: Text(
              unread ? 'New messages' : 'Chat with everyone in the community',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: unread ? FontWeight.w600 : null,
              ),
            ),
            trailing: unread
                ? Container(
                    key: const ValueKey('unread-community'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
