import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/photo_gallery.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../../auth/application/session_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// Counts and upcoming plans come from `GET /users/me/activities` (hosted / joined are
/// upcoming only, `past` holds finished ones; its rows carry `isHost`), so totals add them.
class _ActivityStats {
  const _ActivityStats({
    required this.hosted,
    required this.joined,
    required this.upcoming,
    required this.capped,
  });
  final int hosted;
  final int joined;
  final List<MyActivity> upcoming;

  /// True when any list hit the page size, so the counts are a lower bound.
  final bool capped;
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _page = 50;
  _ActivityStats? _stats;
  bool _statsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = context.read<MyActivitiesRepository>();
    try {
      final res = await Future.wait([
        repo.list(MyActivitiesRole.hosted, limit: _page),
        repo.list(MyActivitiesRole.joined, limit: _page),
        repo.list(MyActivitiesRole.past, limit: _page),
      ]);
      final past = res[2].items;
      final upcoming = [...res[0].items, ...res[1].items]
        ..sort((a, b) => a.activity.startAt.compareTo(b.activity.startAt));
      final stats = _ActivityStats(
        hosted:
            res[0].items.length + past.where((m) => m.activity.isHost).length,
        joined:
            res[1].items.length + past.where((m) => !m.activity.isHost).length,
        upcoming: upcoming,
        capped: res.any((r) => r.items.length >= _page),
      );
      if (mounted) setState(() => _stats = stats);
    } on AppException {
      if (mounted) setState(() => _statsFailed = true);
    } catch (_) {
      if (mounted) setState(() => _statsFailed = true);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<SessionController>().signOut();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final session = context.read<SessionController>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your profile, memberships and blocks. Hosted upcoming plans will be cancelled. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await session.deleteAccount();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final p = session.profile;
    final t = Theme.of(context);
    if (p == null) return const Scaffold(body: SizedBox.shrink());
    final cityName = MapConfig.cityById(p.city).name;
    final grey = t.colorScheme.onSurfaceVariant;
    final stats = _stats;
    String count(int? n) =>
        n == null ? '–' : (stats!.capped && n >= _page ? '$_page+' : '$n');

    Widget row(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: Icon(icon, color: color ?? grey, size: 22),
      title: Text(label, style: t.textTheme.bodyMedium?.copyWith(color: color)),
      trailing: color == null
          ? Icon(Icons.chevron_right, color: grey, size: 20)
          : null,
      onTap: onTap,
      contentPadding: AppSpacing.page,
      minTileHeight: 48,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    UserAvatar(
                      name: p.displayName,
                      photoUrl: p.photoUrl,
                      size: 64,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cityName,
                            style: t.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
              if (p.bio.isNotEmpty)
                Padding(
                  padding: AppSpacing.page.copyWith(top: AppSpacing.md),
                  child: Text(
                    p.bio,
                    style: t.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              Padding(
                padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
                child: Row(
                  children: [
                    Text('My Photos', style: t.textTheme.titleMedium),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('manage-photos'),
                      onPressed: () => context.push('/profile/edit'),
                      child: Text(p.photos.isEmpty ? 'Add photos' : 'Manage'),
                    ),
                  ],
                ),
              ),
              if (p.photos.isNotEmpty)
                Padding(
                  padding: AppSpacing.page.copyWith(top: AppSpacing.xs),
                  child: PhotoGalleryStrip(urls: p.photos, height: 104),
                ),
              Padding(
                padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
                child: Row(
                  children: [
                    _Stat(
                      key: const ValueKey('stat-hosted'),
                      value: _statsFailed ? '–' : count(stats?.hosted),
                      label: 'Meetups hosted',
                    ),
                    _Stat(
                      key: const ValueKey('stat-joined'),
                      value: _statsFailed ? '–' : count(stats?.joined),
                      label: 'Joined',
                    ),
                    _Stat(
                      key: const ValueKey('stat-interests'),
                      value: '${p.interests.length}',
                      label: 'Interests',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppSpacing.page.copyWith(top: AppSpacing.xl),
                child: Text('My Interests', style: t.textTheme.titleMedium),
              ),
              Padding(
                padding: AppSpacing.page.copyWith(top: AppSpacing.md),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in p.interests) InterestChip(interestId: i),
                  ],
                ),
              ),
              Padding(
                padding: AppSpacing.page.copyWith(top: AppSpacing.xl),
                child: Text('Upcoming Meetups', style: t.textTheme.titleMedium),
              ),
              if (stats != null && stats.upcoming.isNotEmpty)
                for (final m in stats.upcoming.take(5))
                  Padding(
                    padding: AppSpacing.page.copyWith(top: AppSpacing.md),
                    child: _UpcomingCard(activity: m.activity),
                  )
              else
                Padding(
                  padding: AppSpacing.page.copyWith(top: AppSpacing.md),
                  child: Text(
                    stats == null && !_statsFailed
                        ? 'Loading…'
                        : _statsFailed
                        ? 'Couldn\'t load your meetups. Pull down to retry.'
                        : 'No upcoming meetups yet. Join or host one!',
                    key: const ValueKey('upcoming-empty'),
                    style: t.textTheme.bodySmall?.copyWith(color: grey),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              row(
                Icons.photo_album_outlined,
                'Memories',
                () => context.push('/memories'),
              ),
              row(
                Icons.shield_outlined,
                'Safety & Community',
                () => context.push('/safety'),
              ),
              const Divider(),
              row(Icons.logout, 'Sign out', () => _confirmSignOut(context)),
              row(
                Icons.delete_outline,
                'Delete account',
                () => _confirmDelete(context),
                color: AppColors.danger,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final grey = t.colorScheme.onSurfaceVariant;
    final color = CategoryStyle.color(activity.category);
    final cover = activity.coverImageUrl;
    final fallback = Container(
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(CategoryStyle.icon(activity.category), color: color),
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/activity/${activity.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: (cover == null || cover.isEmpty)
                      ? fallback
                      : CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          memCacheWidth: 192,
                          placeholder: (_, _) => fallback,
                          errorWidget: (_, _, _) => fallback,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.activityWhen(activity.startAt),
                      style: t.textTheme.bodySmall?.copyWith(color: grey),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: grey),
                        const SizedBox(width: 2),
                        Text(
                          MapConfig.cityById(activity.city).name,
                          style: t.textTheme.bodySmall?.copyWith(color: grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: t.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: t.textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
