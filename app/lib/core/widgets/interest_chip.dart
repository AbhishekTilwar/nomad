import 'package:flutter/material.dart';

import '../../features/profile/data/user_profile.dart';
import '../utils/category_style.dart';

/// Selectable chip when [onSelected] is set, otherwise a read-only label.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.interestId,
    this.selected = false,
    this.onSelected,
  });

  final String interestId;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(interestId);
    final label = interestLabel(interestId);
    if (onSelected == null) {
      return Chip(
        avatar: Icon(CategoryStyle.icon(interestId), size: 16, color: color),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      );
    }
    return FilterChip(
      avatar: Icon(
        CategoryStyle.icon(interestId),
        size: 18,
        color: selected ? null : color,
      ),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
