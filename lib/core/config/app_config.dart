import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration
  // Автоматическое определение адреса сервера
  static String get baseUrl {
    const String overrideBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    if (overrideBaseUrl.isNotEmpty) {
      return overrideBaseUrl;
    }

    if (kReleaseMode) {
      // Временно: release APK против Docker на Mac в локальной сети.
      // Пересборка: ./scripts/build-home-server-apk.sh
      // Домашний сервер: API_BASE_URL=http://andex.1rmx.ru:40080/api ./scripts/build-home-server-apk.sh
      return 'http://192.168.1.147/api';
    }

    if (kIsWeb) {
      // Web не поддерживает dart:io Platform; используем URL текущего хоста.
      final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return '$scheme://$host/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Для Android эмулятора
      return 'http://10.0.2.2/api';
    }

    // Для iOS симулятора и macOS
    // Если вы используете физическое устройство, замените localhost на IP вашего компьютера
    // Например: return 'http://192.168.1.147/api';
    return 'http://localhost/api';
  }

  /// Origin for uploaded media (`/uploads/...`), without the `/api` suffix.
  static String get uploadsOrigin {
    final apiUri = Uri.parse(baseUrl);
    return Uri(
      scheme: apiUri.scheme.isEmpty ? 'http' : apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    ).toString();
  }

  static const String apiVersion = 'v1';

  // Yandex Maps
  // Do NOT hardcode API keys. Provide at build time via --dart-define or CI env:
  //   flutter run/build ... --dart-define=YANDEX_MAPS_API_KEY=<your_key>
  static const String yandexMapsApiKey = String.fromEnvironment(
    'YANDEX_MAPS_API_KEY',
    defaultValue: '',
  );

  // Геолокация
  static const int defaultMaxDistance = 50000; // 50 км в метрах
  static const int minDistance = 100; // 100 м
  static const int maxDistance = 50000; // 50 км

  // События
  static const int eventsPerPage = 20;
  static const int hoursBeforeEventReminder = 24;
  static const int minutesBeforeEventReminder = 60;

  // Матчи
  static const int matchesPerPage = 10;

  // Таймауты
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Retry логика
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
