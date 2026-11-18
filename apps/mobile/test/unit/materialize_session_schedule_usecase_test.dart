import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/session_availability_exception.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_price_disclosure.dart';
import 'package:recharge/features/create/domain/entities/session_schedule.dart';
import 'package:recharge/features/create/domain/entities/session_slot_projection.dart';
import 'package:recharge/features/create/domain/repositories/event_timezone_repository.dart';
import 'package:recharge/features/create/domain/usecases/materialize_session_schedule_usecase.dart';

void main() {
  final EventTimezoneRepository timezone = EventTimezoneRepositoryImpl();
  final MaterializeSessionScheduleUseCase materialize =
      MaterializeSessionScheduleUseCase(timezone);

  SessionDraftData draft({
    required List<SessionWeeklyRule> weeklyRules,
    int slotDurationMinutes = 60,
    int bufferAfterSlotMinutes = 0,
    int minNoticeMinutes = 0,
    int projectionWindowDays = 30,
    List<SessionAvailabilityException> exceptions = const [],
    String timezoneId = 'Europe/Riga',
  }) => SessionDraftData(
    resourceName: 'Sauna 1',
    timezoneId: timezoneId,
    timezoneConfirmed: true,
    maxPartySize: 4,
    schedule: SessionSchedule(
      scheduleRevision: 1,
      slotDurationMinutes: slotDurationMinutes,
      bufferAfterSlotMinutes: bufferAfterSlotMinutes,
      minNoticeMinutes: minNoticeMinutes,
      projectionWindowDays: projectionWindowDays,
      weeklyRules: weeklyRules,
    ),
    price: SessionPriceDisclosure.free,
    externalBookingUrl: 'https://example.com/book',
    exceptions: exceptions,
  );

  test('weekly rule with buffer produces spaced candidate starts', () {
    // Monday 2026-08-24 (Riga, no DST transition nearby) 09:00-13:00,
    // duration 60, buffer 10 -> 09:00, 10:10, 11:20 (§11.1 example).
    final result = materialize(
      listingId: 'listing_1',
      draft: draft(
        weeklyRules: const [
          SessionWeeklyRule(
            id: 'r1',
            isoWeekday: 1,
            startMinuteLocal: 9 * 60,
            endMinuteLocalExclusive: 13 * 60,
          ),
        ],
        bufferAfterSlotMinutes: 10,
      ),
      nowUtc: DateTime.utc(2026, 8, 24, 0),
    );

    final firstDay = result.projections
        .where((p) => p.localDate == '2026-08-24')
        .toList();
    expect(firstDay, hasLength(3));
    expect(firstDay[0].startAtUtc, DateTime.utc(2026, 8, 24, 6)); // 09:00 EEST
    expect(firstDay[1].startAtUtc, DateTime.utc(2026, 8, 24, 7, 10));
    expect(firstDay[2].startAtUtc, DateTime.utc(2026, 8, 24, 8, 20));
    expect(
      firstDay.every(
        (p) => p.internalStatus == SessionProjectionStatus.offeredBySchedule,
      ),
      isTrue,
    );
  });

  test(
    'projection starts on listing local date on both sides of UTC midnight',
    () {
      final cases = [
        (
          'Pacific/Honolulu',
          DateTime.utc(2026, 8, 24, 5),
          7,
          1200,
          '2026-08-23',
          DateTime.utc(2026, 8, 24, 6),
        ),
        (
          'Pacific/Kiritimati',
          DateTime.utc(2026, 12, 31, 12),
          5,
          540,
          '2027-01-01',
          DateTime.utc(2026, 12, 31, 19),
        ),
      ];
      for (final c in cases) {
        final value = draft(
          timezoneId: c.$1,
          projectionWindowDays: 1,
          weeklyRules: [
            SessionWeeklyRule(
              id: 'r',
              isoWeekday: c.$3,
              startMinuteLocal: c.$4,
              endMinuteLocalExclusive: c.$4 + 60,
            ),
          ],
        );
        final result = materialize(
          listingId: 'listing',
          draft: value,
          nowUtc: c.$2,
        );
        expect(result.calendarFailure, isNull);
        expect(result.offeredCandidates, hasLength(1));
        final slot = result.offeredCandidates.single;
        expect(slot.localDate, c.$5);
        expect(slot.startAtUtc, c.$6);
        expect(
          slot.slotKey,
          computeSessionSlotKey(
            listingId: 'listing',
            scheduleRevision: 1,
            localDate: c.$5,
            startMinuteLocal: c.$4,
            timezoneId: c.$1,
          ),
        );
      }
    },
  );

  test(
    'projection spans exactly local calendar days across DST and year rollover',
    () {
      final rules = [
        for (var day = 1; day <= 7; day++)
          SessionWeeklyRule(
            id: 'r$day',
            isoWeekday: day,
            startMinuteLocal: 540,
            endMinuteLocalExclusive: 600,
          ),
      ];
      for (final c in [
        (
          DateTime.utc(2026, 3, 28, 22),
          ['2026-03-29', '2026-03-30', '2026-03-31'],
        ),
        (
          DateTime.utc(2026, 10, 24, 21),
          ['2026-10-25', '2026-10-26', '2026-10-27'],
        ),
        (
          DateTime.utc(2026, 12, 31, 22),
          ['2027-01-01', '2027-01-02', '2027-01-03'],
        ),
      ]) {
        final result = materialize(
          listingId: 'listing',
          nowUtc: c.$1,
          draft: draft(weeklyRules: rules, projectionWindowDays: 3),
        );
        expect(result.projections.map((p) => p.localDate), c.$2);
        expect(result.offeredCandidates, hasLength(3));
      }
    },
  );

  test('calendar failures are typed and never yield partial public offers', () {
    final rules = [
      const SessionWeeklyRule(
        id: 'r',
        isoWeekday: 1,
        startMinuteLocal: 540,
        endMinuteLocalExclusive: 600,
      ),
    ];
    final invalidZone = materialize(
      listingId: 'listing',
      nowUtc: DateTime.utc(2026),
      draft: draft(weeklyRules: rules, timezoneId: 'Unknown/Nowhere'),
    );
    expect(invalidZone.calendarFailure, SessionCalendarFailure.unknownTimezone);
    expect(invalidZone.projections, isEmpty);
    expect(invalidZone.offeredCandidates, isEmpty);
    final invalidRange = materialize(
      listingId: 'listing',
      nowUtc: DateTime.utc(9999, 12, 31, 12),
      draft: draft(weeklyRules: rules),
    );
    expect(
      invalidRange.calendarFailure,
      SessionCalendarFailure.unsupportedDateRange,
    );
    expect(invalidRange.projections, isEmpty);
    expect(
      () => materialize(
        listingId: 'listing',
        nowUtc: DateTime(2026),
        draft: draft(weeklyRules: rules),
      ),
      throwsArgumentError,
    );
  });

  test(
    'closing exceptions use strict shared date semantics without changing boundaries',
    () {
      SessionAvailabilityException exception(String first, String last) =>
          SessionAvailabilityException(
            id: 'x',
            startDateLocal: first,
            endDateLocal: last,
            allDay: false,
            startMinuteLocal: 540,
            endMinuteLocalExclusive: 600,
            createdByUserId: 'u',
            createdAtUtc: DateTime.utc(2026),
          );
      for (final invalid in ['2026-02-30', '2026-1-01', '0000-01-01']) {
        expect(exception(invalid, invalid).isStructurallyValid, isFalse);
      }
      final value = exception('2026-02-28', '2026-03-01');
      expect(value.isStructurallyValid, isTrue);
      expect(
        value.closes(
          date: SessionLocalDate(2026, 3, 1),
          candidateStartMinute: 590,
          candidateEndMinute: 650,
        ),
        isTrue,
      );
      expect(
        value.closes(
          date: SessionLocalDate(2026, 3, 1),
          candidateStartMinute: 600,
          candidateEndMinute: 660,
        ),
        isFalse,
      );
      expect(
        value.closes(
          date: SessionLocalDate(2026, 3, 2),
          candidateStartMinute: 540,
          candidateEndMinute: 600,
        ),
        isFalse,
      );
    },
  );

  test('DST gap on 2026-03-29 is skipped, not shifted', () {
    // Riga clocks jump 03:00 -> 04:00; a slot starting exactly at 03:00
    // local does not exist and must be fail-closed skipped (§11.4). Window
    // narrowed to the one week containing the transition Sunday so exactly
    // one candidate is generated.
    final result = materialize(
      listingId: 'listing_1',
      draft: draft(
        weeklyRules: const [
          SessionWeeklyRule(
            id: 'r1',
            isoWeekday: 7, // Sunday
            startMinuteLocal: 3 * 60,
            endMinuteLocalExclusive: 3 * 60 + 30,
          ),
        ],
        slotDurationMinutes: 30,
        projectionWindowDays: 7,
      ),
      nowUtc: DateTime.utc(2026, 3, 23), // Monday before the transition
    );

    final gapSlot = result.projections.singleWhere(
      (p) => p.localDate == '2026-03-29',
    );
    expect(
      gapSlot.internalStatus,
      SessionProjectionStatus.dstTransitionSkipped,
    );
    expect(result.offeredCandidates, isEmpty);
  });

  test('DST overlap on 2026-10-25 is skipped, not duplicated', () {
    // Riga clocks fall back; local 03:00-03:59 occurs twice. Session policy
    // skips ambiguous slots rather than picking earlierOffset (§11.4).
    final result = materialize(
      listingId: 'listing_1',
      draft: draft(
        weeklyRules: const [
          SessionWeeklyRule(
            id: 'r1',
            isoWeekday: 7,
            startMinuteLocal: 3 * 60,
            endMinuteLocalExclusive: 3 * 60 + 30,
          ),
        ],
        slotDurationMinutes: 30,
        projectionWindowDays: 7,
      ),
      nowUtc: DateTime.utc(2026, 10, 19), // Monday before the transition
    );

    expect(result.projections, hasLength(1));
    expect(
      result.projections.single.internalStatus,
      SessionProjectionStatus.dstTransitionSkipped,
    );
  });

  test('minNoticeMinutes excludes near-term candidates from public offers', () {
    final result = materialize(
      listingId: 'listing_1',
      draft: draft(
        weeklyRules: const [
          SessionWeeklyRule(
            id: 'r1',
            isoWeekday: 1,
            startMinuteLocal: 9 * 60,
            endMinuteLocalExclusive: 10 * 60,
          ),
        ],
        minNoticeMinutes: 24 * 60,
        projectionWindowDays: 7,
      ),
      nowUtc: DateTime.utc(2026, 8, 24, 5, 59), // 08:59 Riga, < 24h notice
    );

    expect(result.projections, hasLength(1));
    expect(
      result.projections.single.internalStatus,
      SessionProjectionStatus.insideNoticeWindow,
    );
    expect(result.offeredCandidates, isEmpty);
  });

  test('closing exception blocks the candidate without deleting the rule', () {
    final result = materialize(
      listingId: 'listing_1',
      draft: draft(
        weeklyRules: const [
          SessionWeeklyRule(
            id: 'r1',
            isoWeekday: 1,
            startMinuteLocal: 9 * 60,
            endMinuteLocalExclusive: 10 * 60,
          ),
        ],
        projectionWindowDays: 7,
        exceptions: [
          SessionAvailabilityException(
            id: 'x1',
            startDateLocal: '2026-08-24',
            endDateLocal: '2026-08-24',
            allDay: true,
            createdByUserId: 'u1',
            createdAtUtc: DateTime.utc(2026, 8, 1),
          ),
        ],
      ),
      nowUtc: DateTime.utc(2026, 8, 24, 0),
    );

    expect(result.projections, hasLength(1));
    expect(
      result.projections.single.internalStatus,
      SessionProjectionStatus.blockedByCreator,
    );
    expect(result.offeredCandidates, isEmpty);
  });

  test(
    'same revision and input produce the same slotKey (§11.5, SES-AC-13)',
    () {
      final a = materialize(
        listingId: 'listing_1',
        draft: draft(
          weeklyRules: const [
            SessionWeeklyRule(
              id: 'r1',
              isoWeekday: 1,
              startMinuteLocal: 540,
              endMinuteLocalExclusive: 600,
            ),
          ],
          projectionWindowDays: 7,
        ),
        nowUtc: DateTime.utc(2026, 8, 24, 0),
      );
      final b = materialize(
        listingId: 'listing_1',
        draft: draft(
          weeklyRules: const [
            SessionWeeklyRule(
              id: 'different_local_id',
              isoWeekday: 1,
              startMinuteLocal: 540,
              endMinuteLocalExclusive: 600,
            ),
          ],
          projectionWindowDays: 7,
        ),
        nowUtc: DateTime.utc(2026, 8, 24, 0),
      );

      expect(a.projections.single.slotKey, b.projections.single.slotKey);
    },
  );

  test('candidate cap is fail-closed, not silently truncated', () {
    final result = materialize(
      listingId: 'listing_1',
      draft: draft(
        weeklyRules: [
          for (int weekday = 1; weekday <= 7; weekday++)
            SessionWeeklyRule(
              id: 'r$weekday',
              isoWeekday: weekday,
              startMinuteLocal: 0,
              endMinuteLocalExclusive: 1440,
            ),
        ],
        slotDurationMinutes: 30,
        projectionWindowDays: 1000, // deliberately beyond the validated max
      ),
      nowUtc: DateTime.utc(2026, 1, 1),
    );

    expect(result.candidateCapExceeded, isTrue);
    expect(
      result.projections.length,
      lessThanOrEqualTo(SessionSchedule.maxCandidatesPerMaterialization),
    );
  });
}
