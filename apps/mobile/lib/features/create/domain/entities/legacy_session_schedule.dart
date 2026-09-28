import '../../domain/entities/create_availability.dart';

enum LegacySessionScheduleState { unreviewed, supersededByWeeklySchedule }

/// Read-only compatibility payload for a Session draft created before
/// `SessionSchedule` existed, when the generic `eventSlots` mechanism was
/// the only way to declare time (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §15.4).
///
/// Never guessed into a weekly pattern; kept verbatim until the Creator
/// explicitly builds a `SessionSchedule`, and never written into the public
/// listing projection.
class LegacySessionSchedule {
  const LegacySessionSchedule({
    required this.sourceSchemaVersion,
    this.legacyOneTimeSlots = const <CreateTimeSlotDraft>[],
    this.state = LegacySessionScheduleState.unreviewed,
  });

  final int sourceSchemaVersion;
  final List<CreateTimeSlotDraft> legacyOneTimeSlots;
  final LegacySessionScheduleState state;

  LegacySessionSchedule copyWith({
    int? sourceSchemaVersion,
    List<CreateTimeSlotDraft>? legacyOneTimeSlots,
    LegacySessionScheduleState? state,
  }) => LegacySessionSchedule(
    sourceSchemaVersion: sourceSchemaVersion ?? this.sourceSchemaVersion,
    legacyOneTimeSlots: legacyOneTimeSlots ?? this.legacyOneTimeSlots,
    state: state ?? this.state,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'source_schema_version': sourceSchemaVersion,
    'legacy_one_time_slots': legacyOneTimeSlots
        .map((CreateTimeSlotDraft slot) => slot.toMap())
        .toList(growable: false),
    'state': state.name,
  };

  factory LegacySessionSchedule.fromMap(Map<String, Object?> map) {
    final List<Object?> rawSlots =
        (map['legacy_one_time_slots'] as List<Object?>?) ?? const <Object?>[];
    return LegacySessionSchedule(
      sourceSchemaVersion: (map['source_schema_version'] as num?)?.toInt() ?? 1,
      legacyOneTimeSlots: rawSlots
          .map(
            (Object? value) =>
                CreateTimeSlotDraft.fromMap(value! as Map<String, Object?>),
          )
          .toList(growable: false),
      state: LegacySessionScheduleState.values.firstWhere(
        (LegacySessionScheduleState value) => value.name == map['state'],
        orElse: () => LegacySessionScheduleState.unreviewed,
      ),
    );
  }
}
