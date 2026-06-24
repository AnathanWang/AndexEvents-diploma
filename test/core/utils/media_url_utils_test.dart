import 'package:andexevents/core/config/app_config.dart';
import 'package:andexevents/core/utils/media_url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaUrlUtils', () {
    test('rewrites localhost uploads to uploads origin', () {
      final expectedHost = Uri.parse(AppConfig.uploadsOrigin).host;
      final result = MediaUrlUtils.normalize(
        ' http://localhost/uploads/avatars/u/1.jpg',
      );

      expect(result, isNotNull);
      expect(Uri.parse(result!).host, expectedHost);
      expect(result, endsWith('/uploads/avatars/u/1.jpg'));
    });

    test('rewrites stale LAN IP uploads to uploads origin', () {
      final expectedHost = Uri.parse(AppConfig.uploadsOrigin).host;
      final result = MediaUrlUtils.normalize(
        'http://192.168.1.146/uploads/events/u/1.jpg',
      );

      expect(Uri.parse(result!).host, expectedHost);
      expect(result, contains('/uploads/events/u/1.jpg'));
    });

    test('keeps external https urls unchanged', () {
      const url = 'https://images.unsplash.com/photo-1?w=800';
      expect(MediaUrlUtils.normalize(url), url);
    });

    test('resolve rewrites loopback hosts', () {
      final expectedHost = Uri.parse(AppConfig.uploadsOrigin).host;
      final resolved = MediaUrlUtils.resolve('http://localhost/uploads/x.jpg');
      expect(Uri.parse(resolved).host, expectedHost);
    });
  });
}
