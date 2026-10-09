import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/report_action_sheet.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/data/my_activities_repository.dart'
    show ParticipantPreview;
import '../../activities/models/activity.dart';
import '../../safety/data/safety_repository.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import 'chat_read_store.dart';

enum ChatStatus { loading, ready, error }

String _newClientMessageId() {
  // Backend requires [A-Za-z0-9_-]{8,64}.
  final r = Random.secure().nextInt(1 << 30).toRadixString(36);
  return 'm${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$r';
}

/// State for one chat room. Holds: one live listener on the latest window, older pages loaded on
/// demand, optimistic pending messages (with failure + retry), blocked-sender filtering and
/// 429 cool-down handling. Subclasses add room-specific restrictions via [metaDisabledReason].
class ChatController extends ChangeNotifier {
  ChatController({
    required this.repository,
    required this.safety,
    required this.room,
    required this.currentUid,
    required this.currentName,
    this.currentPhotoUrl,
    this.readStore,
    this.pageSize = 30,
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) : _newId = idGenerator ?? _newClientMessageId,
       clock = clock ?? DateTime.now;

  final ChatRepository repository;
  final SafetyRepository safety;
  final ChatRoom room;
  final String currentUid;
  final String currentName;
  final String? currentPhotoUrl;
  final ChatReadStore? readStore;
  final int pageSize;
  final DateTime Function() clock;
  final String Function() _newId;

  // --- state
  ChatStatus _status = ChatStatus.loading;
  String? _error;
  final Map<String, ChatMessage> _byId = {};
  final List<ChatMessage> _pending = [];
  Set<String> _blocked = {};
  Object? _liveCursor;
  Object? _olderCursor;
  bool _liveMayHaveMore = false;
  bool _hasMoreOlder = false;
  bool _loadingOlder = false;
  String? _olderError;
  String? _sendError;
  DateTime? _cooldownUntil;
  List<ChatMessage>? _view;
  StreamSubscription<ChatWindow>? _sub;
  Timer? _ticker;
  bool _disposed = false;

  ChatStatus get status => _status;
  String? get error => _error;
  bool get hasMoreOlder => _hasMoreOlder;
  bool get loadingOlder => _loadingOlder;
  String? get olderError => _olderError;

  /// Why the last send failed (cleared on the next successful/retried send).
  String? get sendError => _sendError;

  // --- overridable room metadata
  String get title => 'Chat';
  String get subtitle => '';
  List<ParticipantPreview> get headerAvatars => const [];

  /// Shown as a banner above the list (e.g. read-only activity).
  String? get readOnlyBanner => null;

  /// Room-specific restriction (muted, read-only...). Null = may post.
  String? get metaDisabledReason => null;

  /// Loads room-specific info. Failures must not block reading messages.
  @protected
  Future<void> loadMeta() async {}

  /// Null when the composer is enabled.
  String? get composerDisabledReason {
    final cool = cooldownRemaining;
    if (cool > Duration.zero) {
      return 'Slow down. You can send again in ${cool.inSeconds + 1}s.';
    }
    return metaDisabledReason;
  }

  Duration get cooldownRemaining {
    final until = _cooldownUntil;
    if (until == null) return Duration.zero;
    final d = until.difference(clock());
    return d.isNegative ? Duration.zero : d;
  }

  /// Messages newest first (index 0 = newest/bottom of the screen): pending ones first, then
  /// confirmed ones with blocked senders removed. Deduplicated by id.
  List<ChatMessage> get messages => _view ??= _buildView();

  List<ChatMessage> _buildView() {
    final server =
        _byId.values.where((m) => !_blocked.contains(m.senderId)).toList()
          ..sort((a, b) {
            final c = b.createdAt!.compareTo(a.createdAt!);
            return c != 0 ? c : b.id.compareTo(a.id);
          });
    return List.unmodifiable([..._pending.reversed, ...server]);
  }

  void _changed() {
    _view = null;
    if (!_disposed) notifyListeners();
  }

  // --- lifecycle
  Future<void> start() async {
    unawaited(
      _sub?.cancel(),
    ); // not awaited: a cancel after a stream error may not complete promptly
    _sub = null;
    _status = ChatStatus.loading;
    _error = null;
    _changed();
    try {
      _blocked = await repository.blockedIds();
    } catch (_) {
      // Blocklist is best-effort; the server also filters its own message list.
    }
    if (_disposed) return;
    unawaited(_loadMetaSafe());
    _sub = repository
        .watchLatest(room, limit: pageSize)
        .listen(_onWindow, onError: _onStreamError);
  }

  Future<void> _loadMetaSafe() async {
    try {
      await loadMeta();
    } catch (_) {
      // Non-fatal: the server still enforces restrictions on send.
    }
    _changed();
  }

  void _onWindow(ChatWindow w) {
    final ids = {for (final m in w.messages) m.id};
    // Messages inside the live window's time range that are no longer in it were hidden or
    // removed by moderation. Anything older than the window stays (older pages / slid out).
    DateTime? floor;
    if (w.mayHaveMore && w.messages.isNotEmpty) {
      floor = w.messages.last.createdAt;
    } else if (_olderCursor == null) {
      floor = DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (floor != null) {
      _byId.removeWhere(
        (id, m) =>
            !ids.contains(id) &&
            m.createdAt != null &&
            m.createdAt!.isAfter(floor!),
      );
    }
    for (final m in w.messages) {
      if (m.createdAt != null) _byId[m.id] = m;
    }
    _pending.removeWhere(
      (p) =>
          p.clientMessageId != null &&
          _byId.containsKey('${currentUid}_${p.clientMessageId}'),
    );
    _liveCursor = w.cursor;
    _liveMayHaveMore = w.mayHaveMore;
    if (_olderCursor == null) _hasMoreOlder = _liveMayHaveMore;
    _status = ChatStatus.ready;
    _error = null;
    _changed();
    _markRead();
  }

  void _onStreamError(Object e, [StackTrace? _]) {
    _error = e is FirebaseException && e.code == 'permission-denied'
        ? 'You no longer have access to this chat.'
        : 'Couldn\'t load messages. Check your connection and try again.';
    _status = ChatStatus.error;
    _changed();
  }

  void _markRead() {
    final store = readStore;
    if (store == null) return;
    DateTime? newest;
    for (final m in _byId.values) {
      final c = m.createdAt;
      if (c != null && (newest == null || c.isAfter(newest))) newest = c;
    }
    store.markRead(room.readKey, newest ?? clock());
  }

  // --- pagination
  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder || _status != ChatStatus.ready) return;
    final cursor = _olderCursor ?? _liveCursor;
    if (cursor == null) return;
    _loadingOlder = true;
    _olderError = null;
    _changed();
    try {
      final page = await repository.loadOlder(
        room,
        cursor: cursor,
        limit: pageSize,
      );
      for (final m in page.messages) {
        if (m.createdAt != null) _byId[m.id] = m;
      }
      _olderCursor = page.cursor ?? cursor;
      _hasMoreOlder = page.hasMore;
    } catch (_) {
      _olderError = 'Couldn\'t load earlier messages.';
    } finally {
      _loadingOlder = false;
      _changed();
    }
  }

