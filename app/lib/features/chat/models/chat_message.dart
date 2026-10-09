class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.senderPhotoUrl,
    this.pending = false,
    this.failed = false,
    this.clientMessageId,
    this.error,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;

  /// Server timestamp; null while a locally-sent message is awaiting confirmation.
  final DateTime? createdAt;
  final bool pending;
  final bool failed;

  /// Set on locally-sent messages; the server stores `{uid}_{clientMessageId}` as the doc id,
  /// which is how an optimistic message is reconciled with the live listener.
  final String? clientMessageId;

  /// Human-readable failure reason for [failed] messages.
  final String? error;

  ChatMessage copyWith({
    bool? pending,
    bool? failed,
    String? error,
    bool clearError = false,
  }) => ChatMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    senderPhotoUrl: senderPhotoUrl,
    text: text,
    createdAt: createdAt,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
    clientMessageId: clientMessageId,
    error: clearError ? null : (error ?? this.error),
  );
}
