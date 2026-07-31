import '../../../../core/id/id_generator.dart';
import '../entities/create_draft_entity.dart';
import '../entities/create_template_entity.dart';
import '../entities/event_draft_data.dart';

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
    final EventDraftData event = sourceEvent.copyWith(
      schemaVersion: EventDraftData.currentSchemaVersion,
      revision: 0,
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
    final EventDraftData event = draft.eventData!.copyWith(
      revision: 0,
      occurrences: const [],
      occurrenceOverrides: const {},
      clearPublicOnlineUrl: true,
      clearExternalBookingUrl: true,
      mediaMetadata: const EventMediaMetadataDraft(),
      acceptedWarningCodes: const {},
      unknownFields: const {},
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