  // --- sending
  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || composerDisabledReason != null) return;
    final cid = _newId();
    final pending = ChatMessage(
      id: 'local_$cid',
      senderId: currentUid,
      senderName: currentName,
      senderPhotoUrl: currentPhotoUrl,
      text: t,
      createdAt: null,
      pending: true,
      clientMessageId: cid,
    );
    _pending.add(pending);
    _sendError = null;
    _changed();
    await _deliver(pending);
  }

  /// Retries a failed message, reusing its clientMessageId so the server stays idempotent.
  Future<void> retry(String localId) async {
    final i = _pending.indexWhere((m) => m.id == localId);
    if (i < 0 || _pending[i].pending) return;
    final cool = cooldownRemaining;
    if (cool > Duration.zero) {
      _sendError = _rateLimitText(cool.inSeconds + 1);
      _changed();
      return;
    }
    _sendError = null;
    await _deliver(_pending[i]);
  }

  void discard(String localId) {
    _pending.removeWhere((m) => m.id == localId);
    _sendError = null;
    _changed();
  }

  Future<void> _deliver(ChatMessage p) async {
    _setPending(
      p.id,
      p.copyWith(pending: true, failed: false, clearError: true),
    );
    try {
      final sent = await repository.send(
        room,
        text: p.text,
        clientMessageId: p.clientMessageId!,
      );
      if (_pending.indexWhere((m) => m.id == p.id) < 0) {
        return; // discarded meanwhile
      }
      _pending.removeWhere((m) => m.id == p.id);
      if (sent.createdAt != null) _byId[sent.id] = sent;
      _sendError = null;
      _changed();
      _markRead();
    } on AppException catch (e) {
      _fail(p, e);
    } catch (_) {
      _fail(
        p,
        const AppException(
          'Couldn\'t send. Check your connection and tap the message to retry.',
          retryable: true,
        ),
      );
    }
  }

  static String _rateLimitText(int seconds) =>
      'You\'re sending messages too quickly. Try again in ${seconds}s.';

  void _fail(ChatMessage p, AppException e) {
    if (_pending.indexWhere((m) => m.id == p.id) < 0) return;
    String msg = e.message;
    if (e.code == 'rate_limited') {
      final secs = e.retryAfterSeconds;
      if (e.reason == 'duplicate_message') {
        msg = 'You already sent that. Try again in ${secs ?? 30}s.';
      } else if (secs != null) {
        msg = _rateLimitText(secs);
      }
      if (secs != null) {
        _cooldownUntil = clock().add(Duration(seconds: secs));
        _tickUntil(_cooldownUntil!);
      }
    }
    _sendError = msg;
    _setPending(p.id, p.copyWith(pending: false, failed: true, error: msg));
  }

  void _setPending(String id, ChatMessage m) {
    final i = _pending.indexWhere((x) => x.id == id);
    if (i >= 0) _pending[i] = m;
    _changed();
  }

  /// Rebuilds listeners once a second until [until] so countdown text stays live.
  @protected
  void tickUntil(DateTime until) => _tickUntil(until);

  void _tickUntil(DateTime until) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!clock().isBefore(until) || _disposed) {
        t.cancel();
        _cooldownUntil = null;
      }
      _changed();
    });
  }

  // --- safety
  Future<void> report(ChatMessage m, ReportResult r) => safety.report(
    targetType: 'message',
    targetId: m.id,
    reason: r.reason.name,
    details: r.details,
    context: {
      'roomType': room.isCommunity ? 'community' : 'activity',
      'activityId': ?room.activityId,
    },
  );

  Future<void> block(ChatMessage m) async {
    await safety.block(m.senderId);
    repository.markBlocked(m.senderId);
    _blocked = {..._blocked, m.senderId};
    _changed();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}

