import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 36,
    this.showWordmark = true,
    this.onDark = false,
  });
  final bool onDark;
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onDark ? Colors.white : AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.groups_rounded,
            color: onDark ? AppColors.primary : Colors.white,
            size: size * 0.6,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Text(
            'Nomad Mingle',
            style: t.textTheme.titleLarge?.copyWith(fontSize: size * 0.55 + 4),
          ),
        ],
      ],
    );
  }
}
