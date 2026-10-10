import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/activity_repository.dart';
import '../models/activity.dart';

/// Host-only: approve/reject join requests and remove participants.
class ManageMembersScreen extends StatefulWidget {
  const ManageMembersScreen({super.key, required this.activityId});
  final String activityId;

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  List<ActivityMember>? _members;
  String? _error;
  final _busy = <String>{};

  ActivityRepository get _repo => context.read<ActivityRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final m = await _repo.members(widget.activityId);
      if (mounted) setState(() => _members = m);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _decide(ActivityMember m, Future<void> Function() action) async {
    if (_busy.contains(m.userId)) return;
    setState(() => _busy.add(m.userId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _busy.remove(m.userId));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.activityId;
    Widget body;
    if (_error != null && _members == null) {
      body = ErrorState(message: _error, onRetry: _load);
    } else if (_members == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final requests = _members!
          .where((m) => m.status == MembershipStatus.requested)
          .toList();
      final going = _members!
          .where(
            (m) => m.status == MembershipStatus.approved && m.role != 'host',
          )
          .toList();
      if (requests.isEmpty && going.isEmpty) {
        body = const EmptyState(
          icon: Icons.group_outlined,
          title: 'No participants yet',
          message: 'People who join or request to join will show up here.',
        );
      } else {
        body = ListView(
          padding: AppSpacing.page,
          children: [
            if (requests.isNotEmpty) ...[
              Text('Requests', style: Theme.of(context).textTheme.titleMedium),
              for (final m in requests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    name: m.displayName,
                    photoUrl: m.photoUrl,
                  ),
                  title: Text(m.displayName),
                  onTap: () => context.push(
                    '/user/${m.userId}',
                    extra: {'name': m.displayName, 'photoUrl': m.photoUrl},
                  ),
                  trailing: _busy.contains(m.userId)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Reject ${m.displayName}',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  _decide(m, () => _repo.reject(id, m.userId)),
                            ),
                            IconButton(
                              tooltip: 'Approve ${m.displayName}',
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () =>
                                  _decide(m, () => _repo.approve(id, m.userId)),
                            ),
                          ],
                        ),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (going.isNotEmpty) ...[
              Text('Going', style: Theme.of(context).textTheme.titleMedium),
              for (final m in going)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    name: m.displayName,
                    photoUrl: m.photoUrl,
                  ),
                  title: Text(m.displayName),
                  onTap: () => context.push(
                    '/user/${m.userId}',
                    extra: {'name': m.displayName, 'photoUrl': m.photoUrl},
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove ${m.displayName}',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () =>
                        _decide(m, () => _repo.remove(id, m.userId)),
                  ),
                ),
            ],
          ],
        );
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Participants')),
      body: body,
    );
  }
}
