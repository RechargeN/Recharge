import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../domain/entities/event_draft_data.dart';
import '../../domain/repositories/event_timezone_repository.dart';
import '../../../../shared/primitives/time/local_date.dart';
import '../../../../shared/primitives/time/iana_time_zone.dart';
import '../../../../shared/primitives/time/utc_instant.dart';

class EventTimezoneRepositoryImpl implements EventTimezoneRepository {
  EventTimezoneRepositoryImpl() {
    if (!_initialized) {
      timezone_data.initializeTimeZones();
      _initialized = true;
    }
  }

  static bool _initialized = false;

  @override
  LocalDate localDateAt({
    required DateTime instantUtc,
    required String timezoneId,
  }) {
    final instant = UtcInstant(instantUtc).value;
    timezone.Location location;
    try {
      location = timezone.getLocation(IanaTimeZone.parse(timezoneId).value);
    } on FormatException {
      throw const EventLocalTimeException('timezone_not_found');
    } on timezone.LocationNotFoundException {
      throw const EventLocalTimeException('timezone_not_found');
    }
    final local = timezone.TZDateTime.from(instant, location);
    try {
      return LocalDate(local.year, local.month, local.day);
    } on FormatException {
      throw const EventLocalTimeException('invalid_local_date');
    }
  }

  @override
  ResolvedEventLocalTime resolve({
    required String timezoneId,
    required int year,
    required int month,
    required int day,
    required int minuteOfDay,
    required EventDstGapPolicy gapPolicy,
    required EventDstOverlapPolicy overlapPolicy,
  }) {
    try {
      LocalDate(year, month, day);
    } on FormatException {
      throw const EventLocalTimeException('invalid_local_date');
    }
    if (minuteOfDay < 0 || minuteOfDay > 1439) {
      throw const EventLocalTimeException('invalid_local_minute');
    }
    timezone.Location location;
    try {
      location = timezone.getLocation(IanaTimeZone.parse(timezoneId).value);
    } on FormatException {
      throw const EventLocalTimeException('timezone_not_found');
    } on timezone.LocationNotFoundException {
      throw const EventLocalTimeException('timezone_not_found');
    }
    final int hour = minuteOfDay ~/ 60;
    final int minute = minuteOfDay % 60;
    final timezone.TZDateTime normalized = timezone.TZDateTime(
      location,
      year,
      month,
      day,
      hour,
      minute,
    );
    final bool shifted = !_sameLocal(
      normalized,
      year,
      month,
      day,
      hour,
      minute,
    );
    if (shifted && gapPolicy == EventDstGapPolicy.reject) {
      throw const EventLocalTimeException('dst_gap_rejected');
    }

    final List<DateTime> candidates =
        <DateTime>{
            normalized.toUtc(),
            for (final int deltaMinutes in const <int>[
              -120,
              -60,
              -30,
              30,
              60,
              120,
            ])
              normalized.toUtc().add(Duration(minutes: deltaMinutes)),
          }.where((DateTime candidate) {
            final timezone.TZDateTime local = timezone.TZDateTime.from(
              candidate,
              location,
            );
            return _sameLocal(local, year, month, day, hour, minute);
          }).toList()
          ..sort();

    final DateTime selected = candidates.isEmpty
        ? normalized.toUtc()
        : overlapPolicy == EventDstOverlapPolicy.earlierOffset
        ? candidates.first
        : candidates.last;
    return ResolvedEventLocalTime(
      utc: selected,
      shifted: shifted,
      ambiguousLocalTime: candidates.length > 1,
    );
  }

  bool _sameLocal(
    timezone.TZDateTime value,
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) =>
      value.year == year &&
      value.month == month &&
      value.day == day &&
      value.hour == hour &&
      value.minute == minute;
}
