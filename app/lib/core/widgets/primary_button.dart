import 'package:flutter/material.dart';

/// Filled call-to-action with built-in loading state. While [loading] it is
/// disabled so double taps can't submit twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// Overrides the theme's primary colour (e.g. navy in the auth flow).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: backgroundColor == null
          ? null
          : FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: backgroundColor!.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
            ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? Semantics(
              label: 'Loading',
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}
