import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/picker_sheets.dart';
import '../../../core/theme/theme_colors.dart';

/// Shared chrome for the step-by-step onboarding: round back button and a
/// slim progress bar on top, heading block, scrolling body and a pinned
/// footer button.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    this.progress,
    required this.title,
    required this.child,
    this.subtitle,
    this.badge,
    this.titleTrailing,
    this.onBack,
    this.trailing,
    this.footer,
  });

  /// 0..1 share of onboarding completed (including this step).
  /// Null outside onboarding (e.g. the photo prompt opened from a join).
  final double? progress;
  final String title;
  final String? subtitle;

  /// Decorative icon shown top-right of the heading.
  final IconData? badge;
  final Widget? titleTrailing;
  final VoidCallback? onBack;

  /// Top-right action (Skip / Sign out).
  final Widget? trailing;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      if (onBack == null)
                        const SizedBox(width: 44, height: 44)
                      else
                        _RoundBackButton(onPressed: onBack!),
                      const SizedBox(width: AppSpacing.md),
                      if (progress != null)
                        Expanded(child: _ProgressBar(value: progress!))
                      else
                        const Spacer(),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        width: 84,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: t.textTheme.headlineMedium),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                subtitle!,
                                style: t.textTheme.bodyLarge?.copyWith(
                                  color: t.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (titleTrailing != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        titleTrailing!,
                      ] else if (badge != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        ExcludeSemantics(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: context.secondaryLight,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Icon(
                              badge,
                              color: AppColors.secondary,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(child: child),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: ExcludeSemantics(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: CircleBorder(side: BorderSide(color: context.outline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
      ),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progress',
    value: '${(value * 100).round()}%',
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: AppMotion.normal,
          builder: (_, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 4,
            backgroundColor: context.outline,
            color: AppColors.primary,
          ),
        ),
      ),
    ),
  );
}

/// Small field caption above an input (13px medium).
class FieldCaption extends StatelessWidget {
  const FieldCaption(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium),
  );
}

/// Single-choice row: tinted + outlined + check mark when selected.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? context.primaryLight : context.field,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: t.textTheme.bodyLarge?.copyWith(
                          color: selected ? AppColors.primary : context.ink,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check,
                        color: AppColors.primary,
                        size: 22,
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

/// Birthday field that opens a bottom-sheet wheel picker and shows an age
/// badge once chosen. Enforces 18+ via [Validators.dateOfBirth].
class DobPickerTile extends StatelessWidget {
  const DobPickerTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _open(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDateWheelSheet(
      context,
      title: 'Your birthday',
      helper: 'Scroll to your real birthday. You can\'t change it later.',
      initial: initial.isAfter(now) ? now : initial,
      min: DateTime(now.year - 100),
      max: DateTime(now.year, now.month, now.day),
      confirmLabel: 'Confirm birthday',
      error: (d) => Validators.dateOfBirth(d, now: now),
      summary: (d) =>
          'You\'ll be shown as ${Validators.ageOn(d, now)} years old',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dob = value;
    final error = dob == null ? null : Validators.dateOfBirth(dob);
    final age = dob == null ? null : Validators.ageOn(dob, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldCaption('Birthday'),
        Semantics(
          button: true,
          label: dob == null
              ? 'Birthday, not set'
              : 'Birthday, ${DateFormat.yMMMMd().format(dob)}',
          child: ExcludeSemantics(
            child: Material(
              color: context.field,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.field),
                side: BorderSide(
                  color: error == null ? context.outline : AppColors.danger,
                ),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                onTap: () => _open(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          color: context.inkMuted,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dob == null
                                ? 'Select your birthday'
                                : DateFormat.yMMMMd().format(dob),
                            style: t.textTheme.bodyLarge?.copyWith(
                              color: dob == null
                                  ? context.inkMuted
                                  : context.ink,
                            ),
                          ),
                        ),
                        if (age != null && age >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.primaryLight,
                              borderRadius: BorderRadius.circular(
                                AppRadius.chip,
                              ),
                            ),
                            child: Text(
                              '$age yrs',
                              style: t.textTheme.labelMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
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
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: t.textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'You must be 18 or older. Check it carefully: it can\'t be changed later. Others only see an age range.',
              style: t.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
