import '../domain/entities/create_availability.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/session_availability_exception.dart';
import '../domain/entities/session_draft_data.dart';
import '../domain/entities/session_price_disclosure.dart';
import '../domain/entities/session_schedule.dart';
import '../domain/entities/session_slot_projection.dart';
import '../domain/entities/session_validation_issue.dart';
import '../domain/usecases/build_session_public_projection_usecase.dart';
import '../domain/usecases/materialize_session_schedule_usecase.dart';
import '../domain/usecases/validate_session_draft_usecase.dart';

/// Coordinates `SessionDraftData` inside the common `CreateDraftEntity`
/// envelope, mirroring the pattern already used by `EventCreateCoordinator`
/// / `RouteCreateCoordinator` (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §12,
/// §14). Business logic lives here and in the domain usecases it wraps —
/// presentation only sends intents and renders returned state (rule 1
/// AGENTS.md).
class SessionCreateCoordinator {
  const SessionCreateCoordinator({
    required MaterializeSessionScheduleUseCase materializeSchedule,
    ValidateSessionDraftUseCase validateDraft =
        const ValidateSessionDraftUseCase(),
    BuildSessionPublicProjectionUseCase buildPublicProjection =
        const BuildSessionPublicProjectionUseCase(),
  }) : _materializeSchedule = materializeSchedule,
       _validateDraft = validateDraft,
       _buildPublicProjection = buildPublicProjection;

  final MaterializeSessionScheduleUseCase _materializeSchedule;
  final ValidateSessionDraftUseCase _validateDraft;
  final BuildSessionPublicProjectionUseCase _buildPublicProjection;

  SessionDraftData ensureData(
    CreateDraftEntity draft, {
    required String timezoneId,
  }) =>
      draft.sessionData ??
      SessionDraftData.defaults(
        resourceName: draft.title,
        timezoneId: timezoneId,
      );

  SessionScheduleMaterializationResult materialize(
    CreateDraftEntity draft, {
    DateTime? nowUtc,
  }) {
    final SessionDraftData? session = draft.sessionData;
    if (session == null) {
      return const SessionScheduleMaterializationResult(
        projections: <SessionSlotProjection>[],
        candidateCapExceeded: false,
      );
    }
    return _materializeSchedule(
      listingId: draft.id,
      draft: session,
      nowUtc: nowUtc,
    );
  }

  PublicSessionScheduleProjection buildPublicProjection(
    CreateDraftEntity draft, {
    DateTime? nowUtc,
  }) {
    final SessionScheduleMaterializationResult result = materialize(
      draft,
      nowUtc: nowUtc,
    );
    return _buildPublicProjection(
      internalProjections: result.projections,
      scheduleRevision: draft.sessionData?.schedule.scheduleRevision ?? 0,
      generatedAtUtc: nowUtc,
    );
  }

  List<SessionValidationIssue> validate(
    CreateDraftEntity draft, {
    required SessionExternalValidationContext context,
    DateTime? nowUtc,
  }) {
    final SessionDraftData? session = draft.sessionData;
    if (session == null) {
      return const <SessionValidationIssue>[
        SessionValidationIssue(
          code: SessionBlockingCode.resourceMissing,
          severity: SessionValidationSeverity.blocking,
          fieldId: 'resourceName',
        ),
      ];
    }
    final SessionScheduleMaterializationResult materialization = materialize(
      draft,
      nowUtc: nowUtc,
    );
    return _validateDraft(
      session,
      context: context,
      materialization: materialization,
    );
  }

  /// Applies a mutated `SessionDraftData` back onto the shared envelope.
  /// Deliberately does not write `scheduleSlots`/`availabilityKind:
  /// eventSlots` — the typed `schedule` is the single time authority (§6.1);
  /// the legacy fields stay untouched compatibility mirrors only.
  CreateDraftEntity apply(
    CreateDraftEntity draft,
    SessionDraftData session, {
    bool incrementRevision = true,
  }) {
    final SessionDraftData normalized = session.copyWith(
      revision: incrementRevision ? session.revision + 1 : session.revision,
    );
    final bool isFree = normalized.price.mode == SessionPricingMode.free;
    return draft.copyWith(
      sessionData: normalized,
      venueName: normalized.resourceName,
      timezone: normalized.timezoneId,
      availabilityKind: CreateAvailabilityKind.none,
      durationMinutes: normalized.schedule.slotDurationMinutes,
      isFree: isFree,
      basePrice: normalized.price.amount == null
          ? null
          : normalized.price.amount!.amountMinor / 100,
      clearBasePrice: normalized.price.amount == null,
      currency: normalized.price.amount?.currencyCode ?? draft.currency,
      bookingLink: normalized.externalBookingUrl,
      updatedAtUtc: DateTime.now().toUtc(),
    );
  }

  // --- Weekly schedule commands (§12 Блок 2) ---

  SessionDraftData applyWeeklyPreset(
    SessionDraftData session,
    List<SessionWeeklyRule> presetRules,
  ) => session.copyWith(
    schedule: session.schedule.copyWith(weeklyRules: presetRules),
  );

  SessionDraftData addWeeklyRule(
    SessionDraftData session,
    SessionWeeklyRule rule,
  ) => session.copyWith(
    schedule: session.schedule.copyWith(
      weeklyRules: <SessionWeeklyRule>[...session.schedule.weeklyRules, rule],
    ),
  );

  SessionDraftData removeWeeklyRule(SessionDraftData session, String ruleId) =>
      session.copyWith(
        schedule: session.schedule.copyWith(
          weeklyRules: session.schedule.weeklyRules
              .where((SessionWeeklyRule r) => r.id != ruleId)
              .toList(growable: false),
        ),
      );

  SessionDraftData setSlotDuration(SessionDraftData session, int minutes) =>
      session.copyWith(
        schedule: session.schedule.copyWith(slotDurationMinutes: minutes),
      );

  SessionDraftData setBuffer(SessionDraftData session, int minutes) =>
      session.copyWith(
        schedule: session.schedule.copyWith(bufferAfterSlotMinutes: minutes),
      );

  SessionDraftData setNotice(SessionDraftData session, int minutes) => session
      .copyWith(schedule: session.schedule.copyWith(minNoticeMinutes: minutes));

  // --- Exceptions (§12 «Необязательно», §11.3) ---

  SessionDraftData addException(
    SessionDraftData session,
    SessionAvailabilityException exception,
  ) => session.copyWith(
    exceptions: <SessionAvailabilityException>[
      ...session.exceptions,
      exception,
    ],
  );

  SessionDraftData removeException(
    SessionDraftData session,
    String exceptionId,
  ) => session.copyWith(
    exceptions: session.exceptions
        .where((SessionAvailabilityException e) => e.id != exceptionId)
        .toList(growable: false),
  );

  // --- Price and booking (§12 Блок 3) ---

  SessionDraftData setPrice(
    SessionDraftData session,
    SessionPriceDisclosure price,
  ) => session.copyWith(price: price);

  SessionDraftData setExternalBookingUrl(
    SessionDraftData session,
    String url,
  ) => session.copyWith(externalBookingUrl: url);

  SessionDraftData setMaxPartySize(SessionDraftData session, int value) =>
      session.copyWith(maxPartySize: value);
}
