import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/user_photo_cache.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../safety/data/safety_repository.dart';
import '../application/chat_controller.dart';
import '../application/chat_read_store.dart';
import '../data/chat_repository.dart';
import 'chat_identity.dart';
import 'chat_view.dart';

/// One-to-one chat with a friend (route `/dm/:uid`).
class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.otherUid,
    this.fallbackName,
    this.fallbackPhotoUrl,
  });
  final String otherUid;
  final String? fallbackName;
  final String? fallbackPhotoUrl;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  late final DirectChatController _c;

  @override
  void initState() {
    super.initState();
    final me = ChatIdentity.of(context);
    _c = DirectChatController(
      repository: context.read<ChatRepository>(),
      safety: context.read<SafetyRepository>(),
      currentUid: me.uid,
      currentName: me.name,
      currentPhotoUrl: me.photoUrl,
      otherUid: widget.otherUid,
      otherName: widget.fallbackName ?? 'Chat',
      readStore: context.read<ChatReadStore>(),
    )..start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/chats');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _back,
        ),
        titleSpacing: 0,
        title: ValueListenableBuilder<UserSummary?>(
          valueListenable: UserPhotoCache.instance.watch(widget.otherUid),
          builder: (_, now, _) {
            final name = now?.name ?? widget.fallbackName ?? 'Chat';
            return InkWell(
              onTap: () => context.push(
                '/user/${widget.otherUid}',
                extra: {'name': name, 'photoUrl': now?.photoUrl},
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: name,
                    photoUrl: now?.photoUrl ?? widget.fallbackPhotoUrl,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: ChatView(
        controller: _c,
        introText: 'This is the start of your conversation. Keep it friendly.',
      ),
    );
  }
}
