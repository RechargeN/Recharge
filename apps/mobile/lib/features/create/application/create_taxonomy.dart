import '../../../core/config/recharge_taxonomy.dart';
import '../domain/entities/create_draft_entity.dart';

/// L4: a type's name, description and field labels come from
/// `createObjectType*` messages keyed by [objectType]; no copy is kept here.
class CreateBlockConfig {
  const CreateBlockConfig({
    required this.objectType,
    required this.defaultCategoryId,
    required this.defaultSubcategoryId,
    required this.requiresStartDateTime,
  });

  final CreateObjectType objectType;
  final String defaultCategoryId;
  final String defaultSubcategoryId;
  final bool requiresStartDateTime;
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
    defaultCategoryId: 'wellness_recharge',
    defaultSubcategoryId: 'calm_walk',
    requiresStartDateTime: true,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.activity,
    defaultCategoryId: 'wellness_recharge',
    defaultSubcategoryId: 'recharge_walk',
    requiresStartDateTime: false,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.route,
    defaultCategoryId: 'travel_tours',
    defaultSubcategoryId: 'walking_tour',
    requiresStartDateTime: false,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.place,
    defaultCategoryId: '',
    defaultSubcategoryId: '',
    requiresStartDateTime: false,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.session,
    defaultCategoryId: 'sport',
    defaultSubcategoryId: 'tennis',
    // Typed SessionSchedule is the single time authority
    // (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §6.1) — the generic
    // startDateTimeUtc gate does not apply once the typed writer is active.
    requiresStartDateTime: false,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.scenario,
    defaultCategoryId: 'food_drinks',
    defaultSubcategoryId: 'coffee',
    requiresStartDateTime: false,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.findPeople,
    defaultCategoryId: 'sport',
    defaultSubcategoryId: 'tennis',
    requiresStartDateTime: true,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.classWorkshop,
    defaultCategoryId: 'workshops_masterclasses',
    defaultSubcategoryId: 'workshop',
    requiresStartDateTime: true,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.rental,
    defaultCategoryId: 'sport',
    defaultSubcategoryId: 'cycling',
    requiresStartDateTime: false,
  ),
  CreateBlockConfig(
    objectType: CreateObjectType.collection,
    defaultCategoryId: 'travel_tours',
    defaultSubcategoryId: 'hidden_gems_tour',
    requiresStartDateTime: false,
  ),
];

CreateBlockConfig createBlockConfigFor(CreateObjectType objectType) {
  if (objectType == CreateObjectType.quickPlan) {
    return const CreateBlockConfig(
      objectType: CreateObjectType.quickPlan,
      defaultCategoryId: 'food_drinks',
      defaultSubcategoryId: 'coffee',
      requiresStartDateTime: false,
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

/// The server answer to "does this pair apply to [type]" from the canonical
/// taxonomy (M1 stage 3): the pair must exist; for Activity it must also apply
/// to Activity. Collection accepts any existing pair.
bool canonicalSubcategoryApplies(
  RechargeContentType type,
  String categoryId,
  String subcategoryId,
) {
  final RechargeActivityCategory? pair = rechargeActivityCategoryByPath(
    contentGroupId: categoryId,
    categorySlug: subcategoryId,
  );
  if (pair == null) return false;
  return type == RechargeContentType.collection ||
      pair.applicableTypes.contains(type);
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
