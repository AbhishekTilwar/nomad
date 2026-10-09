import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Pulsing placeholder block (no extra dependency).
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppRadius.sm,
  });

  final double height;
  final double? width;
  final double radius;

  /// A stack of card-shaped skeletons for list loading states.
  static Widget list({int count = 3}) => Semantics(
    label: 'Loading',
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppSpacing.page.copyWith(top: 8, bottom: 8),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => const ActivityCardSkeleton(),
    ),
  );

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.outline;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.4 + 0.4 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(height: 14, width: 90),
          SizedBox(height: 12),
          LoadingSkeleton(height: 20),
          SizedBox(height: 8),
          LoadingSkeleton(height: 14, width: 180),
          SizedBox(height: 16),
          LoadingSkeleton(height: 14, width: 120),
        ],
      ),
    ),
  );
}
