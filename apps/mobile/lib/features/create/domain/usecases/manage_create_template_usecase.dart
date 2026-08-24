import '../../../../shared/primitives/id/id_generator.dart';
import '../entities/create_draft_entity.dart';
import '../entities/create_template_entity.dart';
import '../entities/event_draft_data.dart';
import '../entities/event_admission.dart';
import '../entities/event_inventory.dart';
import '../entities/rental_draft_data.dart';

class ManageCreateTemplateUseCase {
  const ManageCreateTemplateUseCase(this._idGenerator);

  final IdGenerator _idGenerator;

  CreateTemplateEntity create({
    required String userId,
    required String name,
    required CreateDraftEntity draft,
    DateTime? nowUtc,
  }) {
    if (draft.objectType != CreateObjectType.event || draft.eventData == null) {
      throw ArgumentError('CRT-TPL-01 supports Event templates only.');
    }
    final String normalizedName = _normalizedName(name);
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    return CreateTemplateEntity(
      schemaVersion: CreateTemplateEntity.currentSchemaVersion,
      id: _idGenerator.generate(),
      ownerUserId: userId,
      objectType: draft.objectType,
      name: normalizedName,
      snapshot: _sanitizeSnapshot(draft),
      createdAtUtc: now,
      updatedAtUtc: now,
      lastUsedAtUtc: now,
    );
  }

  CreateTemplateEntity replace({
    required CreateTemplateEntity template,
    required String userId,
    required CreateDraftEntity draft,
    DateTime? nowUtc,
  }) {
    _verifyOwnership(template, userId);
    if (draft.objectType != template.objectType || draft.eventData == null) {
      throw ArgumentError('Template and draft types must match.');
    }
    return template.copyWith(
      snapshot: _sanitizeSnapshot(draft),
      updatedAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
    );
  }

  CreateTemplateEntity rename({
    required CreateTemplateEntity template,
    required String userId,
    required String name,
    DateTime? nowUtc,
  }) {
    _verifyOwnership(template, userId);
    return template.copyWith(
      name: _normalizedName(name),
      updatedAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
    );
  }

  CreateTemplateEntity markUsed({
    required CreateTemplateEntity template,
    required String userId,
    DateTime? nowUtc,
  }) {
    _verifyOwnership(template, userId);
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    return template.copyWith(updatedAtUtc: now, lastUsedAtUtc: now);
  }

