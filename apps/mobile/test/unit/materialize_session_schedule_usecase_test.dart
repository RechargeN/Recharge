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

  test('same revision and input produce the same slotKey (§11.5, SES-AC-13)', () {
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
  });

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
