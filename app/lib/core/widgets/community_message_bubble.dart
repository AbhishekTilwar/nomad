import 'package:flutter/material.dart';

import '../../features/chat/models/chat_message.dart';
import '../utils/formatters.dart';
import 'user_avatar.dart';

/// Shared by the global room and activity chats. Design look: mine = indigo bubble, white text,
/// time + double ticks below; others = avatar, grey name above, white bordered bubble.
class CommunityMessageBubble extends StatelessWidget {
  const CommunityMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onAvatarTap,
    this.onLongPress,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;

  /// Tapping a failed message calls this (retry send).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final bg = isMine ? scheme.primary : scheme.surface;
    final fg = isMine ? scheme.onPrimary : scheme.onSurface;
    final sent = message.createdAt != null && !message.failed;
    final time = message.createdAt == null
        ? (message.failed ? 'Failed to send' : 'Sending…')
        : Formatters.chatTime(message.createdAt!);
    const r = Radius.circular(14);
    const tail = Radius.circular(4);
    final metaStyle = t.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: message.failed ? scheme.error : scheme.onSurfaceVariant,
      fontWeight: message.failed ? FontWeight.w700 : null,
    );

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      onTap: message.failed ? onRetry : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: isMine ? r : tail,
            bottomRight: isMine ? tail : r,
          ),
          border: isMine ? null : Border.all(color: scheme.outline),
        ),
        child: Text(
          message.text,
          style: t.textTheme.bodyMedium?.copyWith(color: fg, height: 1.35),
        ),
      ),
    );

    final column = Flexible(
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                message.senderName,
                style: t.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          bubble,
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.failed && isMine) ...[
                  Icon(Icons.error, size: 14, color: scheme.error),
                  const SizedBox(width: 4),
                ],
                Text(time, style: metaStyle),
                if (isMine && sent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    key: const ValueKey('sent-ticks'),
                    size: 14,
                    color: scheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: UserAvatar(
                name: message.senderName,
                photoUrl: message.senderPhotoUrl,
                size: 32,
              ),
            ),
            const SizedBox(width: 8),
          ],
          column,
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
