import 'package:flutter/foundation.dart';

class ErrorLogger {
  static final ErrorLogger instance = ErrorLogger._();
  ErrorLogger._();

  /// Log an error with context
  void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ ERROR [$context]: $error');
      if (stackTrace != null) {
        print('Stack trace:\n$stackTrace');
      }
    }
    // In production, send to a logging service (Firebase Crashlytics, Sentry, etc.)
    // Example: FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Log info message
  void logInfo(String message) {
    if (kDebugMode) {
      print('ℹ️ INFO: $message');
    }
  }

  /// Log warning
  void logWarning(String message) {
    if (kDebugMode) {
      print('⚠️ WARNING: $message');
    }
  }

  /// Log success
  void logSuccess(String message) {
    if (kDebugMode) {
      print('✅ SUCCESS: $message');
    }
  }
}
