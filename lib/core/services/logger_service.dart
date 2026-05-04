import 'package:logger/logger.dart';

class _WarningErrorFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return event.level.index >= Level.warning.index;
  }
}

class LoggerService {
  static final Logger _logger = Logger(
    filter: _WarningErrorFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.dateAndTime,
    ),
  );

  static String _normalizeMessage(dynamic message) {
    final raw = message?.toString() ?? '';
    final cleaned = raw.replaceFirst(RegExp(r'^[^A-Za-z0-9\[]+\s*'), '');
    if (cleaned.startsWith('[')) return cleaned;
    return '[Andex] $cleaned';
  }

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(_normalizeMessage(message), error: error, stackTrace: stackTrace);
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_normalizeMessage(message), error: error, stackTrace: stackTrace);
  }

  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_normalizeMessage(message), error: error, stackTrace: stackTrace);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_normalizeMessage(message), error: error, stackTrace: stackTrace);
  }
}
