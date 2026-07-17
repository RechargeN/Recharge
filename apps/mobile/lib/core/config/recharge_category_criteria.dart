class RechargeCriteriaFieldDefinition {
  const RechargeCriteriaFieldDefinition({
    required this.id,
    required this.type,
    required this.description,
  });

  final String id;
  final String type;
  final String description;
}

class RechargeCriteriaProfile {
  const RechargeCriteriaProfile({
    required this.id,
    required this.fieldIds,
    required this.requiredFieldIds,
  });

  final String id;
  final List<String> fieldIds;
  final Set<String> requiredFieldIds;
}

const List<RechargeCriteriaFieldDefinition> rechargeCriteriaFields =
    <RechargeCriteriaFieldDefinition>[
      RechargeCriteriaFieldDefinition(
        id: 'language',
        type: 'multiselect',
        description: 'en / ru / lv / other',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'skill_level',
        type: 'select',
        description: 'any / beginner / intermediate / advanced',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'experience_level',
        type: 'select',
        description: 'newcomers_welcome / regulars / mixed',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'age_restriction',
        type: 'select',
        description: 'none / 12+ / 16+ / 18+',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'age_range',
        type: 'range',
        description: '0–17 (детские)',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'min_age',
        type: 'number',
        description: '3–18 (допуск на активность)',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'equipment_provided',
        type: 'select',
        description: 'provided / bring_own / rental_onsite',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'venue_type',
        type: 'select',
        description: 'indoor / outdoor / mixed',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'team_format',
        type: 'select',
        description: 'опции задаёт подкатегория (5x5, 11x11…)',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'players_min',
        type: 'number',
        description: '2–100',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'players_max',
        type: 'number',
        description: '2–100',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'difficulty',
        type: 'select',
        description: 'easy / medium / hard',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'distance_km',
        type: 'number',
        description: '0.5–100',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'pace',
        type: 'select',
        description: 'relaxed / moderate / fast',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'terrain',
        type: 'select',
        description: 'forest / coast / urban / mixed',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'dietary_options',
        type: 'multiselect',
        description: 'vegan / vegetarian / halal / gluten_free / none',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'tasting_type',
        type: 'select',
        description: 'wine / beer / coffee / cocktail / food',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'dress_code',
        type: 'select',
        description: 'none / smart_casual / themed',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'parental_presence',
        type: 'select',
        description: 'required / optional',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'supervision_provided',
        type: 'bool',
        description: '',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'genre',
        type: 'select',
        description: 'справочник genres (отдельный seed)',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'music_genre',
        type: 'select',
        description: 'справочник music_genres',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'topic',
        type: 'select',
        description: 'справочник topics',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'format',
        type: 'select',
        description: 'talk / discussion / open_meetup',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'seating',
        type: 'select',
        description: 'standing / seated / free',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'entry_type',
        type: 'select',
        description: 'free / ticket / guest_list / registration',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'transport_to_start',
        type: 'select',
        description: 'own / shared / included',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'swimming_required',
        type: 'bool',
        description: '',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'weather_dependent',
        type: 'bool',
        description: '',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'safety_briefing',
        type: 'bool',
        description: 'инструктаж включён',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'reservation_needed',
        type: 'bool',
        description: '',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'venue_booked',
        type: 'bool',
        description: 'место уже забронировано организатором',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'own_games_welcome',
        type: 'bool',
        description: '',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'pet_size',
        type: 'multiselect',
        description: 'small / medium / large / any',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'vaccination_required',
        type: 'bool',
        description: '',
      ),
      RechargeCriteriaFieldDefinition(
        id: 'on_leash',
        type: 'select',
        description: 'required / free_area / mixed',
      ),
    ];

