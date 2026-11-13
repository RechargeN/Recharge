/// Local calendar date, independent of any timezone offset.
///
/// Weekly rules and exceptions are expressed in the listing's local time;
/// this type keeps that arithmetic free of `DateTime`'s implicit local/UTC
/// ambiguity.
class SessionLocalDate implements Comparable<SessionLocalDate> {
  const SessionLocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory SessionLocalDate.parse(String value) {
    final SessionLocalDate? parsed = tryParse(value);
    if (parsed == null) {
      throw const FormatException('Invalid local date');
    }
    return parsed;
  }

  static SessionLocalDate? tryParse(String value) {
    if (value.length != 10) return null;
    final DateTime? parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null) return null;
    return SessionLocalDate(parsed.year, parsed.month, parsed.day);
  }

  factory SessionLocalDate.fromDateTime(DateTime value) =>
      SessionLocalDate(value.year, value.month, value.day);

  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// ISO weekday: 1 = Monday .. 7 = Sunday.
  int get isoWeekday => DateTime.utc(year, month, day).weekday;

  SessionLocalDate addDays(int count) =>
      SessionLocalDate.fromDateTime(DateTime.utc(year, month, day + count));

  @override
  int compareTo(SessionLocalDate other) => DateTime.utc(
    year,
    month,
    day,
  ).compareTo(DateTime.utc(other.year, other.month, other.day));

  bool operator <=(SessionLocalDate other) => compareTo(other) <= 0;

  bool operator <(SessionLocalDate other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is SessionLocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}

/// One non-overlapping local time range on a specific ISO weekday.
class SessionWeeklyRule {
  const SessionWeeklyRule({
    required this.id,
    required this.isoWeekday,
    required this.startMinuteLocal,
    required this.endMinuteLocalExclusive,
  });

  final String id;

  /// 1 = Monday .. 7 = Sunday.
  final int isoWeekday;

  /// Minutes since local midnight, 0..1439.
  final int startMinuteLocal;

  /// Minutes since local midnight, exclusive, 1..1440.
  final int endMinuteLocalExclusive;

  bool get isStructurallyValid =>
      id.trim().isNotEmpty &&
      isoWeekday >= 1 &&
      isoWeekday <= 7 &&
      startMinuteLocal >= 0 &&
      startMinuteLocal < 1440 &&
      endMinuteLocalExclusive > startMinuteLocal &&
      endMinuteLocalExclusive <= 1440;

  int get durationMinutes => endMinuteLocalExclusive - startMinuteLocal;

  bool overlaps(SessionWeeklyRule other) {
    if (isoWeekday != other.isoWeekday) return false;
    return startMinuteLocal < other.endMinuteLocalExclusive &&
        other.startMinuteLocal < endMinuteLocalExclusive;
  }

  SessionWeeklyRule copyWith({
    String? id,
    int? isoWeekday,
    int? startMinuteLocal,
    int? endMinuteLocalExclusive,
  }) => SessionWeeklyRule(
    id: id ?? this.id,
    isoWeekday: isoWeekday ?? this.isoWeekday,
    startMinuteLocal: startMinuteLocal ?? this.startMinuteLocal,
    endMinuteLocalExclusive:
        endMinuteLocalExclusive ?? this.endMinuteLocalExclusive,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionWeeklyRule &&
      id == other.id &&
      isoWeekday == other.isoWeekday &&
      startMinuteLocal == other.startMinuteLocal &&
      endMinuteLocalExclusive == other.endMinuteLocalExclusive;

  @override
  int get hashCode =>
      Object.hash(id, isoWeekday, startMinuteLocal, endMinuteLocalExclusive);
}

/// Versioned weekly availability + slot generation parameters (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §11).
class SessionSchedule {
  const SessionSchedule({
    required this.scheduleRevision,
    this.dstPolicyVersion = 1,
    required this.slotDurationMinutes,
    this.bufferAfterSlotMinutes = 0,
    this.minNoticeMinutes = 0,
    required this.projectionWindowDays,
    this.weeklyRules = const <SessionWeeklyRule>[],
  });

  final int scheduleRevision;
  final int dstPolicyVersion;
  final int slotDurationMinutes;
  final int bufferAfterSlotMinutes;
  final int minNoticeMinutes;
  final int projectionWindowDays;
  final List<SessionWeeklyRule> weeklyRules;

  static const int maxRangesPerWeekday = 4;
  static const int maxActiveRanges = 28;
  static const int minSlotDurationMinutes = 30;
  static const int maxSlotDurationMinutes = 180;
  static const int maxBufferMinutes = 180;
  static const int maxNoticeMinutes = 10080;
  static const int minProjectionWindowDays = 1;
  static const int maxProjectionWindowDays = 90;
  static const int maxCandidatesPerMaterialization = 5000;

  bool get hasActiveWeekday => weeklyRules.isNotEmpty;

  bool get durationInRange =>
      slotDurationMinutes >= minSlotDurationMinutes &&
      slotDurationMinutes <= maxSlotDurationMinutes;

  bool get bufferInRange =>
      bufferAfterSlotMinutes >= 0 && bufferAfterSlotMinutes <= maxBufferMinutes;

  bool get noticeInRange =>
      minNoticeMinutes >= 0 && minNoticeMinutes <= maxNoticeMinutes;

  bool get projectionWindowInRange =>
      projectionWindowDays >= minProjectionWindowDays &&
      projectionWindowDays <= maxProjectionWindowDays;

  /// True if any two ranges on the same weekday overlap, or a weekday has
  /// more than [maxRangesPerWeekday] ranges (§11.1 rule 2, 4).
  bool get hasOverlappingRanges {
    final Map<int, List<SessionWeeklyRule>> byWeekday =
        <int, List<SessionWeeklyRule>>{};
    for (final SessionWeeklyRule rule in weeklyRules) {
      byWeekday
          .putIfAbsent(rule.isoWeekday, () => <SessionWeeklyRule>[])
          .add(rule);
    }
    for (final List<SessionWeeklyRule> rules in byWeekday.values) {
      if (rules.length > maxRangesPerWeekday) return true;
      for (int i = 0; i < rules.length; i++) {
        for (int j = i + 1; j < rules.length; j++) {
          if (rules[i].overlaps(rules[j])) return true;
        }
      }
    }
    return false;
  }

  bool get exceedsMaxActiveRanges => weeklyRules.length > maxActiveRanges;

  SessionSchedule copyWith({
    int? scheduleRevision,
    int? dstPolicyVersion,
    int? slotDurationMinutes,
    int? bufferAfterSlotMinutes,
    int? minNoticeMinutes,
    int? projectionWindowDays,
    List<SessionWeeklyRule>? weeklyRules,
  }) => SessionSchedule(
    scheduleRevision: scheduleRevision ?? this.scheduleRevision,
    dstPolicyVersion: dstPolicyVersion ?? this.dstPolicyVersion,
    slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
    bufferAfterSlotMinutes:
        bufferAfterSlotMinutes ?? this.bufferAfterSlotMinutes,
    minNoticeMinutes: minNoticeMinutes ?? this.minNoticeMinutes,
    projectionWindowDays: projectionWindowDays ?? this.projectionWindowDays,
    weeklyRules: weeklyRules ?? this.weeklyRules,
  );

  static const SessionSchedule empty = SessionSchedule(
    scheduleRevision: 0,
    slotDurationMinutes: 60,
    projectionWindowDays: 30,
  );
}
