import 'dart:async';

import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/activities/data/my_activities_repository.dart';
import 'package:nomad_mingle/features/chat/data/chat_repository.dart';
import 'package:nomad_mingle/features/chat/models/chat_message.dart';
import 'package:nomad_mingle/features/safety/data/safety_repository.dart';

ChatMessage msg(
  String id,
  String sender,
  String text, {
  int minutesAgo = 0,
  DateTime? at,
  String? name,
}) => ChatMessage(
  id: id,
  senderId: sender,
  senderName: name ?? 'User $sender',
  text: text,
  createdAt: at ?? DateTime.now().subtract(Duration(minutes: minutesAgo)),
);

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({this.blocked = const {}});

  Set<String> blocked;
  Object? blockedError;
  CommunityViewer? viewer;
  Object? viewerError;

  // --- latest window
  StreamController<ChatWindow>? _window;
  ChatWindow? _lastWindow;
  int windowListens = 0;
  bool get windowActive => _window != null && _window!.hasListener;

  @override
  Stream<ChatWindow> watchLatest(ChatRoom room, {int limit = 30}) {
    windowListens++;
    late StreamController<ChatWindow> c;
    c = StreamController<ChatWindow>(
      onListen: () {
        if (_lastWindow != null) c.add(_lastWindow!);
      },
    );
    _window = c;
    return c.stream;
  }

  /// [messages] newest first.
  void emitWindow(
    List<ChatMessage> messages, {
    bool mayHaveMore = false,
    Object? cursor = 'cursor-live',
  }) {
    _lastWindow = ChatWindow(
      messages,
      cursor: messages.isEmpty ? null : cursor,
      mayHaveMore: mayHaveMore,
    );
    _window?.add(_lastWindow!);
  }

  void emitWindowError(Object e) => _window?.addError(e);

  // --- older pages
  final olderPages = <ChatPage>[];
  final olderCursorsRequested = <Object>[];
  Object? olderError;

  @override
  Future<ChatPage> loadOlder(
    ChatRoom room, {
    required Object cursor,
    int limit = 30,
  }) async {
    olderCursorsRequested.add(cursor);
    if (olderError != null) throw olderError!;
    return olderPages.isEmpty ? const ChatPage([]) : olderPages.removeAt(0);
  }

  // --- newest (unread)
  StreamController<ChatMessage?>? _newest;
  ChatMessage? _lastNewest;
  int newestListens = 0;
  bool get newestActive => _newest != null && _newest!.hasListener;

  @override
  Stream<ChatMessage?> watchNewestCommunityMessage() {
    newestListens++;
    late StreamController<ChatMessage?> c;
    c = StreamController<ChatMessage?>(
      onListen: () {
        if (_lastNewest != null) c.add(_lastNewest);
      },
    );
    _newest = c;
    return c.stream;
  }

  void emitNewest(ChatMessage? m) {
    _lastNewest = m;
    _newest?.add(m);
  }

  // --- send
  final sent = <({String text, String cid})>[];
  Future<ChatMessage> Function(String text, String cid)? onSend;
  String senderUid = 'me';

  @override
  Future<ChatMessage> send(
    ChatRoom room, {
    required String text,
    required String clientMessageId,
  }) {
    sent.add((text: text, cid: clientMessageId));
    final h = onSend;
    if (h != null) return h(text, clientMessageId);
    return Future.value(
      ChatMessage(
        id: '${senderUid}_$clientMessageId',
        senderId: senderUid,
        senderName: 'Me',
        text: text,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<CommunityViewer> communityViewer() async {
    if (viewerError != null) throw viewerError!;
    return viewer ?? const CommunityViewer(canPost: true);
  }

  @override
  Future<Set<String>> blockedIds({bool refresh = false}) async {
    if (blockedError != null) throw blockedError!;
    return blocked;
  }

  final markedBlocked = <String>[];
  @override
  void markBlocked(String uid) => markedBlocked.add(uid);
}

class FakeSafetyRepository implements SafetyRepository {
  final reports = <Map<String, Object?>>[];
  final blockedUids = <String>[];
  Object? reportError;

  @override
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
    Map<String, dynamic>? context,
  }) async {
    if (reportError != null) throw reportError!;
    reports.add({
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details,
      'context': context,
    });
  }

  @override
  Future<void> block(String uid) async => blockedUids.add(uid);
  @override
  Future<void> unblock(String uid) async => blockedUids.remove(uid);
  @override
  Future<List<BlockedUser>> blocks() async => const [];
}

class FakeMyActivitiesRepository implements MyActivitiesRepository {
  final Map<MyActivitiesRole, List<MyActivity>> byRole = {};
  Object? error;
  int calls = 0;

  @override
  Future<MyActivitiesPage> list(
    MyActivitiesRole role, {
    String? cursor,
    int limit = 20,
  }) async {
    calls++;
    if (error != null) throw error!;
    return MyActivitiesPage(byRole[role] ?? const [], null);
  }
}

AppException rateLimited(int seconds, {String reason = 'rate_limit'}) =>
    AppException(
      'You are sending messages too quickly',
      code: 'rate_limited',
      retryable: true,
      retryAfterSeconds: seconds,
      reason: reason,
    );
