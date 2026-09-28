import '../../../../shared/models/catalog_object_ref.dart';

/// The Object/Offer visual profiles. Data-driven
/// membership — `ObjectOfferDetailsRenderer` never branches on
/// `CatalogObjectType` directly; it asks this file which profile a type
/// belongs to (OBJ-AC-06).
enum ObjectOfferProfile { venue, participation }

/// Which profile a given catalog type renders under. Throws for any type
/// outside this slice's scope (`DTL-OBJ-01` §1.1) — a caller reaching this
/// with e.g. `session` is a routing bug upstream, not a case to render
/// something generic for.
ObjectOfferProfile objectOfferProfileFor(CatalogObjectType type) {
  return switch (type) {
    CatalogObjectType.place => ObjectOfferProfile.venue,
    CatalogObjectType.event ||
    CatalogObjectType.activity => ObjectOfferProfile.participation,
    CatalogObjectType.route ||
    CatalogObjectType.session ||
    CatalogObjectType.scenario ||
    CatalogObjectType.findPeople ||
    CatalogObjectType.classWorkshop ||
    CatalogObjectType.collection ||
    CatalogObjectType.rental => throw ArgumentError(
      '$type has no Object/Offer profile (DTL-OBJ-01 §1.1) — '
      'ObjectOfferDetailsRenderer must not be reached for it.',
    ),
  };
}

/// Legacy Rental section order retained until Rental moves to its own Details
/// renderer family. Rental is intentionally outside the Object/Offer visual
/// system; these identifiers only preserve its current runtime composition.
enum RentalDetailsSection {
  hero,
  inventory,
  availability,
  pricing,
  pickup,
  duration,
  publisher,
  externalCta,
}

const List<RentalDetailsSection> rentalDetailsSections = <RentalDetailsSection>[
  RentalDetailsSection.hero,
  RentalDetailsSection.inventory,
  RentalDetailsSection.availability,
  RentalDetailsSection.pricing,
  RentalDetailsSection.pickup,
  RentalDetailsSection.duration,
  RentalDetailsSection.publisher,
  RentalDetailsSection.externalCta,
];

/// Canonical section identifiers for Event specifically, within the
/// `participation` profile (`DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §7.3).
/// `objectOfferProfileFor` above is unchanged — Event still classifies as
/// `participation` alongside Activity. The typed `.event` constructor uses
/// this list; Activity uses its own list below because the two read models
/// expose different fields.
enum EventDetailsSection {
  hero,
  header,
  metrics,
  organizer,
  about,
  program,
  location,
  stickyCta,
}

const List<EventDetailsSection> eventProfileSections = <EventDetailsSection>[
  EventDetailsSection.hero,
  EventDetailsSection.header,
  EventDetailsSection.metrics,
  EventDetailsSection.organizer,
  EventDetailsSection.about,
  EventDetailsSection.program,
  EventDetailsSection.location,
  EventDetailsSection.stickyCta,
];

/// Place is the second visual composition migrated to the shared Object /
/// Offer grammar. Presence of optional data controls visibility; this list
/// controls order only and does not calculate availability or actions.
enum PlaceDetailsSection {
  hero,
  header,
  metrics,
  publisher,
  about,
  openingHours,
  location,
  stickyCta,
}

const List<PlaceDetailsSection> placeProfileSections = <PlaceDetailsSection>[
  PlaceDetailsSection.hero,
  PlaceDetailsSection.header,
  PlaceDetailsSection.metrics,
  PlaceDetailsSection.publisher,
  PlaceDetailsSection.about,
  PlaceDetailsSection.openingHours,
  PlaceDetailsSection.location,
  PlaceDetailsSection.stickyCta,
];

/// Recharge Activity is the third composition on the shared Object / Offer
/// surface. Sections whose fields are not present in `DiscoverItemEntity`
/// (for example intensity, equipment or requirements) are deliberately not
/// represented by placeholders: they can be added when the read contract
/// actually supplies them.
enum ActivityDetailsSection {
  hero,
  header,
  metrics,
  organizer,
  about,
  schedule,
  location,
  stickyCta,
}

const List<ActivityDetailsSection> activityProfileSections =
    <ActivityDetailsSection>[
      ActivityDetailsSection.hero,
      ActivityDetailsSection.header,
      ActivityDetailsSection.metrics,
      ActivityDetailsSection.organizer,
      ActivityDetailsSection.about,
      ActivityDetailsSection.schedule,
      ActivityDetailsSection.location,
      ActivityDetailsSection.stickyCta,
    ];

/// Find People typed runtime composition (`DTL-FP-01` §5). This remains a
/// dedicated matrix: shared primitives do not turn six object types into one
/// universal nullable section list.
enum FindPeopleDetailsSection {
  hero,
  header,
  metrics,
  organizer,
  about,
  schedule,
  meetingFormat,
  requirements,
  cost,
  location,
  stickyCta,
}

const List<FindPeopleDetailsSection> findPeopleProfileSections =
    <FindPeopleDetailsSection>[
      FindPeopleDetailsSection.hero,
      FindPeopleDetailsSection.header,
      FindPeopleDetailsSection.metrics,
      FindPeopleDetailsSection.organizer,
      FindPeopleDetailsSection.about,
      FindPeopleDetailsSection.schedule,
      FindPeopleDetailsSection.meetingFormat,
      FindPeopleDetailsSection.requirements,
      FindPeopleDetailsSection.cost,
      FindPeopleDetailsSection.location,
      FindPeopleDetailsSection.stickyCta,
    ];

/// Class / Workshop typed runtime composition (DTL-CLS-01), preserving the
/// visual-system order. It is not a universal nullable section list.
enum ClassWorkshopDetailsSection {
  hero,
  header,
  metrics,
  teacher,
  about,
  schedule,
  materials,
  requirements,
  location,
  stickyCta,
}

const List<ClassWorkshopDetailsSection> classWorkshopProfileSections =
    <ClassWorkshopDetailsSection>[
      ClassWorkshopDetailsSection.hero,
      ClassWorkshopDetailsSection.header,
      ClassWorkshopDetailsSection.metrics,
      ClassWorkshopDetailsSection.teacher,
      ClassWorkshopDetailsSection.about,
      ClassWorkshopDetailsSection.schedule,
      ClassWorkshopDetailsSection.materials,
      ClassWorkshopDetailsSection.requirements,
      ClassWorkshopDetailsSection.location,
      ClassWorkshopDetailsSection.stickyCta,
    ];

/// Bookable Session visual composition
/// (`OBJECT_OFFER_DETAILS_VISUAL_SYSTEM_PLAN.md` §6: "услуга, длительность,
/// формат, provider, представленная доступность, место"). Same
/// typed runtime composition (`DTL-SES-01`). Freshness and visible offers are
/// resolved before the renderer; this matrix controls order only.
enum BookableSessionDetailsSection {
  hero,
  header,
  metrics,
  provider,
  about,
  availability,
  location,
  stickyCta,
}

const List<BookableSessionDetailsSection> bookableSessionProfileSections =
    <BookableSessionDetailsSection>[
      BookableSessionDetailsSection.hero,
      BookableSessionDetailsSection.header,
      BookableSessionDetailsSection.metrics,
      BookableSessionDetailsSection.provider,
      BookableSessionDetailsSection.about,
      BookableSessionDetailsSection.availability,
      BookableSessionDetailsSection.location,
      BookableSessionDetailsSection.stickyCta,
    ];
