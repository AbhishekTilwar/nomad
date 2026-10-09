import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/app_exception.dart';

/// Thin REST client for the Nomad Mingle API. Attaches a fresh Firebase ID
/// token to each request (the backend verifies it; nothing client-supplied is
/// trusted as identity) and maps the error envelope to [AppException].
class ApiClient {
  ApiClient({
    required this.tokenProvider,
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  /// Returns an ID token; when [forceRefresh] is true it must bypass the cache.
  final Future<String?> Function({bool forceRefresh}) tokenProvider;
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);
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
    final token = await tokenProvider(forceRefresh: isRetry);
    if (token == null) {
      throw const AppException(
        'Please sign in again.',
        code: 'unauthenticated',
      );
    }
    final uri = Uri.parse('$baseUrl$path').replace(
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

    http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(timeout),
      );
    } on TimeoutException {
      throw const AppException(
        'The server is taking too long to respond. Please try again.',
        code: 'timeout',
        retryable: true,
      );
    } on SocketException {
      throw const AppException(
        'No internet connection.',
        code: 'offline',
        retryable: true,
      );
    } on http.ClientException {
      throw const AppException(
        'Couldn\'t reach Nomad Mingle. Check your connection and try again.',
        code: 'offline',
        retryable: true,
      );
    }

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
      return ApiResponse(json['data'], json['nextCursor'] as String?);
    }
    throw _mapError(res.statusCode, json);
  }

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

class ApiResponse {
  const ApiResponse(this.data, this.nextCursor);
  final Object? data;
  final String? nextCursor;

  Map<String, dynamic> get asMap => (data as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> get asList =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
}