  CreateDraftEntity materializeEvent({
    required CreateTemplateEntity template,
    required String userId,
    required String organizerEmail,
    required String organizerName,
    required String marketCityId,
    required String timezone,
    required String country,
    required String city,
    required String currency,
    PublisherRef? publisherRef,
    DateTime? nowUtc,
  }) {
    _verifyOwnership(template, userId);
    if (template.objectType != CreateObjectType.event) {
      throw ArgumentError('CRT-TPL-01 supports Event templates only.');
    }
    final CreateDraftEntity fresh = CreateDraftEntity.defaults(
      organizerId: userId,
      organizerEmail: organizerEmail,
      organizerName: organizerName,
      marketCityId: marketCityId,
      timezone: timezone,
      country: country,
      city: city,
      currency: currency,
    );
    final CreateDraftEntity source = template.snapshot;
    final EventDraftData freshEvent = fresh.eventData!;
    final EventDraftData sourceEvent = source.eventData!;
    final EventAdmissionDraft? admission = _templateAdmission(
      sourceEvent.admission,
      renewIds: true,
    );
    final EventInventoryConfiguration? inventory = _templateInventory(
      sourceEvent.inventory,
      renewIds: true,
    );
    final EventDraftData event = sourceEvent.copyWith(
      schemaVersion: admission != null || inventory != null
          ? EventDraftData.accessSchemaVersion
          : EventDraftData.classificationSchemaVersion,
      revision: 0,
      publisherRef: publisherRef ?? freshEvent.publisherRef,
      admission: admission,
      clearAdmission: admission == null,
      inventory: inventory,
      clearInventory: inventory == null,
      timezoneId: timezone,
      localStartDate: freshEvent.localStartDate,
      occurrences: const [],
      occurrenceOverrides: const {},
      clearPublicOnlineUrl: true,
      clearExternalBookingUrl: true,
      location: sourceEvent.location.copyWith(
        marketCityId: marketCityId,
        countryCode: country,
        city: sourceEvent.location.city.trim().isEmpty
            ? city
            : sourceEvent.location.city,
      ),
      currencyCode: currency,
      mediaMetadata: const EventMediaMetadataDraft(),
      acceptedWarningCodes: const {},
      unknownFields: const {},
      unsupportedFieldIds: const {},
    );
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    return fresh.copyWith(
      id: 'loc_${now.microsecondsSinceEpoch}',
      objectType: CreateObjectType.event,
      title: source.title,
      eventType: source.eventType,
      mainCategory: source.mainCategory,
      subcategory: source.subcategory,
      tags: List<String>.from(source.tags),
      shortDescription: source.shortDescription,
      fullDescription: source.fullDescription,
      sectionData: _reusableSectionData(source.sectionData),
      eventData: event,
      clearPlaceData: true,
      clearFindPeopleData: true,
      clearRouteData: true,
      clearScenarioData: true,
      clearStartDateTimeUtc: true,
      clearEndDateTimeUtc: true,
      clearRegistrationDeadlineUtc: true,
      timezone: timezone,
      marketCityId: marketCityId,
      availabilityKind: fresh.availabilityKind,
      scheduleSlots: const [],
      openingHours: const [],
      format: source.format,
      country: country,
      city: event.location.city,
      venueName: event.location.venueName ?? '',
      addressLine1: event.location.formattedAddress ?? '',
      latitude: event.location.latitude,
      clearLatitude: event.location.latitude == null,
      longitude: event.location.longitude,
      clearLongitude: event.location.longitude == null,
      meetingPoint: event.location.meetingPoint ?? '',
      minParticipants: source.minParticipants,
      clearMinParticipants: source.minParticipants == null,
      maxParticipants: source.maxParticipants,
      clearMaxParticipants: source.maxParticipants == null,
      currentParticipants: 0,
      ageMin: source.ageMin,
      clearAgeMin: source.ageMin == null,
      ageMax: source.ageMax,
      clearAgeMax: source.ageMax == null,
      familyFriendly: source.familyFriendly,
      kidsAllowed: source.kidsAllowed,
      petFriendly: source.petFriendly,
      wheelchairAccessible: source.wheelchairAccessible,
      isFree: source.isFree,
      basePrice: source.basePrice,
      clearBasePrice: source.basePrice == null,
      currency: currency,
      pricingModel: source.pricingModel,
      registrationRequired: source.registrationRequired,
      approvalRequired: source.approvalRequired,
      bookingLink: '',
      waitlistEnabled: source.waitlistEnabled,
      organizerId: userId,
      organizerName: organizerName,
      organizerEmail: organizerEmail,
      organizerProfileLink: '',
      organizerPhone: '',
      media: const MediaEntity(coverImage: '', gallery: []),
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      reportCount: 0,
      createdAtUtc: now,
      updatedAtUtc: now,
      clearPublishedAtUtc: true,
      clearBasedOnPublishedVersionId: true,
    );
  }

  CreateDraftEntity _sanitizeSnapshot(CreateDraftEntity draft) {
    final EventAdmissionDraft? admission = _templateAdmission(
      draft.eventData!.admission,
      renewIds: true,
    );
    final EventInventoryConfiguration? inventory = _templateInventory(
      draft.eventData!.inventory,
      renewIds: true,
    );
    final EventDraftData event = draft.eventData!.copyWith(
      schemaVersion: admission != null || inventory != null
          ? EventDraftData.accessSchemaVersion
          : EventDraftData.classificationSchemaVersion,
      revision: 0,
      clearPublisherRef: true,
      admission: admission,
      clearAdmission: admission == null,
      inventory: inventory,
      clearInventory: inventory == null,
      occurrences: const [],
      occurrenceOverrides: const {},
      clearPublicOnlineUrl: true,
      clearExternalBookingUrl: true,
      mediaMetadata: const EventMediaMetadataDraft(),
      acceptedWarningCodes: const {},
      unknownFields: const {},
      unsupportedFieldIds: const {},
    );
    return draft.copyWith(
      eventData: event,
      clearStartDateTimeUtc: true,
      clearEndDateTimeUtc: true,
      scheduleSlots: const [],
      clearRegistrationDeadlineUtc: true,
      bookingLink: '',
      organizerId: '',
      organizerName: '',
      organizerEmail: '',
      organizerProfileLink: '',
      organizerPhone: '',
      media: const MediaEntity(coverImage: '', gallery: []),
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      reportCount: 0,
      clearPublishedAtUtc: true,
      clearBasedOnPublishedVersionId: true,
      sectionData: _reusableSectionData(draft.sectionData),
    );
  }

