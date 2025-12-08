import 'package:dio/dio.dart';
import '../../config/map_config.dart';

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

  /// Получить адрес по координатам (reverse geocoding)
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'apikey': MapConfig.yandexApiKey,
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
      print('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Поиск адресов (forward geocoding)
  Future<List<GeocodingResult>> searchAddresses(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'apikey': MapConfig.yandexApiKey,
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
      print('Geocoding search error: $e');
      return [];
    }
  }
}
