import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/local_date.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/features/discover/domain/usecases/build_time_window_usecase.dart';

void main() {
  final TimezoneRepositoryImpl repository = TimezoneRepositoryImpl();

  test('rejects nonexistent Riga user time in spring DST gap', () {
    final LocalTimeResolution result = repository.resolveLocal(
      date: const LocalDate(2026, 3, 29),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.userStart,
    );

    expect(result.isValid, isFalse);
    expect(result.instantUtc, isNull);
  });

  test('ambiguous user start is early and end is late', () {
    final LocalTimeResolution start = repository.resolveLocal(
      date: const LocalDate(2026, 10, 25),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.userStart,
    );
    final LocalTimeResolution end = repository.resolveLocal(
      date: const LocalDate(2026, 10, 25),
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
      date: const LocalDate(2026, 3, 29),
      minutesSinceMidnight: 3 * 60 + 30,
      timezoneId: 'Europe/Riga',
      policy: LocalBoundaryPolicy.openingStart,
    );
    final LocalTimeResolution close = repository.resolveLocal(
      date: const LocalDate(2026, 3, 29),
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
        startLocal: DateTime(2026, 7, 20, 23),
        endLocal: DateTime(2026, 7, 21, 1),
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
