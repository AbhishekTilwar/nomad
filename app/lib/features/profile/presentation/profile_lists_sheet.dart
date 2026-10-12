import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/plan_emoji.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../../social/data/social_repository.dart';

/// What the profile drawer lists.
enum ProfileList { hosted, joined, friends }

/// Opens the drawer for [kind]: everything hosted / joined (upcoming first,
/// then past, loaded a page at a time as you scroll) or all friends. A person
/// can have hundreds of plans, so the profile page itself never lists them all.
Future<void> showProfileListSheet(BuildContext context, ProfileList kind) {
  final plans = context.read<MyActivitiesRepository>();
  final social = context.read<SocialRepository>();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) =>
          _ListSheet(kind: kind, plans: plans, social: social, scroll: scroll),
    ),
  );
}

class _ListSheet extends StatefulWidget {
  const _ListSheet({
    required this.kind,
    required this.plans,
    required this.social,
    required this.scroll,
  });
  final ProfileList kind;
  final MyActivitiesRepository plans;
  final SocialRepository social;
  final ScrollController scroll;

  @override
  State<_ListSheet> createState() => _ListSheetState();
}

class _ListSheetState extends State<_ListSheet> {
  final _plans = <Activity>[];
  List<FriendEntry> _friends = const [];
  // Plans come from two feeds: upcoming first, then finished ones.
  late final List<MyActivitiesRole> _feeds = [
    widget.kind == ProfileList.hosted
        ? MyActivitiesRole.hosted
        : MyActivitiesRole.joined,
    MyActivitiesRole.past,
  ];
  int _feed = 0;
  String? _cursor;
  bool _loading = true;
  bool _done = false;
  String? _error;

  bool get _isFriends => widget.kind == ProfileList.friends;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onScroll);
    _more();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final s = widget.scroll;
    if (!s.hasClients || _loading || _done) return;
    if (s.position.extentAfter < 300) _more();
  }

  Future<void> _more() async {
    if (_done ||
        (_loading && _plans.isNotEmpty) ||
        (_loading && _isFriends && _friends.isNotEmpty)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isFriends) {
        _friends = await widget.social.friends();
        _done = true;
      } else {
        // Keep reading pages until something visible turns up or feeds run out.
        var added = 0;
        while (added == 0 && !_done) {
          final page = await widget.plans.list(
            _feeds[_feed],
            cursor: _cursor,
            limit: 30,
          );
          final wantHost = widget.kind == ProfileList.hosted;
          for (final m in page.items) {
            // The finished feed holds hosted and joined plans together.
            if (_feeds[_feed] == MyActivitiesRole.past &&
                m.activity.isHost != wantHost) {
              continue;
            }
            _plans.add(m.activity);
            added++;
          }
          _cursor = page.nextCursor;
          if (_cursor == null) {
            if (_feed + 1 < _feeds.length) {
              _feed++;
            } else {
              _done = true;
            }
          }
        }
      }
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Couldn\'t load this list. Try again.';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    // A short page may not fill the screen, so no scroll would ever ask for
    // more: check again once laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _error == null) _onScroll();
    });
  }

  String get _title => switch (widget.kind) {
    ProfileList.hosted => 'Hosted',
    ProfileList.joined => 'Joined',
    ProfileList.friends => 'Friends',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final count = _isFriends ? _friends.length : _plans.length;
    final empty = count == 0 && !_loading && _error == null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(
                _title,
                key: const ValueKey('list-sheet-title'),
                style: t.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Text(
                  _done ? '$count' : '$count+',
                  style: t.textTheme.titleMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.outline),
        Expanded(
          child: empty
              ? EmptyState(
                  icon: _isFriends
                      ? Icons.group_outlined
                      : Icons.event_available_outlined,
                  title: switch (widget.kind) {
                    ProfileList.hosted => 'You haven\'t hosted a plan yet',
                    ProfileList.joined => 'You haven\'t joined a plan yet',
                    ProfileList.friends => 'No friends yet',
                  },
                  message: _isFriends
                      ? 'Meet people at a plan, then add them as friends.'
                      : null,
                )
              : ListView.builder(
                  controller: widget.scroll,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: count + 1,
                  itemBuilder: (context, i) {
                    if (i == count) return _footer(context);
                    return _isFriends
                        ? _FriendRow(friend: _friends[i])
                        : _PlanRow(activity: _plans[i]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _more, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// A plan as a compact row: emoji, title, when, and Ended/Cancelled if over.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = activity;
    final over = a.status != ActivityStatus.scheduled;
    final color = CategoryStyle.color(a.category);
    final note = a.status == ActivityStatus.cancelled
        ? 'Cancelled'
        : (over ? 'Ended' : null);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/activity/${a.id}');
      },
      child: Opacity(
        opacity: over ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  PlanEmoji.of(a.title, a.category),
                  style: const TextStyle(fontSize: 22, height: 1.1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [Formatters.activityWhen(a.startAt), ?note].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});
  final FriendEntry friend;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.push('/user/${friend.uid}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              name: friend.displayName,
              photoUrl: friend.photoUrl,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                friend.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleSmall?.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
