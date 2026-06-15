import '../config/app_config.dart';

/// Rewrites loopback / emulator media hosts to the active API host so images
/// uploaded on a simulator still load on a physical device.
class MediaUrlUtils {
  static const Set<String> _rewriteHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '10.0.2.2',
  };

  static String? normalize(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return rawUrl;

    try {
      final uri = Uri.parse(rawUrl);
      final host = uri.host.toLowerCase();
      if (!_rewriteHosts.contains(host)) return rawUrl;

      final apiUri = Uri.parse(AppConfig.baseUrl);
      if (apiUri.host.isEmpty) return rawUrl;

      return uri
          .replace(
            scheme: apiUri.scheme.isEmpty ? 'http' : apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
          )
          .toString();
    } catch (_) {
      return rawUrl;
    }
  }
}
