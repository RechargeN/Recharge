import '../domain/entities/create_availability.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_draft_data.dart';
import '../domain/entities/event_admission.dart';
import '../domain/entities/event_availability_projection.dart';
import '../domain/entities/event_classification.dart';
import '../domain/entities/event_inventory.dart';
import '../domain/entities/event_validation_issue.dart';
import '../domain/repositories/event_inventory_snapshot_repository.dart';
import '../domain/repositories/event_timezone_repository.dart';
import '../domain/usecases/materialize_event_schedule_usecase.dart';
import '../domain/usecases/normalize_event_admission_preset_usecase.dart';
import '../domain/usecases/project_event_availability_usecase.dart';
import '../domain/usecases/validate_event_draft_usecase.dart';
import '../domain/usecases/suggest_event_classification_usecase.dart';
import 'event_admission_section.dart';
import 'event_classification_section.dart';
import 'event_inventory_section.dart';

class EventCreateCoordinator {
  const EventCreateCoordinator({
    required MaterializeEventScheduleUseCase materializeSchedule,
    ValidateEventDraftUseCase validateDraft = const ValidateEventDraftUseCase(),
    SuggestEventClassificationUseCase suggestClassification =
        const SuggestEventClassificationUseCase(),
    NormalizeEventAdmissionPresetUseCase normalizeAdmissionPreset =
        const NormalizeEventAdmissionPresetUseCase(),
    SuggestLegacyEventAdmissionUseCase suggestLegacyAdmission =
        const SuggestLegacyEventAdmissionUseCase(),
    ProjectEventAvailabilityUseCase projectAvailability =
        const ProjectEventAvailabilityUseCase(),
    EventInventorySnapshotRepository? inventorySnapshotRepository,
  }) : _materializeSchedule = materializeSchedule,
       _validateDraft = validateDraft,
       _suggestClassification = suggestClassification,
       _normalizeAdmissionPreset = normalizeAdmissionPreset,
       _suggestLegacyAdmission = suggestLegacyAdmission,
       _projectAvailability = projectAvailability,
       _inventorySnapshotRepository = inventorySnapshotRepository;

  final MaterializeEventScheduleUseCase _materializeSchedule;
  final ValidateEventDraftUseCase _validateDraft;
  final SuggestEventClassificationUseCase _suggestClassification;
  final NormalizeEventAdmissionPresetUseCase _normalizeAdmissionPreset;
  final SuggestLegacyEventAdmissionUseCase _suggestLegacyAdmission;
  final ProjectEventAvailabilityUseCase _projectAvailability;
  final EventInventorySnapshotRepository? _inventorySnapshotRepository;

  AdmissionPresetNormalizationResult normalizeAdmissionPreset(
    EventAdmissionPreset preset, {
    AdmissionMode? admissionMode,
    EventRegistrationMode? registrationMode,
    ConfirmationMode? confirmationMode,
  }) => _normalizeAdmissionPreset(
    preset,
    admissionMode: admissionMode,
    registrationMode: registrationMode,
    confirmationMode: confirmationMode,
  );

  EventAdmissionSectionState admissionState(
    CreateDraftEntity draft, {
    required bool enabled,
    EventAdmissionPreset? selectedPreset,
    EventAdmissionDraft? presetPreview,
    List<EventValidationIssue> presetIssues = const <EventValidationIssue>[],
  }) {
    final EventAdmissionDraft? admission = draft.eventData?.admission;
    final EventAdmissionLegacySuggestion? legacySuggestion =
        enabled && admission == null && draft.eventData != null
        ? _suggestLegacyAdmission(
            schemaVersion: draft.eventData!.schemaVersion,
            registrationMode: draft.eventData!.registrationMode,
          )
        : null;
    final List<EventValidationIssue> issues = enabled
        ? <EventValidationIssue>[
            ...presetIssues,
            ..._validateDraft(
              draft,
              throughStep: 3,
              includeAccessConfiguration: true,
            ).where((issue) => _admissionFieldIds.contains(issue.fieldId)),
          ]
        : const <EventValidationIssue>[];
    final List<EventAccessCapabilityDisclosure>
    disclosures = <EventAccessCapabilityDisclosure>[
      const EventAccessCapabilityDisclosure(
        code: EventAccessDisclosureCode.localConfiguration,
        message:
            'Local configuration only. No booking or inventory is reserved.',
      ),
      if (admission?.registrationMode == EventRegistrationMode.internal)
        const EventAccessCapabilityDisclosure(
          code: EventAccessDisclosureCode.internalLifecycleUnavailable,
          message: 'Internal registration is not active until ECL-03.',
          blocking: true,
        ),
      if (admission?.confirmationMode == ConfirmationMode.providerManaged)
        const EventAccessCapabilityDisclosure(
          code: EventAccessDisclosureCode.providerUnavailable,
          message: 'Provider-managed confirmation is not connected.',
          blocking: true,
        ),
      if (admission?.waitlistPolicy?.enabled == true)
        const EventAccessCapabilityDisclosure(
          code: EventAccessDisclosureCode.waitlistPreviewOnly,
          message: 'Waitlist is configuration-only; no queue is running.',
          blocking: true,
        ),
    ];
    return EventAdmissionSectionState(
      enabled: enabled,
      admission: admission,
      selectedPreset: selectedPreset,
      presetPreview: presetPreview,
      legacySuggestion: legacySuggestion,
      disclosures: List<EventAccessCapabilityDisclosure>.unmodifiable(
        disclosures,
      ),
      issues: List<EventValidationIssue>.unmodifiable(issues),
    );
  }

