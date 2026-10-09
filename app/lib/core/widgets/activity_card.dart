import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/activities/models/activity.dart';
import '../../features/profile/data/user_profile.dart';
import '../theme/app_tokens.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'user_avatar.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.compact = false,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = activity;
    final color = CategoryStyle.color(a.category);
    final muted = t.textTheme.bodyMedium?.copyWith(
      color: t.colorScheme.onSurfaceVariant,
    );
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
              if (!compact && a.coverImageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: CachedNetworkImage(
                    imageUrl: a.coverImageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 900,
                    placeholder: (_, _) =>
                        ColoredBox(color: color.withValues(alpha: 0.1)),
                    errorWidget: (_, _, _) =>
                        ColoredBox(color: color.withValues(alpha: 0.1)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CategoryStyle.icon(a.category),
                          size: 16,
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
                    const SizedBox(height: 2),
                    _iconLine(
                      Icons.place_outlined,
                      [
                        a.venueName,
                        if (a.distanceKm != null)
                          Formatters.distance(a.distanceKm),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      muted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        if (!a.isSummary) ...[
                          UserAvatar(
                            name: a.hostDisplayName,
                            photoUrl: a.hostPhotoUrl,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            a.isSummary ? '' : 'Hosted by ${a.hostDisplayName}',
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
                                : AppColors.success,
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
