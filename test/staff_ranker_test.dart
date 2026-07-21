import 'package:apex/features/smart_suggestions/staff_ranker.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> shift({
  required String staff,
  required String title,
  required String date,
  String notes = 'Shift: 9:00 AM - 5:00 PM',
}) =>
    {'staff': staff, 'title': title, 'shift_date': date, 'notes': notes};

// 2026-07-24 is a Friday; the surrounding dates below are all Fridays.
final friday = DateTime(2026, 7, 24);

void main() {
  group('rankStaff', () {
    test('ranks by how often the staffer worked this exact role', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: [
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-17'),
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-10'),
          shift(staff: 'Ben', title: 'Bar', date: '2026-07-17'),
        ],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.first.name, 'Ana');
      expect(ranked.first.reasons, contains('Worked Bar 2×'));
    });

    test('history for a different role does not count', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: [
          shift(staff: 'Ana', title: 'Kitchen', date: '2026-07-17'),
          shift(staff: 'Ben', title: 'Bar', date: '2026-07-17'),
        ],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.first.name, 'Ben');
    });

    test('approved vacation is a hard exclusion, never a low rank', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: [
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-17'),
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-10'),
        ],
        onVacation: {'Ana'},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.map((c) => c.name), isNot(contains('Ana')));
    });

    test('self-declared unavailable is a hard exclusion', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: const [],
        onVacation: {},
        availability: {'Ana': false},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.map((c) => c.name), ['Ben']);
    });

    test('a missing availability record is treated as available', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana'],
        history: const [],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.map((c) => c.name), ['Ana']);
    });

    test('already booked that day is demoted but still selectable', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: [
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-17'),
          shift(staff: 'Ben', title: 'Bar', date: '2026-07-17'),
        ],
        onVacation: {},
        availability: {},
        bookedThatDay: {'Ana'},
        hoursThisWeek: {},
      );

      expect(ranked.first.name, 'Ben');
      final ana = ranked.firstWhere((c) => c.name == 'Ana');
      expect(ana.isBookedThatDay, isTrue);
      expect(ana.reasons, contains('Already on a shift'));
    });

    test('a staffer near a full week is demoted below an equal peer', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: [
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-17'),
          shift(staff: 'Ben', title: 'Bar', date: '2026-07-17'),
        ],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {'Ana': 38.0},
      );

      expect(ranked.first.name, 'Ben');
      expect(ranked.last.reasons, contains('38h this week'));
    });

    test('equal history spreads hours to the less-scheduled staffer', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: const [],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {'Ana': 12.0, 'Ben': 4.0},
      );

      expect(ranked.map((c) => c.name), ['Ben', 'Ana']);
    });

    test("'Open' slots in history never become candidates", () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana'],
        history: [shift(staff: 'Open', title: 'Bar', date: '2026-07-17')],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.map((c) => c.name), ['Ana']);
      expect(ranked.first.reasons, contains('No history for this role'));
    });

    test('same-weekday history outranks equal history on other days', () {
      final ranked = rankStaff(
        title: 'Bar',
        targetDate: friday,
        staffNames: ['Ana', 'Ben'],
        history: [
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-17'), // Friday
          shift(staff: 'Ben', title: 'Bar', date: '2026-07-15'), // Wednesday
        ],
        onVacation: {},
        availability: {},
        bookedThatDay: {},
        hoursThisWeek: {},
      );

      expect(ranked.first.name, 'Ana');
      expect(ranked.first.reasons, contains('1 on Fridays'));
    });
  });

  group('hoursScheduledInWeek', () {
    test('sums only the anchor week and skips Open slots', () {
      final totals = hoursScheduledInWeek(
        shifts: [
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-20'), // Mon, in week
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-24'), // Fri, in week
          shift(staff: 'Ana', title: 'Bar', date: '2026-07-13'), // prior week
          shift(staff: 'Open', title: 'Bar', date: '2026-07-21'),
        ],
        anchor: friday,
      );

      expect(totals['Ana'], 16.0);
      expect(totals.containsKey('Open'), isFalse);
    });

    test('an unparseable notes value contributes zero rather than guessing', () {
      final totals = hoursScheduledInWeek(
        shifts: [shift(staff: 'Ana', title: 'Bar', date: '2026-07-20', notes: 'covering')],
        anchor: friday,
      );

      expect(totals['Ana'], 0.0);
    });
  });
}
