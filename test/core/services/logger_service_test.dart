import 'package:flutter_test/flutter_test.dart';
import 'package:andexevents/core/services/logger_service.dart';

void main() {
  group('LoggerService', () {
    test('debug does not throw', () {
      expect(() => LoggerService.debug('test debug'), returnsNormally);
    });

    test('info does not throw', () {
      expect(() => LoggerService.info('test info'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(() => LoggerService.warning('test warning'), returnsNormally);
    });

    test('error does not throw', () {
      expect(() => LoggerService.error('test error'), returnsNormally);
    });

    test('debug with error object does not throw', () {
      expect(
        () => LoggerService.debug('msg', Exception('test')),
        returnsNormally,
      );
    });

    test('error with error and stack trace does not throw', () {
      final trace = StackTrace.current;
      expect(
        () => LoggerService.error('msg', Exception('test'), trace),
        returnsNormally,
      );
    });

    test('all methods accept null-like dynamic values', () {
      expect(() => LoggerService.debug(42), returnsNormally);
      expect(() => LoggerService.info({'key': 'value'}), returnsNormally);
      expect(() => LoggerService.warning(['list', 'items']), returnsNormally);
    });
  });
}
