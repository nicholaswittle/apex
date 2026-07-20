import 'package:apex/core/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimeOffService {
  TimeOffService(this._client);

  final SupabaseClient _client;

  Future<List<dynamic>> loadRequests() async {
    final data = await _client
        .from('time_off_requests')
        .select()
        .order('start_date', ascending: true);
    return data;
  }

  Stream<List<Map<String, dynamic>>> watchRequests() {
    return _client
        .from('time_off_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> submitRequest({
    required String userId,
    required String userName,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    await _client.from('time_off_requests').insert({
      'user_id': userId,
      'user_name': userName,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
    });
  }

  Future<void> updateStatus({
    required String id,
    required String targetStatus,
  }) async {
    final existing = await _client
        .from('time_off_requests')
        .select('user_id, start_date, end_date')
        .eq('id', id)
        .maybeSingle();

    await _client
        .from('time_off_requests')
        .update({'status': targetStatus, 'notified': false})
        .eq('id', id);

    if (existing != null) {
      await NotificationService.notifyUser(
        targetUserId: existing['user_id'] as String,
        title: 'Time off $targetStatus',
        body:
            'Your request ${existing['start_date']} to ${existing['end_date']} was $targetStatus.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> checkUnnotified(String userId) async {
    final unnotified = await _client
        .from('time_off_requests')
        .select()
        .eq('user_id', userId)
        .eq('notified', false)
        .or('status.eq.Approved,status.eq.Denied');
    return (unnotified as List).cast<Map<String, dynamic>>();
  }

  /// Permanently removes a time-off request (e.g. owner clearing old
  /// history). No soft-delete: callers should confirm with the user first.
  Future<void> deleteRequest(String id) async {
    await _client.from('time_off_requests').delete().eq('id', id);
  }

  Future<void> markNotified(String requestId) async {
    await _client
        .from('time_off_requests')
        .update({'notified': true})
        .eq('id', requestId);
  }
}
