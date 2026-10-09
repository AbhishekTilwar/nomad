import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../application/community_unread_controller.dart';

/// App-bar icon that opens the community chat, with an unread badge. Placing it in the Explore
/// app bar starts the single lightweight unread listener; it stops when the button is disposed.
class CommunityChatButton extends StatefulWidget {
  const CommunityChatButton({super.key, this.onPressed});

  /// Defaults to `context.push('/community')`.
  final VoidCallback? onPressed;

  @override
  State<CommunityChatButton> createState() => _CommunityChatButtonState();
}

class _CommunityChatButtonState extends State<CommunityChatButton> {
  CommunityUnreadController? _unread;

  @override
  void initState() {
    super.initState();
    _unread = context.read<CommunityUnreadController>()..start();
  }

  @override
  void dispose() {
    _unread?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _unread!,
      builder: (context, _) {
        final unread = _unread!.hasUnread;
        return IconButton(
          tooltip: unread
              ? 'Mingle Community, new messages'
              : 'Mingle Community',
          onPressed: widget.onPressed ?? () => context.push('/community'),
          icon: Badge(
            isLabelVisible: unread,
            smallSize: 10,
            child: const Icon(Icons.forum_outlined),
          ),
        );
      },
    );
  }
}
