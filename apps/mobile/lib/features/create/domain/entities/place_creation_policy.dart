import 'place_draft_data.dart';

enum PlaceCreationProfileId {
  simplePoi,
  publicSpace,
  naturalDestination,
  culturalVenue,
  hospitality,
  activityVenue,
  paidAttraction,
  balanced,
}

enum PlaceFieldRequirement { hidden, optional, recommended, required }

extension PlaceFieldRequirementX on PlaceFieldRequirement {
  bool get isVisible => this != PlaceFieldRequirement.hidden;
  bool get isRequired => this == PlaceFieldRequirement.required;
  bool get isRecommended => this == PlaceFieldRequirement.recommended;
}

class PlaceCreationPolicy {
  const PlaceCreationPolicy({
    required this.id,
    required this.label,
    required this.description,
    required this.suggestedKind,
    required this.shortDescription,
    required this.cover,
    required this.hours,
    required this.admission,
    required this.typicalSpend,
    required this.visitPlanning,
    required this.amenities,
    required this.contacts,
    required this.booking,
    required this.accessNote,
  });

  final PlaceCreationProfileId id;
  final String label;
  final String description;
  final PlaceKind suggestedKind;
  final PlaceFieldRequirement shortDescription;
  final PlaceFieldRequirement cover;
  final PlaceFieldRequirement hours;
  final PlaceFieldRequirement admission;
  final PlaceFieldRequirement typicalSpend;
  final PlaceFieldRequirement visitPlanning;
  final PlaceFieldRequirement amenities;
  final PlaceFieldRequirement contacts;
  final PlaceFieldRequirement booking;
  final PlaceFieldRequirement accessNote;

  bool get isManaged => suggestedKind == PlaceKind.managedVenue;

  static const PlaceCreationPolicy safeFallback = PlaceCreationPolicy(
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
}
