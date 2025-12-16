import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/image_utils.dart';

/// Сервис для загрузки файлов
class ProgressUploadService {
  final SupabaseClient _supabase;

  ProgressUploadService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Загрузить фото события
  Future<String> uploadEventPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('🔵 [ProgressUploadService] Начинаем загрузку фото события...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Сжимаем изображение перед загрузкой
      print('🔵 [ProgressUploadService] Сжимаем изображение...');
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(originalFile);

      // Проверяем размер файла
      final fileSize = await compressedFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. 10MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)',
        );
      }

      // Генерируем уникальный путь
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final path = 'events/$fileName';

      print('🔵 [ProgressUploadService] Загружаем на Supabase: $path');

      // Читаем файл в bytes
      final fileBytes = await compressedFile.readAsBytes();

      // Загружаем на Supabase Storage
      await _supabase.storage.from('events').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      print('🟢 [ProgressUploadService] Файл загружен успешно');

      // Получаем публичный URL
      final url = _supabase.storage.from('events').getPublicUrl(path);
      print('🟢 [ProgressUploadService] Фото события загружено: $url');
      onProgress?.call(1.0);

      return url;
    } catch (e) {
      print('🔴 [ProgressUploadService] Ошибка при загрузке фото события: $e');
      rethrow;
    }
  }

  /// Загрузить фото профиля
  Future<String> uploadProfilePhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('🔵 [ProgressUploadService] Начинаем загрузку фото профиля...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Сжимаем изображение перед загрузкой
      print('🔵 [ProgressUploadService] Сжимаем изображение...');
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(originalFile);

      // Проверяем размер файла
      final fileSize = await compressedFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. 5MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)',
        );
      }

      // Генерируем уникальный путь
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final path = 'avatars/$fileName';

      print('🔵 [ProgressUploadService] Загружаем на Supabase: $path');

      // Читаем файл в bytes
      final fileBytes = await compressedFile.readAsBytes();

      // Загружаем на Supabase Storage
      await _supabase.storage.from('avatars').uploadBinary(
        path,
        fileBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      print('🟢 [ProgressUploadService] Файл загружен успешно');

      // Получаем публичный URL
      final url = _supabase.storage.from('avatars').getPublicUrl(path);
      print('🟢 [ProgressUploadService] Фото профиля загружено: $url');
      onProgress?.call(1.0);

      return url;
    } catch (e) {
      print('🔴 [ProgressUploadService] Ошибка при загрузке фото профиля: $e');
      rethrow;
    }
  }

  /// Очистить ресурсы
  Future<void> dispose() async {
    // Ничего не нужно очищать в этой версии
  }
}
