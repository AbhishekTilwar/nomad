import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/api/api_client.dart';
import '../models/chat_message.dart';

/// Which room a chat screen is showing: the community room, an activity's
/// group chat, or a one-to-one conversation with a friend.
class ChatRoom {
  const ChatRoom.community() : activityId = null, otherUid = null, _me = null;
  const ChatRoom.activity(String this.activityId) : otherUid = null, _me = null;
  const ChatRoom.direct({required String me, required String this.otherUid})
    : activityId = null,
      _me = me;

  /// Null for the community room and direct chats.
  final String? activityId;

  /// The friend in a direct chat.
  final String? otherUid;
  final String? _me;

  bool get isDirect => otherUid != null;
  bool get isCommunity => activityId == null && otherUid == null;

  /// Same pair id the backend uses: both uids sorted and joined by `_`.
  static String pairId(String a, String b) => ([a, b]..sort()).join('_');

  String get collectionPath => isDirect
      ? 'dms/${pairId(_me!, otherUid!)}/messages'
      : isCommunity
      ? 'communityRooms/global/messages'
      : 'activities/$activityId/messages';
  String get apiPath => isDirect
      ? '/users/$otherUid/messages'
      : isCommunity
      ? '/community/messages'
      : '/activities/$activityId/messages';

  /// Key for read-state storage.
  String get readKey => isDirect
      ? 'dm:$otherUid'
      : isCommunity
      ? 'community'
      : 'activity:$activityId';

  /// Value for report context `roomType`.
  String get typeName =>
      isDirect ? 'direct' : (isCommunity ? 'community' : 'activity');

  @override
  bool operator ==(Object other) =>
      other is ChatRoom &&
      other.activityId == activityId &&
      other.otherUid == otherUid;
  @override
  int get hashCode => Object.hash(activityId, otherUid);
}

/// One row of the Chats tab for a one-to-one conversation.
class DmConversation {
  const DmConversation({
    required this.otherUid,
    required this.lastText,
    required this.lastSenderId,
    required this.updatedAt,
  });
  final String otherUid;
  final String lastText;
  final String lastSenderId;
  final DateTime updatedAt;
}

/// Latest live window, newest first. [cursor] is an opaque handle to the OLDEST message in
/// the window (a Firestore DocumentSnapshot in production) used to page further back.
class ChatWindow {
  const ChatWindow(this.messages, {this.cursor, this.mayHaveMore = false});
  final List<ChatMessage> messages;
  final Object? cursor;
  final bool mayHaveMore;
}

class ChatPage {
  const ChatPage(this.messages, {this.cursor, this.hasMore = false});
  final List<ChatMessage> messages;
  final Object? cursor;
  final bool hasMore;
}

/// Viewer restrictions from `GET /community`.
class CommunityViewer {
  const CommunityViewer({
    required this.canPost,
    this.muted = false,
    this.mutedUntil,
    this.cooldownUntil,
    this.accountStatus = 'active',
    this.maxLength = 500,
    this.roomName = 'Mingle Community',
  });

  final bool canPost;
  final bool muted;
  final DateTime? mutedUntil;
  final DateTime? cooldownUntil;
  final String accountStatus;
  final int maxLength;
  final String roomName;

