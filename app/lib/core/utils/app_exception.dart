/// User-presentable failure. Repositories translate low-level errors into this
/// so the UI never shows stack traces or raw backend messages.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.retryable = false,
    this.retryAfterSeconds,
    this.reason,
  });
  final String message;
  final String? code;
  final bool retryable;

  /// Present on `rate_limited` responses (`details.retryAfterSeconds`).
  final int? retryAfterSeconds;

  /// Server `details.reason` (e.g. `read_only`, `cooldown`, `duplicate_message`).
  final String? reason;

  @override
  String toString() => message;
}
