import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/l10n_context.dart';
import 'package:recharge/features/create/presentation/widgets/create_form_texts.dart';

/// L4.4: every step and preset id named in a Create config resolves to text
/// in each R1 language; the resolver's empty fallback is never what shows.
void main() {
  final RegExp idPattern = RegExp(
    r"(?:titleId|descriptionId|labelId):\s*'([A-Za-z]+)'",
  );
  final List<String> ids =
      Directory('lib/features/create/application')
          .listSync()
          .whereType<File>()
          .where((File file) => file.path.endsWith('_create_config.dart'))
          .expand(
            (File file) => idPattern
                .allMatches(file.readAsStringSync())
                .map((RegExpMatch match) => match.group(1)!),
          )
          .toSet()
          .toList()
        ..sort();

  test('the configs name ids at all', () {
    expect(ids.length, greaterThan(40));
  });

  for (final String language in const <String>['en', 'lv', 'ru']) {
    test('every Create config id resolves to text in $language', () {
      final AppLocalizations l10n = lookupAppLocalizations(Locale(language));
      final List<String> empty = <String>[
        for (final String id in ids)
          if (createFormText(l10n, id).trim().isEmpty) id,
      ];
      expect(empty, isEmpty);
    });
  }
}