/// Mingle Community room: `GET /community` restrictions disable the composer with a reason.
class CommunityChatController extends ChatController {
  CommunityChatController({
    required super.repository,
    required super.safety,
    required super.currentUid,
    required super.currentName,
    super.currentPhotoUrl,
    super.readStore,
    super.pageSize,
    super.idGenerator,
    super.clock,
  }) : super(room: const ChatRoom.community());

  CommunityViewer? viewer;

  @override
  String get title => viewer?.roomName ?? 'Mingle Community';
  @override
  String get subtitle => 'Open to all members';

  @override
  Future<void> loadMeta() async {
    viewer = await repository.communityViewer();
    final cd = viewer?.cooldownUntil;
    if (cd != null && cd.isAfter(clock())) tickUntil(cd);
  }

  @override
  String? get metaDisabledReason {
    final v = viewer;
    if (v == null) return null; // unknown: let the server decide
    if (v.accountStatus == 'suspended' || v.accountStatus == 'deleted') {
      return 'Your account is restricted, so you can\'t post.';
    }
    if (v.muted) {
      final until = v.mutedUntil;
      return until != null
          ? 'You\'re muted until ${DateFormat('d MMM, h:mm a').format(until)}. You can still read the chat.'
          : 'A moderator has muted you. You can still read the chat.';
    }
    final cd = v.cooldownUntil;
    if (cd != null && cd.isAfter(clock())) {
      return 'You\'re on a short cooldown. You can post again at ${DateFormat.jm().format(cd)}.';
    }
    if (!v.canPost) return 'Posting is unavailable right now.';
    return null;
  }
}

/// Activity group chat: header from the activity + approved members; read-only when the
/// activity is cancelled or completed.
class ActivityChatController extends ChatController {
  ActivityChatController({
    required super.repository,
    required super.safety,
    required super.currentUid,
    required super.currentName,
    required this.activityId,
    required ActivityRepository activities,
    super.currentPhotoUrl,
    super.readStore,
    super.pageSize,
    super.idGenerator,
    super.clock,
  }) : _activities = activities,
       super(room: ChatRoom.activity(activityId));

  final String activityId;
  final ActivityRepository _activities;
  Activity? activity;
  List<ActivityMember> members = const [];

  @override
  String get title => activity?.title ?? 'Activity chat';

  @override
  String get subtitle {
    final n = members.isNotEmpty
        ? members.length
        : (activity?.participantCount ?? 0);
    if (n == 0) return '';
    return n == 1 ? '1 member' : '$n members';
  }

  @override
  List<ParticipantPreview> get headerAvatars => [
    for (final m in members)
      ParticipantPreview(
        uid: m.userId,
        displayName: m.displayName,
        photoUrl: m.photoUrl,
      ),
  ];

  @override
  String? get readOnlyBanner => switch (activity?.status) {
    ActivityStatus.cancelled =>
      'This activity was cancelled. The chat is read-only.',
    ActivityStatus.completed =>
      'This activity has ended. The chat is read-only.',
    _ => null,
  };

  @override
  String? get metaDisabledReason =>
      readOnlyBanner == null ? null : 'This chat is read-only.';

  @override
  Future<void> loadMeta() async {
    // Independent: a members failure must not hide the title/status or vice versa.
    Future<void> loadActivity() async {
      try {
        activity = await _activities.get(activityId);
      } catch (_) {}
    }

    Future<void> loadMembers() async {
      try {
        members = (await _activities.members(
          activityId,
        )).where((x) => x.status == MembershipStatus.approved).toList();
      } catch (_) {}
    }

    await Future.wait([loadActivity(), loadMembers()]);
  }
}
