import '../../../core/config/recharge_category_criteria.dart';
import '../../../core/config/recharge_taxonomy.dart';

class CategoryCriteriaResult {
  const CategoryCriteriaResult({
    required this.category,
    required this.profile,
    required this.fields,
  });

  final RechargeActivityCategory category;
  final RechargeCriteriaProfile profile;
  final List<RechargeCriteriaFieldDefinition> fields;
}

class GetCategoryCriteriaUseCase {
  const GetCategoryCriteriaUseCase();

  CategoryCriteriaResult? call(String categoryIdOrPath) {
    final RechargeActivityCategory? category = rechargeActivityCategoryById(
      categoryIdOrPath,
    );
    if (category == null) return null;
    final RechargeCriteriaProfile? profile = category.criteriaProfile;
    if (profile == null) return null;
    final List<RechargeCriteriaFieldDefinition> fields = profile.fieldIds
        .map((String id) => rechargeCriteriaFieldsById[id])
        .whereType<RechargeCriteriaFieldDefinition>()
        .toList(growable: false);
    return CategoryCriteriaResult(
      category: category,
      profile: profile,
      fields: fields,
    );
  }
}
