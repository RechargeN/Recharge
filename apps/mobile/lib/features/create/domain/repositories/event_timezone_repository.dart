import '../entities/event_draft_data.dart';

class ResolvedEventLocalTime {
  const ResolvedEventLocalTime({
    required this.utc,
    required this.shifted,
    this.ambiguousLocalTime = false,
  });

  final DateTime utc;
  final bool shifted;

  /// True when the requested local wall-clock time occurred twice (DST
  /// overlap/"fall back") and [utc] was picked by [EventDstOverlapPolicy].
  /// Additive field — defaults to `false` so existing callers are unaffected.
  final bool ambiguousLocalTime;
}

class EventLocalTimeException implements Exception {
  const EventLocalTimeException(this.code);

  final String code;

  @override
  String toString() => 'EventLocalTimeException($code)';
}

abstract class EventTimezoneRepository {
  ResolvedEventLocalTime resolve({
    required String timezoneId,
    required int year,
    required int month,
    required int day,
    required int minuteOfDay,
    required EventDstGapPolicy gapPolicy,
    required EventDstOverlapPolicy overlapPolicy,
  });
}
