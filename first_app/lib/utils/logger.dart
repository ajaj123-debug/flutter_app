import 'package:flutter/foundation.dart';

class Logger {
  static bool _debugMode = kDebugMode;

  static set debugMode(bool value) {
    _debugMode = value;
  }

  static void info(String message) {
    if (_debugMode) {
      debugPrint('ℹ️ $message');
    }
  }

  static void success(String message) {
    if (_debugMode) {
      debugPrint('✅ Successfully $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_debugMode) {
      debugPrint('❌ $message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  static void warning(String message) {
    if (_debugMode) {
      debugPrint('⚠️ $message');
    }
  }

  static void debug(String message) {
    if (_debugMode) {
      debugPrint('🔍 DEBUG: $message');
    }
  }
}
