import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('activity CreateBlockConfig matches the Approved spec (§2, §11)', () {
    final CreateBlockConfig config = createBlockConfigFor(CreateObjectType.activity);
    expect(config.requiresStartDateTime, isFalse);
    expect(config.locationLabel, 'Where to go');
    expect(config.priceLabel, isEmpty);
  });
}
