import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/activities/models/activity.dart';
import '../../features/profile/data/user_profile.dart';
import '../theme/app_theme.dart' show kFontFamily;
import '../theme/app_tokens.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'user_avatar.dart';

/// Card over the map for the selected pin (design #6): thumbnail left,
/// title, tags, date, place, host avatar + going count.
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({super.key, required this.activity, this.onTap});
  final Activity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = activity;
    final color = CategoryStyle.color(a.category);
    final muted = t.textTheme.bodySmall;

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 84,
        height: 96,
        child: a.coverImageUrl != null
            ? CachedNetworkImage(
                imageUrl: a.coverImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(color),
              )
            : _fallback(color),
      ),
    );

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: muted?.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: muted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final status = a.status == ActivityStatus.cancelled
        ? 'Cancelled'
        : a.isFull
        ? 'Full'
        : a.isSummary
        ? '${a.spotsLeft} spots left'
        : '${a.participantCount} going · ${a.spotsLeft} spots left';

    return Semantics(
      button: true,
      label: '${a.title}, ${Formatters.activityDate(a.startAt)}, $status',
      child: Material(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        elevation: 6,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          _Tag(
                            interestLabel(a.category).split(' ').first,
                            color,
                          ),
                          if (!a.isFree) const _Tag('Paid', AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 2),
                      line(
                        Icons.calendar_today_outlined,
                        Formatters.activityDate(a.startAt),
                      ),
                      line(
                        Icons.place_outlined,
                        [
                          a.venueName,
                          if (a.distanceKm != null)
                            Formatters.distance(a.distanceKm),
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            if (!a.isSummary) ...[
                              UserAvatar(
                                name: a.hostDisplayName,
                                photoUrl: a.hostPhotoUrl,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: muted?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: a.isFull
                                      ? AppColors.danger
                                      : t.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
    child: Icon(CategoryStyle.icon(activity.category), color: c, size: 34),
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
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}
