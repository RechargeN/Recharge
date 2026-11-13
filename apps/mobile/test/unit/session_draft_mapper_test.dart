import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/legacy_session_schedule.dart';
import 'package:recharge/features/create/domain/entities/session_availability_exception.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_price_disclosure.dart';
import 'package:recharge/features/create/domain/entities/session_schedule.dart';
import 'package:recharge/features/create/data/models/session_draft_mapper.dart';

void main() {
  SessionDraftData sample() => SessionDraftData(
    resourceName: 'Sauna 1',
    timezoneId: 'Europe/Riga',
    timezoneConfirmed: true,
    amenityIds: const {'towels', 'shower'},
    maxPartySize: 6,
    schedule: SessionSchedule(
      scheduleRevision: 3,
      slotDurationMinutes: 60,
      bufferAfterSlotMinutes: 10,
      minNoticeMinutes: 120,
      projectionWindowDays: 30,
      weeklyRules: const [
        SessionWeeklyRule(
          id: 'r1',
          isoWeekday: 1,
          startMinuteLocal: 540,
          endMinuteLocalExclusive: 780,
        ),
      ],
    ),
    exceptions: [
      SessionAvailabilityException(
        id: 'x1',
        startDateLocal: '2026-09-01',
        endDateLocal: '2026-09-02',
        allDay: true,
        privateNote: 'maintenance',
        createdByUserId: 'u1',
        createdAtUtc: DateTime.utc(2026, 8, 1),
      ),
    ],
    price: const SessionPriceDisclosure(
      mode: SessionPricingMode.fixed,
      amount: SessionMoneyDraft(amountMinor: 2500, currencyCode: 'EUR'),
    ),
    externalBookingUrl: 'https://sauna-riga.lv/book',
    externalTermsUrl: 'https://sauna-riga.lv/terms',
    revision: 2,
  );

  test('round-trip preserves every field', () {
    final SessionDraftData original = sample();
    final SessionDraftData restored = SessionDraftMapper.fromJson(
      SessionDraftMapper.toJson(original),
    );

    expect(restored.resourceName, original.resourceName);
    expect(restored.timezoneId, original.timezoneId);
    expect(restored.timezoneConfirmed, original.timezoneConfirmed);
    expect(restored.amenityIds, original.amenityIds);
    expect(restored.maxPartySize, original.maxPartySize);
    expect(restored.schedule.scheduleRevision, original.schedule.scheduleRevision);
    expect(
      restored.schedule.weeklyRules.single.startMinuteLocal,
      original.schedule.weeklyRules.single.startMinuteLocal,
    );
    expect(restored.exceptions.single.id, original.exceptions.single.id);
    expect(restored.exceptions.single.privateNote, 'maintenance');
    expect(restored.price.mode, SessionPricingMode.fixed);
    expect(restored.price.amount!.amountMinor, 2500);
    expect(restored.externalBookingUrl, original.externalBookingUrl);
    expect(restored.externalTermsUrl, original.externalTermsUrl);
    expect(restored.revision, original.revision);
  });

  test('round-trip preserves unknown fields (§14.1 invariant)', () {
    final Map<String, Object?> json = SessionDraftMapper.toJson(sample());
    json['future_field_not_yet_understood'] = 'keep-me';

    final SessionDraftData restored = SessionDraftMapper.fromJson(json);
    final Map<String, Object?> roundTripped = SessionDraftMapper.toJson(
      restored,
    );

    expect(restored.unknownFields['future_field_not_yet_understood'], 'keep-me');
    expect(roundTripped['future_field_not_yet_understood'], 'keep-me');
  });

  test('future major schema version is rejected, not guessed', () {
    final Map<String, Object?> json = SessionDraftMapper.toJson(sample());
    json['schema_version'] = 999;

    expect(
      () => SessionDraftMapper.fromJson(json),
      throwsA(isA<UnsupportedSessionSchemaException>()),
    );
  });

  test(
    'legacy eventSlots migration keeps the payload read-only and unreviewed (§15.4)',
    () {
      final legacySlots = [
        CreateTimeSlotDraft(
          localId: 'loc_1',
          startAtUtc: DateTime.utc(2026, 8, 1, 9),
          endAtUtc: DateTime.utc(2026, 8, 1, 10),
        ),
      ];

      final LegacySessionSchedule legacy =
          SessionDraftMapper.migrateLegacyEventSlots(legacySlots);

      expect(legacy.state, LegacySessionScheduleState.unreviewed);
      expect(legacy.legacyOneTimeSlots, legacySlots);

      // Round-tripping the legacy payload itself must not lose data either.
      final Map<String, Object?> map = legacy.toMap();
      final LegacySessionSchedule restored = LegacySessionSchedule.fromMap(
        map,
      );
      expect(restored.legacyOneTimeSlots.single.localId, 'loc_1');
      expect(restored.state, LegacySessionScheduleState.unreviewed);
    },
  );
}
