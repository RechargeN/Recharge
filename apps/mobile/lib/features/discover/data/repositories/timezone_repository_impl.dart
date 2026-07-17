import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/local_date.dart';
import '../../domain/repositories/timezone_repository.dart';

class TimezoneRepositoryImpl implements TimezoneRepository {
  TimezoneRepositoryImpl() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
  }

  static bool _initialized = false;

  @override
  bool isValidTimezone(String timezoneId) {
    try {
      tz.getLocation(timezoneId);
      return true;
    } on tz.LocationNotFoundException {
      return false;
    }
  }

  @override
  LocalDateTimeValue toLocal(DateTime instantUtc, String timezoneId) {
    final tz.TZDateTime local = tz.TZDateTime.from(
      instantUtc.toUtc(),
      tz.getLocation(timezoneId),
    );
    return LocalDateTimeValue(
      date: LocalDate(local.year, local.month, local.day),
      minutesSinceMidnight: local.hour * 60 + local.minute,
      weekday: local.weekday,
    );
  }

  @override
  LocalTimeResolution resolveLocal({
    required LocalDate date,
    required int minutesSinceMidnight,
    required String timezoneId,
    required LocalBoundaryPolicy policy,
  }) {
    if (minutesSinceMidnight < 0 || minutesSinceMidnight > 1439) {
      return const LocalTimeResolution(
        instantUtc: null,
        isValid: false,
        wasAmbiguous: false,
        wasShifted: false,
      );
    }
    tz.Location location;
    try {
      location = tz.getLocation(timezoneId);
    } on tz.LocationNotFoundException {
      return const LocalTimeResolution(
        instantUtc: null,
        isValid: false,
        wasAmbiguous: false,
        wasShifted: false,
      );
    }

    final List<DateTime> candidates = _candidates(
      location,
      date,
      minutesSinceMidnight,
    );
    if (candidates.isNotEmpty) {
      final bool chooseLate =
          policy == LocalBoundaryPolicy.userEnd ||
          policy == LocalBoundaryPolicy.openingStart;
      return LocalTimeResolution(
        instantUtc: chooseLate ? candidates.last : candidates.first,
        isValid: true,
        wasAmbiguous: candidates.length > 1,
        wasShifted: false,
      );
    }

    if (policy == LocalBoundaryPolicy.userStart ||
        policy == LocalBoundaryPolicy.userEnd) {
      return const LocalTimeResolution(
        instantUtc: null,
        isValid: false,
        wasAmbiguous: false,
        wasShifted: false,
      );
    }

    final int direction = policy == LocalBoundaryPolicy.openingStart ? 1 : -1;
    final DateTime naive = date.asUtcMidnight.add(
      Duration(minutes: minutesSinceMidnight),
    );
    for (int delta = 1; delta <= 180; delta++) {
      final DateTime shifted = naive.add(Duration(minutes: direction * delta));
      final LocalDate shiftedDate = LocalDate(
        shifted.year,
        shifted.month,
        shifted.day,
      );
      final List<DateTime> shiftedCandidates = _candidates(
        location,
        shiftedDate,
        shifted.hour * 60 + shifted.minute,
      );
      if (shiftedCandidates.isNotEmpty) {
        return LocalTimeResolution(
          instantUtc: policy == LocalBoundaryPolicy.openingStart
              ? shiftedCandidates.last
              : shiftedCandidates.first,
          isValid: true,
          wasAmbiguous: shiftedCandidates.length > 1,
          wasShifted: true,
        );
      }
    }
    return const LocalTimeResolution(
      instantUtc: null,
      isValid: false,
      wasAmbiguous: false,
      wasShifted: false,
    );
  }

  List<DateTime> _candidates(
    tz.Location location,
    LocalDate date,
    int minutesSinceMidnight,
  ) {
    final int hour = minutesSinceMidnight ~/ 60;
    final int minute = minutesSinceMidnight % 60;
    final DateTime naive = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final Set<int> offsets = location.zones
        .map((tz.TimeZone zone) => zone.offset)
        .toSet();
    final List<DateTime> result = <DateTime>[];
    for (final int offset in offsets) {
      final DateTime candidate = DateTime.fromMillisecondsSinceEpoch(
        naive.millisecondsSinceEpoch - offset,
        isUtc: true,
      );
      final tz.TZDateTime local = tz.TZDateTime.from(candidate, location);
      if (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day &&
          local.hour == hour &&
          local.minute == minute) {
        result.add(candidate);
      }
    }
    result.sort();
    return result.toSet().toList(growable: false)..sort();
  }
}
