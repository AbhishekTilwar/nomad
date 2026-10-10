import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/application/session_controller.dart';
import '../safety/data/safety_repository.dart';

/// In-app notification inbox. Reads the signed-in user's own `notifications`
/// documents (rules allow owner reads; the backend writes them). Latest 30 only.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotifFilter { all, joinRequests, activities }

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotifFilter _filter = _NotifFilter.all;

  static const _joinTypes = {
    'join_request',
    'join_approved',
    'join_rejected',
    'removed',
  };

  bool _matches(String type) => switch (_filter) {
    _NotifFilter.all => true,
    _NotifFilter.joinRequests => _joinTypes.contains(type),
    _NotifFilter.activities => !_joinTypes.contains(type),
  };

  static IconData _icon(String type) {
    switch (type) {
      case 'join_request':
        return Icons.person_add_alt_1_outlined;
      case 'join_approved':
        return Icons.check_circle_outline;
      case 'join_rejected':
      case 'removed':
        return Icons.cancel_outlined;
      case 'activity_cancelled':
        return Icons.event_busy_outlined;
      case 'reminder':
        return Icons.alarm;
      case 'moderation':
        return Icons.gavel_outlined;
      case 'friend_request':
      case 'friend_accepted':
        return Icons.people_outline;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SessionController>().user?.uid;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          'Notifications',
          style: t.textTheme.headlineMedium?.copyWith(fontSize: 22),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                for (final (f, label, icon) in [
                  (_NotifFilter.all, 'All', Icons.notifications_none),
                  (
                    _NotifFilter.joinRequests,
                    'Join Requests',
                    Icons.person_add_alt_1_outlined,
                  ),
                  (_NotifFilter.activities, 'Activities', Icons.event_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: label,
                      icon: icon,
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: uid == null
                ? const SizedBox.shrink()
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: uid)
                        .orderBy('createdAt', descending: true)
                        .limit(30)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const ErrorState(
                          message:
                              'Couldn\'t load notifications. Check your connection.',
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data!.docs
                          .where(
                            (d) => _matches(d.data()['type'] as String? ?? ''),
                          )
                          .toList();
                      if (docs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.notifications_none,
                          title: 'You\'re all caught up',
                          message:
                              'Join requests, approvals and plan updates show up here.',
                        );
                      }
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final created = (d['createdAt'] as Timestamp?)
                              ?.toDate();
                          final activityId =
                              (d['data'] as Map?)?['activityId'] as String?;
                          final data =
                              (d['data'] as Map?)?.cast<String, dynamic>() ??
                              const {};
                          final actorName = data['actorName'] as String?;
                          final actorPhoto = data['actorPhotoUrl'] as String?;
                          final actorId = data['actorId'] as String?;
                          final type = d['type'] as String? ?? '';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            leading: actorName != null
                                ? UserAvatar(
                                    name: actorName,
                                    photoUrl: actorPhoto,
                                    size: 48,
                                  )
                                : CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.tint,
                                    child: Icon(
                                      _icon(type),
                                      size: 22,
                                      color: t.colorScheme.primary,
                                    ),
                                  ),
                            title: Text(
                              d['title'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['body'] as String? ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (created != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      Formatters.timeAgo(created),
                                      style: t.textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (activityId != null) {
                                context.push('/activity/$activityId');
                              } else if (actorId != null) {
                                context.push('/user/$actorId');
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<BlockedUser>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final u = await context.read<SafetyRepository>().blocks();
      if (mounted) setState(() => _users = u);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unblock(BlockedUser u) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SafetyRepository>().unblock(u.uid);
      await _load();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null && _users == null) {
      body = ErrorState(message: _error, onRetry: _load);
    } else if (_users == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_users!.isEmpty) {
      body = const EmptyState(
        icon: Icons.block,
        title: 'No blocked users',
        message: 'People you block won\'t appear in your chats.',
      );
    } else {
      body = ListView(
        padding: AppSpacing.page,
        children: [
          for (final u in _users!)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(u.displayName),
              trailing: TextButton(
                onPressed: () => _unblock(u),
                child: const Text('Unblock'),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: body,
    );
  }
}
