import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';

/// L4 checks 9 and 10: translations carry no user content, secret or private
/// parameter, the localization layer logs nothing, and the language never
/// touches market availability (EE/LT stay disabled and outside the app).
void main() {
  Map<String, dynamic> template() =>
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('message parameters are counts, stable ids or already-localized '
      'fragments; no user content or identity reaches a translation', () {
    const Set<String> allowed = <String>{
      // numbers
      'count', 'seats', 'selected', 'max', 'meters', 'done', 'total',
      // L4.2: the lower length limit of a Create field (a number, like max)
      'min',
      // L4.5 Discover: durations, an age limit and positions in a list —
      // numbers the app computes, never text a person typed
      'minutes', 'hours', 'days', 'age', 'index', 'current', 'order',
      // stable ids / server enum values chosen by select
      'type', 'status', 'state', 'kind', 'value', 'revision', 'contentId',
      // localized or formatted fragments built by the app itself
      'reason', 'classification', 'review', 'visibility', 'deadline', 'date',
      'start', 'end',
      // the owner's own unlisted share token, shown only to the owner
      'token',
      // stable local check codes and section ids chosen by select
      'code', 'section',
      // localized fragments and formatted values
      'field', 'message', 'km', 'price', 'time',
      // the public object's own venue name, inserted verbatim (never
      // translated); it is published data, not private input
      'venue',
    };
    final List<String> unexpected = <String>[];
    template().forEach((String key, dynamic meta) {
      if (!key.startsWith('@') || key == '@@locale' || meta is! Map) return;
      final Object? placeholders = meta['placeholders'];
      if (placeholders is! Map) return;
      for (final Object? name in placeholders.keys) {
        if (!allowed.contains(name)) unexpected.add('$key:$name');
      }
    });
    expect(unexpected, isEmpty);
  });

  test('user-authored text is shown verbatim, never passed into a message', () {
    final RegExp call = RegExp(r'l10n\.\w+\(');
    final RegExp userText = RegExp(
      r'\b(title|draftTitle|displayName|email|about|body|description|'
      r'comment|note)\b',
    );
    final List<String> hits = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.contains('generated')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      for (final RegExpMatch match in call.allMatches(source)) {
        int depth = 1;
        int at = match.end;
        while (at < source.length && depth > 0) {
          if (source[at] == '(') depth += 1;
          if (source[at] == ')') depth -= 1;
          at += 1;
        }
        final String arguments = source.substring(match.end, at - 1);
        if (userText.hasMatch(arguments)) {
          hits.add('${entity.path}: ${match.group(0)}$arguments)');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('no screen renders a raw code, failure code or reason as text', () {
    final RegExp raw = RegExp(
      r"Text\(\s*(?:[a-zA-Z_.!]*\.)?(?:code|failureCode|refusalCode|reason)"
      r"\b(?!\s*[,)]?\s*=)|\$\{[a-zA-Z_.!]*\.(?:code|failureCode|refusalCode)\}",
    );
    final List<String> hits = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      final String path = entity.path.replaceAll(r'\', '/');
      if (entity is! File ||
          !path.endsWith('.dart') ||
          !path.contains('/presentation/')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      for (final RegExpMatch match in raw.allMatches(source)) {
        final int lineStart = source.lastIndexOf('\n', match.start) + 1;
        // A widget Key built from a code is an id, not shown text.
        if (source.substring(lineStart, match.start).contains('Key(')) {
          continue;
        }
        hits.add('$path: ${match.group(0)}');
      }
    }
    expect(hits, isEmpty);
    // Positive control: the pattern that showed Place check codes is found.
    expect(
      raw.hasMatch("title: Text(issue.code.replaceAll('_', ' '))"),
      isTrue,
    );
    expect(raw.hasMatch("Text('unavailable: \${item.failureCode}')"), isTrue);
  });

  test('the localization layer has no logging, analytics or network path', () {
    for (final FileSystemEntity entity in Directory(
      'lib/core/localization',
    ).listSync()) {
      final String source = (entity as File).readAsStringSync();
      for (final String forbidden in <String>[
        'print(',
        'debugPrint',
        'AnalyticsService',
        'ProductAnalytics',
        'track(',
        'package:http',
        'developer.log',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason: '${entity.path} uses $forbidden',
        );
      }
    }
  });

  test('market facts are independent of the language and EE/LT stay out', () {
    expect(AppLocalePolicy.r1LanguageCodes, <String>['en', 'lv', 'ru']);
    for (final MarketConfig market in const MarketRegistry().markets) {
      expect(market.countryCode, 'LV');
      expect(market.currencyCode, 'EUR');
      expect(market.timezoneId, 'Europe/Riga');
    }
    final Map<String, dynamic> config =
        jsonDecode(
              File('../backend/config/fixtures/valid.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final List<dynamic> markets = config['marketCapabilities'] as List<dynamic>;
    expect(
      <String, String>{
        for (final dynamic market in markets)
          (market as Map<String, dynamic>)['marketId'] as String:
              market['status'] as String,
      },
      <String, String>{'LV': 'disabled', 'EE': 'disabled', 'LT': 'disabled'},
    );
    final Map<String, dynamic> schema =
        jsonDecode(
              File(
                '../backend/config/market-capability.schema.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final Map<String, dynamic> properties =
        schema['properties'] as Map<String, dynamic>;
    expect((properties['status'] as Map<String, dynamic>)['const'], 'disabled');
  });
}
