import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('INFO', message, error, stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('WARN', message, error, stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', message, error, stackTrace);
  }

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('DEBUG', message, error, stackTrace);
  }

  static void _log(String level, String message,
      [dynamic error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] $message';

    // Print to console for visibility in run tab
    debugPrint(logMessage);
    if (error != null) debugPrint('Error: $error');
    if (stackTrace != null) debugPrint('Stack: $stackTrace');

    // Use developer log for advanced filtering in Dart DevTools
    developer.log(
      message,
      name: 'ToptancimApp',
      level: _getLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _getLevel(String level) {
    switch (level) {
      case 'INFO':
        return 800;
      case 'WARN':
        return 900;
      case 'ERROR':
        return 1000;
      case 'DEBUG':
        return 500;
      default:
        return 0;
    }
  }
}
