import '../../../../shared/primitives/time/utc_instant.dart';

enum CreateAvailabilityKind { eventSlots, openingHours, none }

class CreateTimeSlotDraft {
  CreateTimeSlotDraft({
    required this.localId,
    required this.startAtUtc,
    required this.endAtUtc,
  }) {
    UtcInstant(startAtUtc);
    UtcInstant(endAtUtc);
    if (localId.trim().isEmpty) throw ArgumentError.value(localId, 'localId');
    if (!startAtUtc.isBefore(endAtUtc)) {
      throw ArgumentError('startAtUtc must be before endAtUtc');
    }
  }

  final String localId;
  final DateTime startAtUtc;
  final DateTime endAtUtc;

  CreateTimeSlotDraft copyWith({String? localId}) => CreateTimeSlotDraft(
    localId: localId ?? this.localId,
    startAtUtc: startAtUtc,
    endAtUtc: endAtUtc,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'local_id': localId,
    'start_at_utc': UtcInstant(startAtUtc).toString(),
    'end_at_utc': UtcInstant(endAtUtc).toString(),
  };

  factory CreateTimeSlotDraft.fromMap(Map<String, Object?> map) {
    final id = map['local_id'];
    final start = map['start_at_utc'];
    final end = map['end_at_utc'];
    if (id is! String ||
        id.trim().isEmpty ||
        start is! String ||
        end is! String) {
      throw const FormatException('Incomplete stored Create time slot');
    }
    final startUtc = UtcInstant.parse(start).value;
    final endUtc = UtcInstant.parse(end).value;
    if (!startUtc.isBefore(endUtc)) {
      throw const FormatException('create_slot_duration_invalid');
    }
    return CreateTimeSlotDraft(
      localId: id,
      startAtUtc: startUtc,
      endAtUtc: endUtc,
    );
  }
}

class CreateOpeningHoursDraftRule {
  const CreateOpeningHoursDraftRule({
    this.dayOfWeek,
    this.exceptionDateIso,
    required this.isClosedAllDay,
    this.openMinutesSinceLocalMidnight,
    this.closeMinutesSinceLocalMidnight,
  });

  final int? dayOfWeek;
  final String? exceptionDateIso;
  final bool isClosedAllDay;
  final int? openMinutesSinceLocalMidnight;
  final int? closeMinutesSinceLocalMidnight;

  Map<String, Object?> toMap() => <String, Object?>{
    'day_of_week': dayOfWeek,
    'exception_date_iso': exceptionDateIso,
    'is_closed_all_day': isClosedAllDay,
    'open_minutes': openMinutesSinceLocalMidnight,
    'close_minutes': closeMinutesSinceLocalMidnight,
  };

  factory CreateOpeningHoursDraftRule.fromMap(Map<String, Object?> map) =>
      CreateOpeningHoursDraftRule(
        dayOfWeek: (map['day_of_week'] as num?)?.toInt(),
        exceptionDateIso: map['exception_date_iso'] as String?,
        isClosedAllDay: (map['is_closed_all_day'] as bool?) ?? false,
        openMinutesSinceLocalMidnight: (map['open_minutes'] as num?)?.toInt(),
        closeMinutesSinceLocalMidnight: (map['close_minutes'] as num?)?.toInt(),
      );
}
