import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

void main() {
  test('activity CreateBlockConfig matches the Approved spec (§2, §11)', () {
    final CreateBlockConfig config = createBlockConfigFor(
      CreateObjectType.activity,
    );
    expect(config.requiresStartDateTime, isFalse);
    // L4.3: labels are messages keyed by the stable type (English fallback).
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.createObjectTypeLocationLabel(config.objectType.name),
      'Where to go',
    );
    expect(en.createObjectTypePriceLabel(config.objectType.name), isEmpty);
  });
}
