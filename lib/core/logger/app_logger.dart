import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String _tag;
  const AppLogger(this._tag);

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    if (kReleaseMode && level == LogLevel.debug) return;
    final prefix = '[${level.name.toUpperCase()}] [$_tag]';
    debugPrint('$prefix $message');
    if (error != null) debugPrint('$prefix Error: $error');
    if (stackTrace != null) debugPrint('$prefix Stack: $stackTrace');
  }
}
