import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/id_token_provider.dart';
import '../../core/services/logger_service.dart';
import '../models/event_model.dart';
import '../models/participant_model.dart';
import 'local_storage_service.dart';

/// Сервис для работы с событиями
class EventService {
  final IdTokenProvider _idTokenProvider = const IdTokenProvider();
  late final LocalStorageService _storageService;

  EventService() {
    _storageService = LocalStorageService();
  }

  Future<void> clearEventsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('events_cache_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      LoggerService.error('[EventService] Cache clear error', e);
    }
  }

  /// Загрузить фото события в локальное хранилище
  Future<String> uploadEventPhoto(File photoFile) async {
    try {
      final url = await _storageService.uploadEventPhoto(
        photoFile.path,
        onProgress: (progress) {
          // Прогресс загрузки обновляется в UI слое
        },
      );

      return url;
    } catch (e) {
      throw Exception('Не удалось загрузить фото события: $e');
    }
  }

  /// Получить Supabase Access Token для авторизованных запросов
  Future<String?> _getIdToken() async {
    return _idTokenProvider.getIdToken();
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
    List<String>? imageUrls,
    required bool isOnline,
    int? maxParticipants,
    int? minAge,
    int? maxAge,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final Map<String, dynamic> body = {
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'dateTime': dateTime.toUtc().toIso8601String(),
        'price': price,
        'isOnline': isOnline,
      };

      if (endDateTime != null) {
        body['endDateTime'] = endDateTime.toUtc().toIso8601String();
      }
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (imageUrls != null) body['imageUrls'] = imageUrls;
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
      ).timeout(AppConfig.receiveTimeout);

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
    bool writeCache = true,
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
      if (maxDistance != null) {
        queryParams['maxDistance'] = maxDistance.toString();
      }

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/events',
      ).replace(queryParameters: queryParams);

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      LoggerService.debug('[EventService] 🔹 Loading events: $uri');

      final response = await http.get(uri, headers: headers).timeout(AppConfig.receiveTimeout);

      LoggerService.debug('[EventService] 🔹 Response status: ${response.statusCode}');
      LoggerService.debug('[EventService] 🔹 Response body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка загрузки событий');
      }

      final responseData = json.decode(response.body);
      final List<dynamic> eventsJson = responseData['data']['events'];

      if (page == 1 && writeCache) {
        try {
          final String cacheKey = 'events_cache_${category ?? "all"}_page1';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, json.encode(eventsJson));
        } catch (cacheError) {
          LoggerService.error('[EventService] Cache write error', cacheError);
        }
      }

      return eventsJson.map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      LoggerService.error('[EventService] Ошибка загрузки событий из сети, пробуем кэш', e);
      if (page == 1) {
        final cached = await getCachedEvents(category: category);
        if (cached.isNotEmpty) {
          LoggerService.debug('[EventService] Возвращаем события из кэша');
          return cached;
        }
      }
      throw Exception('Ошибка загрузки событий: $e');
    }
  }

  /// Получить список событий для модерации (включая скрытые санкцией HIDE_VISIBILITY).
  /// Требует роль ADMIN/MODERATOR.
  Future<List<EventModel>> getEventsForModeration({int limit = 500}) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/events/moderation/all')
          .replace(queryParameters: {'limit': limit.toString()});

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.receiveTimeout);

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

  /// Получить события из локального кэша
  Future<List<EventModel>> getCachedEvents({String? category}) async {
    try {
      final String cacheKey = 'events_cache_${category ?? "all"}_page1';
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final List<dynamic> eventsJson = json.decode(cachedData);
        return eventsJson.map((json) => EventModel.fromJson(json)).toList();
      }
    } catch (e) {
      LoggerService.error('[EventService] Cache read error', e);
    }
    return [];
  }

  /// Получить детали события
  Future<EventModel> getEventById(String eventId) async {
    try {
      final String? token = await _getIdToken();

      final headers = <String, String>{'Content-Type': 'application/json'};
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
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

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
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

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

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events/user/$userId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Ошибка загрузки событий пользователя',
        );
      }

      final responseData = json.decode(response.body);
      final List<dynamic> eventsJson = responseData['data'];

      return eventsJson.map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки событий пользователя: $e');
    }
  }

  /// Получить события, в которых пользователь участвовал
  Future<List<EventModel>> getUserParticipatedEvents(String userId) async {
    try {
      final String? token = await _getIdToken();

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events/user/$userId/participated'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ??
              'Ошибка загрузки событий участия пользователя',
        );
      }

      final responseData = json.decode(response.body);
      final List<dynamic> eventsJson = responseData['data'];

      return eventsJson.map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки событий участия пользователя: $e');
    }
  }

  /// Получить список участников события
  Future<List<ParticipantModel>> getEventParticipants(String eventId) async {
    try {
      final String? token = await _getIdToken();

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events/$eventId/participants'),
        headers: headers,
      ).timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки участников события');
      }

      final responseData = json.decode(response.body);
      final List<dynamic> participantsJson = responseData['data'];

      return participantsJson
          .map((json) => ParticipantModel.fromJson(json))
          .toList();
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
    List<String>? imageUrls,
    bool? isOnline,
    int? maxParticipants,
    int? minAge,
    int? maxAge,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;
      if (location != null) body['location'] = location;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (dateTime != null) body['dateTime'] = dateTime.toUtc().toIso8601String();
      if (endDateTime != null) {
        body['endDateTime'] = endDateTime.toUtc().toIso8601String();
      }
      if (price != null) body['price'] = price;
      if (imageUrl != null) body['imageUrl'] = imageUrl;
      if (imageUrls != null) body['imageUrls'] = imageUrls;
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
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

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
}
