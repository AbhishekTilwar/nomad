import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Typeface: Inter (bundled in assets/fonts, SIL OFL).
const kFontFamily = 'Inter';

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

  /// Type scale (Inter): 32 splash, 28 page titles, 20 section headings,
  /// 16 card titles / large body, 15 buttons & inputs, 14 body, 12-13 metadata.
  static TextTheme _textTheme(ColorScheme c) {
    TextStyle s(double size, FontWeight w, {double h = 1.4, Color? color}) =>
        TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: color ?? c.onSurface,
        );
    return TextTheme(
      displaySmall: s(32, FontWeight.w700, h: 1.2),
      headlineMedium: s(28, FontWeight.w700, h: 1.25),
      headlineSmall: s(20, FontWeight.w700, h: 1.3),
      titleLarge: s(20, FontWeight.w600, h: 1.3),
      titleMedium: s(16, FontWeight.w600, h: 1.35),
      titleSmall: s(14, FontWeight.w600),
      bodyLarge: s(16, FontWeight.w400, h: 1.5),
      bodyMedium: s(14, FontWeight.w400, h: 1.5),
      bodySmall: s(12, FontWeight.w400, h: 1.35, color: c.onSurfaceVariant),
      labelLarge: s(15, FontWeight.w600, h: 1.2),
      labelMedium: s(13, FontWeight.w500, h: 1.2),
      labelSmall: s(12, FontWeight.w500, h: 1.2),
    );
  }

  static ThemeData _build(ColorScheme scheme, {required Color scaffold}) {
    final text = _textTheme(scheme);
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: kFontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
    );
    final btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
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
          minimumSize: const Size.fromHeight(48),
          shape: btnShape,
          elevation: 0,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: btnShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
          shape: btnShape,
          textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        disabledBorder: border(scheme.outline),
        focusedBorder: border(scheme.primary, 1.5),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.5),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium,
        side: BorderSide(color: scheme.outline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent, // design: no pill, tint only
        elevation: 0,
        height: 66,
        iconTheme: WidgetStateProperty.resolveWith(
          (st) => IconThemeData(
            size: 24,
            color: st.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (st) => text.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: st.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outline,
        thumbColor: scheme.primary,
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: btnShape,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodySmall,
      ),
    );
  }
}
