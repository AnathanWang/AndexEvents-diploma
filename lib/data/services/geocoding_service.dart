import 'package:dio/dio.dart';
import '../../config/map_config.dart';
import '../../core/services/logger_service.dart';

class GeocodingResult {
  final String address;
  final double latitude;
  final double longitude;

  GeocodingResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

/// Сервис для работы с Yandex Geocoding API через HTTP
class GeocodingService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://geocode-maps.yandex.ru/1.x/';

  /// Checks if the Yandex API key is configured
  bool get _hasApiKey => MapConfig.yandexApiKey.isNotEmpty || MapConfig.yandexMapKitApiKey.isNotEmpty;

  /// Gets the best available API key
  String get _apiKey => MapConfig.yandexApiKey.isNotEmpty 
      ? MapConfig.yandexApiKey 
      : MapConfig.yandexMapKitApiKey;

  /// Получить адрес по координатам (reverse geocoding)
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    if (!_hasApiKey) {
      LoggerService.warning('[GeocodingService] Yandex API key not configured (YANDEX_API_KEY or YANDEX_MAPKIT_API_KEY)');
      return null;
    }
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'apikey': _apiKey,
          'geocode': '$longitude,$latitude', // Yandex ожидает "lon,lat"
          'format': 'json',
          'lang': 'ru_RU',
          'results': 1,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final featureMember = data['response']['GeoObjectCollection']['featureMember'] as List;
        
        if (featureMember.isNotEmpty) {
          final geoObject = featureMember.first['GeoObject'];
          final name = geoObject['name'];
          final description = geoObject['description'];
          
          // Формируем полный адрес
          if (description != null) {
            return '$description, $name';
          }
          return name;
        }
      }
      return null;
    } catch (e) {
      LoggerService.error('[GeocodingService] Reverse geocoding error', e);
      return null;
    }
  }

  /// Поиск адресов (forward geocoding)
  Future<List<GeocodingResult>> searchAddresses(String query) async {
    if (query.isEmpty) return [];
    if (!_hasApiKey) {
      LoggerService.warning('[GeocodingService] Yandex API key not configured (YANDEX_API_KEY or YANDEX_MAPKIT_API_KEY)');
      return [];
    }

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'apikey': _apiKey,
          'geocode': query,
          'format': 'json',
          'lang': 'ru_RU',
          'results': 10,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final featureMember = data['response']['GeoObjectCollection']['featureMember'] as List;
        
        return featureMember.map((item) {
          final geoObject = item['GeoObject'];
          final point = geoObject['Point']['pos'].toString().split(' ');
          final lon = double.parse(point[0]);
          final lat = double.parse(point[1]);
          
          return GeocodingResult(
            address: geoObject['metaDataProperty']['GeocoderMetaData']['text'],
            latitude: lat,
            longitude: lon,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      LoggerService.error('[GeocodingService] Search error', e);
      return [];
    }
  }
}