const List<RechargeCriteriaProfile>
rechargeCriteriaProfiles = <RechargeCriteriaProfile>[
  RechargeCriteriaProfile(
    id: 'physical_activity',
    fieldIds: <String>[
      'skill_level',
      'equipment_provided',
      'venue_type',
      'pace',
    ],
    requiredFieldIds: <String>{'skill_level'},
  ),
  RechargeCriteriaProfile(
    id: 'team_game',
    fieldIds: <String>[
      'team_format',
      'skill_level',
      'venue_type',
      'equipment_provided',
    ],
    requiredFieldIds: <String>{'team_format', 'skill_level'},
  ),
  RechargeCriteriaProfile(
    id: 'competition',
    fieldIds: <String>['skill_level', 'entry_type', 'age_restriction'],
    requiredFieldIds: <String>{'entry_type'},
  ),
  RechargeCriteriaProfile(
    id: 'game_session',
    fieldIds: <String>[
      'players_min',
      'players_max',
      'language',
      'experience_level',
      'own_games_welcome',
    ],
    requiredFieldIds: <String>{'players_min', 'players_max', 'language'},
  ),
  RechargeCriteriaProfile(
    id: 'venue_game',
    fieldIds: <String>['venue_type', 'reservation_needed', 'min_age'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'adrenaline_activity',
    fieldIds: <String>[
      'age_restriction',
      'equipment_provided',
      'safety_briefing',
      'weather_dependent',
    ],
    requiredFieldIds: <String>{'age_restriction'},
  ),
  RechargeCriteriaProfile(
    id: 'performance_show',
    fieldIds: <String>['genre', 'age_restriction', 'seating', 'language'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'exhibition_visit',
    fieldIds: <String>['venue_type', 'language'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'talk_lecture',
    fieldIds: <String>['topic', 'language', 'format', 'experience_level'],
    requiredFieldIds: <String>{'language'},
  ),
  RechargeCriteriaProfile(
    id: 'networking_social',
    fieldIds: <String>['language', 'experience_level', 'dress_code'],
    requiredFieldIds: <String>{'language'},
  ),
  RechargeCriteriaProfile(
    id: 'hands_on_class',
    fieldIds: <String>[
      'skill_level',
      'equipment_provided',
      'language',
      'age_restriction',
    ],
    requiredFieldIds: <String>{'skill_level', 'equipment_provided'},
  ),
  RechargeCriteriaProfile(
    id: 'food_gathering',
    fieldIds: <String>['dietary_options', 'language', 'venue_booked'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'tasting',
    fieldIds: <String>['tasting_type', 'age_restriction', 'dietary_options'],
    requiredFieldIds: <String>{'tasting_type', 'age_restriction'},
  ),
  RechargeCriteriaProfile(
    id: 'guided_tour',
    fieldIds: <String>[
      'language',
      'distance_km',
      'transport_to_start',
      'difficulty',
    ],
    requiredFieldIds: <String>{'language'},
  ),
  RechargeCriteriaProfile(
    id: 'outdoor_activity',
    fieldIds: <String>[
      'distance_km',
      'difficulty',
      'terrain',
      'weather_dependent',
    ],
    requiredFieldIds: <String>{'difficulty'},
  ),
  RechargeCriteriaProfile(
    id: 'water_activity',
    fieldIds: <String>[
      'equipment_provided',
      'swimming_required',
      'difficulty',
      'weather_dependent',
    ],
    requiredFieldIds: <String>{'equipment_provided', 'swimming_required'},
  ),
  RechargeCriteriaProfile(
    id: 'kids_event',
    fieldIds: <String>[
      'age_range',
      'parental_presence',
      'supervision_provided',
    ],
    requiredFieldIds: <String>{'age_range', 'parental_presence'},
  ),
  RechargeCriteriaProfile(
    id: 'pet_event',
    fieldIds: <String>['pet_size', 'vaccination_required', 'on_leash'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'wellness_session',
    fieldIds: <String>[
      'skill_level',
      'equipment_provided',
      'language',
      'venue_type',
    ],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'market_fair',
    fieldIds: <String>['entry_type', 'venue_type'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'volunteer_action',
    fieldIds: <String>['min_age', 'equipment_provided', 'weather_dependent'],
    requiredFieldIds: <String>{},
  ),
  RechargeCriteriaProfile(
    id: 'open_event',
    fieldIds: <String>[],
    requiredFieldIds: <String>{},
  ),
];

final Map<String, RechargeCriteriaFieldDefinition> rechargeCriteriaFieldsById =
    <String, RechargeCriteriaFieldDefinition>{
      for (final RechargeCriteriaFieldDefinition field
          in rechargeCriteriaFields)
        field.id: field,
    };

final Map<String, RechargeCriteriaProfile> rechargeCriteriaProfilesById =
    <String, RechargeCriteriaProfile>{
      for (final RechargeCriteriaProfile profile in rechargeCriteriaProfiles)
        profile.id: profile,
    };

RechargeCriteriaProfile? rechargeCriteriaProfileById(String id) {
  return rechargeCriteriaProfilesById[id.trim()];
}
