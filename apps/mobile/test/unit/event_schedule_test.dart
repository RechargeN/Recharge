import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/event_timezone_repository.dart';
import 'package:recharge/features/create/domain/usecases/build_event_content_body.dart';
import 'package:recharge/features/create/domain/usecases/materialize_event_schedule_usecase.dart';

void main() {
  final EventTimezoneRepository timezone = EventTimezoneRepositoryImpl();
  final MaterializeEventScheduleUseCase materialize =
      MaterializeEventScheduleUseCase(timezone);

  EventDraftData defaults() => EventDraftData.defaults(
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    timezoneId: 'Europe/Riga',
    currencyCode: 'EUR',
  );

  test('one-time Riga local time materializes to UTC', () {
    final List<EventOccurrenceDraft> result = materialize(
      defaults().copyWith(
        localStartDate: '2026-01-15',
        startMinute: 10 * 60,
        durationMinutes: 90,
      ),
    );

    expect(result, hasLength(1));
    expect(result.single.startAtUtc, DateTime.utc(2026, 1, 15, 8));
    expect(result.single.endAtUtc, DateTime.utc(2026, 1, 15, 9, 30));
  });

  test('all-day occurrence ends at next local midnight across DST', () {
    final List<EventOccurrenceDraft> result = materialize(
      defaults().copyWith(
        allDay: true,
        localStartDate: '2026-03-29',
        durationMinutes: 1440,
      ),
    );

    expect(result.single.startAtUtc, DateTime.utc(2026, 3, 28, 22));
    expect(result.single.endAtUtc, DateTime.utc(2026, 3, 29, 21));
    expect(
      result.single.endAtUtc.difference(result.single.startAtUtc),
      const Duration(hours: 23),
    );
  });

  test('weekly recurrence and exceptions are deterministic', () {
    final EventDraftData draft = defaults().copyWith(
      scheduleMode: EventScheduleMode.recurring,
      localStartDate: '2026-08-03',
      recurrence: const EventRecurrenceRuleDraft(
        frequency: EventRecurrenceFrequency.weekly,
        weekdays: <int>{1, 3},
        endMode: EventRecurrenceEndMode.occurrenceCount,
        occurrenceCount: 4,
        exceptionLocalDates: <String>{'2026-08-05'},
      ),
    );

    final List<EventOccurrenceDraft> first = materialize(draft);
    final List<EventOccurrenceDraft> second = materialize(draft);

    expect(first.map((EventOccurrenceDraft item) => item.localDate), <String>[
      '2026-08-03',
      '2026-08-10',
      '2026-08-12',
      '2026-08-17',
    ]);
    expect(
      second.map((EventOccurrenceDraft item) => item.id),
      first.map((EventOccurrenceDraft item) => item.id),
    );
  });

  test('DST overlap policy selects distinct UTC instants', () {
    final ResolvedEventLocalTime earlier = timezone.resolve(
      timezoneId: 'Europe/Riga',
      year: 2026,
      month: 10,
      day: 25,
      minuteOfDay: 3 * 60 + 30,
      gapPolicy: EventDstGapPolicy.shiftForward,
      overlapPolicy: EventDstOverlapPolicy.earlierOffset,
    );
    final ResolvedEventLocalTime later = timezone.resolve(
      timezoneId: 'Europe/Riga',
      year: 2026,
      month: 10,
      day: 25,
      minuteOfDay: 3 * 60 + 30,
      gapPolicy: EventDstGapPolicy.shiftForward,
      overlapPolicy: EventDstOverlapPolicy.laterOffset,
    );

    expect(later.utc.difference(earlier.utc), const Duration(hours: 1));
  });

  test('F2: moving a one-time Event keeps its occurrence and server id', () {
    final EventDraftData first = defaults().copyWith(
      localStartDate: '2026-11-10',
      startMinute: 18 * 60,
      durationMinutes: 120,
    );
    final EventOccurrenceDraft original = materialize(first).single;
    final EventDraftData published = first.copyWith(
      occurrences: <EventOccurrenceDraft>[original],
    );
    final EventOccurrenceDraft moved = materialize(
      published.copyWith(localStartDate: '2026-11-12', startMinute: 19 * 60),
    ).single;
    expect(moved.id, original.id);
    expect(moved.localDate, '2026-11-12');
    expect(moved.startAtUtc, DateTime.utc(2026, 11, 12, 17));
    expect(
      EventContentBodyMapper.serverOccurrenceId('loc_draft_f2', moved.id),
      EventContentBodyMapper.serverOccurrenceId('loc_draft_f2', original.id),
    );
  });

  test(
    'F2: multi-date dates stay identities; a replaced date is a new one',
    () {
      final EventDraftData first = defaults().copyWith(
        scheduleMode: EventScheduleMode.multiDate,
        multiDateLocalDates: <String>['2026-11-10', '2026-11-11'],
        startMinute: 18 * 60,
        durationMinutes: 60,
      );
      final List<EventOccurrenceDraft> original = materialize(first);
      final List<EventOccurrenceDraft> edited = materialize(
        first.copyWith(
          occurrences: original,
          multiDateLocalDates: <String>['2026-11-10', '2026-11-20'],
        ),
      );
      expect(edited.first.id, original.first.id, reason: 'kept date');
      expect(edited.last.id, isNot(original.last.id), reason: 'replaced date');
      final List<EventOccurrenceDraft> removed = materialize(
        first.copyWith(
          occurrences: original,
          multiDateLocalDates: <String>['2026-11-10'],
        ),
      );
      expect(removed.single.id, original.first.id);
    },
  );
}
