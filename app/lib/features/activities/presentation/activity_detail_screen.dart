import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/map_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/activity_marker.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/join_activity_button.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/report_action_sheet.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/user_profile.dart';
import '../../safety/data/safety_repository.dart';
import '../data/activity_repository.dart';
import '../models/activity.dart';
import 'activity_detail_controller.dart';

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
    final msg = c.actionMessage;
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final m = c.takeMessage();
        if (m != null) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(SnackBar(content: Text(m)));
        }
      });
    }

    if (c.loading) {
      return Scaffold(appBar: AppBar(), body: LoadingSkeleton.list(count: 2));
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
    final muted = t.textTheme.bodyMedium?.copyWith(
      color: t.colorScheme.onSurfaceVariant,
    );
    final color = CategoryStyle.color(a.category);
    final joinState = joinUiStateFor(a);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filled(
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
            ),
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/explore'),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.more_horiz, size: 20, color: AppColors.ink),
            ),
            onSelected: (v) {
              if (v == 'report') _report(a);
              if (v == 'cancel') {
                _confirm(
                  'Cancel this plan?',
                  'Everyone who joined will be notified.',
                  'Cancel plan',
                  c.cancelActivity,
                );
              }
              if (v == 'members') context.push('/activity/${a.id}/members');
            },
            itemBuilder: (_) => [
              if (a.isHost && a.status == ActivityStatus.scheduled) ...[
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: c.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            SizedBox(
              height: 250,
              child: a.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: a.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          _HeroFallback(color, a.category),
                    )
                  : _HeroFallback(color, a.category),
            ),
            Padding(
              padding: AppSpacing.page.copyWith(top: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CategoryStyle.icon(a.category),
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        interestLabel(a.category),
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (a.status != ActivityStatus.scheduled) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            a.status == ActivityStatus.cancelled
                                ? 'Cancelled'
                                : 'Completed',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(a.title, style: t.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.lg),
                  _Fact(
                    Icons.schedule,
                    Formatters.activityWhen(a.startAt),
                    'Ends ${Formatters.activityWhen(a.endAt)}',
                  ),
                  _Fact(
                    Icons.place_outlined,
                    a.venueName,
                    [
                      if (a.distanceKm != null)
                        Formatters.distance(a.distanceKm),
                      a.city,
                    ].join(' · '),
                  ),
                  _Fact(
                    Icons.group_outlined,
                    '${a.participantCount} going',
                    a.isFull ? 'No spots left' : '${a.spotsLeft} spots left',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Capacity', style: t.textTheme.titleMedium),
                            const Spacer(),
                            Text(
                              '${a.participantCount} / ${a.capacity}',
                              style: t.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: a.capacity == 0
                                ? 0
                                : (a.participantCount / a.capacity).clamp(0, 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Fact(
                    Icons.payments_outlined,
                    a.isFree ? 'Free' : 'Paid plan',
                    a.costDescription.isEmpty ? null : a.costDescription,
                  ),
                  _Fact(
                    Icons.verified_user_outlined,
                    a.approvalRequired
                        ? 'Host approves requests'
                        : 'Open to join',
                    a.isPrivate ? 'Private plan' : 'Public plan',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('About', style: t.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(a.description, style: t.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      UserAvatar(
                        name: a.hostDisplayName,
                        photoUrl: a.hostPhotoUrl,
                        size: 44,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hosted by', style: muted),
                            Text(
                              a.hostDisplayName,
                              style: t.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (a.safetyNotes.isNotEmpty ||
                      a.cancellationPolicy.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.health_and_safety_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Safety and notes',
                                  style: t.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            if (a.safetyNotes.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(a.safetyNotes),
                            ],
                            if (a.cancellationPolicy.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Cancellation: ${a.cancellationPolicy}',
                                style: muted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text('Location', style: t.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _MiniMap(activity: a),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Meet in a public place and let a friend know where you\'re going.',
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: JoinActivityButton(
            state: joinState,
            loading: c.busy,
            onJoin: c.join,
            onLeave: () => _confirm(
              joinState == JoinUiState.requested
                  ? 'Withdraw your request?'
                  : 'Leave this plan?',
              'You can request to join again later if there\'s space.',
              joinState == JoinUiState.requested ? 'Withdraw' : 'Leave',
              c.leave,
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: t.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.textTheme.titleMedium),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
        height: 160,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: activity.position,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: cfg.tileUrlTemplate,
              userAgentPackageName: cfg.userAgentPackageName,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: activity.position,
                  width: ActivityMarker.size,
                  height: ActivityMarker.size + 8,
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

class _HeroFallback extends StatelessWidget {
  const _HeroFallback(this.color, this.category);
  final Color color;
  final String category;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.4)],
      ),
    ),
    child: Center(
      child: Icon(CategoryStyle.icon(category), size: 84, color: Colors.white),
    ),
  );
}
