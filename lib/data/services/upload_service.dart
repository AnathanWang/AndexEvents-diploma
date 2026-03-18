import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/image_utils.dart';
import '../../core/services/logger_service.dart';

/// Сервис для загрузки файлов через Go upload-service
class ProgressUploadService {
  final FirebaseAuth _auth;

  ProgressUploadService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Загрузить фото события
  Future<String> uploadEventPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    return _uploadFile(
      filePath: filePath,
      bucket: 'events',
      maxSizeMB: 10,
      onProgress: onProgress,
    );
  }

  /// Загрузить дополнительное фото профиля
  Future<String> uploadAdditionalPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    return _uploadFile(
      filePath: filePath,
      bucket: 'photos',
      maxSizeMB: 5,
      onProgress: onProgress,
    );
  }

  /// Удалить фото с бэкенда
  Future<void> deletePhoto(String photoUrl) async {
    try {
      LoggerService.info('[ProgressUploadService] Удаляем фото: $photoUrl');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      final token = await user.getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      final url = Uri.parse(
        '${AppConfig.baseUrl}/upload?bucket=photos&url=${Uri.encodeComponent(photoUrl)}',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        LoggerService.info('[ProgressUploadService] Фото удалено');
      } else {
        LoggerService.error('[ProgressUploadService] Ошибка удаления: ${response.statusCode}');
        throw Exception('Ошибка удаления фото: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('[ProgressUploadService] Ошибка при удалении фото', e);
      rethrow;
    }
  }

  Future<String> _uploadFile({
    required String filePath,
    required String bucket,
    required double maxSizeMB,
    Function(double)? onProgress,
  }) async {
    try {
      LoggerService.info('[ProgressUploadService] Начинаем загрузку ($bucket)...');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Сжимаем изображение
      LoggerService.info('[ProgressUploadService] Сжимаем изображение...');
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(originalFile);

      // Проверяем размер
      final fileSize = await compressedFile.length();
      if (fileSize > maxSizeMB * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. ${maxSizeMB}MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)',
        );
      }

      // Получаем ID token
      final token = await user.getIdToken();
      if (token == null) {
        throw Exception('Не удалось получить токен авторизации');
      }

      // URL
      final url = Uri.parse('${AppConfig.baseUrl}/upload?bucket=$bucket');
      LoggerService.info('[ProgressUploadService] Uploading to $url');

      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Определение MIME типа
      final mimeType = lookupMimeType(compressedFile.path) ?? 'image/jpeg';
      final mimeTypeData = mimeType.split('/');

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          compressedFile.path,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        ),
      );

      // Если нужна поддержка прогресса, можно использовать StreamedRequest или специальный клиент,
      // но стандартный http.MultipartRequest не дает прогресс отправки из коробки.
      // Для упрощения пока имитируем прогресс 0 -> 1.
      onProgress?.call(0.1);

      final streamedResponse = await request.send();
      onProgress?.call(0.8);

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        onProgress?.call(1.0);
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['fileUrl'] != null) {
          final fileUrl = data['fileUrl'];
          LoggerService.info('[ProgressUploadService] Файл загружен: $fileUrl');
          return fileUrl;
        } else {
          throw Exception(data['message'] ?? 'Неизвестная ошибка сервера');
        }
      } else {
        LoggerService.error('[ProgressUploadService] Server Error: ${response.statusCode} ${response.body}');
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('[ProgressUploadService] Ошибка', e);
      rethrow;
    }
  }

  /// Очистить ресурсы
  Future<void> dispose() async {
    // Ничего не нужно очищать в этой версии
  }
}
