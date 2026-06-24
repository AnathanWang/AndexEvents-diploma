import 'dart:convert';

import '../../core/auth/id_token_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/services/logger_service.dart';
import '../models/managed_participant_model.dart';
import '../models/user_preview_model.dart';
import '../models/waitlist_entry_model.dart';
import 'package:http/http.dart' as http;

class EventParticipantsManageService {
  final IdTokenProvider _idTokenProvider = const IdTokenProvider();

  Future<String> _getIdToken() async {
    final token = await _idTokenProvider.getIdToken();
    if (token == null) {
      throw Exception('Не удалось получить токен авторизации');
    }
    return token;
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg.trim();
        final err = decoded['error']?.toString();
        if (err != null && err.trim().isNotEmpty) return err.trim();
      }
    } catch (_) {}
    return body.trim().isEmpty ? 'Ошибка запроса' : body.trim();
  }

  Future<List<ManagedParticipantModel>> listManageParticipants(String eventId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/participants/manage');
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final list = (data['participants'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ManagedParticipantModel.fromJson)
        .toList();
    return list;
  }

  Future<void> kick(String eventId, String userId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/participants/$userId');
    final resp = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<void> setSelfCheckIn(String eventId, {required bool checkedIn}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/checkin/me');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'checkedIn': checkedIn}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      LoggerService.warning(
        '[EventParticipantsManageService] setSelfCheckIn failed: '
        'status=${resp.statusCode} uri=$uri body=${resp.body}',
      );
      throw Exception('${_extractMessage(resp.body)} (${resp.statusCode})');
    }
  }

  Future<void> setCheckIn(String eventId, String userId, {required bool checkedIn}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/checkin/$userId');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'checkedIn': checkedIn}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<void> banForEvent(String eventId, String userId, {String? reason}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/bans');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'userId': userId, 'reason': reason}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<void> unbanForEvent(String eventId, String userId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/bans/$userId');
    final resp = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<List<WaitlistEntryModel>> listWaitlist(String eventId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/waitlist');
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final list = (data['waitlist'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(WaitlistEntryModel.fromJson)
        .toList();
    return list;
  }

  Future<void> approveWaitlist(String eventId, String userId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/waitlist/$userId/approve');
    final resp = await http.put(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<void> rejectWaitlist(String eventId, String userId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/events/$eventId/waitlist/$userId/reject');
    final resp = await http.put(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<void> blockGlobally(String blockedUserId, {String? reason}) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/users/blocks');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'blockedUserId': blockedUserId, 'reason': reason}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }

  Future<List<UserPreviewModel>> listGlobalBlocked() async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/users/blocks');
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final list = (data['blocked'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(UserPreviewModel.fromJson)
        .toList();
    return list;
  }

  Future<void> unblockGlobally(String blockedUserId) async {
    final token = await _getIdToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/users/blocks/$blockedUserId');
    final resp = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_extractMessage(resp.body));
    }
  }
}