  EventInventorySectionState inventoryState(
    CreateDraftEntity draft, {
    required bool enabled,
    required bool mockPreviewEnabled,
    required EventAvailabilityProjection availabilityPreview,
    required bool refreshingPreview,
  }) {
    final EventInventoryConfiguration? inventory = draft.eventData?.inventory;
    final List<EventValidationIssue> issues = enabled
        ? _validateDraft(
                draft,
                throughStep: 3,
                includeAccessConfiguration: true,
              )
              .where((issue) => _inventoryFieldIds.contains(issue.fieldId))
              .toList(growable: false)
        : const <EventValidationIssue>[];
    final List<EventAccessCapabilityDisclosure> disclosures =
        <EventAccessCapabilityDisclosure>[
          const EventAccessCapabilityDisclosure(
            code: EventAccessDisclosureCode.localConfiguration,
            message: 'Capacity is configuration, not a live remaining balance.',
          ),
          if (inventory?.authority == InventoryAuthority.externalProvider)
            const EventAccessCapabilityDisclosure(
              code: EventAccessDisclosureCode.providerUnavailable,
              message: 'External inventory has no verified provider source.',
              blocking: true,
            ),
          if (inventory?.primaryShape == InventoryShape.assignedSeating ||
              (inventory?.additionalShapes.contains(
                    InventoryShape.assignedSeating,
                  ) ??
                  false))
            const EventAccessCapabilityDisclosure(
              code: EventAccessDisclosureCode.assignedSeatingUnavailable,
              message: 'Assigned seating requires an authoritative hold API.',
              blocking: true,
            ),
        ];
    int count(InventoryChannel channel) =>
        inventory?.pools.where((pool) => pool.channel == channel).length ?? 0;
    return EventInventorySectionState(
      enabled: enabled,
      mockPreviewEnabled: mockPreviewEnabled,
      configuration: inventory,
      capacityMode: draft.eventData?.capacityMode ?? EventCapacityMode.unknown,
      capacity: draft.eventData?.capacity,
      channelSummary: EventInventoryChannelSummary(
        onsitePoolCount: count(InventoryChannel.onsite),
        onlinePoolCount: count(InventoryChannel.online),
        anyPoolCount: count(InventoryChannel.any),
      ),
      availabilityPreview: availabilityPreview,
      refreshingPreview: refreshingPreview,
      disclosures: List<EventAccessCapabilityDisclosure>.unmodifiable(
        disclosures,
      ),
      issues: issues,
    );
  }

  Future<EventAvailabilityProjection> loadAvailabilityPreview(
    CreateDraftEntity draft, {
    DateTime? nowUtc,
  }) async {
    final EventDraftData? event = draft.eventData;
    final EventInventoryConfiguration? inventory = event?.inventory;
    final EventOccurrenceDraft? occurrence =
        event == null || event.occurrences.isEmpty
        ? null
        : event.occurrences.first;
    final EventInventorySnapshotRepository? repository =
        _inventorySnapshotRepository;
    if (inventory == null || occurrence == null || repository == null) {
      return EventAvailabilityProjection.unknown;
    }
    final EventInventorySnapshot? snapshot = await repository.loadSnapshot(
      eventId: draft.id,
      occurrenceId: occurrence.id,
    );
    final bool cancelled =
        event!.occurrenceOverrides[occurrence.id]?.cancelled == true;
    return _projectAvailability(
      configuration: inventory,
      snapshot: snapshot,
      nowUtc: (nowUtc ?? DateTime.now()).toUtc(),
      occurrenceCancelled: cancelled,
      verifiedActiveWaitlist: false,
    );
  }

  EventClassificationSectionState classificationState(
    CreateDraftEntity draft, {
    required bool enabled,
  }) {
    final EventClassificationDraft? classification =
        draft.eventData?.classification;
    final EventClassificationSuggestion? suggestion =
        enabled && classification == null
        ? _suggestClassification(
            subcategoryId: draft.subcategory,
            legacyEventType: draft.eventType,
          )
        : null;
    final List<EventValidationIssue> issues = enabled
        ? _validateDraft(draft, throughStep: 0, includeClassification: true)
              .where((EventValidationIssue issue) {
                return issue.fieldId == 'eventArchetype' ||
                    issue.fieldId == 'eventArchetypeOtherReason' ||
                    issue.fieldId == 'primaryParticipationMode' ||
                    issue.fieldId == 'additionalParticipationModes' ||
                    issue.fieldId == 'publisherRef';
              })
              .toList(growable: false)
        : const <EventValidationIssue>[];
    return EventClassificationSectionState(
      enabled: enabled,
      classification: classification,
      suggestion: suggestion,
      issues: issues,
    );
  }

