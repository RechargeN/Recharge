import '../../../core/config/recharge_taxonomy.dart';
import '../domain/entities/create_draft_entity.dart';

class CreateBlockConfig {
  const CreateBlockConfig({
    required this.objectType,
    required this.title,
    required this.description,
    required this.defaultCategoryId,
    required this.defaultSubcategoryId,
    required this.requiresStartDateTime,
    required this.locationLabel,
    required this.priceLabel,
  });

  final CreateObjectType objectType;
  final String title;
  final String description;
  final String defaultCategoryId;
  final String defaultSubcategoryId;
  final bool requiresStartDateTime;
  final String locationLabel;
  final String priceLabel;
}

class CreateTaxonomySubcategory {
  const CreateTaxonomySubcategory(this.activityCategory);

  final RechargeActivityCategory activityCategory;

  String get id => activityCategory.slug;
  String get title => activityCategory.title;
  String get fullId => activityCategory.legacyId;

  bool allows(CreateObjectType objectType) {
    return activityCategory.allowsCreateBlock(objectType.taxonomyId);
  }

  String participationModeFor(CreateObjectType objectType) {
    return activityCategory.participationModeFor(objectType.taxonomyId);
  }
}

class CreateTaxonomyCategory {
  const CreateTaxonomyCategory({
    required this.contentGroup,
    required this.subcategories,
  });

  final RechargeContentGroup contentGroup;
  final List<CreateTaxonomySubcategory> subcategories;

  String get id => contentGroup.id;
  String get title => contentGroup.title;
  String get description => contentGroup.description;
  String get defaultParticipationMode => contentGroup.defaultParticipationMode;
  Set<CreateObjectType> get allowedObjectTypes => <CreateObjectType>{
    ...contentGroup.allowedCreateBlockIds.map(createObjectTypeFromId),
    for (final CreateTaxonomySubcategory subcategory in subcategories)
      ...subcategory.activityCategory.allowedCreateBlockIds.map(
        createObjectTypeFromId,
      ),
  };

  bool allows(CreateObjectType objectType) {
    return contentGroup.allowsCreateBlock(objectType.taxonomyId) ||
        subcategories.any(
          (CreateTaxonomySubcategory subcategory) =>
              subcategory.allows(objectType),
        );
  }
}

const List<CreateBlockConfig> rechargeCreateBlockConfigs = <CreateBlockConfig>[
  CreateBlockConfig(
    objectType: CreateObjectType.event,
    title: 'Event',
    description: 'Public activity with time, place, and attendees',
    defaultCategoryId: 'wellness_recharge',
    defaultSubcategoryId: 'calm_walk',
    requiresStartDateTime: true,
    locationLabel: 'Venue',
    priceLabel: 'Ticket or entry price',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.activity,
    title: 'Recharge activity',
    description: 'Lightweight activity such as a walk or reset',
    defaultCategoryId: 'wellness_recharge',
    defaultSubcategoryId: 'recharge_walk',
    requiresStartDateTime: false,
    locationLabel: 'Where to go',
    priceLabel: '',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.route,
    title: 'Route',
    description: 'Continuous track with anchors, segments and route details',
    defaultCategoryId: 'travel_tours',
    defaultSubcategoryId: 'walking_tour',
    requiresStartDateTime: false,
    locationLabel: 'Start point',
    priceLabel: 'Route budget',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.place,
    title: 'Place',
    description: 'A permanent physical place, venue, public space or landmark',
    defaultCategoryId: '',
    defaultSubcategoryId: '',
    requiresStartDateTime: false,
    locationLabel: 'Place name',
    priceLabel: 'Typical spend',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.session,
    title: 'Bookable session',
    description: 'Time-based service, class, table, court, or session',
    defaultCategoryId: 'sport',
    defaultSubcategoryId: 'tennis',
    requiresStartDateTime: true,
    locationLabel: 'Bookable venue',
    priceLabel: 'Booking price',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.scenario,
    title: 'Scenario',
    description: 'City, day, weekend or trip plan made of independent stops',
    defaultCategoryId: 'food_drinks',
    defaultSubcategoryId: 'coffee',
    requiresStartDateTime: false,
    locationLabel: 'Area or city',
    priceLabel: 'Scenario budget',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.findPeople,
    title: 'Find people',
    description: 'Find company for a specific activity',
    defaultCategoryId: 'sport',
    defaultSubcategoryId: 'tennis',
    requiresStartDateTime: true,
    locationLabel: 'Meeting place',
    priceLabel: 'Expected spend',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.classWorkshop,
    title: 'Class / workshop',
    description: 'A guided class, workshop, or hands-on experience',
    defaultCategoryId: 'workshops_masterclasses',
    defaultSubcategoryId: 'workshop',
    requiresStartDateTime: true,
    locationLabel: 'Class venue',
    priceLabel: 'Participation price',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.rental,
    title: 'Rental / equipment',
    description: 'Equipment or transport available for rent',
    defaultCategoryId: 'sport',
    defaultSubcategoryId: 'cycling',
    requiresStartDateTime: false,
    locationLabel: 'Pickup place',
    priceLabel: 'Rental price',
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.collection,
    title: 'Collection / guide',
    description: 'A curated collection of places and ideas',
    defaultCategoryId: 'travel_tours',
    defaultSubcategoryId: 'hidden_gems_tour',
    requiresStartDateTime: false,
    locationLabel: 'Area',
    priceLabel: 'Collection budget',
  ),
];

