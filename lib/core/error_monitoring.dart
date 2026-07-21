import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Initializes global error handlers.
///
/// Sentry was removed: it was never configured with a DSN, so it reported
/// nothing, and its 8.x iOS pod does not build under current Xcode.
Future<void> initErrorMonitoring({Future<void> Function()? appRunner}) async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  if (appRunner != null) await appRunner();
}
