import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/event_timezone_repository.dart';
import 'package:recharge/features/create/domain/usecases/build_event_content_body.dart';
import 'package:recharge/features/create/domain/usecases/materialize_event_schedule_usecase.dart';
import 'package:recharge/features/create/application/event_create_coordinator.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

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

  test(
    'all materialized calendar inputs fail closed instead of normalizing',
    () {
      for (final invalid in [
        '2026-02-30',
        '2026-04-31',
        '0000-01-01',
        '2026-1-01',
        '',
      ]) {
        expect(
          () => materialize(defaults().copyWith(localStartDate: invalid)),
          throwsFormatException,
        );
        expect(
          () => materialize(
            defaults().copyWith(
              scheduleMode: EventScheduleMode.multiDate,
              multiDateLocalDates: ['2026-01-01', invalid],
            ),
          ),
          throwsFormatException,
        );
        expect(
          () => materialize(
            defaults().copyWith(
              scheduleMode: EventScheduleMode.recurring,
              localStartDate: '2026-01-01',
              recurrence: EventRecurrenceRuleDraft(
                frequency: EventRecurrenceFrequency.daily,
                endMode: EventRecurrenceEndMode.untilDate,
                untilLocalDate: invalid,
              ),
            ),
          ),
          throwsFormatException,
        );
        expect(
          () => materialize(
            defaults().copyWith(
              recurrence: EventRecurrenceRuleDraft(
                frequency: EventRecurrenceFrequency.daily,
                exceptionLocalDates: {invalid},
              ),
            ),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => materialize(
          defaults().copyWith(
            scheduleMode: EventScheduleMode.recurring,
            recurrence: const EventRecurrenceRuleDraft(
              frequency: EventRecurrenceFrequency.daily,
              endMode: EventRecurrenceEndMode.untilDate,
            ),
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'projection clock requires UTC and keeps the inclusive UTC horizon policy',
    () {
      expect(
        () => materialize(defaults(), projectionNowUtc: DateTime(2026)),
        throwsArgumentError,
      );
      final now = DateTime.utc(2026, 1, 1);
      final horizon = now.add(const Duration(days: 548));
      final localDate = horizon.toIso8601String().substring(0, 10);
      final draft = defaults().copyWith(
        scheduleMode: EventScheduleMode.recurring,
        localStartDate: localDate,
        recurrence: const EventRecurrenceRuleDraft(
          frequency: EventRecurrenceFrequency.daily,
        ),
      );
      final results = materialize(draft, projectionNowUtc: now);
      expect(results.map((e) => e.localDate), [localDate]);
      expect(
        () => materialize(draft, projectionNowUtc: DateTime.utc(9999)),
        throwsFormatException,
      );
    },
  );

  test('daily monthly and yearly recurrence retain their feature policies', () {
    List<String> dates(EventDraftData draft, {DateTime? now}) => materialize(
      draft,
      projectionNowUtc: now ?? DateTime.utc(2026),
    ).map((e) => e.localDate).toList();
    final recurring = defaults().copyWith(
      scheduleMode: EventScheduleMode.recurring,
      localStartDate: '2026-01-31',
    );
    for (final policy in EventMonthlyDayPolicy.values) {
      final result = dates(
        recurring.copyWith(
          recurrence: EventRecurrenceRuleDraft(
            frequency: EventRecurrenceFrequency.monthly,
            monthlyDayPolicy: policy,
            endMode: EventRecurrenceEndMode.occurrenceCount,
            occurrenceCount: 3,
          ),
        ),
      );
      expect(
        result,
        policy == EventMonthlyDayPolicy.useLastDay
            ? ['2026-01-31', '2026-02-28', '2026-03-31']
            : ['2026-01-31', '2026-03-31', '2026-05-31'],
      );
    }
    expect(
      dates(
        recurring.copyWith(
          localStartDate: '2026-01-01',
          recurrence: const EventRecurrenceRuleDraft(
            frequency: EventRecurrenceFrequency.daily,
            interval: 2,
            endMode: EventRecurrenceEndMode.untilDate,
            untilLocalDate: '2026-01-07',
            exceptionLocalDates: {'2026-01-03'},
          ),
        ),
      ),
      ['2026-01-01', '2026-01-05', '2026-01-07'],
    );
    expect(
      dates(
        recurring.copyWith(
          localStartDate: '2024-02-29',
          recurrence: const EventRecurrenceRuleDraft(
            frequency: EventRecurrenceFrequency.yearly,
            endMode: EventRecurrenceEndMode.occurrenceCount,
            occurrenceCount: 2,
          ),
        ),
        now: DateTime.utc(2027),
      ),
      ['2024-02-29', '2028-02-29'],
    );
  });

  test(
    'multi-date ordering deduplication and persisted occurrence IDs stay stable',
    () {
      final existing = EventOccurrenceDraft(
        id: 'persisted-id',
        localDate: '2026-02-28',
        startAtUtc: DateTime.utc(2026, 2, 28),
        endAtUtc: DateTime.utc(2026, 3, 1),
      );
      final draft = defaults().copyWith(
        scheduleMode: EventScheduleMode.multiDate,
        multiDateLocalDates: ['2026-03-01', '2026-02-28', '2026-03-01'],
        occurrences: [existing],
      );
      final first = materialize(draft);
      final again = materialize(draft.copyWith(occurrences: first));
      expect(first.map((e) => e.localDate), ['2026-02-28', '2026-03-01']);
      expect(first.first.id, 'persisted-id');
      expect(again.map((e) => e.id), first.map((e) => e.id));
    },
  );

  test(
    'Event gap shift/reject and 25-hour all-day policy remain deterministic',
    () {
      ResolvedEventLocalTime gap(EventDstGapPolicy policy) => timezone.resolve(
        timezoneId: 'Europe/Riga',
        year: 2026,
        month: 3,
        day: 29,
        minuteOfDay: 210,
        gapPolicy: policy,
        overlapPolicy: EventDstOverlapPolicy.earlierOffset,
      );
      final shifted = gap(EventDstGapPolicy.shiftForward);
      expect(shifted.shifted, isTrue);
      expect(shifted.utc, DateTime.utc(2026, 3, 29, 1, 30));
      expect(
        () => gap(EventDstGapPolicy.reject),
        throwsA(
          isA<EventLocalTimeException>().having(
            (e) => e.code,
            'code',
            'dst_gap_rejected',
          ),
        ),
      );
      final allDay = materialize(
        defaults().copyWith(
          allDay: true,
          localStartDate: '2026-10-25',
          durationMinutes: 1440,
        ),
      ).single;
      expect(
        allDay.endAtUtc.difference(allDay.startAtUtc),
        const Duration(hours: 25),
      );
    },
  );

  test('direct resolver rejects malformed calendar minute and zone input', () {
    ResolvedEventLocalTime resolve({
      int year = 2026,
      int month = 1,
      int day = 1,
      int minute = 0,
      String zone = 'Europe/Riga',
    }) => timezone.resolve(
      timezoneId: zone,
      year: year,
      month: month,
      day: day,
      minuteOfDay: minute,
      gapPolicy: EventDstGapPolicy.shiftForward,
      overlapPolicy: EventDstOverlapPolicy.earlierOffset,
    );
    final invalid = throwsA(isA<EventLocalTimeException>());
    for (final minute in [-1, 1440, 9007199254740991]) {
      expect(() => resolve(minute: minute), invalid);
    }
    expect(() => resolve(month: 2, day: 30), invalid);
    expect(() => resolve(year: 0), invalid);
    expect(() => resolve(year: 10000), invalid);
    for (final zone in ['Europe/Riga ', 'Unknown/Nowhere', '+03:00', '']) {
      expect(() => resolve(zone: zone), invalid);
    }
    expect(resolve().utc.isUtc, isTrue);
  });

  test('calendar overflow is contained by the existing Event coordinator', () {
    final base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Host',
    );
    final event = defaults().copyWith(
      localStartDate: '9999-12-31',
      allDay: true,
      durationMinutes: 1440,
    );
    expect(() => materialize(event), throwsRangeError);
    final coordinator = EventCreateCoordinator(
      materializeSchedule: materialize,
    );
    final result = coordinator.apply(base, event);
    expect(result.eventData!.localStartDate, '9999-12-31');
    expect(result.eventData!.occurrences, isEmpty);
    expect(result.startDateTimeUtc, isNull);
    expect(result.endDateTimeUtc, isNull);
  });

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
