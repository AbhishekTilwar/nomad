import 'package:flutter/material.dart';

import '../utils/validators.dart';

/// Text composer with live length counter. Validation mirrors the backend
/// (which remains the authority).
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.disabledReason,
  });

  /// Return value is awaited; the field clears only when it completes normally.
  final Future<void> Function(String text) onSend;
  final bool enabled;
  final String? disabledReason;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _c = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (_sending || Validators.message(text) != null) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _c.clear();
    } catch (_) {
      // Caller surfaces the error; keep the text so the user can retry.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (!widget.enabled) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.disabledReason ?? 'You can\'t send messages right now.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
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
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      counterText: len > Validators.maxMessageLength - 100
                          ? '$len/${Validators.maxMessageLength}'
                          : '',
                      errorText: len > Validators.maxMessageLength
                          ? 'Too long'
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _c,
              builder: (_, v, _) => IconButton.filled(
                tooltip: 'Send message',
                onPressed: (_sending || Validators.message(v.text) != null)
                    ? null
                    : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
