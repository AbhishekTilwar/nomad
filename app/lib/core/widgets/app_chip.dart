import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppChipStyle {
  /// Selected = solid primary, white label (map filter row, date/location pickers).
  solid,

  /// Selected = light indigo wash with primary label (sign-up interests).
  tinted,

  /// Plain grey read-only pill (profile interests).
  quiet,
}

/// The design's pill chip. Always at least 40px tall to stay tappable.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.style = AppChipStyle.solid,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final AppChipStyle style;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    Color bg, fg, border;
    switch (style) {
      case AppChipStyle.solid:
        bg = selected ? c.primary : c.surface;
        fg = selected ? c.onPrimary : c.onSurface;
        border = selected ? c.primary : c.outline;
      case AppChipStyle.tinted:
        bg = selected ? AppColors.tint : c.surface;
        fg = selected ? c.primary : c.onSurfaceVariant;
        border = selected ? c.primary.withValues(alpha: 0.35) : c.outline;
      case AppChipStyle.quiet:
        bg = AppColors.field;
        fg = c.onSurface;
        border = c.outline;
    }
    return Semantics(
      button: onSelected != null,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: bg,
          shape: StadiumBorder(side: BorderSide(color: border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onSelected == null ? null : () => onSelected!(!selected),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: t.textTheme.labelMedium?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented pill control (Today / This Weekend / Next Week, Mumbai / Pune).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: e.key == value,
                label: e.value,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value ? c.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.value,
                      style: t.textTheme.labelMedium?.copyWith(
                        color: e.key == value
                            ? c.onPrimary
                            : c.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