  factory CommunityViewer.fromJson(Map<String, dynamic> j) {
    final v = (j['viewer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final room = (j['room'] as Map?)?.cast<String, dynamic>() ?? const {};
    DateTime? dt(Object? s) =>
        s is String ? DateTime.tryParse(s)?.toLocal() : null;
    return CommunityViewer(
      canPost: v['canPost'] as bool? ?? true,
      muted: v['muted'] as bool? ?? false,
      mutedUntil: dt(v['mutedUntil']),
      cooldownUntil: dt(v['cooldownUntil']),
      accountStatus: v['accountStatus'] as String? ?? 'active',
      maxLength: ((v['limits'] as Map?)?['maxLength'] as num?)?.toInt() ?? 500,
      roomName: room['name'] as String? ?? 'Mingle Community',
    );
  }
}

/// Chat data seam. Reads are Firestore listeners (rules-authorised); writes go through the API
/// (rate limits and moderation live there). Tests use a fake implementation.
abstract class ChatRepository {
  /// Live listener on the latest [limit] visible messages only (newest first). Cancel the
  /// subscription when the screen goes away.
  Stream<ChatWindow> watchLatest(ChatRoom room, {int limit = 30});

  /// Older messages strictly before [cursor] (newest first).
  Future<ChatPage> loadOlder(
    ChatRoom room, {
    required Object cursor,
    int limit = 30,
  });

  /// Lightweight listener (limit 1) on the newest visible community message; null = none.
  Stream<ChatMessage?> watchNewestCommunityMessage();

  /// Sends through the API. Reuse the same [clientMessageId] when retrying (idempotent).
  /// Throws `AppException` (`rate_limited` carries `retryAfterSeconds`).
  Future<ChatMessage> send(
    ChatRoom room, {
    required String text,
    required String clientMessageId,
  });

  Future<CommunityViewer> communityViewer();

  /// Live list of my one-to-one conversations, newest first.
  Stream<List<DmConversation>> watchConversations(String myUid) =>
      const Stream.empty();

  /// Sender ids the viewer blocked (cached; pass [refresh] to refetch).
  Future<Set<String>> blockedIds({bool refresh = false});

  /// Update the local cache after a successful block.
  void markBlocked(String uid);
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({
    required FirebaseFirestore firestore,
    required ApiClient api,
    this.blocksTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _db = firestore,
       _api = api,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final ApiClient _api;
  final Duration blocksTtl;
  final DateTime Function() _clock;

  Set<String>? _blocked;
  DateTime? _blockedAt;
  Future<Set<String>>? _blockedInFlight;

  Query<Map<String, dynamic>> _latestQuery(ChatRoom room) => _db
      .collection(room.collectionPath)
      .where('moderationStatus', isEqualTo: 'visible')
      .orderBy('createdAt', descending: true);

  static ChatMessage? _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data();
    // Server timestamps only: a doc without createdAt yet is skipped until it resolves.
    final created = j['createdAt'];
    if (created is! Timestamp) return null;
    return ChatMessage(
      id: d.id,
      senderId: j['senderId'] as String? ?? '',
      senderName: j['senderName'] as String? ?? 'Member',
      senderPhotoUrl: j['senderPhotoUrl'] as String?,
      text: j['text'] as String? ?? '',
      createdAt: created.toDate(),
    );
  }

  @override
  Stream<ChatWindow> watchLatest(ChatRoom room, {int limit = 30}) =>
      _latestQuery(room).limit(limit).snapshots().map((snap) {
        final docs = snap.docs;
        return ChatWindow(
          [for (final d in docs) ?_fromDoc(d)],
          cursor: docs.isEmpty ? null : docs.last,
          mayHaveMore: docs.length >= limit,
        );
      });

  @override
  Future<ChatPage> loadOlder(
    ChatRoom room, {
    required Object cursor,
    int limit = 30,
  }) async {
    final snap = await _latestQuery(
      room,
    ).startAfterDocument(cursor as DocumentSnapshot).limit(limit).get();
    final docs = snap.docs;
    return ChatPage(
      [for (final d in docs) ?_fromDoc(d)],
      cursor: docs.isEmpty ? cursor : docs.last,
      hasMore: docs.length >= limit,
    );
  }

  @override
  Stream<ChatMessage?> watchNewestCommunityMessage() =>
      _latestQuery(const ChatRoom.community()).limit(1).snapshots().map((s) {
        for (final d in s.docs) {
          final m = _fromDoc(d);
          if (m != null) return m;
        }
        return null;
      });

  @override
  Future<ChatMessage> send(
    ChatRoom room, {
    required String text,
    required String clientMessageId,
  }) async {
    final res = await _api.post(
      room.apiPath,
      body: {'text': text, 'clientMessageId': clientMessageId},
    );
    final j = res.asMap;
    return ChatMessage(
      id: j['id'] as String,
      senderId: j['senderId'] as String? ?? '',
      senderName: j['senderName'] as String? ?? 'Me',
      senderPhotoUrl: j['senderPhotoUrl'] as String?,
      text: j['text'] as String? ?? text,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal(),
      clientMessageId: clientMessageId,
    );
  }

  @override
  Stream<List<DmConversation>> watchConversations(String myUid) => _db
      .collection('dms')
      .where('users', arrayContains: myUid)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) {
        final out = <DmConversation>[];
        for (final d in snap.docs) {
          final j = d.data();
          final users = (j['users'] as List?)?.cast<String>() ?? const [];
          final other = users.where((u) => u != myUid).firstOrNull;
          final at = j['updatedAt'];
          final last = (j['lastMessage'] as Map?)?.cast<String, dynamic>();
          if (other == null || at is! Timestamp || last == null) continue;
          out.add(
            DmConversation(
              otherUid: other,
              lastText: last['text'] as String? ?? '',
              lastSenderId: last['senderId'] as String? ?? '',
              updatedAt: at.toDate(),
            ),
          );
        }
        return out;
      });

  @override
  Future<CommunityViewer> communityViewer() async =>
      CommunityViewer.fromJson((await _api.get('/community')).asMap);

  @override
  Future<Set<String>> blockedIds({bool refresh = false}) {
    final fresh =
        _blocked != null &&
        _blockedAt != null &&
        _clock().difference(_blockedAt!) < blocksTtl;
    if (!refresh && fresh) return Future.value(_blocked);
    return _blockedInFlight ??= _api
        .get('/users/me/blocks')
        .then((r) {
          _blocked = {
            for (final j in r.asList)
              (j['uid'] ?? j['targetUid'] ?? j['id']) as String,
          };
          _blockedAt = _clock();
          return _blocked!;
        })
        .whenComplete(() => _blockedInFlight = null);
  }

  @override
  void markBlocked(String uid) {
    // If nothing is cached yet the next fetch will include it server-side.
    if (_blocked != null) _blocked = {..._blocked!, uid};
  }
}
