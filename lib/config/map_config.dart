class MapConfig {
  // Do NOT hardcode real API keys in source code.
  // Provide them at build time via --dart-define or CI environment variables:
  //   flutter build ... --dart-define=YANDEX_MAPKIT_API_KEY=your_key --dart-define=YANDEX_API_KEY=your_key
  static const String yandexMapKitApiKey = String.fromEnvironment(
    'YANDEX_MAPKIT_API_KEY',
    defaultValue: '',
  );
  static const String yandexApiKey = String.fromEnvironment(
    'YANDEX_API_KEY',
    defaultValue: '',
  ); // Для Geocoding/Suggest API
}
