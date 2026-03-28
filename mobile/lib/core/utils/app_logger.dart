import 'package:flutter/foundation.dart';

/// Application logger — debug-only output, no-op in release builds.
///
/// Never logs passwords, tokens, or email addresses.
/// In production, capture errors via Sentry at the call site:
///   `Sentry.captureException(error, stackTrace: stackTrace)`
abstract final class AppLogger {
  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint('[DEBUG] $message');
    if (error != null) debugPrint('[DEBUG] Error: $error');
    if (stackTrace != null) debugPrint('[DEBUG] StackTrace:\n$stackTrace');
  }

  static void info(String message) {
    if (!kDebugMode) return;
    debugPrint('[INFO ] $message');
  }

  static void warning(String message, {Object? error}) {
    if (!kDebugMode) return;
    debugPrint('[WARN ] $message');
    if (error != null) debugPrint('[WARN ] Error: $error');
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint('[ERROR] Error: $error');
    if (stackTrace != null) debugPrint('[ERROR] StackTrace:\n$stackTrace');
  }

  const AppLogger._();
}
