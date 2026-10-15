import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/user_photo_cache.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/plan_banner.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../social/application/requests_controller.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/requests_screen.dart';
import '../application/chat_read_store.dart';
import '../application/community_unread_controller.dart';
import '../application/chats_list_controller.dart';
import '../data/chat_repository.dart';
import 'chat_identity.dart';
import '../../../core/theme/theme_colors.dart';

/// The Chats tab: activities I host or have joined, with last message, time and unread dot.
class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

enum _ChatFilter { all, unread, plans, direct, requests }

class _ChatsListScreenState extends State<ChatsListScreen> {
  late final ChatsListController _c;
  late final RequestsController _requests;
  late final ChatReadStore _store;
  late final String _myUid;
  StreamSubscription<List<DmConversation>>? _dmSub;
  List<DmConversation> _dms = const [];
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
    _store = context.read<ChatReadStore>();
    _myUid = ChatIdentity.of(context).uid;
    _store.addListener(_onStore);
    _requests = RequestsController(
      social: context.read<SocialRepository>(),
      mine: context.read<MyActivitiesRepository>(),
      activities: context.read<ActivityRepository>(),
    )..load();
    _dmSub = chat.watchConversations(_myUid).listen(
      (list) {
        if (mounted) setState(() => _dms = list);
      },
      onError: (_) {}, // direct chats are optional; plans still show
    );
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  bool _dmUnread(DmConversation d) => _store.isUnread(
    'dm:${d.otherUid}',
    latest: d.updatedAt,
    senderId: d.lastSenderId,
    myUid: _myUid,
  );

