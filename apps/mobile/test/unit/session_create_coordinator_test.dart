import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/session_create_coordinator.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_price_disclosure.dart';
import 'package:recharge/features/create/domain/entities/session_schedule.dart';
import 'package:recharge/features/create/domain/usecases/materialize_session_schedule_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_session_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/build_session_public_projection_usecase.dart';
import 'package:recharge/features/create/domain/entities/session_validation_issue.dart';

void main() {
  final SessionCreateCoordinator coordinator = SessionCreateCoordinator(
    materializeSchedule: MaterializeSessionScheduleUseCase(
      EventTimezoneRepositoryImpl(),
    ),
  );

  CreateDraftEntity baseDraft() => CreateDraftEntity.defaults(
    organizerId: 'user_1',
    organizerEmail: 'user@example.com',
    organizerName: 'Sauna Owner',
    timezone: 'Europe/Riga',
    currency: 'EUR',
  ).copyWith(objectType: CreateObjectType.session, title: 'Sauna 1');

  test('ensureData seeds a default draft from the entity title/timezone', () {
    final SessionDraftData data = coordinator.ensureData(
      baseDraft(),
      timezoneId: 'Europe/Riga',
    );
    expect(data.resourceName, 'Sauna 1');
    expect(data.timezoneId, 'Europe/Riga');
    expect(data.maxPartySizeInRange, isTrue);
  });

  test('one explicit UTC clock governs offers and public freshness', () {
    final now = DateTime.utc(2026, 8, 24, 5);
    final session =
        SessionDraftData.defaults(
          resourceName: 'Sauna',
          timezoneId: 'Pacific/Honolulu',
        ).copyWith(
          schedule: const SessionSchedule(
            scheduleRevision: 1,
            slotDurationMinutes: 60,
            projectionWindowDays: 1,
            weeklyRules: [
              SessionWeeklyRule(
                id: 'r',
                isoWeekday: 7,
                startMinuteLocal: 1200,
                endMinuteLocalExclusive: 1260,
              ),
            ],
          ),
        );
    final value = baseDraft().copyWith(sessionData: session);
    final first = coordinator.buildPublicProjection(value, nowUtc: now);
    final second = coordinator.buildPublicProjection(value, nowUtc: now);
    expect(first.generatedAtUtc, now);
    expect(first.validUntilUtc, now.add(const Duration(minutes: 5)));
    expect(first.offers.single.startAtUtc, DateTime.utc(2026, 8, 24, 6));
    expect(second.offers.single.slotKey, first.offers.single.slotKey);
    expect(first.providerAvailabilityUnknown, isTrue);
    expect(
      () => coordinator.buildPublicProjection(value, nowUtc: DateTime(2026)),
      throwsArgumentError,
    );
    expect(
      () => const BuildSessionPublicProjectionUseCase()(
        internalProjections: [],
        scheduleRevision: 1,
        generatedAtUtc: DateTime(2026),
      ),
      throwsArgumentError,
    );
  });

  test(
    'confirmed but unknown timezone stays on draft and blocks readiness',
    () {
      final session = SessionDraftData.defaults(
        resourceName: 'Sauna',
        timezoneId: 'Unknown/Nowhere',
      ).copyWith(timezoneConfirmed: true);
      final value = baseDraft().copyWith(sessionData: session);
      final now = DateTime.utc(2026);
      final result = coordinator.materialize(value, nowUtc: now);
      expect(result.calendarFailure, SessionCalendarFailure.unknownTimezone);
      expect(
        coordinator.buildPublicProjection(value, nowUtc: now).offers,
        isEmpty,
      );
      final issues = coordinator.validate(
        value,
        nowUtc: now,
        context: const SessionExternalValidationContext(
          categoryAllowedForSession: true,
          hasCover: true,
          publisherEligible: true,
        ),
      );
      expect(
        issues
            .where((i) => i.code == SessionBlockingCode.timezoneInvalid)
            .single
            .isBlocking,
        isTrue,
      );
      expect(value.sessionData!.timezoneId, 'Unknown/Nowhere');
    },
  );

  test('applyWeeklyPreset replaces weekly rules atomically', () {
    final SessionDraftData data = coordinator.ensureData(
      baseDraft(),
      timezoneId: 'Europe/Riga',
    );
    final withRules = coordinator.applyWeeklyPreset(data, const [
      SessionWeeklyRule(
        id: 'r1',
        isoWeekday: 1,
        startMinuteLocal: 540,
        endMinuteLocalExclusive: 780,
      ),
    ]);
    expect(withRules.schedule.weeklyRules, hasLength(1));

    final replaced = coordinator.applyWeeklyPreset(withRules, const [
      SessionWeeklyRule(
        id: 'r2',
        isoWeekday: 2,
        startMinuteLocal: 600,
        endMinuteLocalExclusive: 720,
      ),
    ]);
    expect(replaced.schedule.weeklyRules, hasLength(1));
    expect(replaced.schedule.weeklyRules.single.id, 'r2');
  });

  test('addWeeklyRule/removeWeeklyRule mutate the rule list only', () {
    final SessionDraftData data = coordinator.ensureData(
      baseDraft(),
      timezoneId: 'Europe/Riga',
    );
    final added = coordinator.addWeeklyRule(
      data,
      const SessionWeeklyRule(
        id: 'r1',
        isoWeekday: 1,
        startMinuteLocal: 540,
        endMinuteLocalExclusive: 600,
      ),
    );
    expect(added.schedule.weeklyRules, hasLength(1));

    final removed = coordinator.removeWeeklyRule(added, 'r1');
    expect(removed.schedule.weeklyRules, isEmpty);
  });

  test('setSlotDuration/setBuffer/setNotice update only their own field', () {
    final SessionDraftData data = coordinator.ensureData(
      baseDraft(),
      timezoneId: 'Europe/Riga',
    );
    final tuned = coordinator
        .setSlotDuration(data, 90)
        .let(coordinator.setBuffer, 15)
        .let(coordinator.setNotice, 60);

    expect(tuned.schedule.slotDurationMinutes, 90);
    expect(tuned.schedule.bufferAfterSlotMinutes, 15);
    expect(tuned.schedule.minNoticeMinutes, 60);
  });

  test(
    'apply() mirrors typed data onto the shared envelope and increments revision',
    () {
      final CreateDraftEntity draft = baseDraft();
      final SessionDraftData data = coordinator
          .ensureData(draft, timezoneId: 'Europe/Riga')
          .copyWith(
            resourceName: 'Sauna Deluxe',
            price: const SessionPriceDisclosure(
              mode: SessionPricingMode.fixed,
              amount: SessionMoneyDraft(amountMinor: 2500, currencyCode: 'EUR'),
            ),
            externalBookingUrl: 'https://sauna-riga.lv/book',
            schedule: const SessionSchedule(
              scheduleRevision: 1,
              slotDurationMinutes: 45,
              projectionWindowDays: 30,
            ),
          );

      final CreateDraftEntity applied = coordinator.apply(draft, data);

      expect(applied.sessionData!.revision, 1);
      expect(applied.venueName, 'Sauna Deluxe');
      expect(applied.timezone, 'Europe/Riga');
      expect(applied.availabilityKind, CreateAvailabilityKind.none);
      expect(applied.durationMinutes, 45);
      expect(applied.isFree, isFalse);
      expect(applied.basePrice?.minorUnits, 2500);
      expect(applied.basePrice?.currency.value, 'EUR');
      expect(applied.currency, 'EUR');
      expect(applied.bookingLink, 'https://sauna-riga.lv/book');
      // Legacy per-type mechanism must not be (re)populated by the typed
      // writer (§6.1 "новый Session writer их не создаёт").
      expect(applied.scheduleSlots, isEmpty);
    },
  );

  test('validate() flags a missing draft as resourceMissing', () {
    final issues = coordinator.validate(
      baseDraft(),
      context: const SessionExternalValidationContext(
        categoryAllowedForSession: true,
        hasCover: true,
        publisherEligible: true,
      ),
    );
    expect(issues, isNotEmpty);
    expect(issues.every((i) => i.isBlocking), isTrue);
  });
}

extension _Let<T> on T {
  R let<A, R>(R Function(T, A) f, A arg) => f(this, arg);
}
