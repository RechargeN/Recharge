import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/shared/primitives/time/local_date.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/features/discover/domain/usecases/build_time_window_usecase.dart';

void main() {
  final TimezoneRepositoryImpl repository = TimezoneRepositoryImpl();
  LocalDateTimeValue local(
    int year,
    int month,
    int day,
    int hour, [
    int minute = 0,
  ]) {
    final date = LocalDate(year, month, day);
    return LocalDateTimeValue(
      date: date,
      minutesSinceMidnight: hour * 60 + minute,
      weekday: date.weekday,
    );
  }

  test(
    'local wall-clock arithmetic crosses calendar days without host DST',
    () {
      final before = local(2026, 3, 29, 2, 30);
      final gap = before.addMinutes(60);
      expect(gap.date, LocalDate(2026, 3, 29));
      expect(gap.minutesSinceMidnight, 210);
      expect(gap.compareTo(before), greaterThan(0));
      final previous = local(2024, 3, 1, 0).addMinutes(-1);
      expect(previous.date, LocalDate(2024, 2, 29));
      expect(previous.minutesSinceMidnight, 1439);
      expect(
        local(2026, 12, 31, 23, 59).addMinutes(1).date,
        LocalDate(2027, 1, 1),
      );
      expect(() => before.addMinutes(9223372036854775807), throwsRangeError);
      expect(() => local(1, 1, 1, 0).addMinutes(-1), throwsRangeError);
      expect(() => local(9999, 12, 31, 23, 59).addMinutes(1), throwsRangeError);
    },
  );

  test('local minute and weekday validation does not rely on assertions', () {
    final date = LocalDate(2026, 1, 1);
    for (final minute in [-1, 1440]) {
      expect(
        () => LocalDateTimeValue(
          date: date,
          minutesSinceMidnight: minute,
          weekday: date.weekday,
        ),
        throwsRangeError,
      );
    }
    expect(
      () => LocalDateTimeValue(date: date, minutesSinceMidnight: 0, weekday: 1),
      throwsArgumentError,
    );
  });

  test('instant boundaries reject local values even on UTC hosts', () {
    expect(
      () => repository.toLocal(DateTime(2026), 'Europe/Riga'),
      throwsArgumentError,
    );
    for (final mode in TimeWindowMode.values) {
      expect(
        () => BuildTimeWindowUseCase(repository)(
          mode: mode,
          timezoneId: 'Europe/Riga',
          nowUtc: DateTime(2026),
          startLocal: local(2026, 1, 1, 12),
          endLocal: local(2026, 1, 1, 13),
          flexibilityMinutes: 30,
        ),
        throwsA(isA<TimeWindowValidationException>()),
      );
    }
  });

  test('known timezone validation rejects malformed and unknown zones', () {
    for (final zone in [
      'Unknown/Nowhere',
      ' Europe/Riga',
      'Europe/Riga\n',
      '+03:00',
      '',
    ]) {
      expect(repository.isValidTimezone(zone), isFalse, reason: zone);
    }
    expect(repository.isValidTimezone('Europe/Riga'), isTrue);
    expect(repository.isValidTimezone('UTC'), isTrue);
  });

  test('rejects nonexistent Riga user time in spring DST gap', () {
    final LocalTimeResolution result = repository.resolveLocal(
      date: LocalDate(2026, 3, 29),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.userStart,
    );

    expect(result.isValid, isFalse);
    expect(result.instantUtc, isNull);
  });

  test('ambiguous user start is early and end is late', () {
    final LocalTimeResolution start = repository.resolveLocal(
      date: LocalDate(2026, 10, 25),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.userStart,
    );
    final LocalTimeResolution end = repository.resolveLocal(
      date: LocalDate(2026, 10, 25),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.userEnd,
    );

    expect(start.wasAmbiguous, isTrue);
    expect(end.wasAmbiguous, isTrue);
    expect(start.instantUtc!.isBefore(end.instantUtc!), isTrue);
    expect(end.instantUtc!.difference(start.instantUtc!).inHours, 1);
  });

  test('opening gap shifts open forward and close backward', () {
    final LocalTimeResolution open = repository.resolveLocal(
      date: LocalDate(2026, 3, 29),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.openingStart,
    );
    final LocalTimeResolution close = repository.resolveLocal(
      date: LocalDate(2026, 3, 29),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.openingEnd,
    );

    expect(open.isValid, isTrue);
    expect(close.isValid, isTrue);
    expect(open.wasShifted, isTrue);
    expect(close.wasShifted, isTrue);
    expect(open.instantUtc!.isAfter(close.instantUtc!), isTrue);
  });

  test(
    'flexible window expands exactly and overnight local interval stays ordered',
    () {
      final BuildTimeWindowUseCase useCase = BuildTimeWindowUseCase(repository);
      final TimeWindow window = useCase(
        mode: TimeWindowMode.flexible,
        timezoneId: 'Europe/Riga',
        nowUtc: DateTime.utc(2026, 7, 20, 18),
        startLocal: local(2026, 7, 20, 23),
        endLocal: local(2026, 7, 21, 1),
        flexibilityMinutes: 30,
      );

      expect(window.startAtUtc.isBefore(window.endAtUtc), isTrue);
      expect(
        window.startAtUtc.difference(window.effectiveStartAtUtc).inMinutes,
        30,
      );
      expect(
        window.effectiveEndAtUtc.difference(window.endAtUtc).inMinutes,
        30,
      );
    },
  );

  test('anytime today resolves a fixed UTC end for the local Riga day', () {
    final BuildTimeWindowUseCase useCase = BuildTimeWindowUseCase(repository);
    final TimeWindow window = useCase(
      mode: TimeWindowMode.anytimeToday,
      timezoneId: 'Europe/Riga',
      nowUtc: DateTime.utc(2026, 7, 20, 10),
    );

    expect(window.startAtUtc, DateTime.utc(2026, 7, 20, 10));
    expect(window.endAtUtc, DateTime.utc(2026, 7, 20, 20, 59));
    expect(window.resolvedAtUtc, DateTime.utc(2026, 7, 20, 10));
  });
}