  /// Rental counterpart of `create()` — same shape, keyed on
  /// `CreateObjectType.rental`/`RentalDraftData` (spec §15.3). A parallel
  /// method on the same class rather than a generic refactor of the Event
  /// path above, so Event's template behavior/tests are untouched.
  CreateTemplateEntity createRentalTemplate({
    required String userId,
    required String name,
    required CreateDraftEntity draft,
    DateTime? nowUtc,
  }) {
    if (draft.objectType != CreateObjectType.rental ||
        draft.rentalData == null) {
      throw ArgumentError('Rental templates require a rental draft.');
    }
    final String normalizedName = _normalizedName(name);
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    return CreateTemplateEntity(
      schemaVersion: CreateTemplateEntity.currentSchemaVersion,
      id: _idGenerator.generate(),
      ownerUserId: userId,
      objectType: draft.objectType,
      name: normalizedName,
      snapshot: _sanitizeRentalSnapshot(draft),
      createdAtUtc: now,
      updatedAtUtc: now,
      lastUsedAtUtc: now,
    );
  }

  CreateTemplateEntity replaceRentalTemplate({
    required CreateTemplateEntity template,
    required String userId,
    required CreateDraftEntity draft,
    DateTime? nowUtc,
  }) {
    _verifyOwnership(template, userId);
    if (draft.objectType != template.objectType || draft.rentalData == null) {
      throw ArgumentError('Template and draft types must match.');
    }
    return template.copyWith(
      snapshot: _sanitizeRentalSnapshot(draft),
      updatedAtUtc: (nowUtc ?? DateTime.now()).toUtc(),
    );
  }

  /// Materializes a brand-new Rental draft from [template]. Publisher and
  /// market defaults always come from the current authenticated context —
  /// never the template snapshot (spec §15.3).
  CreateDraftEntity materializeRental({
    required CreateTemplateEntity template,
    required String userId,
    required String currencyCode,
    required String timeZoneId,
    PublisherRef? publisherRef,
    DateTime? nowUtc,
  }) {
    _verifyOwnership(template, userId);
    if (template.objectType != CreateObjectType.rental) {
      throw ArgumentError('Rental materialization requires a rental template.');
    }
    final CreateDraftEntity fresh = CreateDraftEntity.defaults(
      organizerId: userId,
      organizerEmail: '',
      organizerName: '',
      marketCityId: '',
      timezone: timeZoneId,
      country: '',
      city: '',
      currency: currencyCode,
    );
    final CreateDraftEntity source = template.snapshot;
    final RentalDraftData sourceRental = source.rentalData!;
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    final PublisherRef resolvedPublisher =
        publisherRef ?? PublisherRef(type: PublisherType.user, id: userId);
    final RentalDraftData rental = sourceRental.copyWith(
      revision: 0,
      publisherRef: resolvedPublisher,
      inventoryGroups: sourceRental.inventoryGroups
          .map((RentalInventoryGroup g) => g.copyWith(id: _newLocalId()))
          .toList(growable: false),
      availability: RentalAvailabilityCalendar(timeZoneId: timeZoneId),
      fulfillment: const RentalExternalFulfillment(),
      attestation: RentalPublisherAttestation(
        policyVersion: sourceRental.attestation.policyVersion,
      ),
    );
    return fresh.copyWith(
      id: 'loc_${now.microsecondsSinceEpoch}',
      objectType: CreateObjectType.rental,
      title: source.title,
      mainCategory: source.mainCategory,
      subcategory: source.subcategory,
      tags: List<String>.from(source.tags),
      shortDescription: source.shortDescription,
      fullDescription: source.fullDescription,
      sectionData: _reusableSectionData(source.sectionData),
      rentalData: rental,
      clearEventData: true,
      clearPlaceData: true,
      clearFindPeopleData: true,
      clearRouteData: true,
      clearScenarioData: true,
      clearActivityData: true,
      media: const MediaEntity(coverImage: '', gallery: []),
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      reportCount: 0,
      createdAtUtc: now,
      updatedAtUtc: now,
      clearPublishedAtUtc: true,
      clearBasedOnPublishedVersionId: true,
      organizerId: userId,
    );
  }

