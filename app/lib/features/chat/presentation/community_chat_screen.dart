import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../safety/data/safety_repository.dart';
import '../application/chat_controller.dart';
import '../application/chat_read_store.dart';
import '../data/chat_repository.dart';
import 'chat_header.dart';
import 'chat_identity.dart';
import 'chat_view.dart';

/// "Mingle Community": full-screen route layered over Explore (route `/community`).
class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  late final CommunityChatController _c;

  @override
  void initState() {
    super.initState();
    final me = ChatIdentity.of(context);
    _c = CommunityChatController(
      repository: context.read<ChatRepository>(),
      safety: context.read<SafetyRepository>(),
      currentUid: me.uid,
      currentName: me.name,
      currentPhotoUrl: me.photoUrl,
      readStore: context.read<ChatReadStore>(),
    )..start();
  }

  @override
  void dispose() {
    _c.dispose(); // cancels the Firestore listener
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/explore');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: _c,
          builder: (_, _) => ChatHeaderTitle(
            title: _c.title,
            subtitle: _c.subtitle,
            fallbackIcon: Icons.public,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert),
            onSelected: (_) => context.push('/legal/guidelines'),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'guidelines',
                child: Text('Community guidelines'),
              ),
            ],
          ),
        ],
      ),
      body: ChatView(
        controller: _c,
        introText:
            'Welcome to Mingle Community. Be kind and follow the community guidelines.',
      ),
    );
  }
}
