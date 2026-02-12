import 'dart:io';
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
      // TODO: Укажите адрес продакшн сервера
      return 'https://api.andexevents.com/api';
    }

    if (Platform.isAndroid) {
      // Для Android эмулятора
      return 'http://10.0.2.2/api';
    }

    // Для iOS симулятора и macOS
    // Если вы используете физическое устройство, замените localhost на IP вашего компьютера
    // Например: return 'http://192.168.1.147:3000/api';
    return 'http://localhost/api';
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
