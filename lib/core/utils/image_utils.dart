import 'dart:io';
import 'dart:async';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Утилита для работы с изображениями
class ImageUtils {
  /// Сжать изображение до нужного размера
  /// Возвращает новый File с сжатым изображением
  static Future<File> compressImage(
    File imageFile, {
    int quality = 70,
  }) async {
    try {
      print('🔵 [ImageUtils] Сжимаем изображение...');

      final originalSize = await imageFile.length();
      print('🔵 [ImageUtils] Исходный размер: ${(originalSize / 1024).toStringAsFixed(2)}KB');

      // Используем flutter_image_compress для сжатия
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        '${imageFile.absolute.path}_compressed.jpg',
        quality: quality,
        minWidth: 512,
        minHeight: 512,
        format: CompressFormat.jpeg,
      ).timeout(const Duration(seconds: 20));

      if (compressedFile == null) {
        print('🟡 [ImageUtils] Не удалось сжать изображение, используем оригинальное');
        return imageFile;
      }

      final file = File(compressedFile.path);
      final compressedSize = await file.length();
      final reduction = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);

      print('✅ [ImageUtils] Сжатие завершено');
      print('📊 [ImageUtils] Сжатый размер: ${(compressedSize / 1024).toStringAsFixed(2)}KB');
      print('📊 [ImageUtils] Сокращение: $reduction%');

      return file;
    } on TimeoutException {
      print('🟡 [ImageUtils] Таймаут при сжатии, используем оригинальное изображение');
      return imageFile;
    } catch (e) {
      print('🔴 [ImageUtils] Ошибка при сжатии: $e');
      // Если ошибка - возвращаем исходный файл
      return imageFile;
    }
  }

  /// Получить размер файла в MB
  static Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Проверить, является ли файл изображением
  static bool isImageFile(String filePath) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final ext = filePath.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }
}
