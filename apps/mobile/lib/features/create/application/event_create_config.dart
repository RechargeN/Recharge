class EventCreateStepConfig {
  const EventCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
    required this.sectionIds,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
  final List<String> sectionIds;
}

const List<EventCreateStepConfig> eventCreateSteps = <EventCreateStepConfig>[
  EventCreateStepConfig(
    id: 'basics_media',
    titleId: 'createStepEventBasicsMediaTitle',
    descriptionId: 'createStepEventBasicsMediaDescription',
    sectionIds: <String>[
      'event_taxonomy',
      'event_classification',
      'event_identity',
      'event_media',
    ],
  ),
  EventCreateStepConfig(
    id: 'location_schedule',
    titleId: 'createStepEventLocationScheduleTitle',
    descriptionId: 'createStepEventLocationScheduleDescription',
    sectionIds: <String>['event_location', 'event_schedule'],
  ),
  EventCreateStepConfig(
    id: 'requirements',
    titleId: 'createStepEventRequirementsTitle',
    descriptionId: 'createStepEventRequirementsDescription',
    sectionIds: <String>['event_requirements'],
  ),
  EventCreateStepConfig(
    id: 'price_participants',
    titleId: 'createStepEventPriceParticipantsTitle',
    descriptionId: 'createStepEventPriceParticipantsDescription',
    sectionIds: <String>['event_pricing', 'event_admission', 'event_inventory'],
  ),
  EventCreateStepConfig(
    id: 'preview_publish',
    titleId: 'createStepEventPreviewPublishTitle',
    descriptionId: 'createStepEventPreviewPublishDescription',
    sectionIds: <String>['event_preview', 'event_publish'],
  ),
];

class EventAmenityDefinition {
  const EventAmenityDefinition(this.id, this.group);

  final String id;

  /// Stable group id; the UI shows `createAmenityGroup` (L4).
  final String group;
}

const List<EventAmenityDefinition> eventAmenityTaxonomy =
    <EventAmenityDefinition>[
      EventAmenityDefinition('wheelchair_accessible', 'accessibility'),
      EventAmenityDefinition('accessible_toilet', 'accessibility'),
      EventAmenityDefinition('parking', 'transport'),
      EventAmenityDefinition('bike_parking', 'transport'),
      EventAmenityDefinition('public_transport', 'transport'),
      EventAmenityDefinition('family_friendly', 'audience'),
      EventAmenityDefinition('pets_allowed', 'audience'),
      EventAmenityDefinition('toilet', 'facilities'),
      EventAmenityDefinition('wifi', 'facilities'),
      EventAmenityDefinition('drinking_water', 'facilities'),
      EventAmenityDefinition('food_available', 'facilities'),
      EventAmenityDefinition('weather_shelter', 'outdoor'),
      EventAmenityDefinition('first_aid', 'safety'),
      // Bounded extraction for Bookable Session's own amenities section
      // (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §12 «Необязательно», §7) —
      // additive entries only, no change to existing Event/Place behavior.
      EventAmenityDefinition('shower', 'wellness'),
      EventAmenityDefinition('towels', 'wellness'),
      EventAmenityDefinition('changing_room', 'wellness'),
      EventAmenityDefinition('equipment_provided', 'wellness'),
    ];
