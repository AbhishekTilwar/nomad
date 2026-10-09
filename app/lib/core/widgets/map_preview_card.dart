import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/activities/models/activity.dart';
import '../../features/profile/data/user_profile.dart';
import '../theme/app_tokens.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';

/// Compact card shown over the map when a marker is selected
/// (thumbnail left, details right).
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({super.key, required this.activity, this.onTap});
  final Activity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = activity;
    final color = CategoryStyle.color(a.category);
    final muted = t.textTheme.bodySmall?.copyWith(
      color: t.colorScheme.onSurfaceVariant,
    );

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 84,
        height: 84,
        child: a.coverImageUrl != null
            ? CachedNetworkImage(
                imageUrl: a.coverImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(color),
              )
            : _fallback(color),
      ),
    );

    return Semantics(
      button: true,
      label: '${a.title}, ${Formatters.activityWhen(a.startAt)}',
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          _Tag(interestLabel(a.category), color),
                          if (!a.isFree) _Tag('Paid', AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: muted?.color),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              Formatters.activityWhen(a.startAt),
                              style: muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: muted?.color,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                a.venueName,
                                if (a.distanceKm != null)
                                  Formatters.distance(a.distanceKm),
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (!a.isSummary || a.spotsLeft > 0 || a.isFull) ...[
                        const SizedBox(height: 4),
                        Text(
                          a.status == ActivityStatus.cancelled
                              ? 'Cancelled'
                              : a.isFull
                              ? 'Full'
                              : a.isSummary
                              ? '${a.spotsLeft} spots left'
                              : '${a.participantCount} going · ${a.spotsLeft} spots left',
                          style: t.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: a.isFull
                                ? AppColors.danger
                                : t.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(Color c) => ColoredBox(
    color: c.withValues(alpha: 0.14),
    child: Icon(CategoryStyle.icon(activity.category), color: c, size: 32),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
