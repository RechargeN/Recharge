import 'recharge_category_criteria.dart';
import 'recharge_taxonomy_seed.dart';

part 'recharge_taxonomy_migration.dart';

enum RechargeCategoryStatus { active, hidden, deprecated }

enum RechargeModerationLevel { none, standard, strict }

enum RechargeContentType {
  event,
  activity,
  route,
  place,
  session,
  quickPlan,
  findPeople,
  classWorkshop,
  rental,
  collection,
}

extension RechargeContentTypeIds on RechargeContentType {
  String get taxonomyId {
    return switch (this) {
      RechargeContentType.event => 'event',
      RechargeContentType.activity => 'activity',
      RechargeContentType.route => 'route',
      RechargeContentType.place => 'place',
      RechargeContentType.session => 'session',
      RechargeContentType.quickPlan => 'quick_plan',
      RechargeContentType.findPeople => 'find_people',
      RechargeContentType.classWorkshop => 'class_workshop',
      RechargeContentType.rental => 'rental',
      RechargeContentType.collection => 'collection',
    };
  }
}

RechargeContentType? rechargeContentTypeFromId(String value) {
  final String normalized = normalizeRechargeLegacyCreateTypeId(value);
  for (final RechargeContentType type in RechargeContentType.values) {
    if (type.taxonomyId == normalized ||
        type.name.toLowerCase() == normalized.replaceAll('_', '')) {
      return type;
    }
  }
  return null;
}

class RechargeContentGroup {
  const RechargeContentGroup({
    required this.id,
    required this.title,
    required this.l10nKey,
    required this.icon,
    required this.sortOrder,
    required this.applicableTypes,
    required this.defaultProfileId,
    required this.categorySlugs,
    required this.impliedFacets,
    required this.status,
  });

  final String id;
  final String title;
  final String l10nKey;
  final String icon;
  final int sortOrder;
  final Set<RechargeContentType> applicableTypes;
  final String defaultProfileId;
  final List<String> categorySlugs;
  final Map<String, String> impliedFacets;
  final RechargeCategoryStatus status;

  String get description => '$title activities and experiences';
  bool get isHidden => status == RechargeCategoryStatus.hidden;

  Set<RechargeContentType> get effectiveApplicableTypes {
    if (isHidden) return RechargeContentType.values.toSet();
    return <RechargeContentType>{
      ...applicableTypes,
      RechargeContentType.quickPlan,
      RechargeContentType.findPeople,
      RechargeContentType.collection,
      if (rechargeRentalReviewCategoryIds.contains(id))
        RechargeContentType.rental,
    };
  }

  Set<String> get allowedCreateBlockIds => effectiveApplicableTypes
      .map((RechargeContentType type) => type.taxonomyId)
      .toSet();

  bool allowsCreateBlock(String createBlockId) {
    final RechargeContentType? type = rechargeContentTypeFromId(createBlockId);
    return type != null && effectiveApplicableTypes.contains(type);
  }

  String get defaultParticipationMode =>
      _participationModeByProfile[defaultProfileId] ?? 'attend';

  Set<String> get allowedParticipationModes => _allParticipationModes;
}

class RechargeActivityCategory {
  const RechargeActivityCategory({
    required this.id,
    required this.title,
    required this.l10nKey,
    required this.contentGroupId,
    required this.slug,
    required this.profileId,
    required this.applicableTypes,
    required this.aliases,
    required this.keywordsEn,
    required this.keywordsRu,
    required this.keywordsLv,
    required this.impliedFacets,
    required this.seasonality,
    required this.status,
    required this.moderationLevel,
    required this.secondaryGroupIds,
  });

  final String id;
  final String title;
  final String l10nKey;
  final String contentGroupId;
  final String slug;
  final String profileId;
  final Set<RechargeContentType> applicableTypes;
  final List<String> aliases;
  final List<String> keywordsEn;
  final List<String> keywordsRu;
  final List<String> keywordsLv;
  final Map<String, String> impliedFacets;
  final String? seasonality;
  final RechargeCategoryStatus status;
  final RechargeModerationLevel moderationLevel;

