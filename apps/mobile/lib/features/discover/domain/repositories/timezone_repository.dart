import 'package:recharge/shared/primitives/time/local_date.dart';

enum LocalBoundaryPolicy { userStart, userEnd, openingStart, openingEnd }

class LocalDateTimeValue implements Comparable<LocalDateTimeValue> {
  LocalDateTimeValue({
    required this.date,
    required this.minutesSinceMidnight,
    required int weekday,
  }) {
    if (minutesSinceMidnight < 0 || minutesSinceMidnight > 1439) {
      throw RangeError.range(
        minutesSinceMidnight,
        0,
        1439,
        'minutesSinceMidnight',
      );
    }
    if (weekday != date.weekday) {
      throw ArgumentError.value(
        weekday,
        'weekday',
        'Must match the local date',
      );
    }
  }

  final LocalDate date;
  final int minutesSinceMidnight;
  int get weekday => date.weekday;

  /// Wall-clock calendar arithmetic; no host timezone or elapsed-time meaning.
  LocalDateTimeValue addMinutes(int minutes) {
    const maxCalendarMinutes = 9999 * 366 * 1440;
    if (minutes < -maxCalendarMinutes || minutes > maxCalendarMinutes) {
      throw RangeError.value(minutes, 'minutes');
    }
    final total = minutesSinceMidnight + minutes;
    final minute = total % 1440;
    final nextDate = date.addDays((total - minute) ~/ 1440);
    return LocalDateTimeValue(
      date: nextDate,
      minutesSinceMidnight: minute,
      weekday: nextDate.weekday,
    );
  }

  @override
  int compareTo(LocalDateTimeValue other) {
    final days = date.compareTo(other.date);
    return days == 0
        ? minutesSinceMidnight.compareTo(other.minutesSinceMidnight)
        : days;
  }
}

class LocalTimeResolution {
  const LocalTimeResolution({
    required this.instantUtc,
    required this.isValid,
    required this.wasAmbiguous,
    required this.wasShifted,
  });

  final DateTime? instantUtc;
  final bool isValid;
  final bool wasAmbiguous;
  final bool wasShifted;
}

abstract class TimezoneRepository {
  bool isValidTimezone(String timezoneId);

  LocalDateTimeValue toLocal(DateTime instantUtc, String timezoneId);

  LocalTimeResolution resolveLocal({
    required LocalDate date,
    required int minutesSinceMidnight,
    required String timezoneId,
    required LocalBoundaryPolicy policy,
  });
}
