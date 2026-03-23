import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalRouteService {
  Future<bool> openRouteToDestination({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final encodedLabel = Uri.encodeComponent(label ?? 'Event');

    final uris = switch (defaultTargetPlatform) {
      TargetPlatform.android => <Uri>[
          Uri.parse('google.navigation:q=$latitude,$longitude'),
          Uri.parse('geo:0,0?q=$latitude,$longitude($encodedLabel)'),
          Uri.parse('https://maps.google.com/?daddr=$latitude,$longitude'),
          Uri.parse('https://yandex.ru/maps/?rtext=~$latitude,$longitude&rtt=auto'),
        ],
      TargetPlatform.iOS => <Uri>[
          Uri.parse('http://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d'),
          Uri.parse('comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving'),
          Uri.parse('https://maps.google.com/?daddr=$latitude,$longitude'),
          Uri.parse('https://yandex.ru/maps/?rtext=~$latitude,$longitude&rtt=auto'),
        ],
      _ => <Uri>[
          if (kIsWeb) Uri.parse('https://yandex.ru/maps/?rtext=~$latitude,$longitude&rtt=auto'),
        ],
    };

    for (final uri in uris) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return true;
        }
      } catch (_) {
        // Try next fallback URI.
      }
    }

    return false;
  }
}
