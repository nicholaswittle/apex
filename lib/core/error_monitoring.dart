import 'package:apex/core/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Initializes global error handlers. Uses Sentry when [AppConfig.sentryDsn] is set.
Future<void> initErrorMonitoring({Future<void> Function()? appRunner}) async {
  if (AppConfig.sentryDsn.isEmpty) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    if (appRunner != null) await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.tracesSampleRate = 0.2;
    },
    appRunner: appRunner ?? () async {},
  );
}
