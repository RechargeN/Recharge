class EventCreateStepConfig {
  const EventCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

const List<EventCreateStepConfig> eventCreateSteps = <EventCreateStepConfig>[
  EventCreateStepConfig(
    id: 'basics_media',
    title: 'Basics',
    description: 'Identity, category, description and media',
  ),
  EventCreateStepConfig(
    id: 'location_schedule',
    title: 'When & where',
    description: 'Format, location, timezone and occurrences',
  ),
  EventCreateStepConfig(
    id: 'requirements',
    title: 'Requirements',
    description: 'Audience, amenities and participation rules',
  ),
  EventCreateStepConfig(
    id: 'price_participants',
    title: 'Price & people',
    description: 'Money, capacity and external registration',
  ),
  EventCreateStepConfig(
    id: 'preview_publish',
    title: 'Publish',
    description: 'Preview, readiness and moderation submission',
  ),
];

class EventAmenityDefinition {
  const EventAmenityDefinition(this.id, this.label, this.group);

  final String id;
  final String label;
  final String group;
}

const List<EventAmenityDefinition> eventAmenityTaxonomy =
    <EventAmenityDefinition>[
      EventAmenityDefinition(
        'wheelchair_accessible',
        'Wheelchair accessible',
        'Accessibility',
      ),
      EventAmenityDefinition(
        'accessible_toilet',
        'Accessible toilet',
        'Accessibility',
      ),
      EventAmenityDefinition('parking', 'Parking', 'Transport'),
      EventAmenityDefinition('bike_parking', 'Bike parking', 'Transport'),
      EventAmenityDefinition(
        'public_transport',
        'Public transport nearby',
        'Transport',
      ),
      EventAmenityDefinition('family_friendly', 'Family friendly', 'Audience'),
      EventAmenityDefinition('pets_allowed', 'Pets allowed', 'Audience'),
      EventAmenityDefinition('toilet', 'Toilet', 'Facilities'),
      EventAmenityDefinition('wifi', 'Wi-Fi', 'Facilities'),
      EventAmenityDefinition('drinking_water', 'Drinking water', 'Facilities'),
      EventAmenityDefinition('food_available', 'Food available', 'Facilities'),
      EventAmenityDefinition('weather_shelter', 'Weather shelter', 'Outdoor'),
      EventAmenityDefinition('first_aid', 'First aid', 'Safety'),
    ];
