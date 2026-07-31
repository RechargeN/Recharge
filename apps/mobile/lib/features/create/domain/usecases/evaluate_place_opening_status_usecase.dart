import '../entities/place_draft_data.dart';

enum PlaceOpeningState { open, closed, unknown }

class EvaluatePlaceOpeningStatusUseCase {
  const EvaluatePlaceOpeningStatusUseCase();

  PlaceOpeningState call(PlaceDraftData place, DateTime localDateTime) {
    if (_operationallyClosed(place.operationalStatus, localDateTime)) {
      return PlaceOpeningState.closed;
    }
    final PlaceHoursDraft hours = place.hours;
    return switch (hours.mode) {
      null || PlaceHoursMode.unknown => PlaceOpeningState.unknown,
      PlaceHoursMode.seasonal => PlaceOpeningState.unknown,
      PlaceHoursMode.alwaysOpen => _alwaysOpenState(hours, localDateTime),
      PlaceHoursMode.regular => _regularState(hours, localDateTime),
    };
  }

  static PlaceOpeningState _alwaysOpenState(
    PlaceHoursDraft hours,
    DateTime localDateTime,
  ) {
    final OpeningException? exception = _exceptionFor(
      hours,
      _dateKey(localDateTime),
    );
    if (exception == null) return PlaceOpeningState.open;
    if (exception.kind == OpeningExceptionKind.closedAllDay) {
      return PlaceOpeningState.closed;
    }
    return _periodsContain(
          exception.periods,
          localDateTime.weekday,
          localDateTime.hour * 60 + localDateTime.minute,
          includePreviousDayOvernight: false,
        )
        ? PlaceOpeningState.open
        : PlaceOpeningState.closed;
  }

  static PlaceOpeningState _regularState(
    PlaceHoursDraft hours,
    DateTime localDateTime,
  ) {
    final String today = _dateKey(localDateTime);
    final OpeningException? todayException = _exceptionFor(hours, today);
    if (todayException != null) {
      if (todayException.kind == OpeningExceptionKind.closedAllDay) {
        return PlaceOpeningState.closed;
      }
      return _periodsContain(
            todayException.periods,
            localDateTime.weekday,
            localDateTime.hour * 60 + localDateTime.minute,
            includePreviousDayOvernight: false,
          )
          ? PlaceOpeningState.open
          : PlaceOpeningState.closed;
    }
    final DateTime yesterday = localDateTime.subtract(const Duration(days: 1));
    final OpeningException? yesterdayException = _exceptionFor(
      hours,
      _dateKey(yesterday),
    );
    final List<LocalOpeningPeriod> previousSource =
        yesterdayException?.kind == OpeningExceptionKind.customHours
        ? yesterdayException!.periods
        : (yesterdayException?.kind == OpeningExceptionKind.closedAllDay
              ? const <LocalOpeningPeriod>[]
              : hours.weeklyPeriods);
    final int minute = localDateTime.hour * 60 + localDateTime.minute;
    final bool openToday = hours.weeklyPeriods.any(
      (LocalOpeningPeriod period) =>
          period.dayOfWeek == localDateTime.weekday &&
          minute >= period.openMinute &&
          (period.closesNextDay || minute < period.closeMinute),
    );
    final bool openFromYesterday = previousSource.any(
      (LocalOpeningPeriod period) =>
          period.dayOfWeek == yesterday.weekday &&
          period.closesNextDay &&
          minute < period.closeMinute,
    );
    return openToday || openFromYesterday
        ? PlaceOpeningState.open
        : PlaceOpeningState.closed;
  }

  static bool _periodsContain(
    List<LocalOpeningPeriod> periods,
    int weekday,
    int minute, {
    required bool includePreviousDayOvernight,
  }) {
    if (periods.any(
      (LocalOpeningPeriod period) =>
          period.dayOfWeek == weekday &&
          minute >= period.openMinute &&
          (period.closesNextDay || minute < period.closeMinute),
    )) {
      return true;
    }
    if (!includePreviousDayOvernight) return false;
    final int previousWeekday = weekday == 1 ? 7 : weekday - 1;
    return periods.any(
      (LocalOpeningPeriod period) =>
          period.dayOfWeek == previousWeekday &&
          period.closesNextDay &&
          minute < period.closeMinute,
    );
  }

  static bool _operationallyClosed(
    PlaceOperationalStatusDraft status,
    DateTime localDateTime,
  ) {
    if (status.status == PlaceOperationalStatus.permanentlyClosed) return true;
    if (status.status != PlaceOperationalStatus.temporarilyClosed ||
        status.closedFromLocalDate == null) {
      return false;
    }
    final String date = _dateKey(localDateTime);
    if (date.compareTo(status.closedFromLocalDate!) < 0) return false;
    final String? until = status.closedUntilLocalDate;
    return until == null || date.compareTo(until) <= 0;
  }

  static OpeningException? _exceptionFor(
    PlaceHoursDraft hours,
    String localDate,
  ) {
    for (final OpeningException exception in hours.exceptions) {
      if (exception.localDate == localDate) return exception;
    }
    return null;
  }

  static String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
