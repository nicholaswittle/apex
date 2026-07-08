import 'package:flutter_test/flutter_test.dart';
import 'package:apex/core/date_utils.dart';
import 'package:apex/core/shift_hours_util.dart';

void main() {
  group('dateKey', () {
    test('formats ISO date', () {
      expect(dateKey(DateTime(2026, 7, 8)), '2026-07-08');
    });

    test('parseDateKey round trips', () {
      final d = parseDateKey('2026-07-08');
      expect(dateKey(d), '2026-07-08');
    });
  });

  group('calculateShiftHours', () {
    test('computes same-day shift', () {
      expect(calculateShiftHours('10:30 AM', '5:30 PM'), closeTo(7.0, 0.01));
    });

    test('computes overnight shift', () {
      expect(calculateShiftHours('10:00 PM', '2:00 AM'), closeTo(4.0, 0.01));
    });
  });
}
