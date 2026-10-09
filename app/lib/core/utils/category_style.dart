import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class CategoryStyle {
  const CategoryStyle._();

  static Color color(String category) =>
      AppColors.categoryColors[category] ?? AppColors.secondary;

  static IconData icon(String category) {
    switch (category) {
      case 'food':
        return Icons.local_cafe_outlined;
      case 'outings':
        return Icons.wb_sunny_outlined;
      case 'travel':
        return Icons.luggage_outlined;
      case 'hiking':
        return Icons.terrain_outlined;
      case 'games':
        return Icons.casino_outlined;
      case 'sports':
        return Icons.directions_run;
      case 'photography':
        return Icons.photo_camera_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'movies':
        return Icons.movie_outlined;
      case 'networking':
        return Icons.handshake_outlined;
      case 'art':
        return Icons.palette_outlined;
      default:
        return Icons.explore_outlined;
    }
  }
}
