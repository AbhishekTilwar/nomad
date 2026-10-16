import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/app_exception.dart';

/// Thin REST client for the Nomad Mingle API. Attaches a fresh Firebase ID
/// token to each request (the backend verifies it; nothing client-supplied is
/// trusted as identity) and maps the error envelope to [AppException].
///
/// With a [backupBaseUrl] the client fails over: if the primary can't be
/// reached, times out (reads only), answers 502/503/504, or answers with
/// something that isn't our API (an HTML placeholder, a proxy page), the same
/// request goes to the backup. After a failover the backup is used for
/// [stickyFor], then the primary is tried again.
class ApiClient {
  ApiClient({
    required this.tokenProvider,
    http.Client? client,
    String? baseUrl,
    String? backupBaseUrl,
    this.timeout = const Duration(seconds: 45),
    this.primaryTimeout = const Duration(seconds: 12),
    this.stickyFor = const Duration(minutes: 3),
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       backupBaseUrl = _clean(backupBaseUrl ?? AppConfig.apiBackupUrl),
       _clock = clock ?? DateTime.now;

  static String? _clean(String? u) =>
      (u == null || u.trim().isEmpty) ? null : u.trim();

  /// Returns an ID token; when [forceRefresh] is true it must bypass the cache.
  final Future<String?> Function({bool forceRefresh}) tokenProvider;
  final http.Client _client;
  final String baseUrl;
  final String? backupBaseUrl;
  final Duration timeout;

  /// How long to wait on the primary before trying the backup (the backup
  /// gets the full [timeout], as it may be waking from sleep).
  final Duration primaryTimeout;
  final Duration stickyFor;
  final DateTime Function() _clock;
  DateTime? _primaryDownUntil;

  /// Which base URL the next request goes to first.
  String get activeBaseUrl =>
      backupBaseUrl != null &&
          _primaryDownUntil != null &&
          _clock().isBefore(_primaryDownUntil!)
      ? backupBaseUrl!
      : baseUrl;

  /// GETs currently on the wire, keyed by path + query. Two callers asking for
  /// the same thing at the same moment share one request (screens that mount
  /// together, e.g. Chats and its requests badge, would otherwise both fetch).
  final Map<String, Future<ApiResponse>> _inFlightGets = {};

  /// Requests actually sent, by `METHOD /path` with ids collapsed to `:id`.
  /// Counts attempts to the server, not callers served; never holds tokens,
  /// bodies or query values. For tests and local measurement.
  final Map<String, int> requestCounts = {};

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) {
    final key = '$path?${_queryKey(query)}';
    // Block body on purpose: `whenComplete` waits on a returned Future, and
    // `remove` would hand back this very request.
    return _inFlightGets[key] ??= _send('GET', path, query: query).whenComplete(
      () {
        _inFlightGets.remove(key);
      },
    );
  }

  static String _queryKey(Map<String, dynamic>? query) {
    if (query == null) return '';
    final keys = query.keys.where((k) => query[k] != null).toList()..sort();
    return keys.map((k) => '$k=${query[k]}').join('&');
  }

  static final _idSegment = RegExp(r'/[A-Za-z0-9_-]{16,}');
  Future<ApiResponse> post(String path, {Object? body}) =>
      _send('POST', path, body: body);
  Future<ApiResponse> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<ApiResponse> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);
  Future<ApiResponse> delete(String path) => _send('DELETE', path);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool isRetry = false,
  }) async {
    if (!isRetry) {
      final shape = path.replaceAll(_idSegment, '/:id');
      requestCounts.update('$method $shape', (n) => n + 1, ifAbsent: () => 1);
    }
    final token = await tokenProvider(forceRefresh: isRetry);
    if (token == null) {
      throw const AppException(
        'Please sign in again.',
        code: 'unauthenticated',
      );
    }
    final bases = [
      activeBaseUrl,
      if (backupBaseUrl != null)
        activeBaseUrl == baseUrl ? backupBaseUrl! : baseUrl,
    ];
    final idempotent = method == 'GET';
    http.Response? res;
    AppException? lastError;
    for (var i = 0; i < bases.length; i++) {
      final base = bases[i];
      final isLast = i == bases.length - 1;
      final usingBackup = base == backupBaseUrl;
      try {
        final r = await _attempt(
          method,
          base,
          path,
          token,
          query: query,
          body: body,
          // Don't make people wait the full timeout on the primary if a
          // backup exists.
          wait: (!usingBackup && backupBaseUrl != null && !isLast)
              ? primaryTimeout
              : timeout,
        );
        if (!isLast && _looksDown(r)) {
          if (!usingBackup) _markPrimaryDown();
          continue;
        }
        res = r;
        break;
      } on TimeoutException {
        lastError = const AppException(
          'The server is taking too long to respond. Please try again.',
          code: 'timeout',
          retryable: true,
        );
        // A timeout may mean the server did act on it; only retry reads.
        if (!isLast && idempotent) {
          if (!usingBackup) _markPrimaryDown();
          continue;
        }
        throw lastError;
      } on SocketException {
        lastError = _offline;
        if (!isLast) {
          if (!usingBackup) _markPrimaryDown();
          continue;
        }
        throw lastError;
      } on http.ClientException {
        lastError = _offline;
        if (!isLast) {
          if (!usingBackup) _markPrimaryDown();
          continue;
        }
        throw lastError;
      }
    }
    if (res == null) throw lastError ?? _offline;

    if (res.statusCode == 401 && !isRetry) {
      return _send(method, path, query: query, body: body, isRetry: true);
    }

    Map<String, dynamic> json = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // Non-JSON body (e.g. proxy error page): handled by status below.
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Our API always answers with a JSON object. Anything else on a 2xx
      // (a hosting placeholder, a proxy page) means this isn't our server.
      if (res.body.trim().isNotEmpty &&
          json.isEmpty &&
          !res.body.trim().startsWith('{')) {
        throw const AppException(
          'The server sent an unexpected reply. Please try again soon.',
          code: 'bad_gateway',
          retryable: true,
        );
      }
      return ApiResponse(json['data'], json['nextCursor'] as String?);
    }
    throw _mapError(res.statusCode, json);
  }

  // Covers a dead network but also a server that refuses or cannot be found,
  // so don't claim the user's internet is down.
  static const _offline = AppException(
    'Couldn\'t reach Nomad Mingle. Check your connection and try again.',
    code: 'offline',
    retryable: true,
  );

  Future<http.Response> _attempt(
    String method,
    String base,
    String path,
    String token, {
    Map<String, dynamic>? query,
    Object? body,
    required Duration wait,
  }) async {
    final uri = Uri.parse('$base$path').replace(
      queryParameters: query == null
          ? null
          : {
              for (final e in query.entries)
                if (e.value != null) e.key: '${e.value}',
            },
    );
    final req = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    return http.Response.fromStream(await _client.send(req).timeout(wait));
  }

  /// True for gateway errors and for replies that aren't from our API at all
  /// (our API always answers with a JSON object).
  bool _looksDown(http.Response r) {
    if (r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504) {
      return true;
    }
    try {
      return jsonDecode(r.body) is! Map;
    } on FormatException {
      return true;
    }
  }

  void _markPrimaryDown() => _primaryDownUntil = _clock().add(stickyFor);

  AppException _mapError(int status, Map<String, dynamic> json) {
    final err = (json['error'] as Map?)?.cast<String, dynamic>();
    final code = err?['code'] as String?;
    final serverMessage = err?['message'] as String?;
    final details = err?['details'];
    final retryAfter = details is Map
        ? (details['retryAfterSeconds'] as num?)?.toInt()
        : null;
    final reason = details is Map ? details['reason'] as String? : null;
    switch (code) {
      case 'validation_failed':
        return AppException(
          _validationMessage(details) ??
              serverMessage ??
              'Please check what you entered.',
          code: code,
        );
      case 'rate_limited':
        return AppException(
          serverMessage ?? 'You\'re doing that too fast. Please wait a bit.',
          code: code,
          retryable: true,
          retryAfterSeconds: retryAfter,
          reason: reason,
        );
      case 'account_restricted':
        return AppException(
          serverMessage ?? 'Your account is restricted from doing that.',
          code: code,
          reason: reason,
        );
      case 'unauthenticated':
        return const AppException(
          'Your session expired. Please sign in again.',
          code: 'unauthenticated',
        );
    }
    if (status >= 500) {
      return const AppException(
        'Something went wrong on our side. Try again soon.',
        code: 'internal',
        retryable: true,
      );
    }
    return AppException(
      serverMessage ?? 'Request failed.',
      code: code ?? '$status',
      reason: reason,
    );
  }
}

