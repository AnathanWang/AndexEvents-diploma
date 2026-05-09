import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/auth/id_token_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/services/logger_service.dart';
import '../models/event_sanction_model.dart';

class EventSanctionService {
  static final EventSanctionService _instance = EventSanctionService._internal();
  final IdTokenProvider _idTokenProvider = const IdTokenProvider();

  factory EventSanctionService() {
    return _instance;
  }

  EventSanctionService._internal();

  Future<String?> _getIdToken() async {
    return _idTokenProvider.getIdToken();
  }

  String? _extractMessage(String body, {String? fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}
    return fallback;
  }

  Future<List<EventSanctionModel>> getActiveSanctions(String eventId) async {
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception('Пользователь не авторизован');

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/events/$eventId/sanctions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          _extractMessage(response.body, fallback: 'Ошибка загрузки санкций'),
        );
      }

      final data = jsonDecode(response.body);
      final List<dynamic> rows = (data['data'] ?? const <dynamic>[]) as List<dynamic>;
      return rows
          .map((e) => EventSanctionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw Exception('Таймаут при загрузке санкций');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[EventSanctionService] Ошибка загрузки санкций', e);
      rethrow;
    }
  }

  Future<EventSanctionModel> createSanction({
    required String eventId,
    required EventSanctionType type,
    required String reason,
    DateTime? expiresAt,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception('Пользователь не авторизован');

      final body = <String, dynamic>{
        'type': eventSanctionTypeToBackend(type),
        'reason': reason.trim(),
      };
      if (expiresAt != null) {
        body['expiresAt'] = expiresAt.toUtc().toIso8601String();
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/events/$eventId/sanctions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 201) {
        throw Exception(
          _extractMessage(response.body, fallback: 'Ошибка назначения санкции'),
        );
      }

      final data = jsonDecode(response.body);
      return EventSanctionModel.fromJson(data['data'] as Map<String, dynamic>);
    } on TimeoutException {
      throw Exception('Таймаут при назначении санкции');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[EventSanctionService] Ошибка назначения санкции', e);
      rethrow;
    }
  }

  Future<void> revokeSanction(String sanctionId) async {
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception('Пользователь не авторизован');

      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/events/sanctions/$sanctionId/revoke'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          _extractMessage(response.body, fallback: 'Ошибка отзыва санкции'),
        );
      }
    } on TimeoutException {
      throw Exception('Таймаут при отзыве санкции');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[EventSanctionService] Ошибка отзыва санкции', e);
      rethrow;
    }
  }
}

