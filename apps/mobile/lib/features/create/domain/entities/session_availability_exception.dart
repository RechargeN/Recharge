import 'session_schedule.dart';

/// Manual, closing-only override on top of the weekly schedule
/// (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §11.3). Never expands availability.
class SessionAvailabilityException {
  const SessionAvailabilityException({
    required this.id,
    required this.startDateLocal,
    required this.endDateLocal,
    required this.allDay,
    this.startMinuteLocal,
    this.endMinuteLocalExclusive,
    this.privateNote,
    required this.createdByUserId,
    required this.createdAtUtc,
  });

  final String id;
  final String startDateLocal;
  final String endDateLocal;
  final bool allDay;
  final int? startMinuteLocal;
  final int? endMinuteLocalExclusive;
  final String? privateNote;
  final String createdByUserId;
  final DateTime createdAtUtc;

  static const int maxActiveExceptions = 366;
  static const int maxPrivateNoteLength = 140;

  bool get isStructurallyValid {
    final SessionLocalDate? start = SessionLocalDate.tryParse(startDateLocal);
    final SessionLocalDate? end = SessionLocalDate.tryParse(endDateLocal);
    if (start == null || end == null || end < start) return false;
    if (id.trim().isEmpty || createdByUserId.trim().isEmpty) return false;
    if ((privateNote?.length ?? 0) > maxPrivateNoteLength) return false;
    if (allDay) return true;
    final int? s = startMinuteLocal;
    final int? e = endMinuteLocalExclusive;
    if (s == null || e == null) return false;
    return s >= 0 && s < 1440 && e > s && e <= 1440;
  }

  /// True if this exception closes the local interval
  /// `[candidateStartMinute, candidateEndMinute)` on [date].
  bool closes({
    required SessionLocalDate date,
    required int candidateStartMinute,
    required int candidateEndMinute,
  }) {
    final SessionLocalDate? start = SessionLocalDate.tryParse(startDateLocal);
    final SessionLocalDate? end = SessionLocalDate.tryParse(endDateLocal);
    if (start == null || end == null) return false;
    if (date < start || end < date) return false;
    if (allDay) return true;
    final int s = startMinuteLocal ?? 0;
    final int e = endMinuteLocalExclusive ?? 1440;
    return candidateStartMinute < e && s < candidateEndMinute;
  }

  SessionAvailabilityException copyWith({
    String? id,
    String? startDateLocal,
    String? endDateLocal,
    bool? allDay,
    int? startMinuteLocal,
    bool clearStartMinuteLocal = false,
    int? endMinuteLocalExclusive,
    bool clearEndMinuteLocalExclusive = false,
    String? privateNote,
    bool clearPrivateNote = false,
    String? createdByUserId,
    DateTime? createdAtUtc,
  }) => SessionAvailabilityException(
    id: id ?? this.id,
    startDateLocal: startDateLocal ?? this.startDateLocal,
    endDateLocal: endDateLocal ?? this.endDateLocal,
    allDay: allDay ?? this.allDay,
    startMinuteLocal: clearStartMinuteLocal
        ? null
        : (startMinuteLocal ?? this.startMinuteLocal),
    endMinuteLocalExclusive: clearEndMinuteLocalExclusive
        ? null
        : (endMinuteLocalExclusive ?? this.endMinuteLocalExclusive),
    privateNote: clearPrivateNote ? null : (privateNote ?? this.privateNote),
    createdByUserId: createdByUserId ?? this.createdByUserId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
}
