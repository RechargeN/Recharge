import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

import '../../support/l10n/arb_checker.dart';

/// L4 check 1: lv/en/ru resources are complete and consistent.
void main() {
  Map<String, String> arbSet() => <String, String>{
    for (final String locale in AppLocalePolicy.r1LanguageCodes)
      locale: File('lib/l10n/app_$locale.arb').readAsStringSync(),
  };

  test('the generated delegate supports exactly the R1 languages', () {
    expect(
      AppLocalizations.supportedLocales
          .map((Locale locale) => locale.toLanguageTag())
          .toSet(),
      AppLocalePolicy.r1LanguageCodes.toSet(),
    );
  });

  test('lv, en and ru: no missing keys, placeholder drift, plural or select '
      'gaps, malformed messages or undocumented template keys', () {
    expect(ArbChecker(templateLocale: 'en').check(arbSet()), isEmpty);
  });

  test('positive control: each defect class is detected', () {
    const String en = '''{
  "@@locale": "en",
  "a": "Book {count, plural, one{{count} seat} other{{count} seats}}",
  "@a": {"description": "d", "placeholders": {"count": {"type": "int"}}},
  "b": "{state, select, on{On} off{Off} other{?}}",
  "@b": {"description": "d", "placeholders": {"state": {"type": "String"}}},
  "c": "Hello {name}",
  "@c": {"description": "d", "placeholders": {"name": {"type": "String"}}},
  "d": "Plain",
  "e": "Gone in lv"
}''';
    const String lv = '''{
  "@@locale": "lv",
  "a": "{count, plural, one{{count} vieta} other{{count} vietas}}",
  "b": "{state, select, on{Ieslēgts} other{?}}",
  "c": "Sveiki {vards}",
  "d": "Plain {",
  "extra": "x"
}''';
    const String ru = '''{
  "@@locale": "ru",
  "a": "{count, plural, one{{count} место} few{{count} места} many{{count} мест} other{{count} места}}",
  "b": "{state, select, on{Вкл} off{Выкл} other{?}}",
  "c": "Привет {name}",
  "d": "",
  "e": "x"
}''';
    final List<String> findings = ArbChecker(
      templateLocale: 'en',
    ).check(<String, String>{'en': en, 'lv': lv, 'ru': ru});
    expect(
      findings,
      containsAll(<Matcher>[
        contains('en:d: no description'),
        contains('lv:e: missing'),
        contains('lv:extra: not in template'),
        contains('lv:a: plural count lacks {zero}'),
        contains('lv:b: select state cases'),
        contains('lv:c: placeholders'),
        contains('lv:d: malformed'),
        contains('ru:d: empty'),
      ]),
    );
  });

  test('the committed generated code matches the ARB files (run '
      '`flutter gen-l10n` after editing an ARB)', () {
    String dartLiteral(String text) => text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');
    final List<String> stale = <String>[];
    for (final String locale in AppLocalePolicy.r1LanguageCodes) {
      final String generated = File(
        'lib/generated/l10n/app_localizations_$locale.dart',
      ).readAsStringSync();
      final Map<String, dynamic> arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      arb.forEach((String key, dynamic value) {
        if (key.startsWith('@') || value is! String || value.contains('{')) {
          return;
        }
        if (!generated.contains('$key =>') ||
            !generated.contains(dartLiteral(value))) {
          stale.add('$locale:$key');
        }
      });
    }
    expect(stale, isEmpty);
  });

  test('every key resolves to non-empty text through the generated code', () {
    for (final String code in AppLocalePolicy.r1LanguageCodes) {
      final AppLocalizations l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.localeName, code);
      expect(l10n.errorGeneric, isNotEmpty);
      expect(l10n.bookingBookSeats(2), isNotEmpty);
      expect(l10n.publicationReviewState('not_a_state'), isNotEmpty);
    }
  });
}
