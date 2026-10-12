import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/map_config.dart';
import '../../../core/widgets/basemap_layer.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/widgets/plan_banner.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/activity_marker.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/join_activity_button.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/report_action_sheet.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/application/photo_gate.dart';
import '../../profile/data/user_profile.dart';
import '../../safety/data/safety_repository.dart';
import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_detail_controller.dart';
import '../../../core/theme/theme_colors.dart';

class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ActivityDetailController(
      context.read<ActivityRepository>(),
      activityId,
    ),
    child: const _DetailView(),
  );
}

class _DetailView extends StatefulWidget {
  const _DetailView();

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  Future<void> _report(Activity a) async {
    final messenger = ScaffoldMessenger.of(context);
    final safety = context.read<SafetyRepository>();
    final result = await ReportActionSheet.show(
      context,
      title: 'Report this plan',
    );
    if (result == null) return;
    try {
      await safety.report(
        targetType: 'activity',
        targetId: a.id,
        reason: result.reason.name,
        details: result.details,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks. Our moderators will review this plan.'),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _share(Activity a) => SharePlus.instance.share(
    ShareParams(
      subject: a.title,
      text:
          '${a.title}\n${Formatters.activityRange(a.startAt, a.endAt)}\n'
          '${a.venueName}\n\nFind it on Nomad Mingle: ${AppConfig.inviteUrl}',
    ),
  );

  Future<void> _directions(Activity a) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}',
    );
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t open a maps app.')),
      );
    }
  }

  Future<void> _confirm(
    String title,
    String body,
    String action,
    VoidCallback onYes,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (ok == true) onYes();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ActivityDetailController>();
    final a = c.activity;

    // Surface action results once.
    if (c.actionMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final m = c.takeMessage();
        if (m != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(m)));
        }
      });
    }

    if (c.loading) {
      return Scaffold(appBar: AppBar(), body: const _DetailSkeleton());
    }
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          title: 'Couldn\'t load this plan',
          message: c.loadError,
          onRetry: c.load,
        ),
      );
    }

    final t = Theme.of(context);
    final color = CategoryStyle.color(a.category);
    final joinState = joinUiStateFor(a);
    final isMember = a.isHost || a.membership == MembershipStatus.approved;

    Widget fact(IconData icon, String text, {String? sub}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: t.textTheme.bodyMedium),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.filled(
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/explore'),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.more_horiz, size: 20, color: AppColors.ink),
            ),
            onSelected: (v) {
              if (v == 'report') _report(a);
              if (v == 'share') _share(a);
              if (v == 'cancel') {
                _confirm(
                  'Cancel this plan?',
                  'Everyone who joined will be notified.',
                  'Cancel plan',
                  c.cancelActivity,
                );
              }
              if (v == 'members') context.push('/activity/${a.id}/members');
              if (v == 'edit') {
                context
                    .push<Activity>('/activity/${a.id}/edit', extra: a)
                    .then((_) => c.load());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: Text('Share plan')),
              if (a.isHost && a.status == ActivityStatus.scheduled) ...[
                const PopupMenuItem(value: 'edit', child: Text('Edit plan')),
                const PopupMenuItem(
                  value: 'members',
                  child: Text('Manage participants'),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel plan'),
                ),
              ],
              if (!a.isHost)
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report plan'),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: c.load,
        edgeOffset: 100,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SizedBox(
              height: 270,
              child: PlanBanner(
                title: a.title,
                category: a.category,
                coverUrl: a.coverImageUrl,
              ),
            ),
            // Content sheet overlaps the hero with rounded top corners.
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: BoxDecoration(
                  color: t.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: t.textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(interestLabel(a.category).split(' ').first, color),
                        _Tag(
                          a.isFree ? 'Free' : 'Paid',
                          a.isFree ? AppColors.success : AppColors.warning,
                        ),
                        if (a.isPrivate) _Tag('Private', t.colorScheme.primary),
                        if (a.status != ActivityStatus.scheduled)
                          _Tag(
                            a.status == ActivityStatus.cancelled
                                ? 'Cancelled'
                                : 'Completed',
                            AppColors.danger,
                          ),
                      ],
                    ),
                    if (isMember && a.status == ActivityStatus.scheduled) ...[
                      const SizedBox(height: 16),
                      _GoingCard(
                        activity: a,
                        onDirections: () => _directions(a),
                      ),
                    ],
                    const SizedBox(height: 16),
                    fact(
                      Icons.calendar_today_outlined,
                      Formatters.activityRange(a.startAt, a.endAt),
                    ),
                    fact(
                      Icons.place_outlined,
                      a.venueName,
                      sub: [
                        a.city.isEmpty
                            ? ''
                            : a.city[0].toUpperCase() + a.city.substring(1),
                        if (a.distanceKm != null)
                          Formatters.distance(a.distanceKm),
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    fact(
                      Icons.group_outlined,
                      a.isFull
                          ? '${a.participantCount} going · full'
                          : '${a.participantCount} going · ${a.spotsLeft} spot${a.spotsLeft == 1 ? '' : 's'} left',
                    ),
                    if (!a.isFree && a.costDescription.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      fact(Icons.payments_outlined, a.costDescription),
                    ],
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: 'View ${a.hostDisplayName}\'s profile',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        onTap: () => context.push(
                          '/user/${a.hostId}',
                          extra: {
                            'name': a.hostDisplayName,
                            'photoUrl': a.hostPhotoUrl,
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: t.colorScheme.outline),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: a.hostDisplayName,
                                photoUrl: a.hostPhotoUrl,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hosted by ${a.hostDisplayName}',
                                      style: t.textTheme.titleSmall,
                                    ),
                                    Text(
                                      a.approvalRequired
                                          ? 'Host approves requests'
                                          : 'Open to join',
                                      style: t.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(a.description, style: t.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    _WhatToExpect(activity: a),
                    if (a.safetyNotes.isNotEmpty ||
                        a.cancellationPolicy.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.tint,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.health_and_safety_outlined,
                                  size: 18,
                                  color: t.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Safety and notes',
                                  style: t.textTheme.titleSmall,
                                ),
                              ],
                            ),
                            if (a.safetyNotes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                a.safetyNotes,
                                style: t.textTheme.bodyMedium,
                              ),
                            ],
                            if (a.cancellationPolicy.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Cancellation: ${a.cancellationPolicy}',
                                style: t.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Location', style: t.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _MiniMap(activity: a),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      icon: Icons.directions_outlined,
                      label: 'Get directions',
                      onPressed: () => _directions(a),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Meet in a public place and let a friend know where you\'re going.',
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child:
              (joinState == JoinUiState.joined ||
                  joinState == JoinUiState.hosting)
              // Going: the next step is the chat; leaving (or managing, for
              // the host) is a smaller secondary action beside it.
              ? Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Open group chat',
                        onPressed: () => context.push('/activity/${a.id}/chat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(96, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: c.busy
                            ? null
                            : a.isHost
                            ? () => context.push('/activity/${a.id}/members')
                            : () => _confirm(
                                'Leave this plan?',
                                'You can request to join again later if there\'s space.',
                                'Leave',
                                c.leave,
                              ),
                        child: Text(a.isHost ? 'Manage' : 'Leave'),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (joinState == JoinUiState.requested)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'You\'ll see the host\'s reply under the bell on the map.',
                          style: t.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    JoinActivityButton(
                      state: joinState,
                      loading: c.busy,
                      onJoin: () async {
                        if (await ensureProfilePhoto(
                          context,
                          reason: 'Add one to join this plan.',
                        )) {
                          c.join();
                        }
                      },
                      onLeave: () => _confirm(
                        'Withdraw your request?',
                        'You can request to join again later if there\'s space.',
                        'Withdraw',
                        c.leave,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Plain-language summary of what joining means, built only from real plan
/// fields so a first-timer can decide without guessing.
class _WhatToExpect extends StatelessWidget {
  const _WhatToExpect({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final t = Theme.of(context);
    final mins = a.endAt.difference(a.startAt).inMinutes;
    final duration = mins <= 0
        ? null
        : mins < 60
        ? '$mins min'
        : '${(mins / 60).toStringAsFixed(mins % 60 == 0 ? 0 : 1)} hr';
    final lines = <(IconData, String)>[
      (
        Icons.groups_2_outlined,
        'A group of up to ${a.capacity} people${duration == null ? '' : ', about $duration'}.',
      ),
      (
        a.approvalRequired
            ? Icons.how_to_reg_outlined
            : Icons.lock_open_outlined,
        a.approvalRequired
            ? 'The host reviews each request before you\'re in.'
            : 'No approval needed. Join and you\'re in.',
      ),
      (
        Icons.payments_outlined,
        a.isFree
            ? 'Free to join.'
            : a.costDescription.isEmpty
            ? 'Paid. Ask the host in the group chat what it covers.'
            : 'Paid: ${a.costDescription}',
      ),
      (
        Icons.chat_bubble_outline,
        'After joining you can chat with the group and the host.',
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What to expect', style: t.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: t.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown once you are in: the two things people look for after joining,
/// when and where, plus a one-tap route. Real data only, no countdowns.
class _GoingCard extends StatelessWidget {
  const _GoingCard({required this.activity, required this.onDirections});
  final Activity activity;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: t.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                a.isHost ? 'You\'re hosting' : 'You\'re going',
                style: t.textTheme.titleSmall?.copyWith(
                  color: t.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.activityWhen(a.startAt),
            style: t.textTheme.titleMedium,
          ),
          Text(a.venueName, style: t.textTheme.bodyMedium),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              minimumSize: const Size(0, 44),
            ),
            onPressed: onDirections,
            icon: const Icon(Icons.directions_outlined, size: 18),
            label: const Text('Get directions'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        // The tuned colours are for light backgrounds; lift them on dark.
        color: Theme.of(context).brightness == Brightness.dark
            ? Color.lerp(color, Colors.white, 0.5)
            : color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}

/// Static (non-interactive) map showing the venue only; nobody's live location.
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final cfg = MapConfig.fromEnvironment();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 150,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: activity.position,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            BasemapLayer(config: cfg),
            MarkerLayer(
              markers: [
                Marker(
                  point: activity.position,
                  width: ActivityMarker.width,
                  height: ActivityMarker.height,
                  alignment: Alignment.topCenter,
                  child: ActivityMarker(category: activity.category),
                ),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution(cfg.attribution)],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading shape of the plan page: hero, title, and the host row, so the
/// screen settles in place instead of jumping when the data arrives.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const LoadingSkeleton(height: 246, radius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LoadingSkeleton(height: 28, width: 240),
                const SizedBox(height: 14),
                const LoadingSkeleton(height: 16, width: 180),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const LoadingSkeleton(height: 40, width: 40, radius: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: LoadingSkeleton(height: 16)),
                  ],
                ),
                const SizedBox(height: 24),
                const LoadingSkeleton(height: 14),
                const SizedBox(height: 8),
                const LoadingSkeleton(height: 14),
                const SizedBox(height: 8),
                const LoadingSkeleton(height: 14, width: 220),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
