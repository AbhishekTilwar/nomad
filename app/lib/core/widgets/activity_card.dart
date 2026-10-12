import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../features/activities/models/activity.dart';
import '../../features/profile/data/user_profile.dart';
import '../theme/app_tokens.dart';
import '../utils/category_style.dart';
import '../utils/plan_emoji.dart';
import '../utils/formatters.dart';
import 'user_avatar.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.compact = false,
    this.distanceFrom,
    this.showServerDistance = true,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final bool compact;

  /// Where distances are measured from (the member's own position). When
  /// null and [showServerDistance] is false, no distance is shown, so a
  /// number never pretends to be measured from the member.
  final LatLng? distanceFrom;
  final bool showServerDistance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = activity;
    final muted = t.textTheme.bodyMedium?.copyWith(
      color: t.colorScheme.onSurfaceVariant,
    );
    final km = distanceFrom != null
        ? const Distance().as(LengthUnit.Kilometer, distanceFrom!, a.position)
        : (showServerDistance ? a.distanceKm : null);
    final place = [
      a.venueName,
      if (km != null) Formatters.distance(km),
    ].where((s) => s.isNotEmpty).join(' · ');
    final spots = a.status == ActivityStatus.cancelled
        ? 'Cancelled'
        : a.isFull
        ? 'Full'
        : '${a.spotsLeft} ${a.spotsLeft == 1 ? 'spot' : 'spots'} left';

    return Semantics(
      button: true,
      label: '${a.title}, ${Formatters.activityWhen(a.startAt)}, $spots',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          PlanEmoji.of(a.title, a.category),
                          style: const TextStyle(fontSize: 16, height: 1.1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          interestLabel(a.category),
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: CategoryStyle.textColor(context, a.category),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          a.isFree ? 'Free' : 'Paid',
                          style: t.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _iconLine(
                      Icons.schedule,
                      Formatters.activityWhen(a.startAt),
                      muted,
                    ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _iconLine(Icons.place_outlined, place, muted),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        if (a.hasHostInfo) ...[
                          UserAvatar(
                            name: a.hostDisplayName,
                            photoUrl: a.hostPhotoUrl,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            a.hasHostInfo
                                ? 'Hosted by ${a.hostDisplayName}'
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                        Text(
                          spots,
                          style: t.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: a.isFull
                                ? AppColors.danger
                                : (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF6FD3A4)
                                      : AppColors.success),
                          ),
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

  Widget _iconLine(IconData icon, String text, TextStyle? style) => Row(
    children: [
      Icon(icon, size: 16, color: style?.color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}
