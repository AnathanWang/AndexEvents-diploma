import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/logger_service.dart';

/// Debug-mode NDJSON logger (session 5e70b9).
class AgentDebugLog {
  static const String _sessionId = '5e70b9';
  static const String _ingestId = '2b24162c-d5a5-4cbc-9c82-84bd65095461';

  static void log({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
  }) {
    final payload = <String, dynamic>{
      'sessionId': _sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? <String, dynamic>{},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    LoggerService.info(
      '[AgentDebug][$hypothesisId] $message ${data ?? ''}',
    );

    final hosts = <String>{
      '127.0.0.1',
      Uri.parse(AppConfig.baseUrl).host,
    };

    for (final host in hosts) {
      final uri = Uri.parse('http://$host:7331/ingest/$_ingestId');
      http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Debug-Session-Id': _sessionId,
            },
            body: json.encode(payload),
          )
          .catchError((_) => http.Response('', 500));
    }
  }
}
