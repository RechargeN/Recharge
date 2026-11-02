import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/recharge_taxonomy.dart';
import 'package:recharge/core/localization/l10n_context.dart';
import 'package:recharge/core/localization/taxonomy_labels.dart';

/// L4.9.5: every Category System id has its own name in lv, en and ru; ids
/// never change and search still works by id and alias.
void main() {
  test('28 categories and 530 subcategories are all covered', () {
    expect(rechargeContentGroups, hasLength(28));
    expect(rechargeActivityCategories, hasLength(530));
    expect(
      taxonomyCategoryLabels.keys.toSet(),
      rechargeContentGroups.map((RechargeContentGroup g) => g.id).toSet(),
    );
    expect(
      taxonomySubcategoryLabels.keys.toSet(),
      rechargeActivityCategories
          .map((RechargeActivityCategory c) => c.id)
          .toSet(),
    );
  });

  for (final String language in const <String>['en', 'lv', 'ru']) {
    test('$language: every name is real text, never the id', () {
      final AppLocalizations l10n = lookupAppLocalizations(Locale(language));
      final List<String> bad = <String>[
        for (final MapEntry<String, String Function(AppLocalizations)> entry
            in <MapEntry<String, String Function(AppLocalizations)>>[
              ...taxonomyCategoryLabels.entries,
              ...taxonomySubcategoryLabels.entries,
            ])
          if (entry.value(l10n).trim().isEmpty ||
              entry.value(l10n).contains('_') ||
              entry.value(l10n) == entry.key)
            entry.key,
      ];
      expect(bad, isEmpty);
    });
  }

  test('a category path resolves to the subcategory name in the reader '
      'language; an unknown id keeps the old English label', () {
    final AppLocalizations lv = lookupAppLocalizations(const Locale('lv'));
    expect(taxonomyLabel(lv, 'music_nightlife'), lv.taxCategoryMusicNightlife);
    expect(
      taxonomyLabel(lv, 'music_nightlife.concert'),
      lv.taxSubcategoryConcert,
    );
    expect(taxonomyLabel(lv, 'brand_new_id'), 'Brand new id');
  });

  test('search still works by id and alias', () {
    expect(
      searchRechargeActivityCategories('concert').map((c) => c.id),
      contains('concert'),
    );
    expect(rechargeActivityCategoryById('concert')?.id, 'concert');
  });
}
