import '../domain/entities/create_availability.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_draft_data.dart';
import '../domain/entities/event_validation_issue.dart';
import '../domain/repositories/event_timezone_repository.dart';
import '../domain/usecases/materialize_event_schedule_usecase.dart';
import '../domain/usecases/validate_event_draft_usecase.dart';

class EventCreateCoordinator {
  const EventCreateCoordinator({
    required MaterializeEventScheduleUseCase materializeSchedule,
    ValidateEventDraftUseCase validateDraft = const ValidateEventDraftUseCase(),
  }) : _materializeSchedule = materializeSchedule,
       _validateDraft = validateDraft;

  final MaterializeEventScheduleUseCase _materializeSchedule;
  final ValidateEventDraftUseCase _validateDraft;

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
      basePrice: normalized.price == null
          ? null
          : normalized.price!.amountMinor / 100,
      clearBasePrice: normalized.price == null,
      currency: normalized.currencyCode,
      pricingModel: normalized.pricingMode.name,
      registrationRequired:
          normalized.registrationMode != EventRegistrationMode.none,
      approvalRequired: false,
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
  }) => _validateDraft(draft, throughStep: throughStep);
}
