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
import '../../../core/widgets/secondary_button.dart';
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
    final color = CategoryStyle.color(a.category);
    final joinState = joinUiStateFor(a);
    final isMember = a.isHost || a.membership == MembershipStatus.approved;
    final capFraction = a.capacity == 0
        ? 0.0
        : (a.participantCount / a.capacity).clamp(0.0, 1.0);

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
              child: a.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: a.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          _HeroFallback(color, a.category),
                    )
                  : _HeroFallback(color, a.category),
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
                    Row(
                      children: [
                        UserAvatar(
                          name: a.hostDisplayName,
                          photoUrl: a.hostPhotoUrl,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${a.participantCount} going',
                          style: t.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (!a.isFree && a.costDescription.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      fact(Icons.payments_outlined, a.costDescription),
                    ],
                    const SizedBox(height: 16),
                    Container(
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
                    const SizedBox(height: 16),
                    Text(a.description, style: t.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Capacity', style: t.textTheme.titleSmall),
                        const Spacer(),
                        Text(
                          '${a.participantCount} / ${a.capacity}',
                          style: t.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: capFraction,
                      ),
                    ),
                    if (a.safetyNotes.isNotEmpty ||
                        a.cancellationPolicy.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.tint,
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
                    Text(
                      'Meet in a public place and let a friend know where you\'re going.',
                      style: t.textTheme.bodySmall,
                    ),
                    if (isMember && a.status == ActivityStatus.scheduled) ...[
                      const SizedBox(height: 16),
                      SecondaryButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Open group chat',
                        onPressed: () => context.push('/activity/${a.id}/chat'),
                      ),
                    ],
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
        color: color,
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
            TileLayer(
              urlTemplate: cfg.tileUrlTemplate,
              userAgentPackageName: cfg.userAgentPackageName,
            ),
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
        colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.45)],
      ),
    ),
    child: Center(
      child: Icon(CategoryStyle.icon(category), size: 84, color: Colors.white),
    ),
  );
}
