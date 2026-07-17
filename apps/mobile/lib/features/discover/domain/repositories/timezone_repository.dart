import '../entities/local_date.dart';

enum LocalBoundaryPolicy { userStart, userEnd, openingStart, openingEnd }

class LocalDateTimeValue {
  const LocalDateTimeValue({
    required this.date,
    required this.minutesSinceMidnight,
    required this.weekday,
  });

  final LocalDate date;
  final int minutesSinceMidnight;
  final int weekday;
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
