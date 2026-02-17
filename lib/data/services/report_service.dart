import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:andexevents/data/models/report_model.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/id_token_provider.dart';
import '../../core/services/logger_service.dart';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  final IdTokenProvider _idTokenProvider = const IdTokenProvider();

  factory ReportService() {
    return _instance;
  }

  ReportService._internal();

  Future<String?> _getIdToken() async {
    return _idTokenProvider.getIdToken();
  }

  Future<void> submitReport({
    required String reporterId,
    String? targetUserId,
    String? targetEventId,
    required ReportReason reason,
    String? details,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Пользователь не авторизован');
      }

      final body = <String, dynamic>{
        'reporterId': reporterId,
        'reason': reason.toBackendValue,
      };
      if (targetUserId != null) body['targetUserId'] = targetUserId;
      if (targetEventId != null) body['targetEventId'] = targetEventId;
      if (details != null && details.isNotEmpty) body['details'] = details;

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/users/reports'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка отправки жалобы: ${response.statusCode}');
      }

      LoggerService.info('[ReportService] Жалоба успешно отправлена');
    } on TimeoutException {
      throw Exception('Таймаут при отправке жалобы');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[ReportService] Ошибка отправки жалобы', e);
      rethrow;
    }
  }

  /// Получить список жалоб (admin)
  Future<List<ReportModel>> getReports() async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Пользователь не авторизован');
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/reports'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> reportsJson = data['data'] ?? [];
        return reportsJson
            .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Ошибка загрузки жалоб: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Таймаут при загрузке жалоб');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[ReportService] Ошибка загрузки жалоб', e);
      rethrow;
    }
  }

  /// Разрешить жалобу (admin)
  Future<void> resolveReport(String reportId, String resolution) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('Пользователь не авторизован');
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/reports/$reportId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'resolution': resolution}),
          )
          .timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200) {
        throw Exception('Ошибка разрешения жалобы: ${response.statusCode}');
      }

      LoggerService.info('[ReportService] Жалоба $reportId разрешена: $resolution');
    } on TimeoutException {
      throw Exception('Таймаут при разрешении жалобы');
    } on SocketException catch (e) {
      throw Exception('Не удалось подключиться к API: ${e.message}');
    } catch (e) {
      LoggerService.error('[ReportService] Ошибка разрешения жалобы', e);
      rethrow;
    }
  }
}
