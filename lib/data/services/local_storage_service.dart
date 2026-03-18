import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../../core/utils/image_utils.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/id_token_provider.dart';
import '../../core/services/logger_service.dart';

/// Сервис загрузки фото на бэкенд
class LocalStorageService {
  /// Получить MIME type файла (для iOS совместимости)
  static String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        // Пробуем определить автоматически
        return lookupMimeType(filePath) ?? 'image/jpeg';
    }
  }
  static final LocalStorageService _instance = LocalStorageService._internal();
  final IdTokenProvider _idTokenProvider = const IdTokenProvider();

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  static String _normalizeUploadUrl(String rawUrl) {
    try {
      final uploadUri = Uri.parse(rawUrl);
      final host = uploadUri.host.toLowerCase();
      final isLoopbackHost =
          host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

      if (!isLoopbackHost) {
        return rawUrl;
      }

      final apiUri = Uri.parse(AppConfig.baseUrl);
      if (apiUri.host.isEmpty) {
        return rawUrl;
      }

      return uploadUri
          .replace(
            scheme: apiUri.scheme.isEmpty ? 'http' : apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
          )
          .toString();
    } catch (_) {
      return rawUrl;
    }
  }

  /// Загрузить фото события на бэкенд
  Future<String> uploadEventPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    return _uploadFile(
      filePath,
      bucket: 'events',
      fileDescription: 'фото события',
      maxSizeBytes: 10 * 1024 * 1024,
      onProgress: onProgress,
    );
  }

  /// Загрузить фото профиля на бэкенд
  Future<String> uploadProfilePhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    return _uploadFile(
      filePath,
      bucket: 'avatars',
      fileDescription: 'фото профиля',
      maxSizeBytes: 5 * 1024 * 1024,
      onProgress: onProgress,
    );
  }

  /// Загрузить дополнительное фото профиля на бэкенд
  Future<String> uploadAdditionalPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    return _uploadFile(
      filePath,
      bucket: 'photos',
      fileDescription: 'дополнительное фото профиля',
      maxSizeBytes: 5 * 1024 * 1024,
      onProgress: onProgress,
    );
  }

  Future<String> uploadCoverPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    return _uploadFile(
      filePath,
      // Upload-service currently allows only avatars/events/photos buckets.
      bucket: 'photos',
      fileDescription: 'обложка профиля',
      maxSizeBytes: 6 * 1024 * 1024,
      onProgress: onProgress,
    );
  }

  /// Удалить дополнительное фото профиля на бэкенде
  Future<void> deletePhoto(String photoUrl) async {
    try {
      final token = await _idTokenProvider.getIdToken();
      if (token == null) {
        throw Exception('Пользователь не авторизован');
      }

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/upload?bucket=photos&url=${Uri.encodeComponent(photoUrl)}',
      );

      final response = await http.delete(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        LoggerService.error('[UploadService] Ошибка удаления фото: ${response.statusCode}');
        throw Exception('Ошибка удаления фото: ${response.statusCode}');
      }
    } catch (e) {
      LoggerService.error('[UploadService] Ошибка при удалении фото: $e');
      rethrow;
    }
  }

  Future<String> _uploadFile(
    String filePath, {
    required String bucket,
    required String fileDescription,
    required int maxSizeBytes,
    Function(double)? onProgress,
  }) async {
    try {
      LoggerService.info('[UploadService] Начинаем загрузку $fileDescription на бэкенд...');

      // Сжимаем изображение
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(originalFile);

      final fileSize = await compressedFile.length();
      if (fileSize > maxSizeBytes) {
        throw Exception(
          'Файл слишком большой (макс. ${maxSizeBytes / 1024 / 1024}MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)',
        );
      }

      // Получаем токен доступа
      final token = await _idTokenProvider.getIdToken();
      if (token == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Создаем multipart request с указанием бакета
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/upload?bucket=$bucket'),
      );

      // Добавляем токен авторизации
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем файл с явным MIME type для iOS совместимости
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          compressedFile.path,
          contentType: MediaType.parse(_getMimeType(compressedFile.path)),
        ),
      );

      onProgress?.call(0.5);
      LoggerService.info('[UploadService] Отправляем файл на сервер...');

      // Отправляем запрос
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      onProgress?.call(1.0);

      if (response.statusCode != 200) {
        LoggerService.error('[UploadService] Ошибка сервера: ${response.statusCode}');
        LoggerService.debug('[UploadService] Ответ: $responseBody');
        throw Exception('Ошибка загрузки на сервер: ${response.statusCode}');
      }

      // Парсим ответ
      final Map<String, dynamic> jsonResponse = _parseJson(responseBody);
      final fileUrl = jsonResponse['fileUrl'] as String?;

      if (fileUrl == null) {
        throw Exception('Сервер не вернул URL файла');
      }

      final normalizedUrl = _normalizeUploadUrl(fileUrl);
      LoggerService.info('[UploadService] $fileDescription успешно загружено: $normalizedUrl');
      return normalizedUrl;
    } catch (e) {
      LoggerService.error('[UploadService] Ошибка при загрузке $fileDescription: $e');
      rethrow;
    }
  }

  /// Парсинг JSON ответа сервера
  Map<String, dynamic> _parseJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      LoggerService.error('[UploadService] Ошибка парсинга', e);
      throw Exception('Ошибка парсинга ответа сервера: $e');
    }
  }
}
