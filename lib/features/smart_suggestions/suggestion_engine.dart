import 'package:apex/core/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rules-based staffing suggestions from the prior four weeks of published shifts.
class SuggestionEngine {
  SuggestionEngine(this._client);

  final SupabaseClient _client;

  Future<List<ShiftSuggestion>> suggestForDate({
    required String orgId,
    required DateTime targetDate,
  }) async {
    final end = targetDate.subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 27));
    final startKey = dateKey(start);
    final endKey = dateKey(end);
    final weekday = targetDate.weekday;

    final rows = await _client
        .from('shifts')
        .select('title, staff, zone, notes, shift_date')
        .eq('organization_id', orgId)
        .gte('shift_date', startKey)
        .lte('shift_date', endKey);

    final history = (rows as List).cast<Map<String, dynamic>>();
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
  });

  final String title;
  final int occurrences;
  final String? zone;
  final String? notes;
}