  /// spec §15.4 `Duplicate listing` — reuses the same sanitizer and
  /// materializer as templates, but only in-memory: the ephemeral
  /// `CreateTemplateEntity` below is never persisted through
  /// `CreateTemplateRepository`.
  CreateDraftEntity duplicateRental({
    required CreateDraftEntity draft,
    required String userId,
    required String currencyCode,
    required String timeZoneId,
    PublisherRef? publisherRef,
    DateTime? nowUtc,
  }) {
    if (draft.objectType != CreateObjectType.rental ||
        draft.rentalData == null) {
      throw ArgumentError('Duplicate requires a rental draft.');
    }
    final DateTime now = (nowUtc ?? DateTime.now()).toUtc();
    final CreateTemplateEntity ephemeral = CreateTemplateEntity(
      schemaVersion: CreateTemplateEntity.currentSchemaVersion,
      id: _idGenerator.generate(),
      ownerUserId: userId,
      objectType: CreateObjectType.rental,
      name: 'duplicate',
      snapshot: _sanitizeRentalSnapshot(draft),
      createdAtUtc: now,
      updatedAtUtc: now,
      lastUsedAtUtc: now,
    );
    return materializeRental(
      template: ephemeral,
      userId: userId,
      currencyCode: currencyCode,
      timeZoneId: timeZoneId,
      publisherRef: publisherRef,
      nowUtc: nowUtc,
    );
  }

  CreateDraftEntity _sanitizeRentalSnapshot(CreateDraftEntity draft) {
    final RentalDraftData source = draft.rentalData!;
    final RentalDraftData sanitized = source.copyWith(
      revision: 0,
      publisherRef: const PublisherRef(type: PublisherType.user, id: ''),
      inventoryGroups: source.inventoryGroups
          .map((RentalInventoryGroup g) => g.copyWith(id: _newLocalId()))
          .toList(growable: false),
      availability: RentalAvailabilityCalendar(
        timeZoneId: source.availability.timeZoneId,
      ),
      fulfillment: const RentalExternalFulfillment(),
      attestation: RentalPublisherAttestation(
        policyVersion: source.attestation.policyVersion,
      ),
    );
    return draft.copyWith(
      rentalData: sanitized,
      media: const MediaEntity(coverImage: '', gallery: []),
      draftStatus: DraftStatus.draft,
      moderationStatus: ModerationStatus.none,
      publishStatus: PublishStatus.draft,
      reportCount: 0,
      clearPublishedAtUtc: true,
      clearBasedOnPublishedVersionId: true,
      organizerId: '',
      organizerName: '',
      organizerEmail: '',
      organizerProfileLink: '',
      organizerPhone: '',
      sectionData: _reusableSectionData(draft.sectionData),
    );
  }

  EventAdmissionDraft? _templateAdmission(
    EventAdmissionDraft? value, {
    required bool renewIds,
  }) {
    if (value == null) return null;
    return value.copyWith(
      eligibilityRules: value.eligibilityRules
          .map(
            (rule) => EligibilityRule(
              id: renewIds ? _newLocalId() : rule.id,
              kind: rule.kind,
              publicExplanation: rule.publicExplanation,
            ),
          )
          .toList(growable: false),
      waitlistPolicy: value.waitlistPolicy?.copyWith(
        enabled: false,
        clearOfferTtlMinutes: true,
        clearPaymentDeadlineMinutes: true,
      ),
    );
  }

  EventInventoryConfiguration? _templateInventory(
    EventInventoryConfiguration? value, {
    required bool renewIds,
  }) {
    if (value == null) return null;
    return EventInventoryConfiguration(
      authority: InventoryAuthority.none,
      primaryShape: value.primaryShape,
      additionalShapes: <InventoryShape>{...value.additionalShapes},
      pools: value.pools
          .map(
            (pool) => EventInventoryPoolDraft(
              id: renewIds ? _newLocalId() : pool.id,
              label: pool.label,
              shape: pool.shape,
              channel: pool.channel,
              capacityMode: pool.capacityMode,
              capacity: pool.capacity,
              roleIds: List<String>.from(pool.roleIds),
              zoneRef: pool.zoneRef,
            ),
          )
          .toList(growable: false),
    );
  }

  String _newLocalId() => 'loc_${_idGenerator.generate()}';

  Map<String, Object?> _reusableSectionData(Map<String, Object?> source) {
    final Object? criteria = source['criteria'];
    return <String, Object?>{
      if (criteria is Map<dynamic, dynamic>)
        'criteria': Map<String, Object?>.from(criteria),
    };
  }

  String _normalizedName(String value) {
    final String name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 || name.length > 80) {
      throw ArgumentError('Template name must contain 2–80 characters.');
    }
    return name;
  }

  void _verifyOwnership(CreateTemplateEntity template, String userId) {
    if (template.ownerUserId != userId) {
      throw StateError('Template belongs to another user.');
    }
  }
}