  // Transitional compatibility for the current presentation layer.
  final List<String> secondaryGroupIds;

  String get legacyId => '${contentGroupId}_$slug';
  bool get isSeasonal => seasonality != null;
  bool get isFamilyFriendly =>
      contentGroupId == 'family_kids' || impliedFacets['withWhom'] == 'family';
  bool get isPetFriendly => contentGroupId == 'pets_animals';

  List<String> get searchKeywords => <String>[
    ...keywordsEn,
    ...keywordsRu,
    ...keywordsLv,
  ];

  Set<RechargeContentType> get effectiveApplicableTypes {
    final RechargeContentGroup? group = rechargeContentGroupById(
      contentGroupId,
    );
    return <RechargeContentType>{
      ...applicableTypes,
      RechargeContentType.quickPlan,
      RechargeContentType.findPeople,
      RechargeContentType.collection,
      if (group != null && rechargeRentalReviewCategoryIds.contains(group.id))
        RechargeContentType.rental,
    };
  }

  Set<String> get allowedCreateBlockIds => effectiveApplicableTypes
      .map((RechargeContentType type) => type.taxonomyId)
      .toSet();

  bool allowsCreateBlock(String createBlockId) {
    final RechargeContentType? type = rechargeContentTypeFromId(createBlockId);
    return type != null && effectiveApplicableTypes.contains(type);
  }

  String get defaultParticipationMode =>
      _participationModeByProfile[profileId] ?? 'attend';

  Set<String> get allowedParticipationModes => _allParticipationModes;

  Map<String, String> get defaultParticipationModeByCreateBlock =>
      const <String, String>{};

  String participationModeFor(String createBlockId) {
    return switch (normalizeRechargeLegacyCreateTypeId(createBlockId)) {
      'find_people' => 'meet_people',
      'session' || 'rental' => 'book',
      'place' => 'visit',
      'route' || 'collection' => 'explore',
      _ => defaultParticipationMode,
    };
  }

  RechargeCriteriaProfile? get criteriaProfile =>
      rechargeCriteriaProfileById(profileId);
}

const Set<String> _allParticipationModes = <String>{
  'watch',
  'attend',
  'learn',
  'practice',
  'play',
  'compete',
  'meet_people',
  'book',
  'visit',
  'eat_drink',
  'explore',
  'travel',
  'shop',
  'claim',
  'volunteer',
};

const Map<String, String> _participationModeByProfile = <String, String>{
  'physical_activity': 'practice',
  'team_game': 'play',
  'competition': 'compete',
  'game_session': 'play',
  'venue_game': 'play',
  'adrenaline_activity': 'practice',
  'performance_show': 'watch',
  'exhibition_visit': 'visit',
  'talk_lecture': 'learn',
  'networking_social': 'meet_people',
  'hands_on_class': 'learn',
  'food_gathering': 'eat_drink',
  'tasting': 'eat_drink',
  'guided_tour': 'explore',
  'outdoor_activity': 'explore',
  'water_activity': 'practice',
  'kids_event': 'attend',
  'pet_event': 'meet_people',
  'wellness_session': 'practice',
  'market_fair': 'shop',
  'volunteer_action': 'volunteer',
  'open_event': 'attend',
};

const Map<String, List<String>> _curatedAliases = <String, List<String>>{
  'football': <String>['soccer'],
  'tennis': <String>['lawn_tennis'],
  'coffee': <String>['cafe', 'coffee_meetup'],
  'cinema': <String>['movie', 'film'],
  'movie_screening': <String>['film_screening'],
  'museum': <String>['museum_visit'],
  'dog_walk': <String>['pet_walk'],
  'animal_shelter_volunteering': <String>['animal_volunteering'],
};

