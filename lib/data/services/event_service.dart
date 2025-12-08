import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../models/event_model.dart';
import '../models/participant_model.dart';

/// Сервис для работы с событиями
class EventService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Получить Firebase ID Token для авторизованных запросов
  Future<String?> _getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  /// Загрузить фото события в Supabase Storage
  Future<String> uploadEventPhoto(File photoFile) async {
    try {
      final firebase_auth.User? user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      if (!await photoFile.exists()) {
        throw Exception('Файл не существует');
      }

      final bytes = await photoFile.readAsBytes();
      final fileExt = photoFile.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Формируем имя файла: USERID_event_TIMESTAMP.ext
      final String fileName = '${user.uid}_event_$timestamp.$fileExt';
      
      // Нормализуем Content-Type (Supabase чувствителен к этому)
      String contentType = 'image/$fileExt';
      if (fileExt.toLowerCase() == 'jpg') contentType = 'image/jpeg';

      // Используем прямой HTTP запрос к Storage API для надежности
      // Это позволяет обойти проблемы с сессиями при использовании Firebase Auth
      final url = Uri.parse('${AppConfig.supabaseUrl}/storage/v1/object/events/$fileName');
      
      final response = await http.post(
        url,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': contentType,
          'x-upsert': 'false',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки (HTTP ${response.statusCode}): ${response.body}');
      }

      // Получаем публичный URL загруженного файла
      final String publicUrl = _supabase.storage.from('events').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error uploading event photo: $e');
      throw Exception('Не удалось загрузить фото: $e');
    }
  }

  /// Создать событие
  Future<EventModel> createEvent({
    required String title,
    required String description,
    required String category,
    required String location,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
    DateTime? endDateTime,
    required double price,
    String? imageUrl,
    required bool isOnline,
    int? maxParticipants,
    int? minAge,
    int? maxAge,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final Map<String, dynamic> body = {
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'dateTime': dateTime.toIso8601String(),
        'price': price,
        'isOnline': isOnline,
      };

      if (endDateTime != null) body['endDateTime'] = endDateTime.toIso8601String();
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (maxParticipants != null) body['maxParticipants'] = maxParticipants;
      if (minAge != null) body['minAge'] = minAge;
      if (maxAge != null) body['maxAge'] = maxAge;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка создания события');
      }

      final responseData = json.decode(response.body);
      return EventModel.fromJson(responseData['data']);
    } catch (e) {
      throw Exception('Ошибка создания события: $e');
    }
  }

  /// Получить список событий
  Future<List<EventModel>> getEvents({
    String? category,
    double? latitude,
    double? longitude,
    int? maxDistance,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final String? token = await _getIdToken();
      
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (maxDistance != null) queryParams['maxDistance'] = maxDistance.toString();

      final uri = Uri.parse('${AppConfig.baseUrl}/events').replace(queryParameters: queryParams);

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка загрузки событий');
      }

      final responseData = json.decode(response.body);
      final List<dynamic> eventsJson = responseData['data']['events'];
      
      return eventsJson.map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки событий: $e');
    }
  }

  /// Получить детали события
  Future<EventModel> getEventById(String eventId) async {
    try {
      final String? token = await _getIdToken();
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка загрузки события');
      }

      final responseData = json.decode(response.body);
      return EventModel.fromJson(responseData['data']);
    } catch (e) {
      throw Exception('Ошибка загрузки события: $e');
    }
  }

  /// Участвовать в событии
  Future<void> participateInEvent(String eventId, String status) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId/participate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': status}), // INTERESTED или GOING
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка участия в событии');
      }
    } catch (e) {
      throw Exception('Ошибка участия в событии: $e');
    }
  }

  /// Отменить участие в событии
  Future<void> cancelParticipation(String eventId) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId/participate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка отмены участия');
      }
    } catch (e) {
      throw Exception('Ошибка отмены участия: $e');
    }
  }

  /// Получить события пользователя
  Future<List<EventModel>> getUserEvents(String userId) async {
    try {
      final String? token = await _getIdToken();
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events/user/$userId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка загрузки событий пользователя');
      }

      final responseData = json.decode(response.body);
      final List<dynamic> eventsJson = responseData['data']['events'];
      
      return eventsJson.map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки событий пользователя: $e');
    }
  }

  /// Получить список участников события
  Future<List<ParticipantModel>> getEventParticipants(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId/participants'),
      );

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки участников события');
      }

      final responseData = json.decode(response.body);
      final List<dynamic> participantsJson = responseData['data'];
      
      return participantsJson.map((json) => ParticipantModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки участников: $e');
    }
  }
}
