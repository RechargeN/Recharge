import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_classification.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/materialize_event_schedule_usecase.dart';

/// A user's Event draft as the Create flow stores it: Create defaults, the
/// fields a user fills in, and occurrences materialized by Create's own
/// schedule use case (local `loc_occ_*` ids). It is not a backend body: the
/// publication path maps it.
CreateDraftEntity userEventDraft({
  required String pageId,
  required String coverPath,
  String? localId,
  String title = 'Pottery evening at the studio',
  String localStartDate = '2035-11-14',
}) {
  final CreateDraftEntity base = CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Stand Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final EventDraftData event = base.eventData!.copyWith(
    publisherRef: PublisherRef(type: PublisherType.page, id: pageId),
    classification: EventClassificationDraft(
      archetype: EventArchetype.workshop,
      primaryParticipationMode: ParticipationMode.learn,
      additionalParticipationModes: const <ParticipationMode>{
        ParticipationMode.create,
      },
    ),
    localStartDate: localStartDate,
    startMinute: 18 * 60,
    durationMinutes: 150,
    location: const EventLocationDraft(
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      venueName: 'Clay Studio',
      formattedAddress: 'Brivibas iela 10, Riga',
      latitude: 56.951,
      longitude: 24.113,
      pinConfirmed: true,
    ),
    mediaMetadata: const EventMediaMetadataDraft(
      coverAltText: 'Hands shaping clay on a pottery wheel',
      rightsConfirmed: true,
    ),
  );
  final EventDraftData materialized = event.copyWith(
    occurrences: MaterializeEventScheduleUseCase(EventTimezoneRepositoryImpl())(
      event,
    ),
  );
  return base.copyWith(
    id: localId ?? base.id,
    title: title,
    mainCategory: 'workshops_masterclasses',
    subcategory: 'pottery',
    shortDescription: 'Shape your own bowl on the wheel in a friendly studio',
    fullDescription:
        'A relaxed evening of guided pottery. Clay, tools, glazes and firing '
        'are included, and you take your bowl home after the second session.',
    eventData: materialized,
    media: MediaEntity(coverImage: coverPath, gallery: const <String>[]),
  );
}

/// E2.0: the same draft with free, instant, offline internal registration v1,
/// every value an explicit user choice in Create (nothing is defaulted).
CreateDraftEntity withInternalRegistration(
  CreateDraftEntity draft, {
  int capacity = 20,
  GuestPolicy guestPolicy = const GuestPolicy(mode: GuestPolicyMode.plusOne),
  int opensBeforeMinutes = 525600,
  int closesBeforeMinutes = 60,
  int? cancellationBeforeMinutes = 120,
}) => draft.copyWith(
  eventData: draft.eventData!.copyWith(
    // Like Create's own controller: admission is a schema-v3 field, so the
    // local draft store keeps it only from that version on.
    schemaVersion: EventDraftData.accessSchemaVersion,
    registrationMode: EventRegistrationMode.internal,
    capacityMode: EventCapacityMode.known,
    capacity: capacity,
    admission: EventAdmissionDraft(
      admissionMode: AdmissionMode.booking,
      registrationMode: EventRegistrationMode.internal,
      confirmationMode: ConfirmationMode.instant,
      guestPolicy: guestPolicy,
      registrationWindow: EventAccessWindow(
        kind: EventAccessWindowKind.occurrenceRelative,
        opensBeforeOccurrenceMinutes: opensBeforeMinutes,
        closesBeforeOccurrenceMinutes: closesBeforeMinutes,
      ),
      cancellationClosesBeforeOccurrenceMinutes: cancellationBeforeMinutes,
    ),
  ),
);
