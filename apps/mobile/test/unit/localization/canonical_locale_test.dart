import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/features/create/data/content_body_locale.dart';

/// L4.9.1: `lv-LV`, `en`, `ru` are the API and data identifiers; `lv` stays the
/// internal UI and ARB code. The contracts and the policy must say the same.
void main() {
  group('canonical locale', () {
    test('the policy maps every UI language and nothing else', () {
      expect(AppLocalePolicy.canonicalLocaleOf('lv'), 'lv-LV');
      expect(AppLocalePolicy.canonicalLocaleOf('en'), 'en');
      expect(AppLocalePolicy.canonicalLocaleOf('ru'), 'ru');
      expect(AppLocalePolicy.canonicalLocaleOf('et'), isNull);
      expect(
        AppLocalePolicy.r1LanguageCodes.map(AppLocalePolicy.canonicalLocaleOf),
        unorderedEquals(AppLocalePolicy.r1CanonicalLocales),
      );
    });

    test('a tag already canonical or unknown passes unchanged', () {
      expect(AppLocalePolicy.canonicalTag('lv-LV'), 'lv-LV');
      expect(AppLocalePolicy.canonicalTag('lv'), 'lv-LV');
      expect(AppLocalePolicy.canonicalTag('other'), 'other');
    });

    test('notifications contracts name exactly the canonical locales', () {
      final Map<String, dynamic> query =
          jsonDecode(
                File(
                  '../../packages/api_contracts/schema/notifications/v1/'
                  'notifications_query.schema.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final Map<String, dynamic> defs = query[r'$defs'] as Map<String, dynamic>;
      final Map<String, dynamic> locale =
          defs['locale'] as Map<String, dynamic>;
      expect(
        (locale['enum'] as List<dynamic>).cast<String>(),
        unorderedEquals(AppLocalePolicy.r1CanonicalLocales),
      );
    });

    test('the synthetic LV market fixture names the canonical locales', () {
      final Map<String, dynamic> valid =
          jsonDecode(
                File(
                  '../backend/config/fixtures/valid.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final String text = jsonEncode(valid);
      expect(text, contains('["lv-LV","en","ru"]'));
      expect(text, isNot(contains('en-LV')));
      expect(text, isNot(contains('ru-LV')));
    });
  });

  group('Content body', () {
    test('an old lv draft goes out canonical and is not edited in place', () {
      final Map<String, Object?> body = <String, Object?>{
        'contentLocale': 'lv',
        'languages': <Object?>['lv', 'other'],
        'title': 'lv',
        'media': <String, Object?>{
          'gallery': <Object?>[
            <String, Object?>{
              'altText': <String, Object?>{'lv': 'Skats'},
            },
          ],
        },
      };
      final Map<String, Object?> sent = canonicalContentBody(body);
      expect(sent['contentLocale'], 'lv-LV');
      expect(sent['languages'], <Object?>['lv-LV', 'other']);
      // Author text that happens to read `lv` stays as written.
      expect(sent['title'], 'lv');
      expect(jsonEncode(sent['media']), contains('"lv-LV":"Skats"'));
      expect(body['contentLocale'], 'lv');
    });

    test('an Event alt text that is plain text is left alone', () {
      expect(
        canonicalContentBody(<String, Object?>{'altText': 'lv'})['altText'],
        'lv',
      );
    });
  });
}
