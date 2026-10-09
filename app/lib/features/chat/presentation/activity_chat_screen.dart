import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../activities/data/activity_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../application/chat_controller.dart';
import '../application/chat_read_store.dart';
import '../data/chat_repository.dart';
import 'chat_header.dart';
import 'chat_identity.dart';
import 'chat_view.dart';

/// Group chat for one activity (route `/activity/:id/chat`).
class ActivityChatScreen extends StatefulWidget {
  const ActivityChatScreen({super.key, required this.activityId});
  final String activityId;

  @override
  State<ActivityChatScreen> createState() => _ActivityChatScreenState();
}

class _ActivityChatScreenState extends State<ActivityChatScreen> {
  late final ActivityChatController _c;

  @override
  void initState() {
    super.initState();
    final me = ChatIdentity.of(context);
    _c = ActivityChatController(
      repository: context.read<ChatRepository>(),
      safety: context.read<SafetyRepository>(),
      activities: context.read<ActivityRepository>(),
      activityId: widget.activityId,
      currentUid: me.uid,
      currentName: me.name,
      currentPhotoUrl: me.photoUrl,
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _back,
        ),
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: _c,
          builder: (_, _) => ChatHeaderTitle(
            title: _c.title,
            subtitle: _c.subtitle,
            people: _c.headerAvatars,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Community guidelines',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/legal/guidelines'),
          ),
        ],
      ),
      body: ChatView(
        controller: _c,
        introText:
            'Chat with the people joining this activity. Keep it friendly.',
      ),
    );
  }
}