  EventArchetypeChangeImpact archetypeImpact(
    EventClassificationDraft? current,
    EventArchetype next,
  ) {
    return EventArchetypeChangeImpact(
      previous: current?.archetype,
      next: next,
      clearsOtherReason:
          current?.archetype == EventArchetype.other &&
          next != EventArchetype.other &&
          (current?.otherReason?.isNotEmpty ?? false),
    );
  }

  CreateDraftEntity apply(
    CreateDraftEntity draft,
    EventDraftData event, {
    bool incrementRevision = true,
  }) {
    List<EventOccurrenceDraft> occurrences;
    try {
      occurrences = _materializeSchedule(event);
    } on FormatException {
      occurrences = const <EventOccurrenceDraft>[];
    } on EventLocalTimeException {
      occurrences = const <EventOccurrenceDraft>[];
    }
    final EventDraftData normalized = event.copyWith(
      revision: incrementRevision ? event.revision + 1 : event.revision,
      occurrences: occurrences,
    );
    final EventOccurrenceDraft? first = occurrences.isEmpty
        ? null
        : occurrences.first;
    final bool isFree = switch (normalized.pricingMode) {
      EventPricingMode.free => true,
      EventPricingMode.donation => (normalized.price?.amountMinor ?? 0) <= 0,
      EventPricingMode.fixed || EventPricingMode.ticketTypes => false,
    };
    return draft.copyWith(
      eventData: normalized,
      startDateTimeUtc: first?.startAtUtc,
      clearStartDateTimeUtc: first == null,
      endDateTimeUtc: first?.endAtUtc,
      clearEndDateTimeUtc: first == null,
      durationMinutes: normalized.durationMinutes,
      timezone: normalized.timezoneId,
      availabilityKind: CreateAvailabilityKind.eventSlots,
      scheduleSlots: occurrences
          .map(
            (EventOccurrenceDraft occurrence) => CreateTimeSlotDraft(
              localId: occurrence.id,
              startAtUtc: occurrence.startAtUtc,
              endAtUtc: occurrence.endAtUtc,
            ),
          )
          .toList(growable: false),
      openingHours: const <CreateOpeningHoursDraftRule>[],
      allowsPartialAttendance: normalized.allowsPartialAttendance,
      format: normalized.format.name,
      country: normalized.location.countryCode,
      city: normalized.location.city,
      venueName: normalized.location.venueName ?? '',
      addressLine1: normalized.location.formattedAddress ?? '',
      latitude: normalized.location.latitude,
      clearLatitude: normalized.location.latitude == null,
      longitude: normalized.location.longitude,
      clearLongitude: normalized.location.longitude == null,
      meetingPoint: normalized.location.meetingPoint ?? '',
      ageMin: normalized.ageMin,
      clearAgeMin: normalized.ageMin == null,
      ageMax: normalized.ageMax,
      clearAgeMax: normalized.ageMax == null,
      familyFriendly: normalized.familyFriendly,
      kidsAllowed: normalized.kidsAllowed,
      petFriendly: normalized.petFriendly,
      wheelchairAccessible: normalized.amenityIds.contains(
        'wheelchair_accessible',
      ),
      isFree: isFree,
      basePrice: normalized.price?.money,
      clearBasePrice: normalized.price == null,
      currency: normalized.currencyCode,
      pricingModel: normalized.pricingMode.name,
      registrationRequired:
          (normalized.admission?.registrationMode ??
              normalized.registrationMode) !=
          EventRegistrationMode.none,
      approvalRequired:
          normalized.admission?.confirmationMode ==
          ConfirmationMode.manualApproval,
      bookingLink: normalized.externalBookingUrl ?? '',
      waitlistEnabled: false,
      visibility: switch (normalized.visibility) {
        EventVisibility.public => VisibilityType.public,
        EventVisibility.unlisted => VisibilityType.unlisted,
        EventVisibility.private => VisibilityType.private,
      },
      updatedAtUtc: DateTime.now().toUtc(),
    );
  }

  List<EventValidationIssue> validate(
    CreateDraftEntity draft, {
    int? throughStep,
    bool includeClassification = true,
    bool includeAccessConfiguration = false,
  }) => _validateDraft(
    draft,
    throughStep: throughStep,
    includeClassification: includeClassification,
    includeAccessConfiguration: includeAccessConfiguration,
  );
}

const Set<String> _admissionFieldIds = <String>{
  'admission',
  'admissionMode',
  'registrationMode',
  'confirmationMode',
  'eligibilityRules',
  'guestPolicy',
  'guestMaxGuests',
  'interestPolicy',
  'registrationWindow',
  'applicationWindow',
  'waitlistPolicy',
  'waitlistOfferTtl',
  'externalBookingUrl',
};

const Set<String> _inventoryFieldIds = <String>{
  'inventory',
  'capacity',
  'inventoryAuthority',
  'inventoryPrimaryShape',
  'inventoryAdditionalShapes',
  'inventoryPools',
};
