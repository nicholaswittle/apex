import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Creates in-app notifications and optionally sends FCM push messages.
abstract final class NotificationService {
  static final _client = Supabase.instance.client;

  static Future<void> notifyUser({
    required String targetUserId,
    required String title,
    required String body,
  }) async {
    try {
      final rows = await _client.rpc('apex_notify_user', params: {
        'target_user_id': targetUserId,
        'notify_title': title,
        'notify_body': body,
      });

      if (rows is! List || rows.isEmpty) return;
      final pushToken = rows.first['push_token'] as String?;
      if (pushToken == null || pushToken.isEmpty || kIsWeb) return;

      await _client.functions.invoke(
        'send-push-notification',
        body: {'token': pushToken, 'title': title, 'body': body},
      );
    } catch (error, stackTrace) {
      debugPrint('Notification delivery skipped: $error');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> notifyOrganization({
    required String title,
    required String body,
    String? excludeUserId,
  }) async {
    try {
      final staff = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'Staff');

      for (final row in (staff as List)) {
        final userId = row['id'] as String;
        if (excludeUserId != null && userId == excludeUserId) continue;
        await notifyUser(targetUserId: userId, title: title, body: body);
      }
    } catch (error, stackTrace) {
      debugPrint('Organization notification skipped: $error');
      debugPrint('$stackTrace');
    }
  }

  static Future<int> unreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  static Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }
}
