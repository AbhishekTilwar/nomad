import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/map_config.dart';
import '../../../core/utils/countries.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/photo_gallery.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/report_action_sheet.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/session_controller.dart';
import '../../safety/data/safety_repository.dart';
import '../../social/data/social_repository.dart';
import '../data/public_profile.dart';

/// Another member's profile (design: banner, overlapping avatar, name with
/// verified badge, interests, About me). Opened from plans and chats.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.uid,
    this.fallbackName,
    this.fallbackPhotoUrl,
  });

  final String uid;

  /// Shown while loading (we usually already know these from the caller).
  final String? fallbackName;
  final String? fallbackPhotoUrl;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _friendBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<PublicProfileRepository>().fetch(widget.uid);
      if (mounted) setState(() => _profile = p);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _friendAction(
    Future<void> Function(SocialRepository) run,
  ) async {
    if (_friendBusy) return;
    final social = context.read<SocialRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _friendBusy = true);
    try {
      await run(social);
      await _load();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _friendBusy = false);
  }

  Widget _friendButtons(PublicProfile p) {
    switch (p.friendship) {
      case Friendship.friends:
        return OutlinedButton.icon(
          onPressed: _friendBusy
              ? null
              : () => _friendAction((s) => s.removeFriend(p.uid)),
          icon: const Icon(Icons.check),
          label: const Text('Friends'),
        );
      case Friendship.requestSent:
        return OutlinedButton.icon(
          onPressed: _friendBusy
              ? null
              : () => _friendAction((s) => s.removeFriend(p.uid)),
          icon: const Icon(Icons.hourglass_top),
          label: const Text('Requested'),
        );
      case Friendship.requestReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: _friendBusy
                  ? null
                  : () => _friendAction((s) => s.acceptFriendRequest(p.uid)),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _friendBusy
                  ? null
                  : () => _friendAction((s) => s.removeFriend(p.uid)),
              child: const Text('Decline'),
            ),
          ],
        );
      case Friendship.none:
        return FilledButton.icon(
          onPressed: _friendBusy
              ? null
              : () => _friendAction((s) => s.sendFriendRequest(p.uid)),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Friend'),
        );
    }
  }

  Future<void> _openInstagram(String handle) async {
    await launchUrl(
      Uri.parse('https://instagram.com/$handle'),
      mode: LaunchMode.externalApplication,
    );
  }

  bool get _isMe => context.read<SessionController>().user?.uid == widget.uid;

  Future<void> _report() async {
    final messenger = ScaffoldMessenger.of(context);
    final safety = context.read<SafetyRepository>();
    final r = await ReportActionSheet.show(
      context,
      title: 'Report this member',
    );
    if (r == null) return;
    try {
      await safety.report(
        targetType: 'user',
        targetId: widget.uid,
        reason: r.reason.name,
        details: r.details,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks. Our moderators will review this.'),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _block() async {
    final messenger = ScaffoldMessenger.of(context);
    final safety = context.read<SafetyRepository>();
    final router = GoRouter.of(context);
    final name = _profile?.displayName ?? widget.fallbackName ?? 'this member';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Block $name?'),
        content: const Text(
          'You won\'t see their messages in chats. You can unblock them any time in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await safety.block(widget.uid);
      messenger.showSnackBar(SnackBar(content: Text('$name blocked.')));
      if (router.canPop()) router.pop();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = _profile;
    final name = p?.displayName ?? widget.fallbackName ?? '';
    final photo = p?.photoUrl ?? widget.fallbackPhotoUrl;

    final firstInterest = (p?.interests.isNotEmpty ?? false)
        ? p!.interests.first
        : 'explore';
    final accent = CategoryStyle.color(firstInterest);

    Widget circleButton(IconData icon, String tip, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filled(
            tooltip: tip,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              padding: EdgeInsets.zero,
            ),
            icon: Icon(icon, size: 20),
            onPressed: onTap,
          ),
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leadingWidth: 56,
        leading: circleButton(
          Icons.arrow_back,
          'Back',
          () => context.canPop() ? context.pop() : context.go('/explore'),
        ),
        actions: [
          if (!_isMe)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(Icons.more_horiz, size: 20, color: AppColors.ink),
              ),
              onSelected: (v) => v == 'report' ? _report() : _block(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report member')),
                PopupMenuItem(value: 'block', child: Text('Block member')),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _error != null && p == null
          ? Padding(
              padding: const EdgeInsets.only(top: 80),
              child: ErrorState(
                title: 'Couldn\'t load this profile',
                message: _error,
                onRetry: _load,
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _Cover(
                  coverUrl: p != null && p.photos.isNotEmpty
                      ? p.photos.first
                      : null,
                  fallbackPhoto: photo,
                  accent: accent,
                  icon: CategoryStyle.icon(firstInterest),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -44),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: t.scaffoldBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.card,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    name: name.isEmpty ? '?' : name,
                                    photoUrl: photo,
                                    size: 92,
                                  ),
                                  if (flagEmoji(p?.countryCode) != null)
                                    Positioned(
                                      right: -4,
                                      bottom: -2,
                                      child: Tooltip(
                                        message: countryName(p?.countryCode),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: t.scaffoldBackgroundColor,
                                            shape: BoxShape.circle,
                                            boxShadow: AppShadows.card,
                                          ),
                                          child: Text(
                                            flagEmoji(p?.countryCode)!,
                                            style: const TextStyle(
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: t.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (p?.emailVerified ?? false) ...[
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message: 'Email verified',
                                      child: Icon(
                                        Icons.verified,
                                        size: 20,
                                        color: t.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (_loading && p == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(minHeight: 2),
                                )
                              else if (p != null) ...[
                                Text(
                                  [
                                    if (p.ageRange != null) p.ageRange!,
                                    if (p.city.isNotEmpty)
                                      MapConfig.cityById(p.city).name,
                                    if (countryName(p.countryCode).isNotEmpty)
                                      countryName(p.countryCode),
                                  ].join('  •  '),
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if ((p.instagram ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _InstagramPill(
                                    handle: p.instagram!,
                                    onTap: () => _openInstagram(p.instagram!),
                                  ),
                                ],
                                if (!_isMe) ...[
                                  const SizedBox(height: 16),
                                  _friendButtons(p),
                                ],
                                const SizedBox(height: 16),
                                if (p.interests.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final i in p.interests)
                                        InterestChip(interestId: i),
                                    ],
                                  ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    _Stat('${p.hosted}', 'Hosted'),
                                    _Stat('${p.attended}', 'Attended'),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'About me',
                                  style: t.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p.bio.isEmpty
                                      ? '${p.displayName} hasn\'t added a bio yet.'
                                      : p.bio,
                                  style: t.textTheme.bodyLarge?.copyWith(
                                    color: p.bio.isEmpty
                                        ? t.colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                if (p.photos.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Photos',
                                    style: t.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  PhotoGalleryStrip(urls: p.photos),
                                ],
                                if (_isMe) ...[
                                  const SizedBox(height: 24),
                                  PrimaryButton(
                                    label: 'Edit profile',
                                    onPressed: () =>
                                        context.push('/profile/edit'),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Banner: the member's first gallery photo (or avatar), else a soft gradient.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.coverUrl,
    required this.fallbackPhoto,
    required this.accent,
    required this.icon,
  });
  final String? coverUrl;
  final String? fallbackPhoto;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl ?? fallbackPhoto;
    final gradient = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.85),
            AppColors.primary.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 36),
            child: Icon(
              icon,
              size: 72,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 230,
      child: url == null || url.isEmpty
          ? gradient
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 1000,
              placeholder: (_, _) => gradient,
              errorWidget: (_, _, _) => gradient,
            ),
    );
  }
}

class _InstagramPill extends StatelessWidget {
  const _InstagramPill({required this.handle, required this.onTap});
  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    onTap: onTap,
    child: Ink(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '@$handle',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.textTheme.titleLarge),
          Text(label, style: t.textTheme.bodySmall),
        ],
      ),
    );
  }
}
