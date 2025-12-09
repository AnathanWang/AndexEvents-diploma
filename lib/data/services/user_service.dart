import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../models/user_model.dart';

/// Сервис для работы с профилем пользователя
class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  /// Загрузить фото в Supabase Storage
  Future<String> uploadProfilePhoto(File photoFile) async {
    try {
      print('🔵 [Supabase] Начинаем загрузку фото...');
      
      // Получаем текущего пользователя и сессию
      final user = _supabase.auth.currentUser;
      final session = _supabase.auth.currentSession;
      
      if (user == null || session == null) {
        print('🔴 [Supabase] Нет активного пользователя или сессии');
        throw Exception('Пользователь не авторизован');
      }

      print('🔵 [Supabase] User ID: ${user.id}');
      print('🔵 [Supabase] User email: ${user.email}');
      print('🔵 [Supabase] Token (первые 50 символов): ${session.accessToken.substring(0, 50)}...');
      print('🔵 [Supabase] Token role: ${session.user.role}');

      // Проверяем файл
      if (!await photoFile.exists()) {
        throw Exception('Файл не найден');
      }

      final fileExt = photoFile.path.split('.').last.toLowerCase();
      final fileName = 'avatar.$fileExt';
      final filePath = '${user.id}/$fileName';
      
      print('🔵 [Supabase] Bucket: avatars');
      print('🔵 [Supabase] Path: $filePath');
      print('🔵 [Supabase] Content-Type: image/$fileExt');
      print('🔵 [Supabase] File exists: ${await photoFile.exists()}');
      print('🔵 [Supabase] File size: ${await photoFile.length()} bytes');

      // Используем прямой HTTP запрос к Supabase Storage API (обходим SDK)
      try {
        print('🔵 [Supabase] Используем прямой HTTP POST к Storage API...');
        print('🔵 [Supabase] Начало: ${DateTime.now()}');
        
        final bytes = await photoFile.readAsBytes();
        final url = '${AppConfig.supabaseUrl}/storage/v1/object/avatars/$filePath';
        
        print('🔵 [Supabase] URL: $url');
        print('🔵 [Supabase] Отправляем ${bytes.length} bytes...');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'image/$fileExt',
            'x-upsert': 'true',
          },
          body: bytes,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('🔴 [Supabase] HTTP timeout после 30 секунд');
            throw TimeoutException('HTTP request timeout');
          },
        );

        print('🟢 [Supabase] Конец: ${DateTime.now()}');
        print('🟢 [Supabase] HTTP Status: ${response.statusCode}');
        print('🟢 [Supabase] Response body: ${response.body}');
        
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
        }

        // Получаем публичный URL
        final publicUrl = _supabase.storage
            .from('avatars')
            .getPublicUrl(filePath);

        // Валидация URL
        if (!publicUrl.startsWith('https://')) {
          throw Exception('Некорректный URL: $publicUrl');
        }
        
        // Проверяем на двойные слэши (кроме https://)
        final cleanUrl = publicUrl.replaceFirst('https://', '').replaceAll('//', '/');
        final finalUrl = 'https://$cleanUrl';
        
        print('🟢 [Supabase] Public URL: $finalUrl');
        print('🟢 [Supabase] URL валиден: ${Uri.tryParse(finalUrl) != null}');
        
        return finalUrl;

      } on StorageException catch (e) {
        print('🔴 [Supabase] StorageException:');
        print('   Message: ${e.message}');
        print('   Status: ${e.statusCode}');
        print('   Error: ${e.error}');
        
        if (e.statusCode == '404') {
          throw Exception('Bucket "avatars" не найден');
        } else if (e.statusCode == '403') {
          throw Exception('Нет прав доступа. Проверьте RLS политики для user ${user.id}');
        } else if (e.statusCode == '401') {
          throw Exception('Не авторизован. Проверьте токен');
        } else {
          throw Exception('Storage error (${e.statusCode}): ${e.message}');
        }
      } on TimeoutException catch (e) {
        print('🔴 [Supabase] TimeoutException после ${e.duration?.inSeconds ?? "?"} секунд');
        print('🔴 [Supabase] Это проблема симулятора iOS. На реальном устройстве должно работать.');
        throw Exception('Timeout. Попробуйте: 1) Меньший файл 2) Реальное устройство 3) Другую WiFi сеть');
      }
    } catch (e, stackTrace) {
      print('🔴 [Supabase] Неожиданная ошибка: $e');
      print('🔴 [Supabase] Тип ошибки: ${e.runtimeType}');
      print('🔴 [Supabase] Stack trace: $stackTrace');
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
      );
      
      print('DEBUG: Ответ статус: ${response.statusCode}');
      print('DEBUG: Ответ body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления профиля');
      }
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
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Ошибка обновления локации');
      }
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
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Не удалось получить профиль');
      }
    } catch (e) {
      throw Exception('Ошибка получения профиля: $e');
    }
  }
}
