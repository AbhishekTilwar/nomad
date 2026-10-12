import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Theme-aware versions of the neutral [AppColors] tokens. The raw tokens are
/// the light palette; use these from widgets so dark mode gets its own colours.
extension ThemeColors on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get _scheme => Theme.of(this).colorScheme;

  /// Primary text.
  Color get ink => _scheme.onSurface;

  /// Secondary text and icons.
  Color get inkMuted => _scheme.onSurfaceVariant;

  /// Hairlines and borders.
  Color get outline => _scheme.outline;

  /// Input / subtle container fill.
  Color get field => _dark ? AppColors.fieldDark : AppColors.field;

  /// Soft brand tint (selected rows, badges).
  Color get tint => _dark ? AppColors.tintDark : AppColors.primaryLight;
  Color get primaryLight => tint;

  /// Soft warm tint.
  Color get secondaryLight =>
      _dark ? AppColors.secondaryTintDark : AppColors.secondaryLight;

  /// Page background.
  Color get sand => Theme.of(this).scaffoldBackgroundColor;
}
