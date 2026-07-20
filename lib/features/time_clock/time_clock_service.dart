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
  ///
  /// Guards against duplicate open entries: a double-tap or reconnect could
  /// otherwise insert two open rows for the same user+shift, inflating payroll.
  /// If an open entry already exists we return it instead of inserting again.
  /// (A partial unique index on (user_id, shift_id) WHERE clock_out IS NULL is
  /// the fully-atomic fix and belongs in an RLS/constraints migration.)
  Future<String> clockIn({
    required String userId,
    required String userName,
    required String shiftId,
  }) async {
    final existing = await _client
        .from('time_entries')
        .select('id')
        .eq('user_id', userId)
        .eq('shift_id', shiftId)
        .isFilter('clock_out', null)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final result = await _client.from('time_entries').insert({
      'user_id': userId,
      'user_name': userName,
      'shift_id': shiftId,
    }).select('id').single();
    return result['id'] as String;
  }

  Future<void> clockOut(String entryId) async {
    // Write UTC (`...Z`) against the timestamptz column. A naive local ISO
    // string is interpreted in the server session's timezone, corrupting the
    // day boundary and payroll math for any non-UTC venue.
    await _client
        .from('time_entries')
        .update({'clock_out': DateTime.now().toUtc().toIso8601String()})
        .eq('id', entryId);
  }
}
