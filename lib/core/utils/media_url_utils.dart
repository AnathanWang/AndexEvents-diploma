import '../config/app_config.dart';

/// Rewrites dev upload URLs (localhost / stale LAN IP) to the active API host.
class MediaUrlUtils {
  static const Set<String> _rewriteHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '10.0.2.2',
  };

  static Uri get _uploadsOrigin => Uri.parse(AppConfig.uploadsOrigin);

  /// Returns a device-reachable URL for [rawUrl], or null when empty.
  static String? normalize(String? rawUrl) {
    if (rawUrl == null) return null;

    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      final path = uri.path;

      if (path.startsWith('/uploads/')) {
        return _uploadsOrigin
            .replace(
              path: path,
              query: uri.hasQuery ? uri.query : null,
            )
            .toString();
      }

      final host = uri.host.toLowerCase();
      if (_rewriteHosts.contains(host)) {
        return uri
            .replace(
              scheme: _uploadsOrigin.scheme,
              host: _uploadsOrigin.host,
              port: _uploadsOrigin.hasPort ? _uploadsOrigin.port : null,
            )
            .toString();
      }

      if (_isPrivateLanHost(host) && host != _uploadsOrigin.host) {
        return uri
            .replace(
              scheme: _uploadsOrigin.scheme,
              host: _uploadsOrigin.host,
              port: _uploadsOrigin.hasPort ? _uploadsOrigin.port : null,
            )
            .toString();
      }

      return trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  /// Non-null helper for widgets: trims and rewrites upload hosts.
  static String resolve(String rawUrl) => normalize(rawUrl) ?? rawUrl.trim();

  static bool _isPrivateLanHost(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;

    final octets = parts.map(int.tryParse).toList();
    if (octets.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }

    final a = octets[0] ?? 0;
    final b = octets[1] ?? 0;

    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }
}