const Map<String, List<String>> _keywordsEn = <String, List<String>>{
  'football': <String>['match', 'team sport', '5v5', '11v11', 'field'],
  'tennis': <String>['court', 'racket', 'singles', 'doubles', 'coach'],
  'coffee': <String>['espresso', 'latte', 'cafe', 'quick coffee'],
  'cinema': <String>['screening', 'movie night', 'cinema buddy'],
  'museum': <String>['exhibit', 'collection', 'guided tour'],
  'board_games': <String>['board game', 'tabletop'],
  'mafia': <String>['mafia', 'werewolf'],
  'sup': <String>['sup', 'paddleboard', 'paddle board'],
  'pirts_ritual': <String>['pirts', 'latvian sauna ritual'],
  'speed_dating': <String>['speed dating'],
};

const Map<String, List<String>> _keywordsRu = <String, List<String>>{
  'board_games': <String>['настолк', 'настольн игр', 'дндшка'],
  'mafia': <String>['мафия', 'мафи'],
  'sup': <String>['сап', 'сапборд', 'сап-борд'],
  'pirts_ritual': <String>['пиртс', 'баня с банщиком', 'парение'],
  'speed_dating': <String>['быстрые свидания', 'спид дейтинг'],
};

const Map<String, List<String>> _keywordsLv = <String, List<String>>{
  'board_games': <String>['galda spēl', 'galda spel'],
  'mafia': <String>['mafija'],
  'sup': <String>['sup', 'airu dēl', 'airu del'],
  'pirts_ritual': <String>['pirts', 'pēriens', 'periens'],
  'speed_dating': <String>['ātrie randiņi', 'atrie randini'],
};

const Map<String, List<String>> _secondaryGroupIds = <String, List<String>>{
  'swimming': <String>['water_activities'],
  'mini_golf': <String>['sport'],
  'dog_walk': <String>['outdoor_nature_walking', 'wellness_recharge'],
  'puppet_show': <String>['family_kids'],
  'christmas_market': <String>['holidays_seasonal', 'winter_seasonal'],
  'charity_market': <String>['community_charity'],
  'coffee_walk': <String>['outdoor_nature_walking', 'food_drinks'],
};

final List<RechargeContentGroup> rechargeContentGroups = rechargeGroupSeeds
    .asMap()
    .entries
    .map((MapEntry<int, RechargeGroupSeedData> entry) {
      final RechargeGroupSeedData seed = entry.value;
      return RechargeContentGroup(
        id: seed.id,
        title: seed.title,
        l10nKey: 'category.${seed.id}',
        icon: seed.id,
        sortOrder: entry.key,
        applicableTypes: seed.applicableTypeIds
            .map(rechargeContentTypeFromId)
            .whereType<RechargeContentType>()
            .toSet(),
        defaultProfileId: seed.defaultProfileId,
        categorySlugs: seed.categorySlugs,
        impliedFacets:
            rechargeGroupImpliedFacets[seed.id] ?? const <String, String>{},
        status: seed.hidden
            ? RechargeCategoryStatus.hidden
            : RechargeCategoryStatus.active,
      );
    })
    .toList(growable: false);

final List<RechargeContentGroup> rechargeVisibleContentGroups =
    rechargeContentGroups
        .where((RechargeContentGroup group) => !group.isHidden)
        .toList(growable: false);

final Map<String, RechargeContentGroup> _groupsById =
    <String, RechargeContentGroup>{
      for (final RechargeContentGroup group in rechargeContentGroups)
        group.id: group,
    };

final List<RechargeActivityCategory> rechargeActivityCategories =
    rechargeContentGroups.expand(_materializeGroup).toList(growable: false);

final Map<String, RechargeActivityCategory> _categoriesById =
    <String, RechargeActivityCategory>{
      for (final RechargeActivityCategory category
          in rechargeActivityCategories)
        category.id: category,
    };

final Map<String, RechargeActivityCategory> _categoriesByPath =
    <String, RechargeActivityCategory>{
      for (final RechargeActivityCategory category
          in rechargeActivityCategories)
        '${category.contentGroupId}.${category.slug}': category,
    };

