import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes `time_entries` for shift clock-in/out.
class TimeClockService {
  TimeClockService(this._client);

  final SupabaseClient _client;

  static String _todayDateKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Active clock-ins for [userId] today: shift_id → time_entry id.
  Future<Map<String, String>> loadActiveEntriesForToday(String userId) async {
    final dateStr = _todayDateKey();
    final data = await _client
        .from('time_entries')
        .select('id, shift_id')
        .eq('user_id', userId)
        .gte('clock_in', '${dateStr}T00:00:00')
        .isFilter('clock_out', null);

    final rows = ((data as List?)?.cast<Map<String, dynamic>>()) ?? [];
    return {for (final r in rows) r['shift_id'] as String: r['id'] as String};
  }

  /// Returns the new time_entry id.
  Future<String> clockIn({
    required String userId,
    required String userName,
    required String shiftId,
  }) async {
    final result = await _client.from('time_entries').insert({
      'user_id': userId,
      'user_name': userName,
      'shift_id': shiftId,
    }).select('id').single();
    return result['id'] as String;
  }

  Future<void> clockOut(String entryId) async {
    await _client
        .from('time_entries')
        .update({'clock_out': DateTime.now().toIso8601String()})
        .eq('id', entryId);
  }
}
