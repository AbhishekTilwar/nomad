import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/session_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

    Widget link(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      minVerticalPadding: 12,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: AppSpacing.page.copyWith(top: 8),
            child: Row(
              children: [
                UserAvatar(name: p.displayName, photoUrl: p.photoUrl, size: 72),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName, style: t.textTheme.titleLarge),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            MapConfig.cityById(p.city).name,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 44),
                  ),
                  onPressed: () => context.push('/profile/edit'),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          if (p.bio.isNotEmpty)
            Padding(
              padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
              child: Text(p.bio, style: t.textTheme.bodyLarge),
            ),
          Padding(
            padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
            child: Row(
              children: [
                _Stat('${p.interests.length}', 'Interests'),
                _Stat(MapConfig.cityById(p.city).name, 'City'),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.page.copyWith(top: AppSpacing.xl),
            child: Text('My Interests', style: t.textTheme.titleMedium),
          ),
          Padding(
            padding: AppSpacing.page.copyWith(top: AppSpacing.sm),
            child: Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                for (final i in p.interests) InterestChip(interestId: i),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          link(
            Icons.settings_outlined,
            'Settings',
            () => context.push('/settings'),
          ),
          link(
            Icons.shield_outlined,
            'Safety & Community',
            () => context.push('/safety'),
          ),
          const Divider(),
          link(Icons.logout, 'Sign out', () => _confirmSignOut(context)),
          link(
            Icons.delete_outline,
            'Delete account',
            () => _confirmDelete(context),
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(value, style: t.textTheme.titleMedium),
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
    );
  }
}
