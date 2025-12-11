import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/utils/image_utils.dart';
import '../models/user_model.dart';

/// Сервис для работы с профилем пользователя
class UserService {
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
      print('🔵 [UserService] Начинаем загрузку фото профиля...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('🔴 [UserService] Нет активного пользователя');
        throw Exception('Пользователь не авторизован');
      }

      if (!await photoFile.exists()) {
        throw Exception('Файл не найден');
      }

      // Сжимаем изображение перед загрузкой
      print('🔵 [UserService] Сжимаем изображение...');
      var compressedFile = await ImageUtils.compressImage(photoFile);

      final fileSize = await compressedFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        // 5MB limit
        throw Exception('Файл слишком большой (макс. 5MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)');
      }

      final fileExt = compressedFile.path.split('.').last.toLowerCase();
      final fileName = 'avatar.$fileExt';
      final filePath = '${user.id}/$fileName';
      
      print('🔵 [UserService] User ID: ${user.id}');
      print('🔵 [UserService] Path: $filePath');
      print('🔵 [UserService] File size: ${(fileSize / 1024).toStringAsFixed(2)}KB');

      // Загружаем через SDK
      print('🔵 [UserService] Загружаем через SDK...');
      
      await _supabase.storage.from('avatars').upload(
        filePath,
        compressedFile,
        fileOptions: FileOptions(
          cacheControl: '3600',
          contentType: _inferImageContentType(fileExt),
          upsert: true,
        ),
      ).timeout(AppConfig.receiveTimeout);

      print('🟢 [UserService] Upload successful!');
      
      // Получаем публичный URL
      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      
      print('🟢 [UserService] Public URL: $publicUrl');
      
      return publicUrl;

    } on StorageException catch (e) {
      print('🔴 [UserService] StorageException: ${e.message} (${e.statusCode})');
      
      String errorMessage = e.message;
      if (e.statusCode == '403') {
        errorMessage = 'Нет прав доступа. Проверьте RLS политики в Supabase Dashboard';
      } else if (e.statusCode == '404') {
        errorMessage = 'Bucket "avatars" не найден. Проверьте Storage в Dashboard';
      } else if (e.statusCode == '413') {
        errorMessage = 'Файл слишком большой';
      }
      
      throw Exception('Storage error: $errorMessage');
    } on TimeoutException {
      throw Exception(
        'Таймаут при загрузке фото в Supabase Storage. '
        'Проверьте интернет/ВПН и повторите попытку.',
      );
    } catch (e) {
      print('🔴 [UserService] Ошибка: $e');
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
