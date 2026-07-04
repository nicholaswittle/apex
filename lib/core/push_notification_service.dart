import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_bootstrap.dart';

/// Registers FCM device token on the signed-in user's profile.
abstract final class PushNotificationService {
  static Future<void> syncTokenForCurrentUser() async {
    if (kIsWeb || !FirebaseBootstrap.isInitialized) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'push_token': token})
          .eq('id', userId);
    } catch (error, stackTrace) {
      debugPrint('Push token sync skipped: $error');
      debugPrint('$stackTrace');
    }
  }
}
