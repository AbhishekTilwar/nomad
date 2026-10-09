import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config/map_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_exception.dart';
import '../auth/application/session_controller.dart';

Widget _sectionTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
  child: Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);

Widget _tile(
  IconData icon,
  String title,
  VoidCallback? onTap, {
  Widget? trailing,
  String? subtitle,
  Color? color,
}) => ListTile(
  leading: Icon(icon, color: color),
  title: Text(title, style: TextStyle(color: color)),
  subtitle: subtitle == null ? null : Text(subtitle),
  trailing:
      trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
  onTap: onTap,
  minVerticalPadding: 10,
);

/// Settings hub, matching the design's grouped list.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final city = MapConfig.cityById(session.profile?.city).name;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionTitle(context, 'Account'),
          _tile(
            Icons.person_outline,
            'Edit Profile',
            () => context.push('/profile/edit'),
          ),
          _tile(
            Icons.favorite_border,
            'Interests',
            () => context.push('/profile/edit'),
          ),
          _tile(
            Icons.place_outlined,
            'Location',
            () => context.push('/location'),
            subtitle: city,
          ),
          _sectionTitle(context, 'Notifications'),
          _tile(
            Icons.notifications_none,
            'Notification preferences',
            () => context.push('/profile/notifications'),
          ),
          _sectionTitle(context, 'Privacy'),
          _tile(
            Icons.block,
            'Blocked Users',
            () => context.push('/profile/blocked'),
          ),
          _tile(
            Icons.shield_outlined,
            'Safety & Community',
            () => context.push('/safety'),
          ),
          _sectionTitle(context, 'About'),
          _tile(
            Icons.favorite_border,
            'Community guidelines',
            () => context.push('/legal/guidelines'),
          ),
          _tile(
            Icons.privacy_tip_outlined,
            'Privacy policy',
            () => context.push('/legal/privacy'),
          ),
          _tile(
            Icons.description_outlined,
            'Terms & Conditions',
            () => context.push('/legal/terms'),
          ),
        ],
      ),
    );
  }
}

/// Two-city switcher (design: "Select Location").
class LocationSwitchScreen extends StatelessWidget {
  const LocationSwitchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final t = Theme.of(context);
    final current = session.profile?.city;
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: ListView(
        padding: AppSpacing.page.copyWith(top: 8),
        children: [
          for (final c in MapConfig.cities)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: Icon(Icons.place, color: t.colorScheme.primary),
                title: Text(c.name),
                trailing: current == c.id
                    ? Icon(Icons.check_circle, color: t.colorScheme.primary)
                    : null,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final router = GoRouter.of(context);
                  try {
                    await session.updateProfile(city: c.id);
                    router.pop();
                  } on AppException catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Icon(
            Icons.location_city_outlined,
            size: 64,
            color: t.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Two cities. Same vibe.',
            textAlign: TextAlign.center,
            style: t.textTheme.titleMedium,
          ),
          Text(
            'Meetups in Mumbai & Pune',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain-language safety information (design: "Safety & Community").
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget item(IconData icon, String title, String body) => ListTile(
      leading: Icon(icon, color: t.colorScheme.primary),
      title: Text(title, style: t.textTheme.titleMedium),
      subtitle: Text(body),
      minVerticalPadding: 12,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Community')),
      body: ListView(
        children: [
          item(
            Icons.flag_outlined,
            'Report & Block',
            'Report any message, plan or person from the ⋯ menu. Block people you don\'t want to see.',
          ),
          item(
            Icons.gavel_outlined,
            'In-App Moderation',
            'Moderators review reports and can remove content or suspend accounts that break the rules.',
          ),
          item(
            Icons.location_off_outlined,
            'Your location stays private',
            'We use your location only to find plans near you. It is never shared with other members.',
          ),
          item(
            Icons.groups_outlined,
            'Meet safely',
            'Meet in public places, tell a friend where you\'re going, and trust your instincts.',
          ),
          Padding(
            padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'If you are ever in danger, contact local emergency services (112 in India) first.',
                  style: t.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/legal/guidelines'),
            child: const Text('Read the community guidelines'),
          ),
        ],
      ),
    );
  }
}

/// Notification preferences backed by `PUT /users/me/notification-prefs`.
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsState();
}

class _NotificationPrefsState extends State<NotificationPrefsScreen> {
  static const _labels = {
    'joinRequests': 'Join requests',
    'approvals': 'Approvals & rejections',
    'activityUpdates': 'Plan updates & cancellations',
    'reminders': 'Reminders before plans',
  };
  final _prefs = {for (final k in _labels.keys) k: true};
  String? _error;

  Future<void> _set(String key, bool v) async {
    final before = _prefs[key]!;
    setState(() {
      _prefs[key] = v;
      _error = null;
    });
    try {
      await context.read<ApiClient>().put(
        '/users/me/notification-prefs',
        body: Map<String, bool>.of(_prefs),
      );
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _prefs[key] = before;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification preferences')),
    body: ListView(
      children: [
        for (final e in _labels.entries)
          SwitchListTile(
            title: Text(e.value),
            value: _prefs[e.key]!,
            onChanged: (v) => _set(e.key, v),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'We never send a push notification for every community message.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
