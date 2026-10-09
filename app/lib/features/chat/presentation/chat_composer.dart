import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';

/// iOS-style rounded composer with a circular send button. The text clears as soon as the
/// message is handed to the controller: delivery failures appear as a retryable failed bubble,
/// so nothing the user typed is lost.
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.onSend, this.disabledReason});

  final Future<void> Function(String text) onSend;

  /// Non-null disables the composer and shows this reason instead of the field.
  final String? disabledReason;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final text = _c.text.trim();
    if (Validators.message(text) != null) return;
    _c.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final reason = widget.disabledReason;
    if (reason != null) {
      return SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('composer-disabled'),
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.outline.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reason,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _c,
                builder: (_, v, _) {
                  final len = v.text.trim().length;
                  return TextField(
                    controller: _c,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      filled: true,
                      fillColor: scheme.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      counterText: len > Validators.maxMessageLength - 100
                          ? '$len/${Validators.maxMessageLength}'
                          : '',
                      errorText: len > Validators.maxMessageLength
                          ? 'Too long'
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _c,
              builder: (_, v, _) => IconButton.filled(
                tooltip: 'Send message',
                onPressed: Validators.message(v.text) != null ? null : _send,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