CreateBlockConfig createBlockConfigFor(CreateObjectType objectType) {
  if (objectType == CreateObjectType.quickPlan) {
    return const CreateBlockConfig(
      objectType: CreateObjectType.quickPlan,
      title: 'Legacy Quick Plan',
      description: 'Personal lightweight plan kept for read compatibility',
      defaultCategoryId: 'food_drinks',
      defaultSubcategoryId: 'coffee',
      requiresStartDateTime: false,
      locationLabel: 'Meeting place',
      priceLabel: 'Expected spend',
    );
  }
  return rechargeCreateBlockConfigs.firstWhere(
    (CreateBlockConfig config) => config.objectType == objectType,
    orElse: () => rechargeCreateBlockConfigs.first,
  );
}

// Materialized from the accepted docs/product/CATEGORY_SYSTEM.md registry.
final List<CreateTaxonomyCategory> rechargeCreateTaxonomy =
    rechargeContentGroups
        .map((RechargeContentGroup group) {
          final List<CreateTaxonomySubcategory> subcategories =
              rechargeActivityCategories
                  .where(
                    (RechargeActivityCategory category) =>
                        category.contentGroupId == group.id,
                  )
                  .map(CreateTaxonomySubcategory.new)
                  .toList(growable: false);
          return CreateTaxonomyCategory(
            contentGroup: group,
            subcategories: subcategories,
          );
        })
        .toList(growable: false);

List<CreateTaxonomyCategory> createTaxonomyForObjectType(
  CreateObjectType objectType,
) {
  if (objectType == CreateObjectType.findPeople) {
    return rechargeCreateTaxonomy;
  }
  return rechargeCreateTaxonomy
      .where((CreateTaxonomyCategory category) => category.allows(objectType))
      .map(
        (CreateTaxonomyCategory category) => CreateTaxonomyCategory(
          contentGroup: category.contentGroup,
          subcategories: category.subcategories
              .where(
                (CreateTaxonomySubcategory subcategory) =>
                    subcategory.allows(objectType),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

CreateTaxonomyCategory? createTaxonomyCategoryById(String id) {
  final String normalized = normalizeRechargeContentGroupId(id);
  for (final CreateTaxonomyCategory category in rechargeCreateTaxonomy) {
    if (category.id == normalized) return category;
  }
  return null;
}

const Map<String, String> _preferredSubcategoryByGroup = <String, String>{
  'art_culture_museums': 'museum',
  'community_charity': 'neighborhood_event',
  'family_kids': 'family_activity',
  'food_drinks': 'coffee',
  'games_indoor': 'board_games',
  'music_nightlife': 'live_music',
  'outdoor_nature_walking': 'city_walk',
  'sport': 'tennis',
  'travel_tours': 'walking_tour',
  'wellness_recharge': 'calm_walk',
};

CreateTaxonomySubcategory? createDefaultSubcategoryFor(
  CreateTaxonomyCategory category,
) {
  final String? preferredId = _preferredSubcategoryByGroup[category.id];
  if (preferredId != null) {
    for (final CreateTaxonomySubcategory subcategory
        in category.subcategories) {
      if (subcategory.id == preferredId) return subcategory;
    }
  }
  return category.subcategories.isEmpty ? null : category.subcategories.first;
}

String createTaxonomyLabelForPath(String path) {
  return rechargeTaxonomyLabel(path);
}
