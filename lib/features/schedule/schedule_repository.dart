import 'package:apex/core/date_utils.dart';
import 'package:apex/core/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleRepository {
  ScheduleRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> listenNewShifts() {
    return _client.from('shifts').stream(primaryKey: ['id']);
  }

  Stream<List<Map<String, dynamic>>> shiftsForDate(String dateKey) {
    return _client.from('shifts').stream(primaryKey: ['id']).eq('shift_date', dateKey);
  }

  Future<void> publishShifts({
    required List<String> targetDates,
    required String title,
    required String staff,
    required String formattedHours,
    required bool isEvent,
    required String? zone,
    required String organizationId,
    required String? excludeUserId,
  }) async {
    final rowsToInsert = targetDates.map((key) {
      return {
        'shift_date': key,
        'day_num': parseDateKey(key).day,
        'title': title,
        'staff': staff,
        'notes': formattedHours,
        'is_event': isEvent,
        'zone': zone,
        'organization_id': organizationId,
      };
    }).toList();

    await _client.from('shifts').insert(rowsToInsert);

    await NotificationService.notifyOrganization(
      title: 'Schedule updated',
      body: 'New shifts were published for ${targetDates.length} day(s).',
      excludeUserId: excludeUserId,
    );
  }

  Future<void> deleteShift(String shiftId) async {
    await _client.from('shifts').delete().eq('id', shiftId);
  }

  /// Copies all shifts from the week before [targetWeekAnchor] into the target week.
  Future<int> copyPreviousWeek({
    required DateTime targetWeekAnchor,
    required String organizationId,
    required String? excludeUserId,
  }) async {
    final targetMonday = targetWeekAnchor.subtract(Duration(days: targetWeekAnchor.weekday - 1));
    final sourceMonday = targetMonday.subtract(const Duration(days: 7));
    final sourceEnd = sourceMonday.add(const Duration(days: 6));

    final rows = await _client
        .from('shifts')
        .select('title, staff, notes, is_event, zone, shift_date')
        .eq('organization_id', organizationId)
        .gte('shift_date', dateKey(sourceMonday))
        .lte('shift_date', dateKey(sourceEnd));

    final source = (rows as List).cast<Map<String, dynamic>>();
    if (source.isEmpty) return 0;

    final inserts = <Map<String, dynamic>>[];
    for (final row in source) {
      final srcDate = parseDateKey(row['shift_date'] as String);
      final dayOffset = srcDate.difference(sourceMonday).inDays;
      final targetDate = targetMonday.add(Duration(days: dayOffset));
      final targetKey = dateKey(targetDate);
      inserts.add({
        'shift_date': targetKey,
        'day_num': targetDate.day,
        'title': row['title'],
        'staff': row['staff'],
        'notes': row['notes'],
        'is_event': row['is_event'] ?? false,
        'zone': row['zone'],
        'organization_id': organizationId,
      });
    }

    await _client.from('shifts').insert(inserts);

    await NotificationService.notifyOrganization(
      title: 'Schedule updated',
      body: 'Last week\'s schedule was copied (${inserts.length} shifts).',
      excludeUserId: excludeUserId,
    );

    return inserts.length;
  }
}
