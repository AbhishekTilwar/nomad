import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../auth/application/session_controller.dart';

/// The signed-in user as chat controllers need it.
class ChatIdentity {
  const ChatIdentity(this.uid, this.name, this.photoUrl);
  final String uid;
  final String name;
  final String? photoUrl;

  factory ChatIdentity.of(BuildContext context) {
    final s = context.read<SessionController>();
    return ChatIdentity(
      s.user?.uid ?? '',
      s.profile?.displayName ?? s.user?.displayName ?? 'Me',
      s.profile?.photoUrl ?? s.user?.photoUrl,
    );
  }
}
