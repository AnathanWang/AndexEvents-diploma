class AppConfig {
  // API Configuration
  // Для iOS симулятора: используем IP адрес машины вместо localhost
  // Для физического устройства/Android: может потребоваться другой адрес
  static const String baseUrl = 'http://192.168.1.147:3000/api';
  static const String apiVersion = 'v1';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://rykbewslbfxltmipyseg.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5a2Jld3NsYmZ4bHRtaXB5c2VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTM5NTUsImV4cCI6MjA3OTAyOTk1NX0.ps3cL3a1fOSG-JN8UQ1z0-WGA9nRTy8LI16nPFuQeJE';
  
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
