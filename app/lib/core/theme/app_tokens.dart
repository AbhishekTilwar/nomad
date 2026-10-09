import 'package:flutter/material.dart';

/// Centralised design tokens. Widgets must use these rather than literals.
class AppColors {
  const AppColors._();

  // Brand: indigo on soft lavender surfaces.
  static const primary = Color(0xFF5B4FE0);
  static const primaryDark = Color(0xFF9A93FF);
  static const onPrimary = Colors.white;
  static const secondary = Color(0xFF3B6FE0);
  static const secondaryDark = Color(0xFF8DB1FF);

  static const sand = Color(0xFFF6F6FC);
  static const sandDark = Color(0xFF12121C);
  static const surface = Colors.white;
  static const surfaceDark = Color(0xFF1C1C2A);

  static const ink = Color(0xFF1E2140);
  static const inkMuted = Color(0xFF666B8A);
  static const inkDark = Color(0xFFF1F1FA);
  static const inkMutedDark = Color(0xFFA9ACC6);

  static const outline = Color(0xFFE3E4F1);
  static const outlineDark = Color(0xFF34354A);

  static const success = Color(0xFF1E8A4C);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFC62F3B);

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
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = EdgeInsets.symmetric(horizontal: 20);
}

class AppRadius {
  const AppRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class AppShadows {
  const AppShadows._();
  static const card = [
    BoxShadow(color: Color(0x141E2140), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x241E2140), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

class AppMotion {
  const AppMotion._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
}

/// Minimum interactive size (Material guideline).
const kMinTouchTarget = 48.0;
