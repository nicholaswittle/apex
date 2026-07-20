import 'package:apex/core/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvailabilityService {
  AvailabilityService(this._client);

  final SupabaseClient _client;

  Future<({
    List<Map<String, dynamic>> availabilityForDay,
    bool myAvailabilityToday,
    bool isOnVacation,
  })> loadForDate({
    required DateTime date,
    required List<String> staffNames,
    required String userName,
  }) async {
    final dateStr = dateKey(date);
    final results = await Future.wait([
      _client.from('availability').select('user_name, available').eq('date', dateStr),
      _client
          .from('time_off_requests')
          .select('user_name')
          .eq('status', 'Approved')
          .lte('start_date', dateStr)
          .gte('end_date', dateStr),
    ]);

    final rows = ((results[0] as List?)?.cast<Map<String, dynamic>>()) ?? [];
    final vacationRows = ((results[1] as List?)?.cast<Map<String, dynamic>>()) ?? [];

    final avMap = <String, bool>{
      for (final row in rows)
        if (row['user_name'] is String && row['available'] is bool)
          row['user_name'] as String: row['available'] as bool,
    };

    final vacationSet = <String>{
      for (final row in vacationRows)
        if (row['user_name'] is String) row['user_name'] as String,
    };

    final availabilityForDay = staffNames
        .map((name) => {
              'user_name': name,
              'available': vacationSet.contains(name) ? false : (avMap[name] ?? true),
              'on_vacation': vacationSet.contains(name),
            })
        .toList();

    return (
      availabilityForDay: availabilityForDay,
      myAvailabilityToday:
          vacationSet.contains(userName) ? false : (avMap[userName] ?? true),
      isOnVacation: vacationSet.contains(userName),
    );
  }

  Future<void> toggleAvailability({
    required String userId,
    required String userName,
    required DateTime date,
    required bool available,
  }) async {
    await _client.from('availability').upsert(
      {
        'user_id': userId,
        'user_name': userName,
        'date': dateKey(date),
        'available': available,
      },
      onConflict: 'user_id,date',
    );
  }
}
