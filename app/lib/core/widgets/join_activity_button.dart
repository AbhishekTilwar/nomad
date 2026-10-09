import 'package:flutter/material.dart';

import '../../features/activities/models/activity.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Primary action for an activity. Presentation only: the backend decides
/// whether a join is actually allowed (capacity is enforced atomically there).
class JoinActivityButton extends StatelessWidget {
  const JoinActivityButton({
    super.key,
    required this.state,
    required this.onJoin,
    this.onLeave,
    this.loading = false,
  });

  final JoinUiState state;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case JoinUiState.join:
        return PrimaryButton(
          label: 'Join',
          onPressed: onJoin,
          loading: loading,
        );
      case JoinUiState.requestToJoin:
        return PrimaryButton(
          label: 'Request to join',
          onPressed: onJoin,
          loading: loading,
        );
      case JoinUiState.requested:
        return SecondaryButton(
          label: 'Requested · waiting for host',
          icon: Icons.hourglass_top,
          onPressed: onLeave,
          loading: loading,
        );
      case JoinUiState.joined:
        return SecondaryButton(
          label: 'Joined · tap to leave',
          icon: Icons.check_circle_outline,
          onPressed: onLeave,
          loading: loading,
        );
      case JoinUiState.hosting:
        return const SecondaryButton(
          label: 'You\'re hosting',
          icon: Icons.star_outline,
          onPressed: null,
        );
      case JoinUiState.full:
        return const PrimaryButton(label: 'Full', onPressed: null);
      case JoinUiState.cancelled:
        return const PrimaryButton(label: 'Cancelled', onPressed: null);
      case JoinUiState.completed:
        return const PrimaryButton(label: 'Completed', onPressed: null);
    }
  }
}
