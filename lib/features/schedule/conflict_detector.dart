import 'package:supabase_flutter/supabase_flutter.dart';

/// Detects scheduling conflicts before publish.
class ConflictDetector {
  ConflictDetector(this._client);

  final SupabaseClient _client;

  /// Returns human-readable conflict messages (empty = OK to publish).
  Future<List<String>> findPublishConflicts({
    required List<String> targetDates,
    required String staff,
  }) async {
    if (staff == 'Open' || staff.isEmpty) return [];

    final conflicts = <String>[];

    for (final dateKey in targetDates) {
      final existing = await _client
          .from('shifts')
          .select('id, title')
          .eq('shift_date', dateKey)
          .eq('staff', staff);
      final rows = (existing as List).cast<Map<String, dynamic>>();
      if (rows.isNotEmpty) {
        final title = rows.first['title'] ?? 'shift';
        conflicts.add('$staff already scheduled for $dateKey ($title)');
      }

      final vacation = await _client
          .from('time_off_requests')
          .select('id')
          .eq('user_name', staff)
          .eq('status', 'Approved')
          .lte('start_date', dateKey)
          .gte('end_date', dateKey);
      if ((vacation as List).isNotEmpty) {
        conflicts.add('$staff has approved time off on $dateKey');
      }
    }

    return conflicts;
  }
}
