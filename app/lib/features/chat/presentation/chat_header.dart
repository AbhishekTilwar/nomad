import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/my_activities_repository.dart';

/// Overlapping circular avatars (max [max]); used by chat headers and the Chats list.
class OverlappedAvatars extends StatelessWidget {
  const OverlappedAvatars({
    super.key,
    required this.people,
    this.size = 28,
    this.max = 3,
  });
  final List<ParticipantPreview> people;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    if (shown.isEmpty) return SizedBox(width: size, height: size);
    final step = size * 0.65;
    final ring = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
                child: UserAvatar(
                  name: shown[i].displayName,
                  photoUrl: shown[i].photoUrl,
                  size: size - 4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// App-bar title: avatars (or [fallbackIcon]) above/next to title and subtitle ("N members").
class ChatHeaderTitle extends StatelessWidget {
  const ChatHeaderTitle({
    super.key,
    required this.title,
    this.subtitle = '',
    this.people = const [],
    this.fallbackIcon = Icons.groups_2_outlined,
    this.onTap,
  });

  /// Tapping the header (e.g. open the meetup page from its group chat).
  final VoidCallback? onTap;
  final String title;
  final String subtitle;
  final List<ParticipantPreview> people;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final row = Row(
      children: [
        if (people.isEmpty)
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.tint,
            child: Icon(fallbackIcon, size: 18, color: t.colorScheme.primary),
          )
        else
          OverlappedAvatars(people: people),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      hint: 'Opens the meetup page',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}
