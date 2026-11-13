import '../domain/entities/place_creation_policy.dart';
import '../domain/entities/place_draft_data.dart';

class PlaceCreateStepConfig {
  const PlaceCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

const List<PlaceCreateStepConfig> placeCreateSteps = <PlaceCreateStepConfig>[
  PlaceCreateStepConfig(
    id: 'identity',
    titleId: 'createStepPlaceIdentityTitle',
    descriptionId: 'createStepPlaceIdentityDescription',
  ),
  PlaceCreateStepConfig(
    id: 'visit',
    titleId: 'createStepPlaceVisitTitle',
    descriptionId: 'createStepPlaceVisitDescription',
  ),
  PlaceCreateStepConfig(
    id: 'publish',
    titleId: 'createStepPlacePublishTitle',
    descriptionId: 'createStepPlacePublishDescription',
  ),
];

const PlaceCreationPolicy simplePoiPlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.simplePoi,
  suggestedKind: PlaceKind.pointOfInterest,
  shortDescription: PlaceFieldRequirement.recommended,
  cover: PlaceFieldRequirement.recommended,
  hours: PlaceFieldRequirement.hidden,
  admission: PlaceFieldRequirement.hidden,
  typicalSpend: PlaceFieldRequirement.hidden,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.hidden,
  contacts: PlaceFieldRequirement.hidden,
  booking: PlaceFieldRequirement.hidden,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy publicSpacePlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.publicSpace,
  suggestedKind: PlaceKind.publicSpace,
  shortDescription: PlaceFieldRequirement.recommended,
  cover: PlaceFieldRequirement.recommended,
  hours: PlaceFieldRequirement.optional,
  admission: PlaceFieldRequirement.optional,
  typicalSpend: PlaceFieldRequirement.hidden,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.hidden,
  booking: PlaceFieldRequirement.hidden,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy naturalDestinationPlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.naturalDestination,
  suggestedKind: PlaceKind.publicSpace,
  shortDescription: PlaceFieldRequirement.recommended,
  cover: PlaceFieldRequirement.recommended,
  hours: PlaceFieldRequirement.optional,
  admission: PlaceFieldRequirement.optional,
  typicalSpend: PlaceFieldRequirement.hidden,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.hidden,
  booking: PlaceFieldRequirement.hidden,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy culturalVenuePlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.culturalVenue,
  suggestedKind: PlaceKind.managedVenue,
  shortDescription: PlaceFieldRequirement.required,
  cover: PlaceFieldRequirement.required,
  hours: PlaceFieldRequirement.required,
  admission: PlaceFieldRequirement.optional,
  typicalSpend: PlaceFieldRequirement.hidden,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.optional,
  booking: PlaceFieldRequirement.optional,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy hospitalityPlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.hospitality,
  suggestedKind: PlaceKind.managedVenue,
  shortDescription: PlaceFieldRequirement.required,
  cover: PlaceFieldRequirement.required,
  hours: PlaceFieldRequirement.required,
  admission: PlaceFieldRequirement.hidden,
  typicalSpend: PlaceFieldRequirement.optional,
  visitPlanning: PlaceFieldRequirement.hidden,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.optional,
  booking: PlaceFieldRequirement.optional,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy activityVenuePlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.activityVenue,
  suggestedKind: PlaceKind.managedVenue,
  shortDescription: PlaceFieldRequirement.required,
  cover: PlaceFieldRequirement.required,
  hours: PlaceFieldRequirement.required,
  admission: PlaceFieldRequirement.hidden,
  typicalSpend: PlaceFieldRequirement.optional,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.optional,
  booking: PlaceFieldRequirement.optional,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy paidAttractionPlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.paidAttraction,
  suggestedKind: PlaceKind.managedVenue,
  shortDescription: PlaceFieldRequirement.required,
  cover: PlaceFieldRequirement.required,
  hours: PlaceFieldRequirement.required,
  admission: PlaceFieldRequirement.optional,
  typicalSpend: PlaceFieldRequirement.hidden,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.optional,
  booking: PlaceFieldRequirement.optional,
  accessNote: PlaceFieldRequirement.optional,
);

const PlaceCreationPolicy balancedPlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.balanced,
  suggestedKind: PlaceKind.pointOfInterest,
  shortDescription: PlaceFieldRequirement.recommended,
  cover: PlaceFieldRequirement.recommended,
  hours: PlaceFieldRequirement.optional,
  admission: PlaceFieldRequirement.optional,
  typicalSpend: PlaceFieldRequirement.optional,
  visitPlanning: PlaceFieldRequirement.optional,
  amenities: PlaceFieldRequirement.optional,
  contacts: PlaceFieldRequirement.optional,
  booking: PlaceFieldRequirement.optional,
  accessNote: PlaceFieldRequirement.optional,
);