List<RechargeActivityCategory> _materializeGroup(RechargeContentGroup group) {
  return group.categorySlugs
      .map((String slug) {
        final RechargeSubcategoryOverrideData? override =
            rechargeSubcategoryOverrides[slug];
        final Set<RechargeContentType> types =
            (override?.applicableTypeIds ??
                    group.applicableTypes
                        .map((RechargeContentType type) => type.taxonomyId)
                        .toList(growable: false))
                .map(rechargeContentTypeFromId)
                .whereType<RechargeContentType>()
                .toSet();
        final Map<String, String> facets = <String, String>{
          ...group.impliedFacets,
          ...?rechargeSubcategoryImpliedFacets[slug],
        };
        return RechargeActivityCategory(
          id: slug,
          title: humanizeRechargeTaxonomyToken(slug),
          l10nKey: 'subcategory.$slug',
          contentGroupId: group.id,
          slug: slug,
          profileId: override?.profileId ?? group.defaultProfileId,
          applicableTypes: types,
          aliases: _curatedAliases[slug] ?? const <String>[],
          keywordsEn: <String>{
            ...slug.split('_'),
            ...?_keywordsEn[slug],
          }.toList(growable: false),
          keywordsRu: _keywordsRu[slug] ?? const <String>[],
          keywordsLv: _keywordsLv[slug] ?? const <String>[],
          impliedFacets: facets,
          seasonality: rechargeSubcategorySeasonality[slug],
          status: RechargeCategoryStatus.active,
          moderationLevel: RechargeModerationLevel.standard,
          secondaryGroupIds: _secondaryGroupIds[slug] ?? const <String>[],
        );
      })
      .toList(growable: false);
}

String normalizeRechargeContentGroupId(String id) {
  final String normalized = id.trim().toLowerCase().replaceAll('-', '_');
  return rechargeLegacyContentGroupAliases[normalized] ?? normalized;
}

RechargeContentGroup? rechargeContentGroupById(String id) {
  return _groupsById[normalizeRechargeContentGroupId(id)];
}

RechargeActivityCategory? rechargeActivityCategoryById(String id) {
  final String normalized = id.trim().toLowerCase().replaceAll('-', '_');
  final RechargeActivityCategory? direct = _categoriesById[normalized];
  if (direct != null) return direct;
  if (normalized.contains('.')) {
    final List<String> parts = normalized.split('.');
    if (parts.length == 2) {
      return rechargeActivityCategoryByPath(
        contentGroupId: parts[0],
        categorySlug: parts[1],
      );
    }
  }
  final String migrated = normalizeRechargeLegacySubcategoryId(normalized);
  final RechargeActivityCategory? legacy = _categoriesById[migrated];
  if (legacy != null) return legacy;
  for (final RechargeContentGroup group in rechargeContentGroups) {
    final String prefix = '${group.id}_';
    if (normalized.startsWith(prefix)) {
      return rechargeActivityCategoryByPath(
        contentGroupId: group.id,
        categorySlug: normalized.substring(prefix.length),
      );
    }
  }
  return null;
}

RechargeActivityCategory? rechargeActivityCategoryByPath({
  required String contentGroupId,
  required String categorySlug,
}) {
  final String groupId = normalizeRechargeContentGroupId(contentGroupId);
  final String slug = categorySlug.trim().toLowerCase().replaceAll('-', '_');
  final String path = '$groupId.$slug';
  final String? aliasTarget = rechargeContextAliases[path];
  if (aliasTarget != null) return _categoriesById[aliasTarget];
  final RechargeActivityCategory? category = _categoriesByPath[path];
  if (category != null) return category;
  return _categoriesById[normalizeRechargeLegacySubcategoryId(slug)];
}

