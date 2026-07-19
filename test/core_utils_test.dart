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

    test('noon and midnight parse per AM/PM convention', () {
      expect(calculateShiftHours('12:00 PM', '5:00 PM'), closeTo(5.0, 0.01));
      expect(calculateShiftHours('12:00 AM', '8:00 AM'), closeTo(8.0, 0.01));
    });

    test('malformed input yields zero hours, never fabricated hours', () {
      // A garbled start must not be treated as midnight (which would
      // fabricate a 17-hour shift here and inflate labor cost).
      expect(calculateShiftHours('', '5:00 PM'), 0.0);
      expect(calculateShiftHours('17:00', '5:00 PM'), 0.0); // 24h format unsupported
      expect(calculateShiftHours('10:00 AM', 'garbage'), 0.0);
      expect(calculateShiftHours('', ''), 0.0);
    });
  });
}
