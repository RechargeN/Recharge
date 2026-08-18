import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('activity taxonomy includes wellness_recharge and outdoor_nature_walking (flag A, §8)', () {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.activity,
    );
    final Set<String> categoryIds = categories
        .map((CreateTaxonomyCategory c) => c.contentGroup.id)
        .toSet();
    expect(categoryIds, contains('wellness_recharge'));
    expect(categoryIds, contains('outdoor_nature_walking'));
    expect(categoryIds, contains('sport'));
  });

  test('activity taxonomy excludes a category with no flag A (music_nightlife, per §7.1 of CATEGORY_SYSTEM.md)', () {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.activity,
    );
    final Set<String> categoryIds = categories
        .map((CreateTaxonomyCategory c) => c.contentGroup.id)
        .toSet();
    expect(categoryIds, isNot(contains('music_nightlife')));
  });
}
