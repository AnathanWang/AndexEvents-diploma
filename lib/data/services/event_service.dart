import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/image_utils.dart';
import '../models/event_model.dart';
import '../models/participant_model.dart';

/// Сервис для работы с событиями
class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _inferImageContentType(String fileExt) {
    switch (fileExt.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  /// Получить Supabase Access Token для авторизованных запросов
  Future<String?> _getIdToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Загрузить фото события через Supabase Storage
  Future<String> uploadEventPhoto(File photoFile) async {
    try {
      print('🔵 [EventService] Начинаем загрузку фото события...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('🔴 [EventService] Нет активного пользователя');
        throw Exception('Пользователь не авторизован');
      }

      final session = _supabase.auth.currentSession;
      print('🔵 [EventService] Session accessToken: ${session?.accessToken != null ? "present" : "null"}');

      if (!await photoFile.exists()) {
        throw Exception('Файл не существует');
      }

      // Сжимаем изображение перед загрузкой
      print('🔵 [EventService] Сжимаем изображение...');
      var compressedFile = await ImageUtils.compressImage(photoFile);

      final fileSize = await compressedFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        // 10MB limit for events (больше чем для аватаров)
        throw Exception('Файл слишком большой (макс. 10MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)');
      }

      final fileExt = compressedFile.path.split('.').last.toLowerCase();
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      print('🔵 [EventService] User ID: ${user.id}');
      print('🔵 [EventService] File path: $fileName');
      print('🔵 [EventService] File size: ${(fileSize / 1024).toStringAsFixed(2)}KB');

      // Быстрый preflight: проверяем доступ к bucket (помогает отличить RLS/доступ от зависаний upload)
      try {
        final listed = await _supabase.storage
            .from('events')
            .list(path: user.id)
            .timeout(const Duration(seconds: 10));
        print('🔵 [EventService] Preflight list ok, files in folder: ${listed.length}');
      } catch (e) {
        print('🟡 [EventService] Preflight list failed: $e');
      }
      
      // Загружаем через SDK
      print('🔵 [EventService] Загружаем через SDK...');

      // На некоторых платформах upload(File) может зависать.
      // uploadBinary работает стабильнее для небольших изображений.
      final bytes = await compressedFile.readAsBytes().timeout(AppConfig.receiveTimeout);

      Future<void> doUpload() {
        return _supabase.storage.from('events').uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                contentType: _inferImageContentType(fileExt),
                upsert: true,
              ),
            );
      }

      try {
        await doUpload().timeout(AppConfig.receiveTimeout);
      } on TimeoutException {
        // Один ретрай на случай кратковременного залипания сети/SDK
        print('🟡 [EventService] Upload timeout, retrying once...');
        await Future.delayed(const Duration(seconds: 1));
        await doUpload().timeout(AppConfig.receiveTimeout);
      }

      print('🟢 [EventService] Upload successful!');

      // Get Public URL
      final String publicUrl = _supabase.storage.from('events').getPublicUrl(fileName).trim();
      
      print('🟢 [EventService] URL: $publicUrl');
      
      return publicUrl;

    } on StorageException catch (e) {
      print('🔴 [EventService] StorageException: ${e.message} (${e.statusCode})');
      
      String errorMessage = e.message;
      if (e.statusCode == '403') {
        errorMessage = 'Нет прав доступа. Проверьте RLS политики в Supabase Dashboard';
      } else if (e.statusCode == '404') {
        errorMessage = 'Bucket "events" не найден. Проверьте Storage в Dashboard';
      } else if (e.statusCode == '413') {
        errorMessage = 'Файл слишком большой';
      }
      
      throw Exception('Storage error: $errorMessage');
    } on TimeoutException {
      throw Exception(
        'Таймаут при загрузке фото события в Supabase Storage. '
        'Проверьте интернет/ВПН и повторите попытку.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Проблема сети при загрузке фото события: ${e.message}',
      );
    } catch (e) {
      print('🔴 [EventService] Ошибка: $e');
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
      final List<dynamic> eventsJson = responseData['data'];
      
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

  /// Обновить событие
  Future<EventModel> updateEvent({
    required String eventId,
    String? title,
    String? description,
    String? category,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? dateTime,
    DateTime? endDateTime,
    double? price,
    String? imageUrl,
    bool? isOnline,
    int? maxParticipants,
    int? minAge,
    int? maxAge,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;
      if (location != null) body['location'] = location;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (dateTime != null) body['dateTime'] = dateTime.toIso8601String();
      if (endDateTime != null) body['endDateTime'] = endDateTime.toIso8601String();
      if (price != null) body['price'] = price;
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (isOnline != null) body['isOnline'] = isOnline;
      if (maxParticipants != null) body['maxParticipants'] = maxParticipants;
      if (minAge != null) body['minAge'] = minAge;
      if (maxAge != null) body['maxAge'] = maxAge;

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления события');
      }

      final responseData = json.decode(response.body);
      return EventModel.fromJson(responseData['data']);
    } catch (e) {
      throw Exception('Ошибка обновления события: $e');
    }
  }

  /// Удалить событие
  Future<void> deleteEvent(String eventId) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка удаления события');
      }
    } catch (e) {
      throw Exception('Ошибка удаления события: $e');
    }
  }

  /// Загрузить изображение в Supabase Storage
  Future<String?> uploadImage(File imageFile, String bucketName, String fileName) async {
    try {
      final response = await _supabase.storage.from(bucketName).upload(fileName, imageFile);
      if (response.isEmpty) {
        throw Exception('Ошибка загрузки: пустой ответ от сервера');
      }
      // Получение публичного URL файла
      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Ошибка загрузки изображения: $e');
      return null;
    }
  }
}
