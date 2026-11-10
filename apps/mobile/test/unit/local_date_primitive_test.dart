import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/time/local_date.dart';

void main() {
  test('rejects invalid dates instead of normalizing overflow', () {
    for (final parts in [
      [0, 1, 1],
      [10000, 1, 1],
      [2026, 0, 1],
      [2026, 13, 1],
      [2026, 1, 0],
      [2026, 1, 32],
      [2026, 4, 31],
      [1900, 2, 29],
    ]) {
      expect(
        () => LocalDate(parts[0], parts[1], parts[2]),
        throwsFormatException,
      );
    }
    expect(LocalDate(2000, 2, 29).toString(), '2000-02-29');
    expect(LocalDate(1, 1, 1).toString(), '0001-01-01');
  });

  test('strict parse, equality, ordering and calendar weekday', () {
    final day = LocalDate.parse('2026-03-29');
    expect(day, LocalDate(2026, 3, 29));
    expect(day.hashCode, LocalDate(2026, 3, 29).hashCode);
    expect(day.weekday, DateTime.sunday);
    expect(
      LocalDate(2025, 12, 31).compareTo(LocalDate(2026, 1, 1)),
      lessThan(0),
    );
    for (final text in [
      '',
      '2026-3-29',
      '2026-03-29Z',
      '2026-03-29T00:00:00Z',
      '2026-02-29',
      '2026-03-29 ',
      '2026-03-29\n',
      '0000-01-01',
      '10000-01-01',
    ]) {
      expect(() => LocalDate.parse(text), throwsFormatException);
    }
  });

  test(
    'day arithmetic crosses leap/year/DST dates and rejects range overflow',
    () {
      expect(LocalDate(2024, 2, 28).addDays(1), LocalDate(2024, 2, 29));
      expect(LocalDate(2024, 2, 29).addDays(1), LocalDate(2024, 3, 1));
      expect(LocalDate(2026, 1, 1).addDays(-1), LocalDate(2025, 12, 31));
      expect(LocalDate(2026, 3, 29).addDays(1), LocalDate(2026, 3, 30));
      expect(LocalDate(2026, 10, 25).addDays(1), LocalDate(2026, 10, 26));
      expect(() => LocalDate(1, 1, 1).addDays(-1), throwsRangeError);
      expect(() => LocalDate(9999, 12, 31).addDays(1), throwsRangeError);
      expect(
        () => LocalDate(2026, 1, 1).addDays(9007199254740991),
        throwsRangeError,
      );
      expect(
        () => LocalDate(2026, 1, 1).addDays(-9007199254740991),
        throwsRangeError,
      );
    },
  );

  test(
    'calendar roundtrip and inverse day arithmetic across 400 leap years',
    () {
      for (var year = 1800; year < 2200; year++) {
        for (var month = 1; month <= 12; month++) {
          final day = LocalDate(year, month, 28);
          expect(LocalDate.parse(day.toString()), day);
          expect(day.addDays(7).addDays(-7), day);
          expect(day.addDays(1).weekday, day.weekday % 7 + 1);
          expect(day.addDays(1).compareTo(day), greaterThan(0));
        }
      }
    },
  );
}