  Widget _filterRow() => ListenableBuilder(
    listenable: _requests,
    builder: (_, _) => _FilterRow(
      value: _filter,
      requestCount: _requests.count,
      onChanged: (f) {
        setState(() => _filter = f);
        if (f == _ChatFilter.requests) _requests.load();
      },
    ),
  );

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _dmSub?.cancel();
    _requests.dispose();
    _search.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
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
            : Text(
                'Chats',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
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
                  (_filter == _ChatFilter.all ||
                      _filter == _ChatFilter.unread) &&
                  (q.isEmpty || 'mingle community'.contains(q));
              if (_filter == _ChatFilter.requests) {
                return Column(
                  children: [
                    _filterRow(),
                    Expanded(child: RequestsView(controller: _requests)),
                  ],
                );
              }
              final showPlans = _filter != _ChatFilter.direct;
              final plans = showPlans ? items : const <MyActivity>[];
              final dms = _filter == _ChatFilter.plans
                  ? const <DmConversation>[]
                  : [
                      for (final d in _dms)
                        if ((_filter != _ChatFilter.unread || _dmUnread(d)) &&
                            (q.isEmpty ||
                                (UserPhotoCache.instance
                                        .watch(d.otherUid)
                                        .value
                                        ?.name
                                        .toLowerCase()
                                        .contains(q) ??
                                    false) ||
                                d.lastText.toLowerCase().contains(q)))
                          d,
                    ];
              return Column(
                children: [
                  _filterRow(),
                  if (showCommunity)
                    _PinnedCommunityTile(
                      onlyUnread: _filter == _ChatFilter.unread,
                    ),
                  Expanded(
                    child: plans.isEmpty && dms.isEmpty
                        ? _emptyFor(context, q)
                        : RefreshIndicator(
                            onRefresh: () async {
                              await Future.wait([_c.load(), _requests.load()]);
                            },
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                for (final d in dms)
                                  _DmRow(
                                    convo: d,
                                    unread: _dmUnread(d),
                                    myUid: _myUid,
                                  ),
                                for (final p in plans)
                                  _ChatRow(
                                    item: p,
                                    preview: _c.previewFor(p),
                                    unread: _c.isUnread(p),
                                    myUid: _c.myUid,
                                  ),
                              ],
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
    if (_filter == _ChatFilter.direct) {
      return const EmptyState(
        icon: Icons.person_outline,
        title: 'No direct chats yet',
        message:
            'Become friends with someone, then message them from the People list on the map.',
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
  const _FilterRow({
    required this.value,
    required this.onChanged,
    required this.requestCount,
  });
  final _ChatFilter value;
  final int requestCount;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final labels = {
      _ChatFilter.all: 'All',
      _ChatFilter.unread: 'Unread',
      _ChatFilter.plans: 'Plans',
      _ChatFilter.direct: 'Friends',
      _ChatFilter.requests: requestCount > 0
          ? 'Requests · $requestCount'
          : 'Requests',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            for (final f in _ChatFilter.values) ...[
              _FilterPill(
                label: labels[f]!,
                selected: value == f,
                onTap: () => onChanged(f),
                theme: t,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rounded pill: filled brand colour when selected, a hairline outline when not.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? scheme.primary : context.outline,
            width: 1.2,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? scheme.onPrimary : context.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One conversation row: avatar, title, one-line preview, time and unread dot,
/// with a hairline under the text (not under the avatar).
class _ChatTile extends StatelessWidget {
  const _ChatTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    required this.onTap,
    this.unreadKey,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final DateTime time;
  final bool unread;
  final VoidCallback onTap;
  final Key? unreadKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            SizedBox(width: 46, height: 46, child: leading),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 11, 16, 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.outline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: unread ? FontWeight.w600 : null,
                              color: unread
                                  ? t.colorScheme.onSurface
                                  : t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.chatTime(time),
                          style: t.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (unread)
                          Container(
                            key: unreadKey,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-to-one conversation; name and photo come from the friend's profile.
class _DmRow extends StatelessWidget {
  const _DmRow({
    required this.convo,
    required this.unread,
    required this.myUid,
  });
  final DmConversation convo;
  final bool unread;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSummary?>(
      valueListenable: UserPhotoCache.instance.watch(convo.otherUid),
      builder: (context, who, _) {
        final name = who?.name ?? 'Friend';
        return _ChatTile(
          key: ValueKey('dm-${convo.otherUid}'),
          onTap: () => context.push(
            '/dm/${convo.otherUid}',
            extra: {'name': name, 'photoUrl': who?.photoUrl},
          ),
          leading: UserAvatar(name: name, photoUrl: who?.photoUrl, size: 46),
          title: name,
          subtitle:
              '${convo.lastSenderId == myUid ? 'You: ' : ''}${convo.lastText}',
          time: convo.updatedAt,
          unread: unread,
        );
      },
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
    final a = item.activity;
    final ended = a.status != ActivityStatus.scheduled;
    final subtitle = preview == null
        ? (ended
              ? (a.status == ActivityStatus.cancelled
                    ? 'Cancelled'
                    : 'Completed')
              : 'No messages yet')
        : '${preview!.senderId == myUid ? 'You' : preview!.senderName}: ${preview!.text}';
    final host = a.hostDisplayName.trim();
    return _ChatTile(
      key: ValueKey('plan-${a.id}'),
      onTap: () => context.push('/activity/${a.id}/chat'),
      // The plan's banner, with a small badge for who is hosting it.
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: PlanBanner(
                title: a.title,
                category: a.category,
                coverUrl: a.coverImageUrl,
                memCacheWidth: 140,
              ),
            ),
          ),
          if (host.isNotEmpty)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Text(
                  host[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: a.title,
      subtitle: subtitle,
      time: preview?.createdAt ?? a.startAt,
      unread: unread,
      unreadKey: ValueKey('unread-${a.id}'),
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Material(
            color: context.tint,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/community'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_rounded,
                        color: t.colorScheme.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                              const SizedBox(width: 8),
                              Icon(
                                Icons.push_pin,
                                size: 13,
                                color: t.colorScheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            unread
                                ? 'New messages'
                                : 'Chat with everyone in the community',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5,
                              fontWeight: unread ? FontWeight.w600 : null,
                              color: t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread)
                      Container(
                        key: const ValueKey('unread-community'),
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: t.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(
                      Icons.chevron_right,
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
