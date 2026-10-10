import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/community_message_bubble.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/report_action_sheet.dart';
import '../application/chat_controller.dart';
import '../models/chat_message.dart';
import 'chat_composer.dart';

/// Shared body for the community and activity chats: banner, messages (newest at the bottom,
/// older pages load when scrolling up), send-error strip and the composer.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.controller,
    this.introText,
    this.onOpenProfile,
  });

  final ChatController controller;

  /// Grey system line shown above the oldest message.
  final String? introText;

  /// Override for "View profile"; defaults to the built-in profile sheet.
  final void Function(ChatMessage message)? onOpenProfile;

  @override
  State<ChatView> createState() => _ChatViewState();
}

sealed class _Entry {
  const _Entry();
}

class _Msg extends _Entry {
  const _Msg(this.message);
  final ChatMessage message;
}

class _Label extends _Entry {
  const _Label(this.text);
  final String text;
}

class _Spinner extends _Entry {
  const _Spinner();
}

class _OlderRetry extends _Entry {
  const _OlderRetry();
}

class _ChatViewState extends State<ChatView> {
  final _scroll = ScrollController();

  ChatController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadOlder);
    c.addListener(_afterChange);
  }

  @override
  void dispose() {
    c.removeListener(_afterChange);
    _scroll.dispose();
    super.dispose();
  }

  void _afterChange() {
    // Content may not fill the viewport yet (few messages + more pages available).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadOlder());
  }

  void _maybeLoadOlder() {
    if (!mounted || !_scroll.hasClients) return;
    if (c.olderError != null) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 300) c.loadOlder();
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(d);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_Entry> _entries() {
    final msgs = c.messages;
    final out = <_Entry>[];
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      out.add(_Msg(m));
      final next = i + 1 < msgs.length ? msgs[i + 1] : null;
      final at = m.createdAt;
      if (at == null) continue;
      final startsDay = next == null
          ? !c.hasMoreOlder
          : (next.createdAt != null && !_sameDay(at, next.createdAt!));
      if (startsDay) out.add(_Label(_dayLabel(at)));
    }
    if (c.loadingOlder) {
      out.add(const _Spinner());
    } else if (c.olderError != null) {
      out.add(const _OlderRetry());
    } else if (!c.hasMoreOlder && widget.introText != null) {
      out.add(_Label(widget.introText!));
    }
    return out;
  }

  // ---- actions
  Future<void> _onLongPress(ChatMessage m) async {
    if (m.senderId == c.currentUid) {
      if (m.failed) await _failedSheet(m);
      return;
    }
    if (m.pending) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View profile'),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report message'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text('Block ${m.senderName}'),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'profile':
        _openProfile(m);
      case 'report':
        await _report(m);
      case 'block':
        await _block(m);
    }
  }

  void _openProfile(ChatMessage m) {
    final cb = widget.onOpenProfile;
    if (cb != null) return cb(m);
    context.push(
      '/user/${m.senderId}',
      extra: {'name': m.senderName, 'photoUrl': m.senderPhotoUrl},
    );
  }

  Future<void> _failedSheet(ChatMessage m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Try again'),
              onTap: () => Navigator.pop(ctx, 'retry'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'discard'),
            ),
          ],
        ),
      ),
    );
    if (action == 'retry') c.retry(m.id);
    if (action == 'discard') c.discard(m.id);
  }

  Future<void> _report(ChatMessage m) async {
    final result = await ReportActionSheet.show(
      context,
      title: 'Report message',
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await c.report(m, result);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report sent. Thanks for keeping Mingle safe.'),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _block(ChatMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${m.senderName}?'),
        content: const Text(
          'You won\'t see their messages in chats anymore. You can unblock them later from your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await c.block(m);
      messenger.showSnackBar(
        SnackBar(content: Text('${m.senderName} is blocked.')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ---- build
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        children: [
          if (c.readOnlyBanner != null) _Banner(text: c.readOnlyBanner!),
          Expanded(child: _body(context)),
          if (c.sendError != null) _SendError(text: c.sendError!),
          if (c.status != ChatStatus.error)
            ChatComposer(
              onSend: c.send,
              disabledReason: c.composerDisabledReason,
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (c.status) {
      case ChatStatus.loading:
        return const _ChatSkeleton();
      case ChatStatus.error:
        return ErrorState(
          title: 'Couldn\'t load the chat',
          message: c.error,
          onRetry: c.start,
        );
      case ChatStatus.ready:
        if (c.messages.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No messages yet',
            message: 'Be the first to say hi.',
          );
        }
        final entries = _entries();
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            return switch (e) {
              _Msg(:final message) => _bubble(message),
              _Label(:final text) => _SystemLine(text),
              _Spinner() => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              _OlderRetry() => Center(
                child: TextButton(
                  onPressed: c.loadOlder,
                  child: Text(c.olderError ?? 'Try again'),
                ),
              ),
            };
          },
        );
    }
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.senderId == c.currentUid;
    return CommunityMessageBubble(
      key: ValueKey(m.id),
      message: m,
      isMine: mine,
      onLongPress: () => _onLongPress(m),
      onAvatarTap: mine ? null : () => _openProfile(m),
      onRetry: m.failed ? () => c.retry(m.id) : null,
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      key: const ValueKey('chat-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: t.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _SendError extends StatelessWidget {
  const _SendError({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        key: const ValueKey('send-error'),
        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.error),
      ),
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading messages',
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        Align(
          alignment: Alignment.centerLeft,
          child: LoadingSkeleton(height: 44, width: 200, radius: AppRadius.lg),
        ),
        SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: LoadingSkeleton(height: 36, width: 150, radius: AppRadius.lg),
        ),
        SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: LoadingSkeleton(height: 56, width: 240, radius: AppRadius.lg),
        ),
      ],
    ),
  );
}
