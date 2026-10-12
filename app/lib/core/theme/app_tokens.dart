import 'package:flutter/material.dart';

/// Centralised design tokens. Widgets must use these rather than literals.
class AppColors {
  const AppColors._();

  // Brand: deep forest teal with a warm amber accent on warm-white surfaces.
  static const primary = Color(0xFF0F4C45);
  static const primaryPressed = Color(0xFF0B332F);
  static const primaryLight = Color(0xFFDCEFEA);
  static const onPrimary = Colors.white;

  static const secondary = Color(0xFFE99A32);
  static const secondaryLight = Color(0xFFFFF0D8);

  /// Brighter primary for dark theme (readable on dark surfaces).
  static const primaryDark = Color(0xFF5FB3A5);
  static const secondaryDark = Color(0xFFF0B25E);

  static const sand = Color(0xFFFAF9F6); // app background
  static const sandDark = Color(0xFF0F1A19);
  static const surface = Colors.white;
  static const surfaceDark = Color(0xFF172625);

  static const ink = Color(0xFF172B2A);
  static const inkMuted = Color(0xFF64716F);
  static const inkFaint = Color(0xFF89938F); // timestamps, low-priority meta
  static const inkDark = Color(0xFFEDF3F1);
  static const inkMutedDark = Color(0xFFA3B2AE);

  static const outline = Color(0xFFE2E7E3);
  static const field = Color(0xFFF1F3F0); // input / subtle container fill
  static const tint = primaryLight;
  static const outlineDark = Color(0xFF2C3E3B);
  static const fieldDark = Color(0xFF223634); // input fill on dark surfaces
  static const tintDark = Color(0xFF1F3F3A); // soft brand tint on dark
  static const secondaryTintDark = Color(0xFF3A2E18);

  static const success = Color(0xFF23845B);
  static const warning = Color(0xFFB96D12);
  static const danger = Color(0xFFC83F42);
  static const info = Color(0xFF326CCB);

  /// Category accents for markers and chips.
  static const categoryColors = <String, Color>{
    'food': Color(0xFFD9532B),
    'outings': Color(0xFF14746F),
    'travel': Color(0xFF2F6FBF),
    'hiking': Color(0xFF3F8A3C),
    'games': Color(0xFF8E4FB5),
    'sports': Color(0xFFB7791F),
    'photography': Color(0xFF5B6B7A),
    'music': Color(0xFFC2408A),
    'movies': Color(0xFF7A4B2A),
    'networking': Color(0xFF1F5F8B),
    'art': Color(0xFFA23E48),
    'explore': Color(0xFF0F7E8C),
  };
}

class AppSpacing {
  const AppSpacing._();
  static const xxs = 4.0;
  static const xs = 4.0; // legacy alias of xxs
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 40.0;
  static const page = EdgeInsets.symmetric(horizontal: 20);
}

class AppRadius {
  const AppRadius._();
  static const chip = 12.0;
  static const sm = 8.0;
  static const field = 12.0;
  static const md = 14.0; // buttons
  static const lg = 16.0; // cards
  static const xl = 24.0; // sheets / large panels
  static const pill = 999.0;
}

class AppShadows {
  const AppShadows._();
  static const card = [
    BoxShadow(color: Color(0x120F2A28), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x1F0F2A28), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

class AppMotion {
  const AppMotion._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
}

/// Minimum interactive size (Material guideline).
const kMinTouchTarget = 48.0;
