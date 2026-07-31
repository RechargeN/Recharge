import '../entities/event_draft_data.dart';
import '../repositories/event_timezone_repository.dart';

class MaterializeEventScheduleUseCase {
  const MaterializeEventScheduleUseCase(this._timezoneRepository);

  final EventTimezoneRepository _timezoneRepository;

  List<EventOccurrenceDraft> call(
    EventDraftData draft, {
    int maxProjectionCount = 180,
    DateTime? projectionNowUtc,
  }) {
    final List<_LocalDate> dates = switch (draft.scheduleMode) {
      EventScheduleMode.oneTime => <_LocalDate>[
        _LocalDate.parse(draft.localStartDate),
      ],
      EventScheduleMode.multiDate =>
        draft.multiDateLocalDates.map(_LocalDate.parse).toSet().toList()
          ..sort(),
      EventScheduleMode.recurring => _recurringDates(
        draft,
        maxProjectionCount: maxProjectionCount,
        projectionNowUtc: projectionNowUtc ?? DateTime.now().toUtc(),
      ),
    };
    final Map<String, String> existingIds = <String, String>{
      for (final EventOccurrenceDraft value in draft.occurrences)
        value.localDate: value.id,
    };
    final EventRecurrenceRuleDraft? rule = draft.recurrence;
    final List<EventOccurrenceDraft> result = <EventOccurrenceDraft>[];
    for (final _LocalDate date in dates) {
      if (rule?.exceptionLocalDates.contains(date.iso) ?? false) continue;
      final ResolvedEventLocalTime start = _timezoneRepository.resolve(
        timezoneId: draft.timezoneId,
        year: date.year,
        month: date.month,
        day: date.day,
        minuteOfDay: draft.allDay ? 0 : draft.startMinute,
        gapPolicy: rule?.dstGapPolicy ?? EventDstGapPolicy.shiftForward,
        overlapPolicy:
            rule?.dstOverlapPolicy ?? EventDstOverlapPolicy.earlierOffset,
      );
      final DateTime end;
      if (draft.allDay) {
        final _LocalDate endDate = date.addDays(draft.durationMinutes ~/ 1440);
        end = _timezoneRepository
            .resolve(
              timezoneId: draft.timezoneId,
              year: endDate.year,
              month: endDate.month,
              day: endDate.day,
              minuteOfDay: 0,
              gapPolicy: rule?.dstGapPolicy ?? EventDstGapPolicy.shiftForward,
              overlapPolicy:
                  rule?.dstOverlapPolicy ?? EventDstOverlapPolicy.earlierOffset,
            )
            .utc;
      } else {
        end = start.utc.add(Duration(minutes: draft.durationMinutes));
      }
      result.add(
        EventOccurrenceDraft(
          id:
              existingIds[date.iso] ??
              'loc_occ_${date.iso.replaceAll('-', '')}_${draft.startMinute}',
          localDate: date.iso,
          startAtUtc: start.utc,
          endAtUtc: end,
          shiftedForDst: start.shifted,
        ),
      );
    }
    result.sort(
      (EventOccurrenceDraft left, EventOccurrenceDraft right) =>
          left.startAtUtc.compareTo(right.startAtUtc),
    );
    return List<EventOccurrenceDraft>.unmodifiable(result);
  }

  List<_LocalDate> _recurringDates(
    EventDraftData draft, {
    required int maxProjectionCount,
    required DateTime projectionNowUtc,
  }) {
    final EventRecurrenceRuleDraft? rule = draft.recurrence;
    if (rule == null) return const <_LocalDate>[];
    final _LocalDate anchor = _LocalDate.parse(draft.localStartDate);
    final _LocalDate horizon = _LocalDate.fromDateTime(
      projectionNowUtc.add(const Duration(days: 548)),
    );
    final _LocalDate? until =
        rule.endMode != EventRecurrenceEndMode.untilDate ||
            rule.untilLocalDate == null
        ? null
        : _LocalDate.tryParse(rule.untilLocalDate!);
    final int targetCount =
        rule.endMode == EventRecurrenceEndMode.occurrenceCount
        ? (rule.occurrenceCount ?? 0)
        : maxProjectionCount;
    if (targetCount <= 0 || rule.interval <= 0) return const <_LocalDate>[];

    final List<_LocalDate> result = <_LocalDate>[];
    _LocalDate cursor = anchor;
    while (result.length < targetCount && cursor.compareTo(horizon) <= 0) {
      if (until != null && cursor.compareTo(until) > 0) break;
      if (_matches(anchor, cursor, rule) &&
          !rule.exceptionLocalDates.contains(cursor.iso)) {
        result.add(cursor);
      }
      cursor = cursor.addDays(1);
    }
    return result;
  }

  bool _matches(
    _LocalDate anchor,
    _LocalDate candidate,
    EventRecurrenceRuleDraft rule,
  ) {
    final int days = candidate.daysSince(anchor);
    if (days < 0) return false;
    return switch (rule.frequency) {
      EventRecurrenceFrequency.daily => days % rule.interval == 0,
      EventRecurrenceFrequency.weekly =>
        (days ~/ 7) % rule.interval == 0 &&
            (rule.weekdays.isEmpty
                ? candidate.weekday == anchor.weekday
                : rule.weekdays.contains(candidate.weekday)),
      EventRecurrenceFrequency.monthly => _matchesMonthly(
        anchor,
        candidate,
        rule,
      ),
      EventRecurrenceFrequency.yearly =>
        (candidate.year - anchor.year) % rule.interval == 0 &&
            candidate.month == anchor.month &&
            candidate.day == anchor.day,
    };
  }

  bool _matchesMonthly(
    _LocalDate anchor,
    _LocalDate candidate,
    EventRecurrenceRuleDraft rule,
  ) {
    final int monthDelta =
        (candidate.year - anchor.year) * 12 + candidate.month - anchor.month;
    if (monthDelta < 0 || monthDelta % rule.interval != 0) return false;
    if (candidate.day == anchor.day) return true;
    return rule.monthlyDayPolicy == EventMonthlyDayPolicy.useLastDay &&
        anchor.day > _daysInMonth(candidate.year, candidate.month) &&
        candidate.day == _daysInMonth(candidate.year, candidate.month);
  }
}

class _LocalDate implements Comparable<_LocalDate> {
  const _LocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory _LocalDate.parse(String value) {
    final _LocalDate? parsed = tryParse(value);
    if (parsed == null) throw const FormatException('Invalid local date');
    return parsed;
  }

  static _LocalDate? tryParse(String value) {
    final DateTime? parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null || value.length != 10) return null;
    return _LocalDate(parsed.year, parsed.month, parsed.day);
  }

  factory _LocalDate.fromDateTime(DateTime value) =>
      _LocalDate(value.year, value.month, value.day);

  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  int get weekday => DateTime.utc(year, month, day).weekday;

  _LocalDate addDays(int count) =>
      _LocalDate.fromDateTime(DateTime.utc(year, month, day + count));

  int daysSince(_LocalDate other) => DateTime.utc(
    year,
    month,
    day,
  ).difference(DateTime.utc(other.year, other.month, other.day)).inDays;

  @override
  int compareTo(_LocalDate other) => DateTime.utc(
    year,
    month,
    day,
  ).compareTo(DateTime.utc(other.year, other.month, other.day));

  @override
  bool operator ==(Object other) =>
      other is _LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;
