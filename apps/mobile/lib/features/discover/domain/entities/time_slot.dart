import 'package:recharge/shared/primitives/time/utc_instant.dart';

class TimeSlot {
  TimeSlot({
    required this.slotId,
    required this.startAtUtc,
    required this.endAtUtc,
  }) {
    if (slotId.trim().isEmpty) throw ArgumentError.value(slotId, 'slotId');
    if (!startAtUtc.isBefore(endAtUtc)) {
      throw ArgumentError('startAtUtc must be before endAtUtc');
    }
  }

  final String slotId;
  final DateTime startAtUtc;
  final DateTime endAtUtc;

  Map<String, Object?> toMap() => <String, Object?>{
    'slot_id': slotId,
    'start_at_utc': startAtUtc.toUtc().toIso8601String(),
    'end_at_utc': endAtUtc.toUtc().toIso8601String(),
  };

  factory TimeSlot.fromMap(Map<String, Object?> map) => TimeSlot(
    slotId: map['slot_id']! as String,
    startAtUtc: UtcInstant.parse(map['start_at_utc']! as String).value,
    endAtUtc: UtcInstant.parse(map['end_at_utc']! as String).value,
  );
}
