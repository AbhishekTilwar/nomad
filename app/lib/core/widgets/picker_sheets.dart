import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'primary_button.dart';
import '../theme/theme_colors.dart';

/// One picker language for the whole app: every choice (a date, a category, a
/// duration, a country) opens the same rounded bottom sheet with a title, a
/// clear current value and a labelled action, instead of a mix of dialogs,
/// dropdown menus and clocks.

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
);

/// A tappable form field that looks like [AppFormField] (label above, filled
/// tile) and opens a picker sheet. Shows [errorText] like a text field does.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.onTap,
    this.valueText,
    this.icon,
    this.errorText,
    this.showLabel = true,
  });

  final String label;
  final String hint;
  final String? valueText;
  final IconData? icon;
  final String? errorText;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final has = (valueText ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          ExcludeSemantics(
            child: Text(
              label,
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          button: true,
          label: has ? '$label, $valueText' : '$label, not set',
          child: ExcludeSemantics(
            child: Material(
              color: context.field,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.field),
                side: BorderSide(
                  color: errorText == null
                      ? context.outline
                      : AppColors.danger,
                ),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: context.inkMuted),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            has ? valueText! : hint,
                            style: t.textTheme.bodyLarge?.copyWith(
                              color: has ? context.ink : context.inkMuted,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: context.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                style: t.textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          ),
      ],
    );
  }
}

class PickerOption<T> {
  const PickerOption(
    this.value,
    this.label, {
    this.subtitle,
    this.leading,
    this.icon,
    this.iconColor,
  });
  final T value;
  final String label;
  final String? subtitle;

  /// A short text glyph, e.g. a flag emoji.
  final String? leading;

  /// An icon in a tinted circle (recognition over reading), e.g. a category.
  final IconData? icon;
  final Color? iconColor;
}

/// Single-choice sheet. Returns the chosen value, or null if dismissed.
/// Set [searchable] for long lists (countries).
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
  bool searchable = false,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  shape: _sheetShape,
  builder: (_) => _OptionSheet<T>(
    title: title,
    options: options,
    selected: selected,
    searchable: searchable,
  ),
);

class _OptionSheet<T> extends StatefulWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
  });
  final String title;
  final List<PickerOption<T>> options;
  final T? selected;
  final bool searchable;

  @override
  State<_OptionSheet<T>> createState() => _OptionSheetState<T>();
}

class _OptionSheetState<T> extends State<_OptionSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final shown = [
      for (final o in widget.options)
        if (_q.isEmpty || o.label.toLowerCase().contains(_q.toLowerCase())) o,
    ];
    final maxH = MediaQuery.sizeOf(context).height * 0.8;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.title, style: t.textTheme.titleLarge),
                ),
              ),
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No matches.',
                          style: t.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final o = shown[i];
                          final on = o.value == widget.selected;
                          return Semantics(
                            button: true,
                            selected: on,
                            label: o.label,
                            child: ExcludeSemantics(
                              child: ListTile(
                                minTileHeight: 52,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                tileColor: on ? context.primaryLight : null,
                                leading: o.icon != null
                                    ? CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            (o.iconColor ?? AppColors.primary)
                                                .withValues(alpha: 0.14),
                                        child: Icon(
                                          o.icon,
                                          size: 20,
                                          color:
                                              o.iconColor ?? AppColors.primary,
                                        ),
                                      )
                                    : o.leading == null
                                    ? null
                                    : Text(
                                        o.leading!,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                title: Text(
                                  o.label,
                                  style: t.textTheme.bodyLarge?.copyWith(
                                    fontWeight: on
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: o.subtitle == null
                                    ? null
                                    : Text(o.subtitle!),
                                trailing: on
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () => Navigator.pop(context, o.value),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date (or date and time) wheel in the same sheet. Returns the chosen value,
/// or null if dismissed. [error] is checked live and disables the action;
/// [summary] is the live line under the wheel (e.g. an age or a weekday).
Future<DateTime?> showDateWheelSheet(
  BuildContext context, {
  required String title,
  required DateTime initial,
  required DateTime min,
  required DateTime max,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
  String? helper,
  String confirmLabel = 'Confirm',
  int minuteInterval = 1,
  String? Function(DateTime)? error,
  String Function(DateTime)? summary,
}) => showModalBottomSheet<DateTime>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  shape: _sheetShape,
  builder: (_) => _DateWheelSheet(
    title: title,
    initial: initial,
    min: min,
    max: max,
    mode: mode,
    helper: helper,
    confirmLabel: confirmLabel,
    minuteInterval: minuteInterval,
    error: error,
    summary: summary,
  ),
);

class _DateWheelSheet extends StatefulWidget {
  const _DateWheelSheet({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.mode,
    required this.helper,
    required this.confirmLabel,
    required this.minuteInterval,
    required this.error,
    required this.summary,
  });
  final String title;
  final DateTime initial;
  final DateTime min;
  final DateTime max;
  final CupertinoDatePickerMode mode;
  final String? helper;
  final String confirmLabel;
  final int minuteInterval;
  final String? Function(DateTime)? error;
  final String Function(DateTime)? summary;

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  late DateTime _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final err = widget.error?.call(_picked);
    final line = err ?? widget.summary?.call(_picked);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: t.textTheme.titleLarge),
            if (widget.helper != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.helper!,
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: widget.mode,
                  initialDateTime: widget.initial,
                  minimumDate: widget.min,
                  maximumDate: widget.max,
                  minuteInterval: widget.minuteInterval,
                  onDateTimeChanged: (d) => setState(() => _picked = d),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 24,
              child: line == null
                  ? null
                  : Semantics(
                      liveRegion: true,
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: err == null ? context.ink : AppColors.danger,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: widget.confirmLabel,
              onPressed: err == null
                  ? () => Navigator.pop(context, _picked)
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
