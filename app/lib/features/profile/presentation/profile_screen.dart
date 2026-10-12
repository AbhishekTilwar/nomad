import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../create/presentation/create_activity_screen.dart';
import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/instagram_pill.dart' show openInstagram;
import '../../../core/utils/plan_emoji.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/my_activities_repository.dart';
import '../../activities/models/activity.dart';
import '../../auth/application/session_controller.dart';
import '../../social/data/social_repository.dart';
import '../data/user_profile.dart';
import 'profile_lists_sheet.dart';
import '../../../core/theme/theme_colors.dart';

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
    this.friends,
  });
  final int hosted;
  final int? friends;
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

  Future<int?> _loadFriends() async {
    try {
      return (await context.read<SocialRepository>().friends()).length;
    } catch (_) {
      return null; // the count is a nicety; the rest still shows
    }
  }

  Future<void> _loadStats() async {
    final repo = context.read<MyActivitiesRepository>();
    final friends = _loadFriends();
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
        friends: await friends,
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
    final grey = t.colorScheme.onSurfaceVariant;
    final stats = _stats;
    String count(int? n) =>
        n == null ? '–' : (stats!.capped && n >= _page ? '$_page+' : '$n');
    final friends = stats?.friends;
    Widget heading(String text, {String? badge, Widget? action}) => Padding(
      padding: AppSpacing.page.copyWith(top: 20),
      child: Row(
        children: [
          Text(
            text,
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              key: ValueKey('count-$text'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: context.tint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge,
                style: t.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: t.colorScheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          ?action,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton.outlined(
            key: const ValueKey('open-settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Clear the floating tab bar.
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Identity(
              profile: p,
              hosted: _statsFailed ? '–' : count(stats?.hosted),
              joined: _statsFailed ? '–' : count(stats?.joined),
              onOpen: (k) => showProfileListSheet(context, k),
              friends: friends == null
                  ? '–'
                  : (friends >= 100 ? '100+' : '$friends'),
            ),
            Padding(
              padding: AppSpacing.page.copyWith(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: p.completionPercent < 100
                        ? OutlinedButton(
                            key: const ValueKey('edit-profile'),
                            onPressed: () => context.push('/profile/edit'),
                            child: const Text('Complete profile'),
                          )
                        : OutlinedButton(
                            key: const ValueKey('edit-profile'),
                            onPressed: () => context.push('/profile/edit'),
                            child: const Text('Edit profile'),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('invite-friends'),
                      onPressed: () => context.push('/invite'),
                      child: const Text('Invite friends'),
                    ),
                  ),
                ],
              ),
            ),
            if (p.completionPercent < 100)
              Padding(
                padding: AppSpacing.page.copyWith(top: 8),
                child: Text(
                  _nextProfileStep(p),
                  key: const ValueKey('profile-completion'),
                  style: t.textTheme.bodySmall?.copyWith(color: grey),
                ),
              ),
            heading('Interests', badge: '${p.interests.length}'),
            Padding(
              padding: AppSpacing.page.copyWith(top: 10),
              child: p.interests.isEmpty
                  ? Text(
                      'Add interests so we can suggest plans you\'ll like.',
                      style: t.textTheme.bodySmall?.copyWith(color: grey),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in p.interests) _InterestPill(id: i),
                      ],
                    ),
            ),
            heading(
              'My plans',
              badge: stats == null ? null : '${stats.upcoming.length}',
              action: stats != null && stats.upcoming.isNotEmpty
                  ? TextButton.icon(
                      key: const ValueKey('add-plan'),
                      onPressed: () => showCreatePlanSheet(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Host'),
                    )
                  : null,
            ),
            if (stats != null && stats.upcoming.isNotEmpty)
              for (final m in stats.upcoming.take(3))
                Padding(
                  padding: AppSpacing.page.copyWith(top: 8),
                  child: _UpcomingCard(activity: m.activity),
                )
            else
              Padding(
                padding: AppSpacing.page.copyWith(top: 8),
                child: stats == null && !_statsFailed
                    ? const LoadingSkeleton(height: 80, radius: AppRadius.lg)
                    : _statsFailed
                    ? Text(
                        'Couldn\'t load your plans. Pull down to retry.',
                        key: const ValueKey('upcoming-empty'),
                        style: t.textTheme.bodySmall?.copyWith(color: grey),
                      )
                    : _NoPlans(onAdd: () => showCreatePlanSheet(context)),
              ),
            const _SectionLabel('Your space'),
            _GroupCard(
              children: [
                _SpaceRow(
                  icon: Icons.photo_album_outlined,
                  label: 'Memories',
                  onTap: () => context.push('/memories'),
                ),
                _SpaceRow(
                  icon: Icons.shield_outlined,
                  label: 'Safety & Community',
                  onTap: () => context.push('/safety'),
                ),
              ],
            ),
            const _SectionLabel('Account'),
            _GroupCard(
              children: [
                _SpaceRow(
                  icon: Icons.logout,
                  label: 'Sign out',
                  onTap: () => _confirmSignOut(context),
                ),
                _SpaceRow(
                  icon: Icons.delete_outline,
                  label: 'Delete account',
                  color: AppColors.danger,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What to do next to complete the profile, by the same checklist as
/// [UserProfile.completionPercent].
String _nextProfileStep(UserProfile p) {
  if ((p.photoUrl ?? '').isEmpty) {
    return 'Add a photo so people know who\'s coming';
  }
  if (p.bio.trim().isEmpty) {
    return 'Write a short bio about yourself';
  }
  if (p.interests.length < 3) {
    return 'Pick at least 3 interests';
  }
  if ((p.countryCode ?? '').isEmpty) {
    return 'Add your hometown country';
  }
  if ((p.instagram ?? '').isEmpty) {
    return 'Link your Instagram';
  }
  return 'Add a few photos to your gallery';
}

/// Avatar in a completion ring, with name, place and Hosted / Joined / Friends
/// beside it (Instagram-style), and the Instagram handle below.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.profile,
    required this.hosted,
    required this.joined,
    required this.friends,
    required this.onOpen,
  });
  final ValueChanged<ProfileList> onOpen;
  final UserProfile profile;
  final String hosted;
  final String joined;
  final String friends;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = profile;
    final pct = p.completionPercent;
    const size = 96.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: size + 14,
                height: size + 18,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    SizedBox(
                      width: size + 14,
                      height: size + 14,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: context.outline,
                        color: t.colorScheme.primary,
                      ),
                    ),
                    Positioned(
                      top: 7,
                      child: UserAvatar(
                        name: p.displayName,
                        photoUrl: p.photoUrl,
                        size: size,
                      ),
                    ),
                    if (pct < 100)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          key: const ValueKey('completion-pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: t.colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$pct%',
                            style: t.textTheme.labelMedium?.copyWith(
                              color: t.colorScheme.surface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Stat(
                          key: const ValueKey('stat-hosted'),
                          value: hosted,
                          label: 'Hosted',
                          onTap: () => onOpen(ProfileList.hosted),
                        ),
                        _Stat(
                          key: const ValueKey('stat-joined'),
                          value: joined,
                          label: 'Joined',
                          onTap: () => onOpen(ProfileList.joined),
                        ),
                        _Stat(
                          key: const ValueKey('stat-friends'),
                          value: friends,
                          label: 'Friends',
                          onTap: () => onOpen(ProfileList.friends),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((p.instagram ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _InstagramChip(
              handle: p.instagram!,
              onTap: () => openInstagram(p.instagram!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quiet outlined "@handle" chip that opens Instagram.
class _InstagramChip extends StatelessWidget {
  const _InstagramChip({required this.handle, required this.onTap});
  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Instagram @$handle',
      child: Material(
        color: context.tint,
        shape: StadiumBorder(side: BorderSide(color: context.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 20,
                  color: t.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label, $value. Tap to see the list',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterestPill extends StatelessWidget {
  const _InterestPill({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: context.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CategoryStyle.icon(id),
            size: 22,
            color: t.colorScheme.onSurface,
          ),
          const SizedBox(width: 10),
          Text(
            CategoryStyle.shortLabels[id] ?? interestLabel(id),
            style: t.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact upcoming-plan row (no banner): emoji, title, when and where.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final grey = t.colorScheme.onSurfaceVariant;
    final color = CategoryStyle.color(activity.category);
    final city = MapConfig.cityById(activity.city).name;
    final venue = activity.venueName.trim();
    return Material(
      color: t.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: context.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/activity/${activity.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  PlanEmoji.of(activity.title, activity.category),
                  style: const TextStyle(fontSize: 22, height: 1.1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.activityWhen(activity.startAt)}  ·  ${venue.isEmpty ? city : venue}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(color: grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// "— Your space —" divider label.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final line = Expanded(child: Divider(color: context.outline, height: 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Divider(color: context.outline, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

/// Bordered card that stacks rows with hairlines between them.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.page,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.outline),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SpaceRow extends StatelessWidget {
  const _SpaceRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = color ?? t.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 24, color: c),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: t.textTheme.bodyLarge?.copyWith(
                  fontSize: 16.5,
                  color: color,
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

/// Empty "My plans": says so and offers the add button.
class _NoPlans extends StatelessWidget {
  const _NoPlans({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      key: const ValueKey('upcoming-empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.field,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text('No plans yet', style: t.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Host something or join a plan and it will show up here.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey('add-plan'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add a plan'),
          ),
        ],
      ),
    );
  }
}