const Set<String> _simplePoiSubcategoryIds = <String>{
  'monument',
  'memorial',
  'sculpture',
  'historic_landmark',
  'viewpoint',
  'public_art',
  'street_art',
  'architecture',
  'cultural_heritage',
};

const Set<String> _publicSpaceSubcategoryIds = <String>{
  'park',
  'beach',
  'promenade',
  'public_square',
  'park_walk',
  'beach_walk',
  'promenade_walk',
  'community_garden',
};

const Set<String> _naturalDestinationSubcategoryIds = <String>{
  'forest',
  'lake',
  'waterfall',
  'cave',
  'natural_landmark',
  'nature_reset',
  'botanical_garden',
};

const Set<String> _culturalVenueSubcategoryIds = <String>{
  'museum',
  'gallery',
  'exhibition',
  'cinema',
  'planetarium',
  'science_center',
};

const Set<String> _hospitalitySubcategoryIds = <String>{
  'coffee',
  'cafe_visit',
  'restaurant_visit',
  'bakery_visit',
  'night_bar',
  'cat_cafe',
  'pet_friendly_cafe',
};

const Set<String> _activityVenueSubcategoryIds = <String>{
  'arcade',
  'billiards',
  'bowling',
  'darts',
  'escape_room',
  'gym',
  'massage',
  'mini_golf',
  'pirts_ritual',
  'rope_park',
  'sauna',
  'spa',
  'trampoline_park',
  'vr_arcade',
};

const Set<String> _paidAttractionSubcategoryIds = <String>{
  'zoo',
  'petting_zoo',
  'aquarium',
  'amusement_park',
  'water_park',
  'adventure_park',
  'observation_deck',
  'ferris_wheel',
  'seasonal_attraction',
};

PlaceCreationPolicy placeCreationPolicyFor(String subcategoryId) {
  final String id = subcategoryId.trim().toLowerCase();
  if (_simplePoiSubcategoryIds.contains(id)) return simplePoiPlacePolicy;
  if (_publicSpaceSubcategoryIds.contains(id)) return publicSpacePlacePolicy;
  if (_naturalDestinationSubcategoryIds.contains(id)) {
    return naturalDestinationPlacePolicy;
  }
  if (_culturalVenueSubcategoryIds.contains(id)) {
    return culturalVenuePlacePolicy;
  }
  if (_hospitalitySubcategoryIds.contains(id)) return hospitalityPlacePolicy;
  if (_activityVenueSubcategoryIds.contains(id)) {
    return activityVenuePlacePolicy;
  }
  if (_paidAttractionSubcategoryIds.contains(id)) {
    return paidAttractionPlacePolicy;
  }
  return balancedPlacePolicy;
}

class PlaceAmenityDefinition {
  const PlaceAmenityDefinition({required this.id, required this.group});

  final String id;

  /// Stable group id; the UI shows `createAmenityGroup` (L4).
  final String group;
}

const List<PlaceAmenityDefinition> placeAmenityTaxonomy =
    <PlaceAmenityDefinition>[
      PlaceAmenityDefinition(
        id: 'wheelchair_accessible',
        group: 'accessibility',
      ),
      PlaceAmenityDefinition(id: 'accessible_toilet', group: 'accessibility'),
      PlaceAmenityDefinition(id: 'parking', group: 'transport'),
      PlaceAmenityDefinition(id: 'bike_parking', group: 'transport'),
      PlaceAmenityDefinition(id: 'public_transport_nearby', group: 'transport'),
      PlaceAmenityDefinition(id: 'family_friendly', group: 'family'),
      PlaceAmenityDefinition(id: 'baby_changing', group: 'family'),
      PlaceAmenityDefinition(id: 'pets_allowed', group: 'pets'),
      PlaceAmenityDefinition(id: 'toilet', group: 'facilities'),
      PlaceAmenityDefinition(id: 'wifi', group: 'facilities'),
      PlaceAmenityDefinition(id: 'drinking_water', group: 'facilities'),
      PlaceAmenityDefinition(id: 'food_available', group: 'food'),
      PlaceAmenityDefinition(id: 'outdoor_seating', group: 'outdoor'),
      PlaceAmenityDefinition(id: 'shelter', group: 'outdoor'),
      PlaceAmenityDefinition(id: 'first_aid', group: 'safety'),
    ];
