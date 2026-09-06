import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// تسجيل بسيط يظهر في وضع التطوير فقط.
class Log {
  const Log._();

  static void d(String tag, String message) {
    if (!kDebugMode) return;
    developer.log(message, name: tag);
  }

  static void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode) return;
    developer.log(
      message,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
