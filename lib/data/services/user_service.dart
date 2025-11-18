import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Сервис для работы с профилем пользователя
class UserService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Получить Firebase ID Token для авторизованных запросов
  Future<String?> _getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  /// Загрузить фото в Supabase Storage
  Future<String> uploadProfilePhoto(File photoFile) async {
    try {
      final firebase_auth.User? user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('Пользователь не авторизован');

      // Проверяем существование файла
      if (!await photoFile.exists()) {
        throw Exception('Файл не существует: ${photoFile.path}');
      }

      // Читаем файл
      final bytes = await photoFile.readAsBytes();
      final fileExt = photoFile.path.split('.').last;
      
      // Путь к файлу в Supabase Storage: avatars/{userId}/photo_1.{ext}
      final String filePath = '${user.uid}/photo_1.$fileExt';

      // Загружаем файл в Supabase Storage bucket 'avatars'
      await _supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$fileExt',
          upsert: true, // Перезаписываем если файл уже существует
        ),
      );

      // Получаем публичный URL
      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      throw Exception('Ошибка загрузки фото: $e');
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
  Future<Map<String, dynamic>> getCurrentUser() async {
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
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Не удалось получить профиль');
      }
    } catch (e) {
      throw Exception('Ошибка получения профиля: $e');
    }
  }
}
