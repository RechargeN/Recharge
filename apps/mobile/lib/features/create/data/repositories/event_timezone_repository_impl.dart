import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../domain/entities/event_draft_data.dart';
import '../../domain/repositories/event_timezone_repository.dart';

class EventTimezoneRepositoryImpl implements EventTimezoneRepository {
  EventTimezoneRepositoryImpl() {
    if (!_initialized) {
      timezone_data.initializeTimeZones();
      _initialized = true;
    }
  }

  static bool _initialized = false;

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
    timezone.Location location;
    try {
      location = timezone.getLocation(timezoneId);
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
    return ResolvedEventLocalTime(utc: selected, shifted: shifted);
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
