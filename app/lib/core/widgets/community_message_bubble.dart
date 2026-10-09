import 'package:flutter/material.dart';

import '../../features/chat/models/chat_message.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';
import 'user_avatar.dart';

/// Shared by the global room and activity chats. iOS-like look: my messages are
/// primary-filled with white text, others are white cards with the sender name.
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
    final meta = isMine
        ? scheme.onPrimary.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant;
    final time = message.createdAt == null
        ? (message.failed ? 'Failed to send' : 'Sending…')
        : Formatters.chatTime(message.createdAt!);
    const r = Radius.circular(AppRadius.lg);
    const tail = Radius.circular(4);

    final bubble = Flexible(
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: message.failed ? onRetry : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Text(
                  message.senderName,
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                  ),
                ),
              Text(
                message.text,
                style: t.textTheme.bodyLarge?.copyWith(color: fg),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: message.failed && !isMine ? scheme.error : meta,
                    fontWeight: message.failed ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
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
          bubble,
          if (message.failed && isMine) ...[
            const SizedBox(width: 6),
            Icon(Icons.error, size: 18, color: scheme.error),
          ],
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
