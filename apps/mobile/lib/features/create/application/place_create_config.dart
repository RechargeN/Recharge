import '../domain/entities/place_creation_policy.dart';
import '../domain/entities/place_draft_data.dart';

class PlaceCreateStepConfig {
  const PlaceCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

const List<PlaceCreateStepConfig> placeCreateSteps = <PlaceCreateStepConfig>[
  PlaceCreateStepConfig(
    id: 'identity',
    title: 'About',
    description: 'Name, category and only the details this place needs',
  ),
  PlaceCreateStepConfig(
    id: 'visit',
    title: 'Visit',
    description: 'Confirmed map point and relevant visit information',
  ),
  PlaceCreateStepConfig(
    id: 'publish',
    title: 'Publish',
    description: 'Readiness, optional improvements and final checks',
  ),
];

const PlaceCreationPolicy simplePoiPlacePolicy = PlaceCreationPolicy(
  id: PlaceCreationProfileId.simplePoi,
  label: 'Simple point of interest',
  description:
      'A landmark people can identify and visit without managed access.',
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
  label: 'Public space',
  description: 'An open public area with optional access restrictions.',
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
  label: 'Natural destination',
  description: 'A natural point or area where access facts may be unknown.',
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
  label: 'Cultural venue',
  description: 'A managed museum, gallery, cinema or cultural venue.',
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
  label: 'Food or hospitality venue',
  description: 'A managed venue where spend matters but admission does not.',
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
  label: 'Activity or service venue',
  description: 'A managed venue with optional booking, spend and facilities.',
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
  label: 'Managed attraction',
  description: 'A managed attraction that may have admission and facilities.',
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
  label: 'General place',
  description: 'A safe fallback with no invented opening or pricing facts.',
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
  const PlaceAmenityDefinition({
    required this.id,
    required this.label,
    required this.group,
  });

  final String id;
  final String label;
  final String group;
}

const List<PlaceAmenityDefinition>
placeAmenityTaxonomy = <PlaceAmenityDefinition>[
  PlaceAmenityDefinition(
    id: 'wheelchair_accessible',
    label: 'Wheelchair accessible',
    group: 'Accessibility',
  ),
  PlaceAmenityDefinition(
    id: 'accessible_toilet',
    label: 'Accessible toilet',
    group: 'Accessibility',
  ),
  PlaceAmenityDefinition(id: 'parking', label: 'Parking', group: 'Transport'),
  PlaceAmenityDefinition(
    id: 'bike_parking',
    label: 'Bike parking',
    group: 'Transport',
  ),
  PlaceAmenityDefinition(
    id: 'public_transport_nearby',
    label: 'Public transport nearby',
    group: 'Transport',
  ),
  PlaceAmenityDefinition(
    id: 'family_friendly',
    label: 'Family friendly',
    group: 'Family',
  ),
  PlaceAmenityDefinition(
    id: 'baby_changing',
    label: 'Baby changing',
    group: 'Family',
  ),
  PlaceAmenityDefinition(
    id: 'pets_allowed',
    label: 'Pets allowed',
    group: 'Pets',
  ),
  PlaceAmenityDefinition(id: 'toilet', label: 'Toilet', group: 'Facilities'),
  PlaceAmenityDefinition(id: 'wifi', label: 'Wi-Fi', group: 'Facilities'),
  PlaceAmenityDefinition(
    id: 'drinking_water',
    label: 'Drinking water',
    group: 'Facilities',
  ),
  PlaceAmenityDefinition(
    id: 'food_available',
    label: 'Food available',
    group: 'Food',
  ),
  PlaceAmenityDefinition(
    id: 'outdoor_seating',
    label: 'Outdoor seating',
    group: 'Outdoor',
  ),
  PlaceAmenityDefinition(
    id: 'shelter',
    label: 'Weather shelter',
    group: 'Outdoor',
  ),
  PlaceAmenityDefinition(id: 'first_aid', label: 'First aid', group: 'Safety'),
];
