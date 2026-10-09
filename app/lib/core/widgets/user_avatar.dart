import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
  });

  final String name;
  final String? photoUrl;
  final double size;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      alignment: Alignment.center,
      color: scheme.secondary.withValues(alpha: 0.18),
      child: Text(
        _initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          color: scheme.secondary,
        ),
      ),
    );
    return Semantics(
      label: 'Avatar of $name',
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? fallback
              : CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: (size * 3).round(),
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