List<RechargeActivityCategory> searchRechargeActivityCategories(
  String query, {
  String? contentGroupId,
  String? createBlockId,
}) {
  final String normalizedQuery = query.trim().toLowerCase().replaceAll(
    '_',
    ' ',
  );
  final String? normalizedGroup = contentGroupId == null
      ? null
      : normalizeRechargeContentGroupId(contentGroupId);
  final List<RechargeActivityCategory> result = rechargeActivityCategories
      .where((RechargeActivityCategory category) {
        if (normalizedGroup != null &&
            category.contentGroupId != normalizedGroup) {
          return false;
        }
        if (createBlockId != null &&
            !category.allowsCreateBlock(createBlockId)) {
          return false;
        }
        if (normalizedQuery.isEmpty) return true;
        return <String>[
          category.id,
          category.title,
          ...category.aliases,
          ...category.keywordsEn,
          ...category.keywordsRu,
          ...category.keywordsLv,
        ].any(
          (String value) => value
              .toLowerCase()
              .replaceAll('_', ' ')
              .contains(normalizedQuery),
        );
      })
      .toList(growable: true);

  if (normalizedGroup != null && normalizedQuery.isNotEmpty) {
    for (final MapEntry<String, String> alias
        in rechargeContextAliases.entries) {
      if (!alias.key.startsWith('$normalizedGroup.')) continue;
      final String aliasSlug = alias.key.split('.').last.replaceAll('_', ' ');
      if (!aliasSlug.contains(normalizedQuery)) continue;
      final RechargeActivityCategory? target = _categoriesById[alias.value];
      if (target != null &&
          (createBlockId == null || target.allowsCreateBlock(createBlockId)) &&
          !result.contains(target)) {
        result.add(target);
      }
    }
  }
  return result.toList(growable: false);
}

String rechargeTaxonomyLabel(String idOrPath) {
  final String normalized = idOrPath.trim().toLowerCase();
  final RechargeContentGroup? group = rechargeContentGroupById(normalized);
  if (group != null) return group.title;
  final RechargeActivityCategory? category = rechargeActivityCategoryById(
    normalized,
  );
  if (category != null) return category.title;
  if (normalized.contains('.')) {
    return humanizeRechargeTaxonomyToken(normalized.split('.').last);
  }
  return humanizeRechargeTaxonomyToken(normalized);
}

List<String> validateRechargeTaxonomy() {
  final List<String> errors = <String>[];
  if (rechargeContentGroups.length != 28) {
    errors.add('Expected 28 category records');
  }
  if (rechargeVisibleContentGroups.length != 27) {
    errors.add('Expected 27 visible categories');
  }
  if (rechargeActivityCategories.length != 516) {
    errors.add('Expected 516 subcategories');
  }
  if (_categoriesById.length != rechargeActivityCategories.length) {
    errors.add('Subcategory ids must be globally unique');
  }
  for (final RechargeContentGroup group in rechargeContentGroups) {
    if (group.l10nKey.isEmpty) errors.add('Missing l10nKey for ${group.id}');
    if (!rechargeCriteriaProfilesById.containsKey(group.defaultProfileId)) {
      errors.add('Unknown default profile for ${group.id}');
    }
  }
  for (final RechargeActivityCategory category in rechargeActivityCategories) {
    if (category.l10nKey.isEmpty) {
      errors.add('Missing l10nKey for ${category.id}');
    }
    if (!rechargeCriteriaProfilesById.containsKey(category.profileId)) {
      errors.add('Unknown profile for ${category.id}');
    }
    for (final String facet in category.impliedFacets.keys) {
      if (!const <String>{'withWhom', 'timeOfDay', 'season'}.contains(facet)) {
        errors.add('Unknown facet $facet for ${category.id}');
      }
    }
  }
  for (final MapEntry<String, String> alias in rechargeContextAliases.entries) {
    if (!_categoriesById.containsKey(alias.value)) {
      errors.add('Alias ${alias.key} has missing target ${alias.value}');
    }
  }
  for (final RechargeCriteriaProfile profile in rechargeCriteriaProfiles) {
    for (final String fieldId in profile.fieldIds) {
      if (!rechargeCriteriaFieldsById.containsKey(fieldId)) {
        errors.add('Profile ${profile.id} has missing field $fieldId');
      }
    }
  }
  return errors;
}

String humanizeRechargeTaxonomyToken(String value) {
  final String normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return normalized;
  return normalized[0].toUpperCase() + normalized.substring(1);
}
