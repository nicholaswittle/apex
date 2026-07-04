import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase when platform config files are present.
abstract final class FirebaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Firebase init skipped: $error');
      debugPrint('$stackTrace');
    }
  }
}
