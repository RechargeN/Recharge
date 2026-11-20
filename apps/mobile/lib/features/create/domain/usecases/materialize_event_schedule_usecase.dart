import '../../../../shared/primitives/time/local_date.dart';
import '../../../../shared/primitives/time/utc_instant.dart';
import '../entities/event_draft_data.dart';
import '../repositories/event_timezone_repository.dart';

class MaterializeEventScheduleUseCase {
  const MaterializeEventScheduleUseCase(this._timezoneRepository);

  final EventTimezoneRepository _timezoneRepository;

  LocalDate localDateAt({
    required DateTime instantUtc,
    required String timezoneId,
  }) => _timezoneRepository.localDateAt(
    instantUtc: instantUtc,
    timezoneId: timezoneId,
  );

  List<EventOccurrenceDraft> call(
    EventDraftData draft, {
    int maxProjectionCount = 180,
    DateTime? projectionNowUtc,
  }) {
    final now = UtcInstant(projectionNowUtc ?? DateTime.now().toUtc()).value;
    final rule = draft.recurrence;
    if (rule != null) {
      for (final exception in rule.exceptionLocalDates) {
        LocalDate.parse(exception);
      }
    }
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
        projectionNowUtc: now,
      ),
    };
    final Map<String, String> existingIds = <String, String>{
      for (final EventOccurrenceDraft value in draft.occurrences)
        value.localDate: value.id,
    };
    // D07: a one-time Event has exactly one occurrence; moving its date or
    // time is a reschedule of that occurrence, so it keeps its id (and with it
    // the server occurrence id, the bookings and their allocation). Multi-date
    // and recurring occurrences stay identified by their local date.
    final String? oneTimeId =
        draft.scheduleMode == EventScheduleMode.oneTime &&
            draft.occurrences.length == 1
        ? draft.occurrences.single.id
        : null;
    final EventRecurrenceRuleDraft? rule = draft.recurrence;
    final List<EventOccurrenceDraft> result = <EventOccurrenceDraft>[];
    for (final _LocalDate date in dates) {
      if (rule?.exceptionLocalDates.contains(date.toString()) ?? false) {
        continue;
      }
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
              oneTimeId ??
              existingIds[date.toString()] ??
              'loc_occ_${date.toString().replaceAll('-', '')}_${draft.startMinute}',
          localDate: date.toString(),
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
    // Preserve the existing 548 elapsed-day UTC projection cutoff policy.
    final horizonUtc = projectionNowUtc.add(const Duration(days: 548));
    final _LocalDate horizon = LocalDate(
      horizonUtc.year,
      horizonUtc.month,
      horizonUtc.day,
    );
    final _LocalDate? until = rule.endMode == EventRecurrenceEndMode.untilDate
        ? LocalDate.parse(rule.untilLocalDate ?? '')
        : null;
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
          !rule.exceptionLocalDates.contains(cursor.toString())) {
        result.add(cursor);
      }
      if (result.length >= targetCount ||
          cursor == horizon ||
          cursor == until) {
        break;
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

// Temporary name compatibility; final reference migration/removal belongs to M2-D.
typedef _LocalDate = LocalDate;

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;
