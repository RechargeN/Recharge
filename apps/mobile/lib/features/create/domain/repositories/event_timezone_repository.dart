import '../entities/event_draft_data.dart';

class ResolvedEventLocalTime {
  const ResolvedEventLocalTime({required this.utc, required this.shifted});

  final DateTime utc;
  final bool shifted;
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
