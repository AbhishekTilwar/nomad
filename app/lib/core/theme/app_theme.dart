import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
      error: AppColors.danger,
    ),
    scaffold: AppColors.sand,
  );

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.sandDark,
      secondary: AppColors.secondaryDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.inkDark,
      onSurfaceVariant: AppColors.inkMutedDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineDark,
    ),
    scaffold: AppColors.sandDark,
  );

  static ThemeData _build(ColorScheme scheme, {required Color scaffold}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
    );
    final text = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        )
        // Overridden styles above carry no colour; re-apply so text is visible.
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget + 4),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget + 4),
          shape: shape,
          side: BorderSide(color: scheme.outline, width: 1.5),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary, 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 2),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        backgroundColor: scheme.surface,
        secondaryLabelStyle: text.bodyMedium?.copyWith(color: scheme.primary),
        checkmarkColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: scheme.outline),
        ),
        labelStyle: text.bodyMedium,
        side: BorderSide(color: scheme.outline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
    );
  }
}
