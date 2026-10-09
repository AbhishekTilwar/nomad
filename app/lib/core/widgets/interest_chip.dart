import 'package:flutter/material.dart';

import '../../features/profile/data/user_profile.dart';
import '../utils/category_style.dart';
import 'app_chip.dart';

/// Interest/category pill. Selectable when [onSelected] is set, otherwise a
/// quiet read-only pill (profile). Uses the short design labels.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.interestId,
    this.selected = false,
    this.onSelected,
    this.style,
  });

  final String interestId;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final AppChipStyle? style;

  @override
  Widget build(BuildContext context) {
    final readOnly = onSelected == null;
    return AppChip(
      label: CategoryStyle.shortLabels[interestId] ?? interestLabel(interestId),
      icon: readOnly ? null : CategoryStyle.icon(interestId),
      selected: selected,
      onSelected: onSelected,
      style: style ?? (readOnly ? AppChipStyle.quiet : AppChipStyle.tinted),
    );
  }
}
