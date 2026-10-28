import '../entities/local_date.dart';
import '../entities/time_window.dart';
import '../repositories/timezone_repository.dart';

/// L4.5: why a time window cannot be built; the UI turns the code into text.
enum TimeWindowIssue {
  unknownTimezone,
  dayEnded,
  boundsRequired,
  nonexistentLocalTime,
  endBeforeStart,
  invalidTravelContext,
  serviceUnavailable,
}

class TimeWindowValidationException implements Exception {
  const TimeWindowValidationException(this.issue);
  final TimeWindowIssue issue;
}

class BuildTimeWindowUseCase {
  const BuildTimeWindowUseCase(this._timezoneRepository);

  final TimezoneRepository _timezoneRepository;

  TimeWindow call({
    required TimeWindowMode mode,
    required String timezoneId,
    required DateTime nowUtc,
    DateTime? startLocal,
    DateTime? endLocal,
    int flexibilityMinutes = 0,
  }) {
    if (!_timezoneRepository.isValidTimezone(timezoneId)) {
      throw const TimeWindowValidationException(
        TimeWindowIssue.unknownTimezone,
      );
    }
    if (mode == TimeWindowMode.anytimeToday) {
      final LocalDateTimeValue localNow = _timezoneRepository.toLocal(
        nowUtc,
        timezoneId,
      );
      final LocalTimeResolution end = _timezoneRepository.resolveLocal(
        date: localNow.date,
        minutesSinceMidnight: 23 * 60 + 59,
        timezoneId: timezoneId,
        policy: LocalBoundaryPolicy.userEnd,
      );
      if (!end.isValid || !nowUtc.isBefore(end.instantUtc!)) {
        throw const TimeWindowValidationException(TimeWindowIssue.dayEnded);
      }
      return TimeWindow(
        startAtUtc: nowUtc.toUtc(),
        endAtUtc: end.instantUtc!,
        timezoneId: timezoneId,
        mode: mode,
        flexibilityMinutes: 0,
        resolvedAtUtc: nowUtc.toUtc(),
      );
    }
    if (startLocal == null || endLocal == null) {
      throw const TimeWindowValidationException(TimeWindowIssue.boundsRequired);
    }
    final LocalTimeResolution start = _timezoneRepository.resolveLocal(
      date: LocalDate(startLocal.year, startLocal.month, startLocal.day),
      minutesSinceMidnight: startLocal.hour * 60 + startLocal.minute,
      timezoneId: timezoneId,
      policy: LocalBoundaryPolicy.userStart,
    );
    final LocalTimeResolution end = _timezoneRepository.resolveLocal(
      date: LocalDate(endLocal.year, endLocal.month, endLocal.day),
      minutesSinceMidnight: endLocal.hour * 60 + endLocal.minute,
      timezoneId: timezoneId,
      policy: LocalBoundaryPolicy.userEnd,
    );
    if (!start.isValid || !end.isValid) {
      throw const TimeWindowValidationException(
        TimeWindowIssue.nonexistentLocalTime,
      );
    }
    if (!start.instantUtc!.isBefore(end.instantUtc!)) {
      throw const TimeWindowValidationException(TimeWindowIssue.endBeforeStart);
    }
    return TimeWindow(
      startAtUtc: start.instantUtc!,
      endAtUtc: end.instantUtc!,
      timezoneId: timezoneId,
      mode: mode,
      flexibilityMinutes: mode == TimeWindowMode.flexible
          ? flexibilityMinutes
          : 0,
      resolvedAtUtc: nowUtc.toUtc(),
    );
  }
}
