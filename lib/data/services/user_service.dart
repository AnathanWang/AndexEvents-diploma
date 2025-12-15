import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../models/user_model.dart';
import 'local_storage_service.dart';

/// Сервис для работы с профилем пользователя
class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final LocalStorageService _storageService;

  UserService() {
    _storageService = LocalStorageService();
  }

  /// Получить Supabase Access Token для авторизованных запросов
  Future<String?> _getIdToken() async {
    // Ждём инициализации сессии с повторными попытками
    for (int attempt = 0; attempt < 10; attempt++) {
      final session = _supabase.auth.currentSession;
      if (session?.accessToken != null) {
        return session!.accessToken;
      }
      print('🟡 [UserService] Ожидание токена, попытка ${attempt + 1}/10...');
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Загрузить фото в локальное хранилище
  Future<String> uploadProfilePhoto(File photoFile) async {
    try {
      print('🔵 [UserService] Начинаем загрузку фото профиля...');
      
      final url = await _storageService.uploadProfilePhoto(
        photoFile.path,
        onProgress: (progress) {
          print('🔵 [UserService] Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      print('🟢 [UserService] Фото профиля успешно загружено: $url');
      return url;
    } catch (e) {
      print('🔴 [UserService] Ошибка при загрузке фото профиля: $e');
      rethrow;
    }
  }

  /// Обновить профиль пользователя
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? bio,
    int? age,
    String? gender,
    List<String>? interests,
    Map<String, String>? socialLinks,
    bool? isOnboardingCompleted,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');
      
      print('DEBUG: Token получен, длина: ${token.length}');
      print('DEBUG: Token начинается с: ${token.substring(0, 20)}...');

      final Map<String, dynamic> body = {};
      if (displayName != null) body['displayName'] = displayName;
      if (photoUrl != null) body['photoUrl'] = photoUrl;
      if (bio != null) body['bio'] = bio;
      if (age != null) body['age'] = age;
      if (gender != null) body['gender'] = gender;
      if (interests != null) body['interests'] = interests;
      if (socialLinks != null) body['socialLinks'] = socialLinks;
      if (isOnboardingCompleted != null) body['isOnboardingCompleted'] = isOnboardingCompleted;

      final url = '${AppConfig.baseUrl}/users/me';
      print('DEBUG: Отправка PUT запроса на: $url');
      print('DEBUG: Body: ${json.encode(body)}');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(AppConfig.receiveTimeout);
      
      print('DEBUG: Ответ статус: ${response.statusCode}');
      print('DEBUG: Ответ body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления профиля');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Если вы на физическом устройстве, укажите IP компьютера через '
        '--dart-define=API_BASE_URL=http://<IP>:3000/api',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}. '
        'Проверьте что backend запущен и устройство в той же сети.',
      );
    } catch (e) {
      throw Exception('Не удалось обновить профиль: $e');
    }
  }

  /// Обновить геолокацию пользователя
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/users/me/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(AppConfig.receiveTimeout);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления локации');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Проверьте доступность backend и правильность адреса.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      throw Exception('Не удалось обновить локацию: $e');
    }
  }

  /// Получить текущий профиль пользователя
  Future<UserModel> getCurrentUser() async {
    try {
      final String? token = await _getIdToken();
      if (token == null) throw Exception('Не удалось получить токен авторизации');

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Не удалось получить профиль');
      }
    } on TimeoutException {
      throw Exception(
        'Таймаут при запросе к API (${AppConfig.baseUrl}). '
        'Проверьте доступность backend и правильность адреса.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Не удалось подключиться к API (${AppConfig.baseUrl}): ${e.message}',
      );
    } catch (e) {
      throw Exception('Ошибка получения профиля: $e');
    }
  }
}
