import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/data/my_activities_repository.dart';
import '../application/requests_controller.dart';
import '../data/social_repository.dart';
import '../../../core/theme/theme_colors.dart';

/// Friend requests sent to me and people asking to join my plans.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late final RequestsController _c;

  @override
  void initState() {
    super.initState();
    _c = RequestsController(
      social: context.read<SocialRepository>(),
      mine: context.read<MyActivitiesRepository>(),
      activities: context.read<ActivityRepository>(),
    )..load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Requests')),
    body: RequestsView(controller: _c),
  );
}

/// Friend requests and join requests, driven by [controller]. Used by the
/// Requests screen and by the Requests filter of the Chats tab.
class RequestsView extends StatefulWidget {
  const RequestsView({super.key, required this.controller});
  final RequestsController controller;

  @override
  State<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<RequestsView> {
  RequestsController get _c => widget.controller;
  final _busy = <String>{};

  Future<void> _act(
    FriendEntry f,
    Future<void> Function(FriendEntry) go,
  ) async {
    if (!_busy.add(f.uid)) return;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      await go(f);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    _busy.remove(f.uid);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        if (_c.loading) return LoadingSkeleton.list(count: 3);
        if (_c.error != null) {
          return ErrorState(message: _c.error, onRetry: _c.load);
        }
        if (_c.count == 0) {
          return const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'No requests',
            message:
                'Friend requests and people asking to join your plans show up here.',
          );
        }
        return RefreshIndicator(
          onRefresh: _c.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (_c.friendRequests.isNotEmpty) ...[
                _Header('Friend requests', _c.friendRequests.length),
                for (final f in _c.friendRequests)
                  ListTile(
                    contentPadding: AppSpacing.page,
                    leading: UserAvatar(
                      name: f.displayName,
                      photoUrl: f.photoUrl,
                      size: 48,
                    ),
                    title: Text(
                      f.displayName,
                      style: t.textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    subtitle: f.requestedAt == null
                        ? null
                        : Text(Formatters.timeAgo(f.requestedAt!)),
                    onTap: () => context.push(
                      '/user/${f.uid}',
                      extra: {'name': f.displayName, 'photoUrl': f.photoUrl},
                    ),
                    trailing: _busy.contains(f.uid)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey('decline-${f.uid}'),
                                tooltip: 'Decline',
                                icon: const Icon(Icons.close),
                                onPressed: () => _act(f, _c.declineFriend),
                              ),
                              IconButton.filled(
                                key: ValueKey('accept-${f.uid}'),
                                tooltip: 'Accept',
                                icon: const Icon(Icons.check),
                                onPressed: () => _act(f, _c.acceptFriend),
                              ),
                            ],
                          ),
                  ),
              ],
              if (_c.joinRequests.isNotEmpty) ...[
                _Header(
                  'Join requests',
                  _c.joinRequests.fold(0, (n, g) => n + g.people.length),
                ),
                for (final g in _c.joinRequests)
                  ListTile(
                    contentPadding: AppSpacing.page,
                    leading: SizedBox(
                      width: 56,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: UserAvatar(
                          name: g.people.first.displayName,
                          photoUrl: g.people.first.photoUrl,
                          size: 48,
                        ),
                      ),
                    ),
                    title: Text(
                      g.activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    subtitle: Text(
                      g.people.length == 1
                          ? '${g.people.first.displayName} wants to join'
                          : '${g.people.first.displayName} and ${g.people.length - 1} more want to join',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push('/activity/${g.activity.id}/members');
                      if (mounted) _c.load();
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label, this.count);
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      '$label · $count',
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: context.inkMuted),
    ),
  );
}
