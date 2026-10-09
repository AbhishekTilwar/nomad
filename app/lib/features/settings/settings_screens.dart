import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config/map_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_exception.dart';
import '../auth/application/session_controller.dart';

const _kPrefKeys = [
  'joinRequests',
  'approvals',
  'activityUpdates',
  'reminders',
];

Widget _sectionTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
  child: Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);

Widget _tile(
  BuildContext context,
  IconData icon,
  String title,
  VoidCallback? onTap, {
  Widget? trailing,
  String? subtitle,
}) {
  final t = Theme.of(context);
  final grey = t.colorScheme.onSurfaceVariant;
  return ListTile(
    leading: Icon(icon, size: 20, color: grey),
    title: Text(title, style: t.textTheme.bodyMedium),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing:
        trailing ??
        (onTap == null ? null : Icon(Icons.chevron_right, color: grey)),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    minTileHeight: 48,
  );
}

/// Settings hub, matching the design's grouped list.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Push Notifications master switch. Initial state comes from `GET /users/me`
  // (private.notificationPrefs); if that fails we default to on (the server default).
  bool _push = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final me = (await context.read<ApiClient>().get('/users/me')).asMap;
      final prefs = (me['private'] as Map?)?['notificationPrefs'];
      if (prefs is Map && mounted) {
        // "On" while any of the four categories is enabled.
        setState(() => _push = _kPrefKeys.any((k) => prefs[k] != false));
      }
    } catch (_) {
      // Keep the default; the toggle still works.
    }
  }

  Future<void> _setPush(bool v) async {
    final before = _push;
    setState(() {
      _push = v;
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().put(
        '/users/me/notification-prefs',
        body: {for (final k in _kPrefKeys) k: v},
      );
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _push = before;
          _error = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            context,
            Icons.person_outline,
            'Edit Profile',
            () => context.push('/profile/edit'),
          ),
          _tile(
            context,
            Icons.favorite_border,
            'Interests',
            () => context.push('/profile/edit'),
          ),
          _tile(
            context,
            Icons.place_outlined,
            'Location',
            () => context.push('/location'),
            subtitle: city,
          ),
          _sectionTitle(context, 'Notifications'),
          _tile(
            context,
            Icons.notifications_none,
            'Push Notifications',
            null,
            trailing: Switch(value: _push, onChanged: _busy ? null : _setPush),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          _tile(
            context,
            Icons.tune,
            'Notification preferences',
            () => context.push('/profile/notifications'),
          ),
          _sectionTitle(context, 'Privacy'),
          _tile(
            context,
            Icons.block,
            'Blocked Users',
            () => context.push('/profile/blocked'),
          ),
          _sectionTitle(context, 'About'),
          _tile(
            context,
            Icons.favorite_border,
            'Community guidelines',
            () => context.push('/legal/guidelines'),
          ),
          _tile(
            context,
            Icons.privacy_tip_outlined,
            'Privacy policy',
            () => context.push('/legal/privacy'),
          ),
          _tile(
            context,
            Icons.description_outlined,
            'Terms & Conditions',
            () => context.push('/legal/terms'),
          ),
          const SizedBox(height: AppSpacing.xl),
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
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: current == c.id ? AppColors.tint : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: current == c.id
                        ? t.colorScheme.primary.withValues(alpha: 0.35)
                        : AppColors.outline,
                  ),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  leading: Icon(
                    Icons.place_outlined,
                    color: t.colorScheme.primary,
                  ),
                  title: Text(
                    c.name,
                    style: t.textTheme.bodyMedium?.copyWith(
                      fontWeight: current == c.id ? FontWeight.w600 : null,
                      color: current == c.id ? t.colorScheme.primary : null,
                    ),
                  ),
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
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: 150,
            child: CustomPaint(
              key: const ValueKey('skyline'),
              painter: const _SkylinePainter(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Two cities. Same vibe.',
            textAlign: TextAlign.center,
            style: t.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Meetups in Mumbai & Pune',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Light grey-indigo city skyline with a hill line behind it (decorative).
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h - 6;
    const ink = Color(0xFFB9BEE6);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0xFFEEF0FF);

    // Hills on the right.
    final hills = Path()
      ..moveTo(w * 0.52, base)
      ..quadraticBezierTo(w * 0.64, h * 0.28, w * 0.76, h * 0.62)
      ..quadraticBezierTo(w * 0.84, h * 0.42, w * 0.96, base);
    canvas.drawPath(hills, fill);
    canvas.drawPath(hills, line);

    // Buildings (x fraction, width fraction, height fraction).
    const blocks = [
      (0.22, 0.09, 0.42),
      (0.31, 0.08, 0.78),
      (0.39, 0.10, 0.55),
      (0.49, 0.07, 0.34),
      (0.14, 0.08, 0.28),
    ];
    for (final b in blocks) {
      final r = Rect.fromLTWH(w * b.$1, base - h * b.$3, w * b.$2, h * b.$3);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, line);
      // Windows.
      for (var y = r.top + 10; y < r.bottom - 8; y += 14) {
        canvas.drawLine(
          Offset(r.left + r.width * 0.3, y),
          Offset(r.right - r.width * 0.3, y),
          line..strokeWidth = 1,
        );
      }
      line.strokeWidth = 1.4;
    }
    // Ground line.
    canvas.drawLine(Offset(w * 0.08, base), Offset(w * 0.92, base), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Plain-language safety information (design: "Safety & Community").
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget item(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 20, color: t.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(body, style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Community')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          item(
            Icons.verified_user_outlined,
            'Email-verified members',
            'Everyone signs up with a verified email address to reduce fake accounts.',
          ),
          item(
            Icons.flag_outlined,
            'Report & Block',
            'Report any message, plan or person from the ⋮ menu. Block people you don\'t want to see.',
          ),
          item(
            Icons.gavel_outlined,
            'In-App Moderation',
            'Moderators review reports and can remove content or suspend accounts that break the rules.',
          ),
          item(
            Icons.location_off_outlined,
            'Your location stays private',
            'Location is only used to show plans and distance near you. It is never shared with other members.',
          ),
          item(
            Icons.local_phone_outlined,
            'Emergency Support',
            'If you are ever in danger, contact local emergency services (112 in India) first.',
          ),
          Padding(
            padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
            child: Container(
              key: const ValueKey('safety-panel'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.tint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your safety matters.',
                    style: t.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'We\'re building a safer community together.',
                    style: t.textTheme.bodySmall,
                  ),
                ],
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
