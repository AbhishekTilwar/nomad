import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/session_controller.dart';
import '../../onboarding/presentation/add_photo_screen.dart';

/// Joining or hosting needs a profile photo (people want to know who is
/// coming), but browsing does not. Returns true when the member already has
/// one or adds one now; false if they decline.
Future<bool> ensureProfilePhoto(
  BuildContext context, {
  required String reason,
}) async {
  final session = context.read<SessionController>();
  if ((session.profile?.photoUrl ?? '').isNotEmpty) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Add a photo first'),
      content: Text(
        'Hosts and guests like to know who is coming. $reason '
        'You can change it any time.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Add photo'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;
  // A plain navigator route, not a router one: the router refreshes whenever
  // the session changes (which uploading a photo does) and would drop the
  // result, so the join could never continue.
  final added = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AddPhotoScreen(standalone: true),
    ),
  );
  return added == true;
}
