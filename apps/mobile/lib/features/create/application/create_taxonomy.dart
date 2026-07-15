import '../domain/entities/create_draft_entity.dart';

class CreateTaxonomySubcategory {
  const CreateTaxonomySubcategory({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;
}

class CreateTaxonomyCategory {
  const CreateTaxonomyCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.allowedObjectTypes,
    required this.defaultParticipationMode,
    required this.subcategories,
  });

  final String id;
  final String title;
  final String description;
  final Set<CreateObjectType> allowedObjectTypes;
  final String defaultParticipationMode;
  final List<CreateTaxonomySubcategory> subcategories;

  bool allows(CreateObjectType objectType) {
    return allowedObjectTypes.contains(objectType);
  }
}

const Set<CreateObjectType> _eventAndPlace = <CreateObjectType>{
  CreateObjectType.event,
  CreateObjectType.place,
};

// Mirrors docs/product/RECHARGE_CREATE_TAXONOMY_V1.md.
const List<CreateTaxonomyCategory> rechargeCreateTaxonomyV1 =
    <CreateTaxonomyCategory>[
  CreateTaxonomyCategory(
    id: 'sport',
    title: 'Sport',
    description: 'Matches, training, courts',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'play',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'tennis', title: 'Tennis'),
      CreateTaxonomySubcategory(id: 'table_tennis', title: 'Table tennis'),
      CreateTaxonomySubcategory(id: 'yoga', title: 'Yoga'),
      CreateTaxonomySubcategory(
        id: 'amateur_tournament',
        title: 'Amateur tournament',
      ),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'outdoor_nature_walking',
    title: 'Outdoor',
    description: 'Walks, routes, nature',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'explore',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'city_walk', title: 'City walk'),
      CreateTaxonomySubcategory(id: 'picnic_walk', title: 'Picnic walk'),
      CreateTaxonomySubcategory(id: 'water_tour', title: 'Water tour'),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'wellness_recharge',
    title: 'Recharge',
    description: 'Calm, reset, low pressure',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'practice',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'calm_walk', title: 'Calm walk'),
      CreateTaxonomySubcategory(id: 'coffee_walk', title: 'Coffee walk'),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'food_drinks',
    title: 'Food & drinks',
    description: 'Cafes, tastings, brunch',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'eat_drink',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'coffee', title: 'Coffee'),
      CreateTaxonomySubcategory(id: 'brunch', title: 'Brunch'),
      CreateTaxonomySubcategory(id: 'picnic', title: 'Picnic'),
      CreateTaxonomySubcategory(id: 'food_tour', title: 'Food tour'),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'art_culture_museums',
    title: 'Culture',
    description: 'Museums, galleries, visits',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'visit',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'museum', title: 'Museum'),
      CreateTaxonomySubcategory(id: 'museum_night', title: 'Museum night'),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'games_indoor',
    title: 'Indoor games',
    description: 'Board, table, social games',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'play',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'board_games', title: 'Board games'),
      CreateTaxonomySubcategory(id: 'mini_golf', title: 'Mini golf'),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'travel_tours',
    title: 'Tours',
    description: 'Guided and local experiences',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'travel',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'city_tour', title: 'City tour'),
      CreateTaxonomySubcategory(id: 'walking_tour', title: 'Walking tour'),
      CreateTaxonomySubcategory(id: 'hidden_gems_tour', title: 'Hidden gems'),
    ],
  ),
  CreateTaxonomyCategory(
    id: 'family_kids',
    title: 'Family',
    description: 'Kids and family activities',
    allowedObjectTypes: _eventAndPlace,
    defaultParticipationMode: 'attend',
    subcategories: <CreateTaxonomySubcategory>[
      CreateTaxonomySubcategory(id: 'family_activity', title: 'Family activity'),
      CreateTaxonomySubcategory(id: 'kids_workshop', title: 'Kids workshop'),
      CreateTaxonomySubcategory(id: 'family_picnic', title: 'Family picnic'),
    ],
  ),
];

List<CreateTaxonomyCategory> createTaxonomyForObjectType(
  CreateObjectType objectType,
) {
  return rechargeCreateTaxonomyV1
      .where((CreateTaxonomyCategory category) => category.allows(objectType))
      .toList(growable: false);
}

CreateTaxonomyCategory? createTaxonomyCategoryById(String id) {
  for (final CreateTaxonomyCategory category in rechargeCreateTaxonomyV1) {
    if (category.id == id) return category;
  }
  return null;
}

String createTaxonomyLabelForPath(String path) {
  final String trimmed = path.trim();
  if (trimmed.isEmpty) return trimmed;

  final List<String> parts = trimmed.split('.');
  if (parts.length >= 2) {
    final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
      parts.first,
    );
    if (category != null) {
      final String subcategoryId = parts.sublist(1).join('.');
      for (final CreateTaxonomySubcategory subcategory
          in category.subcategories) {
        if (subcategory.id == subcategoryId) return subcategory.title;
      }
    }
    return _humanizeTaxonomyToken(parts.last);
  }

  final CreateTaxonomyCategory? category = createTaxonomyCategoryById(trimmed);
  return category?.title ?? _humanizeTaxonomyToken(trimmed);
}

String _humanizeTaxonomyToken(String value) {
  final String normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return normalized;
  return normalized[0].toUpperCase() + normalized.substring(1);
}
