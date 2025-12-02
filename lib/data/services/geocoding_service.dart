import 'package:yandex_geocoder/yandex_geocoder.dart';
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

/// Сервис для работы с Yandex Geocoding API
class GeocodingService {
  final YandexGeocoder _geocoder = YandexGeocoder(apiKey: MapConfig.yandexApiKey);
  
  /// Получить координаты по адресу (не используется пока)
  Future<GeocodingResult?> getCoordinatesFromAddress(String address) async {
    // TODO: Implement after fixing API issues
    return null;
  }

  /// Получить адрес по координатам (reverse geocoding)
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final response = await _geocoder.getGeocode(ReverseGeocodeRequest(
        pointGeocode: (lat: latitude, lon: longitude),
        lang: Lang.enEn,
      ));

      return response.firstAddress?.formatted;
    } catch (e) {
      print('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Поиск адресов - временно отключен
  Future<List<GeocodingResult>> searchAddresses(String query) async {
    // TODO: Implement after fixing API issues
    return [];
  }
}
