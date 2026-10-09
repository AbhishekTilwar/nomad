import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';

/// Honest placeholder for tabs whose phase isn't built yet. Tracked in TASKS.md.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });
  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyState(
      icon: icon,
      title: '$title is on its way',
      message: message,
    ),
  );
}
