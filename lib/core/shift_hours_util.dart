/// Parses AM/PM time strings and returns shift duration in hours.
double calculateShiftHours(String startTime, String endTime) {
  double parse(String t) {
    try {
      final p = t.split(' ');
      final hm = p[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      if (p[1] == 'PM' && h != 12) h += 12;
      if (p[1] == 'AM' && h == 12) h = 0;
      return h + m / 60.0;
    } catch (_) {
      return 0.0;
    }
  }

  final start = parse(startTime);
  var end = parse(endTime);
  if (end < start) end += 24;
  return end - start;
}
