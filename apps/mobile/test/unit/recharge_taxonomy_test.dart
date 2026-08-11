import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/recharge_category_criteria.dart';
import 'package:recharge/core/config/recharge_taxonomy.dart';

void main() {
  test('accepted taxonomy materializes 28/530 with valid invariants', () {
    expect(rechargeContentGroups, hasLength(28));
    expect(rechargeVisibleContentGroups, hasLength(27));
    expect(rechargeActivityCategories, hasLength(530));
    expect(
      rechargeActivityCategories
          .map((RechargeActivityCategory category) => category.id)
          .toSet(),
      hasLength(530),
    );
    expect(rechargeCriteriaFields, hasLength(36));
    expect(rechargeCriteriaProfiles, hasLength(22));
    expect(validateRechargeTaxonomy(), isEmpty);
  });

  test(
    'subcategory ids are global while paths and legacy ids remain readable',
    () {
      final RechargeActivityCategory tennis = rechargeActivityCategoryById(
        'tennis',
      )!;

      expect(tennis.id, 'tennis');
      expect(tennis.legacyId, 'sport_tennis');
      expect(rechargeActivityCategoryById('sport_tennis'), same(tennis));
      expect(rechargeActivityCategoryById('sport.tennis'), same(tennis));
      expect(
        rechargeActivityCategoryByPath(
          contentGroupId: 'sport',
          categorySlug: 'tennis',
        ),
        same(tennis),
      );
      expect(tennis.l10nKey, 'subcategory.tennis');
      expect(tennis.criteriaProfile?.id, 'physical_activity');
    },
  );

  test('canonical aliases resolve without duplicate subcategories', () {
    final RechargeActivityCategory cooking = rechargeActivityCategoryById(
      'cooking_class',
    )!;
    final RechargeActivityCategory volunteering = rechargeActivityCategoryById(
      'animal_shelter_volunteering',
    )!;

    expect(cooking.contentGroupId, 'workshops_masterclasses');
    expect(
      rechargeActivityCategoryByPath(
        contentGroupId: 'food_drinks',
        categorySlug: 'cooking_class',
      ),
      same(cooking),
    );
    expect(
      rechargeActivityCategoryByPath(
        contentGroupId: 'pets_animals',
        categorySlug: 'animal_volunteering',
      ),
      same(volunteering),
    );
    expect(
      rechargeActivityCategories.where(
        (RechargeActivityCategory category) =>
            category.id == 'animal_volunteering',
      ),
      isEmpty,
    );
  });

  test('type applicability follows profiles and universal type rules', () {
    final RechargeActivityCategory museum = rechargeActivityCategoryById(
      'museum',
    )!;
    final RechargeActivityCategory cycling = rechargeActivityCategoryById(
      'cycling',
    )!;

    expect(museum.allowsCreateBlock('place'), isTrue);
    expect(museum.allowsCreateBlock('collection'), isTrue);
    expect(cycling.allowsCreateBlock('rental'), isTrue);
    expect(cycling.allowsCreateBlock('social_request'), isTrue);
    expect(rechargeContentGroupById('other')?.isHidden, isTrue);
  });

  test('adaptive Place types are canonical and place-only', () {
    const Set<String> adaptivePlaceIds = <String>{
      'monument',
      'memorial',
      'sculpture',
      'historic_landmark',
      'park',
      'beach',
      'promenade',
      'viewpoint',
      'forest',
      'lake',
      'waterfall',
      'cave',
      'natural_landmark',
      'public_square',
    };

    for (final String id in adaptivePlaceIds) {
      final RechargeActivityCategory category = rechargeActivityCategoryById(
        id,
      )!;
      expect(category.allowsCreateBlock('place'), isTrue, reason: id);
      expect(category.allowsCreateBlock('event'), isFalse, reason: id);
    }
  });

  test('seasonality and implied facets remain separate metadata', () {
    final RechargeActivityCategory christmas = rechargeActivityCategoryById(
      'christmas',
    )!;
    final RechargeActivityCategory sunsetWalk = rechargeActivityCategoryById(
      'sunset_walk',
    )!;
    final RechargeActivityCategory familyPicnic = rechargeActivityCategoryById(
      'family_picnic',
    )!;

    expect(christmas.seasonality, 'winter');
    expect(christmas.status, RechargeCategoryStatus.active);
    expect(sunsetWalk.impliedFacets['timeOfDay'], 'evening');
    expect(familyPicnic.impliedFacets['withWhom'], 'family');
  });

  test('legacy groups and multilingual category search are supported', () {
    expect(normalizeRechargeContentGroupId('art'), 'art_culture_museums');
    expect(rechargeTaxonomyLabel('wellness'), 'Wellness & recharge');
    expect(
      searchRechargeActivityCategories(
        'lawn tennis',
      ).map((RechargeActivityCategory category) => category.id),
      contains('tennis'),
    );
    expect(
      searchRechargeActivityCategories(
        'настолк',
      ).map((RechargeActivityCategory category) => category.id),
      contains('board_games'),
    );
    expect(
      searchRechargeActivityCategories(
        'animal volunteering',
        contentGroupId: 'pets_animals',
      ).map((RechargeActivityCategory category) => category.id),
      contains('animal_shelter_volunteering'),
    );
  });
}
