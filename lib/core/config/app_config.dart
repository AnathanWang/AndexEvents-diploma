class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://localhost:3000/api';
  static const String apiVersion = 'v1';
  
  // Yandex Maps
  static const String yandexMapsApiKey = 'c1c767ce-7328-4c26-b263-8eba58f98c6a';
  
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
