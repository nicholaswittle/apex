import 'package:apex/core/date_utils.dart';
import 'package:apex/core/shift_hours_util.dart';

/// A staffer ranked for a specific role on a specific date, with the reasons
/// that produced the ranking.
class StaffCandidate {
  const StaffCandidate({
    required this.name,
    required this.score,
    required this.reasons,
    required this.isBookedThatDay,
    required this.hoursThisWeek,
  });

  final String name;
  final double score;
  final List<String> reasons;
  final bool isBookedThatDay;
  final double hoursThisWeek;
}

const _scorePerTitleMatch = 10.0;
const _scorePerWeekdayMatch = 5.0;
const _penaltyAlreadyBooked = 15.0;
const _penaltyApproachingFullWeek = 8.0;
const _penaltyFullWeek = 20.0;

const _fullWeekHours = 35.0;
const _approachingFullWeekHours = 30.0;

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Ranks [staffNames] for filling [title] on [targetDate], best first.
///
/// Pure by design: every input is already-fetched data, so the ranking can be
/// tested without a Supabase client.
///
/// Approved vacation and a self-declared unavailable flag are hard exclusions.
/// Everything else is a nudge — a split shift or a heavy week is a fact for the
/// admin to weigh, not a veto.
List<StaffCandidate> rankStaff({
  required String title,
  required DateTime targetDate,
  required List<String> staffNames,
  required List<Map<String, dynamic>> history,
  required Set<String> onVacation,
  required Map<String, bool> availability,
  required Set<String> bookedThatDay,
  required Map<String, double> hoursThisWeek,
}) {
  final titleCounts = <String, int>{};
  final weekdayCounts = <String, int>{};

  for (final row in history) {
    final staff = row['staff'];
    if (staff is! String || staff == 'Open') continue;
    if (row['title'] != title) continue;

    titleCounts[staff] = (titleCounts[staff] ?? 0) + 1;

    final dateStr = row['shift_date'];
    if (dateStr is! String) continue;
    final worked = DateTime.tryParse(dateStr);
    if (worked != null && worked.weekday == targetDate.weekday) {
      weekdayCounts[staff] = (weekdayCounts[staff] ?? 0) + 1;
    }
  }

  final candidates = <StaffCandidate>[];

  for (final name in staffNames) {
    if (onVacation.contains(name)) continue;
    if (availability[name] == false) continue;

    final titleCount = titleCounts[name] ?? 0;
    final weekdayCount = weekdayCounts[name] ?? 0;
    final hours = hoursThisWeek[name] ?? 0.0;
    final isBooked = bookedThatDay.contains(name);

    var score = titleCount * _scorePerTitleMatch + weekdayCount * _scorePerWeekdayMatch;
    if (isBooked) score -= _penaltyAlreadyBooked;
    if (hours >= _fullWeekHours) {
      score -= _penaltyFullWeek;
    } else if (hours >= _approachingFullWeekHours) {
      score -= _penaltyApproachingFullWeek;
    }

    final reasons = <String>[];
    if (titleCount > 0) reasons.add('Worked $title $titleCount×');
    if (weekdayCount > 0) {
      reasons.add('$weekdayCount on ${_weekdayNames[targetDate.weekday - 1]}s');
    }
    if (hours > 0) reasons.add('${_formatHours(hours)}h this week');
    if (isBooked) reasons.add('Already on a shift');
    if (reasons.isEmpty) reasons.add('No history for this role');

    candidates.add(StaffCandidate(
      name: name,
      score: score,
      reasons: reasons,
      isBookedThatDay: isBooked,
      hoursThisWeek: hours,
    ));
  }

  candidates.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    // Spread hours when history is equal, and keep ties stable for the UI.
    final byHours = a.hoursThisWeek.compareTo(b.hoursThisWeek);
    return byHours != 0 ? byHours : a.name.compareTo(b.name);
  });

  return candidates;
}

/// Hours each staffer is already scheduled for in the week containing [anchor].
Map<String, double> hoursScheduledInWeek({
  required List<Map<String, dynamic>> shifts,
  required DateTime anchor,
}) {
  final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
  final weekKeys = {
    for (var i = 0; i < 7; i++) dateKey(monday.add(Duration(days: i))),
  };

  final totals = <String, double>{};
  for (final row in shifts) {
    final staff = row['staff'];
    if (staff is! String || staff == 'Open') continue;
    if (!weekKeys.contains(row['shift_date'])) continue;
    totals[staff] = (totals[staff] ?? 0.0) + hoursFromNotes(row['notes'] as String?);
  }
  return totals;
}

String _formatHours(double hours) =>
    hours == hours.roundToDouble() ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
