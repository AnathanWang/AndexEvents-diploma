import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../auth/id_token_provider.dart';
import '../services/logger_service.dart';

/// Централизованный HTTP-клиент для API запросов.
///
/// Обеспечивает:
/// - Автоматическое добавление Authorization заголовка (Firebase ID Token)
/// - Retry с exponential backoff при 429 (Too Many Requests)
/// - Единый таймаут для всех запросов
/// - Централизованное логирование запросов и ответов
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final IdTokenProvider _idTokenProvider = const IdTokenProvider();

  factory ApiClient() => _instance;
  ApiClient._internal();

  String get _baseUrl => AppConfig.baseUrl;

  /// GET запрос к API.
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = await _buildHeaders(requireAuth: requireAuth);

    LoggerService.debug('[ApiClient] GET $uri');
    return _withRetry(() => http.get(uri, headers: headers).timeout(AppConfig.receiveTimeout));
  }

  /// POST запрос к API.
  Future<http.Response> post(
    String path, {
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    LoggerService.debug('[ApiClient] POST $uri');
    return _withRetry(
      () => http.post(uri, headers: headers, body: encodedBody).timeout(AppConfig.receiveTimeout),
    );
  }

  /// PUT запрос к API.
  Future<http.Response> put(
    String path, {
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    LoggerService.debug('[ApiClient] PUT $uri');
    return _withRetry(
      () => http.put(uri, headers: headers, body: encodedBody).timeout(AppConfig.receiveTimeout),
    );
  }

  /// DELETE запрос к API.
  Future<http.Response> delete(
    String path, {
    Object? body,
    bool requireAuth = true,
  }) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(requireAuth: requireAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    LoggerService.debug('[ApiClient] DELETE $uri');
    return _withRetry(
      () => http.delete(uri, headers: headers, body: encodedBody).timeout(AppConfig.receiveTimeout),
    );
  }

  /// Создать multipart запрос с авторизацией.
  Future<Map<String, String>> authHeaders() async {
    return _buildHeaders(requireAuth: true);
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final url = '$_baseUrl$path';
    final uri = Uri.parse(url);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  Future<Map<String, String>> _buildHeaders({required bool requireAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final token = await _idTokenProvider.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Retry с exponential backoff при 429 (Too Many Requests).
  Future<http.Response> _withRetry(
    Future<http.Response> Function() send, {
    int maxAttempts = 3,
  }) async {
    http.Response? lastResponse;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await send();
        lastResponse = response;

        LoggerService.debug(
          '[ApiClient] Response: ${response.statusCode} (attempt $attempt)',
        );

        if (response.statusCode != 429) {
          return response;
        }

        if (attempt == maxAttempts) {
          return response;
        }

        final retryAfterRaw =
            response.headers['retry-after'] ?? response.headers['Retry-After'];
        final retryAfterSeconds = int.tryParse((retryAfterRaw ?? '').trim());
        final baseDelayMs = 400 * (1 << (attempt - 1));
        final jitterMs = math.Random().nextInt(200);
        final delay = retryAfterSeconds != null
            ? Duration(seconds: retryAfterSeconds)
            : Duration(milliseconds: baseDelayMs + jitterMs);

        LoggerService.debug('[ApiClient] 429 — retry after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      } on TimeoutException {
        if (attempt == maxAttempts) {
          throw Exception(
            'Таймаут при запросе к API ($_baseUrl). '
            'Если вы на физическом устройстве, укажите IP через '
            '--dart-define=API_BASE_URL=http://<IP>/api',
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } on SocketException catch (e) {
        if (attempt == maxAttempts) {
          throw Exception(
            'Не удалось подключиться к API ($_baseUrl): ${e.message}. '
            'Проверьте что backend запущен и устройство в той же сети.',
          );
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    return lastResponse!;
  }
}
