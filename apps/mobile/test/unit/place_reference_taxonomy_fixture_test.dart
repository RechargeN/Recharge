import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/recharge_taxonomy.dart';

/// D3.1 §2.3: the Emulator Place taxonomy the backend answers with (the
/// canonical fixture file, equal to the backend constant by a backend test) is
/// a true subset of this app's taxonomy: same group, same applicability to
/// Place, same criteria profile and the same required criteria.
void main() {
  test('every Emulator Place taxonomy entry matches the mobile taxonomy', () {
    final Map<String, Object?> fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/'
                'place_reference_taxonomy.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(fixture['typeId'], 'place');
    final List<Object?> entries = fixture['entries']! as List<Object?>;
    expect(entries, hasLength(5));
    for (final Object? value in entries) {
      final Map<String, Object?> entry = value! as Map<String, Object?>;
      final String group = entry['categoryId']! as String;
      final String slug = entry['subcategoryId']! as String;
      final RechargeActivityCategory? category = rechargeActivityCategoryByPath(
        contentGroupId: group,
        categorySlug: slug,
      );
      expect(category, isNotNull, reason: '$group/$slug');
      expect(category!.contentGroupId, group);
      expect(category.slug, slug);
      expect(
        category.applicableTypes.contains(RechargeContentType.place),
        entry['appliesToPlace'],
        reason: '$group/$slug applicability',
      );
      expect(category.profileId, entry['profileId'], reason: '$group/$slug');
      expect(
        category.criteriaProfile?.requiredFieldIds ?? const <String>{},
        unorderedEquals(entry['requiredCriteria']! as List<Object?>),
        reason: '$group/$slug required criteria',
      );
    }
  });

  test(
    'the fixture keeps one inapplicable subcategory and one with a required criterion',
    () {
      final List<Object?> entries =
          (jsonDecode(
                    File(
                      '../../packages/api_contracts/schema/content/v1/fixtures/'
                      'place_reference_taxonomy.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, Object?>)['entries']!
              as List<Object?>;
      final List<Map<String, Object?>> typed = entries
          .cast<Map<String, Object?>>()
          .toList();
      expect(
        typed.where((entry) => entry['appliesToPlace'] == false),
        isNotEmpty,
      );
      expect(
        typed.where(
          (entry) =>
              entry['appliesToPlace'] == true &&
              (entry['requiredCriteria']! as List<Object?>).isNotEmpty,
        ),
        isNotEmpty,
      );
    },
  );
}
