/// Parses AM/PM time strings and returns shift duration in hours.
///
/// Malformed input yields 0.0 for the WHOLE shift rather than being
/// treated as midnight — a garbled start time must never fabricate paid
/// hours in labor-cost math.
double calculateShiftHours(String startTime, String endTime) {
  double? parse(String t) {
    try {
      final p = t.split(' ');
      final hm = p[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      if (p[1] == 'PM' && h != 12) h += 12;
      if (p[1] == 'AM' && h == 12) h = 0;
      return h + m / 60.0;
    } catch (_) {
      return null;
    }
  }

  final start = parse(startTime);
  final parsedEnd = parse(endTime);
  if (start == null || parsedEnd == null) return 0.0;
  var end = parsedEnd;
  if (end < start) end += 24;
  return end - start;
}
