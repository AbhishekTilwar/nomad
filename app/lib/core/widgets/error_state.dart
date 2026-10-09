import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Friendly failure view with an optional retry.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: title,
    message: message,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}
