import 'package:flutter/material.dart';

import '../../../core/utils/category_style.dart';

import '../../../core/widgets/app_chip.dart';
import '../../profile/data/user_profile.dart';

/// Minimum interests required to build a useful feed.
const kMinInterests = 3;

/// Wrapped, selectable interest pills (tinted style).
class InterestPicker extends StatelessWidget {
  const InterestPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final void Function(String id, bool on) onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 10,
    children: [
      for (final i in kInterests)
        AppChip(
          label: CategoryStyle.shortLabels[i.id] ?? interestLabel(i.id),
          selected: selected.contains(i.id),
          style: AppChipStyle.tinted,
          onSelected: (v) => onToggle(i.id, v),
        ),
    ],
  );
}

/// "Interests (choose at least 3)" caption row.
class InterestsHeader extends StatelessWidget {
  const InterestsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Interests ',
            style: t.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '(choose at least $kMinInterests)',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
