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
  bool intersectsTransition({
    required LocalDate date,
    required int startMinuteLocal,
    required int endMinuteLocal,
    required String timezoneId,
  }) {
    if (startMinuteLocal < 0 ||
        startMinuteLocal >= 1440 ||
        endMinuteLocal <= startMinuteLocal) {
      throw const EventLocalTimeException('invalid_local_minute');
    }
    // Validate calendar range before multiplying caller-supplied minutes.
    date.addDays(endMinuteLocal ~/ 1440);
    final location = _location(timezoneId);
    // A naive calendar scalar for comparison only, never a stored UTC instant.
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final start = midnight + startMinuteLocal * Duration.millisecondsPerMinute;
    final end = midnight + endMinuteLocal * Duration.millisecondsPerMinute;
    if (location.transitionAt.isEmpty) return false;
    var minOffset = 0;
    var maxOffset = 0;
    for (final zone in location.zones) {
      if (zone.offset < minOffset) minOffset = zone.offset;
      if (zone.offset > maxOffset) maxOffset = zone.offset;
    }
    // Only inspect transitions whose local ranges can touch this interval.
    // Work is bounded by relevant TZDB transitions, not by slot minutes.
    var low = 0;
    var high = location.transitionAt.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (location.transitionAt[middle] < start - maxOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    for (var index = low; index < location.transitionAt.length; index++) {
      final instant = location.transitionAt[index];
      if (instant > end - minOffset) break;
      final before = instant + location.timeZone(instant - 1).offset;
      final after = instant + location.timeZone(instant).offset;
      if (before == after) continue;
      final first = before < after ? before : after;
      final last = before > after ? before : after;
      // Gap/overlap is [first, last). Endpoints inside it also reject a
      // candidate; a candidate starting exactly at last is unambiguous.
      if (start < last && end >= first) return true;
    }
    return false;
  }

  timezone.Location _location(String timezoneId) {
    try {
      return timezone.getLocation(IanaTimeZone.parse(timezoneId).value);
    } on FormatException {
      throw const EventLocalTimeException('timezone_not_found');
    } on timezone.LocationNotFoundException {
      throw const EventLocalTimeException('timezone_not_found');
    }
  }

  int localMinuteAt({
    required DateTime instantUtc,
    required String timezoneId,
  }) {
    final local = timezone.TZDateTime.from(
      UtcInstant(instantUtc).value,
      _location(timezoneId),
    );
    return local.hour * 60 + local.minute;
  }

  @override
  LocalDate localDateAt({
    required DateTime instantUtc,
    required String timezoneId,
  }) {
    final instant = UtcInstant(instantUtc).value;
    final location = _location(timezoneId);
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
    final location = _location(timezoneId);
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