/// Turns the server's `details: [{path, message}]` into one readable line, so
/// "Validation failed" says which field to fix. An "Unrecognized key" means the
/// app sent a field this server version doesn't know (e.g. the server has not
/// been redeployed yet).
String? _validationMessage(Object? details) {
  if (details is! List || details.isEmpty) return null;
  final first = details.first;
  if (first is! Map) return null;
  final path = (first['path'] as String? ?? '').trim();
  final msg = (first['message'] as String? ?? '').trim();
  if (msg.isEmpty) return null;
  if (msg.toLowerCase().contains('unrecognized key')) {
    return 'The server doesn\'t recognise something this app sent ($msg). '
        'The server may need updating.';
  }
  const labels = {
    'displayName': 'Name',
    'dateOfBirth': 'Birthday',
    'city': 'City',
    'bio': 'Bio',
    'interests': 'Interests',
    'preferredActivityTypes': 'Preferences',
    'instagram': 'Instagram',
    'countryCode': 'Country',
    'gender': 'Gender',
    'photoUrl': 'Photo',
    'photos': 'Photos',
  };
  final label = labels[path.split('.').first];
  return label == null ? msg : '$label: $msg';
}

class ApiResponse {
  const ApiResponse(this.data, this.nextCursor);
  final Object? data;
  final String? nextCursor;

  Map<String, dynamic> get asMap => (data as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> get asList =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
}
