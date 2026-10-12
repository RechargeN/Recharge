import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/recharge_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/rental_create_policy.dart';

/// D3.3 §2 Q1a/Q1b: the TEST-ONLY Emulator Rental policy (the canonical
/// fixture file, equal to the backend constant by a backend test) follows the
/// form's own Rental policy: the same category whitelist, the same
/// "required" flags per category and the same absolute duration bounds; every
/// test pair is a real subcategory of its category in this app's taxonomy. The
/// remaining numbers are proposals and are not checked against the form.
void main() {
  final Map<String, Object?> fixture =
      jsonDecode(
            File(
              '../../packages/api_contracts/schema/content/v1/fixtures/'
              'rental_reference_policy.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  const RentalCreatePolicy form = RentalCreatePolicy.safeFallback;

  test('the whitelist and the duration bounds are the form\'s', () {
    expect(fixture['typeId'], 'rental');
    expect(
      (fixture['categories']! as List<Object?>).toSet(),
      form.categoryWhitelist,
    );
    final Map<String, Object?> base = fixture['base']! as Map<String, Object?>;
    expect(base['absoluteMinMinutes'], form.absoluteMinMinutes);
    expect(base['absoluteMaxMinutes'], form.absoluteMaxMinutes);
  });

  test('the required flags per category are the form\'s', () {
    final Map<String, Object?> requirements =
        fixture['requirements']! as Map<String, Object?>;
    for (final String category in form.categoryWhitelist) {
      final Map<String, Object?> flags =
          requirements[category]! as Map<String, Object?>;
      expect(
        flags['requiresSizeOrVariant'],
        form.sizeVariantRequiredCategoryIds.contains(category),
        reason: category,
      );
      expect(
        flags['requiresMinRenterAge'],
        form.minRenterAgeRequiredCategoryIds.contains(category),
        reason: category,
      );
      expect(
        flags['requiresIdAtHandover'],
        form.idRequiredCategoryIds.contains(category),
        reason: category,
      );
      expect(
        flags['requiresSafetyNotice'],
        form.safetyNoticeRequiredCategoryIds.contains(category),
        reason: category,
      );
    }
  });

  test('every test pair is a real subcategory of a whitelisted category', () {
    for (final Object? value in fixture['pairs']! as List<Object?>) {
      final Map<String, Object?> pair = value! as Map<String, Object?>;
      final String group = pair['categoryId']! as String;
      final String slug = pair['subcategoryId']! as String;
      expect(form.categoryWhitelist, contains(group));
      final RechargeActivityCategory? category = rechargeActivityCategoryByPath(
        contentGroupId: group,
        categorySlug: slug,
      );
      expect(category, isNotNull, reason: '$group/$slug');
      expect(category!.contentGroupId, group);
    }
  });
}
