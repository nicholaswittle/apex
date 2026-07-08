/// Shared date formatting helpers for schedule keys.
String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) => DateTime.parse(key);
