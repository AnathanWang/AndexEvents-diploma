import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../../core/utils/image_utils.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/id_token_provider.dart';

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

  /// Загрузить фото события на бэкенд
  Future<String> uploadEventPhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('🔵 [UploadService] Начинаем загрузку фото события на бэкенд...');

      // Сжимаем изображение
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(originalFile);

      final fileSize = await compressedFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. 10MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)',
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
        Uri.parse('${AppConfig.baseUrl}/upload?bucket=events'),
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
      print('🔵 [UploadService] Отправляем файл на сервер...');

      // Отправляем запрос
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      onProgress?.call(1.0);

      if (response.statusCode != 200) {
        print('🔴 [UploadService] Ошибка сервера: ${response.statusCode}');
        print('🔴 [UploadService] Ответ: $responseBody');
        throw Exception('Ошибка загрузки на сервер: ${response.statusCode}');
      }

      // Парсим ответ
      final Map<String, dynamic> jsonResponse = _parseJson(responseBody);
      final fileUrl = jsonResponse['fileUrl'] as String?;

      if (fileUrl == null) {
        throw Exception('Сервер не вернул URL файла');
      }

      print('🟢 [UploadService] Фото события успешно загружено: $fileUrl');
      return fileUrl;
    } catch (e) {
      print('🔴 [UploadService] Ошибка при загрузке фото события: $e');
      rethrow;
    }
  }

  /// Загрузить фото профиля на бэкенд
  Future<String> uploadProfilePhoto(
    String filePath, {
    Function(double)? onProgress,
  }) async {
    try {
      print('🔵 [UploadService] Начинаем загрузку фото профиля на бэкенд...');

      // Сжимаем изображение
      final originalFile = File(filePath);
      final compressedFile = await ImageUtils.compressImage(originalFile);

      final fileSize = await compressedFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception(
          'Файл слишком большой (макс. 5MB, ваш файл ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)',
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
        Uri.parse('${AppConfig.baseUrl}/upload?bucket=avatars'),
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
      print('🔵 [UploadService] Отправляем файл на сервер...');

      // Отправляем запрос
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      onProgress?.call(1.0);

      if (response.statusCode != 200) {
        print('🔴 [UploadService] Ошибка сервера: ${response.statusCode}');
        print('🔴 [UploadService] Ответ: $responseBody');
        throw Exception('Ошибка загрузки на сервер: ${response.statusCode}');
      }

      // Парсим ответ
      final Map<String, dynamic> jsonResponse = _parseJson(responseBody);
      final fileUrl = jsonResponse['fileUrl'] as String?;

      if (fileUrl == null) {
        throw Exception('Сервер не вернул URL файла');
      }

      print('🟢 [UploadService] Фото профиля успешно загружено: $fileUrl');
      return fileUrl;
    } catch (e) {
      print('🔴 [UploadService] Ошибка при загрузке фото профиля: $e');
      rethrow;
    }
  }

  /// Простой парсер JSON
  Map<String, dynamic> _parseJson(String jsonString) {
    try {
      // Пытаемся вытянуть URL из ответа
      final urlMatch = RegExp(r'"fileUrl"\s*:\s*"([^"]+)"').firstMatch(jsonString);
      if (urlMatch != null) {
        return {'fileUrl': urlMatch.group(1)};
      }
      throw Exception('Ошибка парсинга ответа сервера');
    } catch (e) {
      print('🔴 [UploadService] Ошибка парсинга: $e');
      throw Exception('Ошибка парсинга ответа сервера: $e');
    }
  }
}
