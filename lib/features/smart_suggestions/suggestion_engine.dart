import 'package:apex/core/date_utils.dart';
import 'package:apex/features/smart_suggestions/staff_ranker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rules-based staffing suggestions from the prior four weeks of published shifts.
class SuggestionEngine {
  SuggestionEngine(this._client);

  final SupabaseClient _client;

  Future<List<ShiftSuggestion>> suggestForDate({
    required String orgId,
    required DateTime targetDate,
    List<String> staffNames = const [],
  }) async {
    final end = targetDate.subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 27));
    final startKey = dateKey(start);
    final endKey = dateKey(end);
    final targetKey = dateKey(targetDate);
    final weekday = targetDate.weekday;

    final targetMonday = targetDate.subtract(Duration(days: targetDate.weekday - 1));

    final results = await Future.wait([
      _client
          .from('shifts')
          .select('title, staff, zone, notes, shift_date')
          .eq('organization_id', orgId)
          .gte('shift_date', startKey)
          .lte('shift_date', endKey),
      _client
          .from('shifts')
          .select('staff, notes, shift_date')
          .eq('organization_id', orgId)
          .gte('shift_date', dateKey(targetMonday))
          .lte('shift_date', dateKey(targetMonday.add(const Duration(days: 6)))),
      _client.from('availability').select('user_name, available').eq('date', targetKey),
      _client
          .from('time_off_requests')
          .select('user_name')
          .eq('status', 'Approved')
          .lte('start_date', targetKey)
          .gte('end_date', targetKey),
    ]);

    final history = ((results[0] as List?)?.cast<Map<String, dynamic>>()) ?? [];
    final targetWeek = ((results[1] as List?)?.cast<Map<String, dynamic>>()) ?? [];
    final availabilityRows = ((results[2] as List?)?.cast<Map<String, dynamic>>()) ?? [];
    final vacationRows = ((results[3] as List?)?.cast<Map<String, dynamic>>()) ?? [];

    final availability = <String, bool>{
      for (final row in availabilityRows)
        if (row['user_name'] is String && row['available'] is bool)
          row['user_name'] as String: row['available'] as bool,
    };
    final onVacation = <String>{
      for (final row in vacationRows)
        if (row['user_name'] is String) row['user_name'] as String,
    };
    final bookedThatDay = <String>{
      for (final row in targetWeek)
        if (row['shift_date'] == targetKey &&
            row['staff'] is String &&
            row['staff'] != 'Open')
          row['staff'] as String,
    };
    final hoursThisWeek = hoursScheduledInWeek(shifts: targetWeek, anchor: targetDate);
    final sameWeekday = history.where((row) {
      final d = parseDateKey(row['shift_date'] as String);
      return d.weekday == weekday;
    }).toList();

    if (sameWeekday.isEmpty) return [];

    final counts = <String, int>{};
    final zoneByTitle = <String, String?>{};
    final notesByTitle = <String, String?>{};

    for (final row in sameWeekday) {
      final title = (row['title'] as String?) ?? 'General Support Shift';
      counts[title] = (counts[title] ?? 0) + 1;
      zoneByTitle.putIfAbsent(title, () => row['zone'] as String?);
      notesByTitle.putIfAbsent(title, () => row['notes'] as String?);
    }

    final sortedTitles = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return sortedTitles.take(5).map((title) {
      return ShiftSuggestion(
        title: title,
        occurrences: counts[title]!,
        zone: zoneByTitle[title],
        notes: notesByTitle[title],
        candidates: rankStaff(
          title: title,
          targetDate: targetDate,
          staffNames: staffNames,
          history: history,
          onVacation: onVacation,
          availability: availability,
          bookedThatDay: bookedThatDay,
          hoursThisWeek: hoursThisWeek,
        ),
      );
    }).toList();
  }
}

class ShiftSuggestion {
  const ShiftSuggestion({
    required this.title,
    required this.occurrences,
    this.zone,
    this.notes,
    this.candidates = const [],
  });

  final String title;
  final int occurrences;
  final String? zone;
  final String? notes;

  /// Staff ranked for this role on the target date, best first.
  final List<StaffCandidate> candidates;
}
