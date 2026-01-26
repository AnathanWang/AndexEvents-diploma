import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

enum FriendshipStatus {
  none,
  outgoingRequest,
  incomingRequest,
  friends,
}

FriendshipStatus friendshipStatusFromApi(String? value) {
  switch ((value ?? '').toUpperCase().trim()) {
    case 'FRIENDS':
      return FriendshipStatus.friends;
    case 'OUTGOING_REQUEST':
      return FriendshipStatus.outgoingRequest;
    case 'INCOMING_REQUEST':
      return FriendshipStatus.incomingRequest;
    case 'NONE':
    default:
      return FriendshipStatus.none;
  }
}

class FriendService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _getIdToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getIdToken();
    if (token == null) {
      throw Exception('Пользователь не авторизован');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<FriendshipStatus> getStatus(String otherUserId) async {
    try {
      final headers = await _headers();

      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/friends/status/$otherUserId'),
            headers: headers,
          )
          .timeout(AppConfig.receiveTimeout);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Ошибка получения статуса дружбы');
      }

      final data = body['data'] as Map<String, dynamic>;
      return friendshipStatusFromApi(data['status'] as String?);
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Если вы на физическом устройстве, задайте API_BASE_URL через --dart-define.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    }
  }

  Future<FriendshipStatus> sendRequest(String otherUserId) async {
    final headers = await _headers();

    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/friends/requests/$otherUserId'),
          headers: headers,
        )
        .timeout(AppConfig.receiveTimeout);

    final body = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Ошибка отправки запроса в друзья');
    }

    final data = body['data'] as Map<String, dynamic>;
    final status = data['status'] as String?;
    return friendshipStatusFromApi(status);
  }

  Future<FriendshipStatus> cancelRequest(String otherUserId) async {
    final headers = await _headers();

    final response = await http
        .delete(
          Uri.parse('${AppConfig.baseUrl}/friends/requests/$otherUserId'),
          headers: headers,
        )
        .timeout(AppConfig.receiveTimeout);

    final body = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Ошибка отмены запроса');
    }

    final data = body['data'] as Map<String, dynamic>;
    return friendshipStatusFromApi(data['status'] as String?);
  }

  Future<FriendshipStatus> acceptRequest(String requesterUserId) async {
    final headers = await _headers();

    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/friends/requests/$requesterUserId/accept'),
          headers: headers,
        )
        .timeout(AppConfig.receiveTimeout);

    final body = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Ошибка принятия запроса');
    }

    final data = body['data'] as Map<String, dynamic>;
    return friendshipStatusFromApi(data['status'] as String?);
  }

  Future<FriendshipStatus> declineRequest(String requesterUserId) async {
    final headers = await _headers();

    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/friends/requests/$requesterUserId/decline'),
          headers: headers,
        )
        .timeout(AppConfig.receiveTimeout);

    final body = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Ошибка отклонения запроса');
    }

    final data = body['data'] as Map<String, dynamic>;
    return friendshipStatusFromApi(data['status'] as String?);
  }
}
