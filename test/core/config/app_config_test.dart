import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('apiVersion is v1', () {
      expect(AppConfig.apiVersion, 'v1');
    });

    test('default distance constants are valid', () {
      expect(AppConfig.defaultMaxDistance, 50000);
      expect(AppConfig.minDistance, 100);
      expect(AppConfig.maxDistance, 50000);
      expect(AppConfig.minDistance, lessThan(AppConfig.maxDistance));
    });

    test('pagination constants are positive', () {
      expect(AppConfig.eventsPerPage, greaterThan(0));
      expect(AppConfig.matchesPerPage, greaterThan(0));
    });

    test('timeout durations are reasonable', () {
      expect(AppConfig.connectionTimeout.inSeconds, greaterThanOrEqualTo(5));
      expect(AppConfig.receiveTimeout.inSeconds, greaterThanOrEqualTo(5));
      expect(AppConfig.connectionTimeout.inSeconds, lessThanOrEqualTo(60));
      expect(AppConfig.receiveTimeout.inSeconds, lessThanOrEqualTo(60));
    });

    test('retry configuration is valid', () {
      expect(AppConfig.maxRetries, greaterThan(0));
      expect(AppConfig.retryDelay.inMilliseconds, greaterThan(0));
    });

    test('baseUrl is not empty', () {
      // In test environment, should return localhost URL
      expect(AppConfig.baseUrl, isNotEmpty);
      expect(AppConfig.baseUrl, contains('/api'));
    });

    test('reminder constants are positive', () {
      expect(AppConfig.hoursBeforeEventReminder, greaterThan(0));
      expect(AppConfig.minutesBeforeEventReminder, greaterThan(0));
    });
  });
}
