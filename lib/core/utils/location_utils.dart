import 'package:geolocator/geolocator.dart';

/// Быстрое получение координат: сначала кэш GPS, затем свежий fix.
class LocationUtils {
  static Future<Position?> resolvePosition({
    Duration maxCacheAge = const Duration(minutes: 15),
    Duration freshTimeout = const Duration(seconds: 6),
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      final age = DateTime.now().difference(lastKnown.timestamp);
      if (age <= maxCacheAge) {
        return lastKnown;
      }
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: freshTimeout,
        ),
      );
    } catch (_) {
      return lastKnown;
    }
  }
}
