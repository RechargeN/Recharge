import 'dart:convert';

/// L4 resource checks over the ARB set: one template plus translations.
///
/// It parses the ICU subset the app uses (text, `{name}`,
/// `{name, plural, …}`, `{name, select, …}`) and reports, per key: missing or
/// extra keys, malformed messages, placeholders that differ from the
/// template, plural forms missing for the locale's CLDR categories, select
/// cases that differ from the template, and template keys without a
/// description.
final class ArbChecker {
  ArbChecker({required this.templateLocale});

  final String templateLocale;

  /// CLDR cardinal categories the app must cover for each R1 language.
  static const Map<String, Set<String>> requiredPluralForms =
      <String, Set<String>>{
        'en': <String>{'one', 'other'},
        'lv': <String>{'zero', 'one', 'other'},
        'ru': <String>{'one', 'few', 'many', 'other'},
      };

  List<String> check(Map<String, String> arbByLocale) {
    final List<String> findings = <String>[];
    final Map<String, Map<String, Object?>> decoded =
        <String, Map<String, Object?>>{};
    arbByLocale.forEach((String locale, String source) {
      try {
        decoded[locale] = (jsonDecode(source) as Map<String, dynamic>)
            .cast<String, Object?>();
      } on FormatException catch (error) {
        findings.add('$locale: invalid json (${error.message})');
      }
    });
    final Map<String, Object?>? template = decoded[templateLocale];
    if (template == null) return findings..add('missing template');

    final Set<String> templateKeys = _messageKeys(template);
    for (final String key in templateKeys) {
      final Object? meta = template['@$key'];
      if (meta is! Map || (meta['description'] as Object?) is! String) {
        findings.add('$templateLocale:$key: no description');
      }
    }
    final Map<String, _Message> templateMessages = <String, _Message>{};
    for (final String key in templateKeys) {
      final _Message? message = _parse(
        templateLocale,
        key,
        template[key],
        findings,
      );
      if (message != null) {
        templateMessages[key] = message;
        _checkPlurals(templateLocale, key, message, findings);
        final Object? meta = template['@$key'];
        final Set<String> declared = meta is Map && meta['placeholders'] is Map
            ? (meta['placeholders'] as Map).keys.cast<String>().toSet()
            : <String>{};
        if (!_sameSet(declared, message.placeholders)) {
          findings.add(
            '$templateLocale:$key: declared placeholders $declared, '
            'used ${message.placeholders}',
          );
        }
      }
    }

    decoded.forEach((String locale, Map<String, Object?> arb) {
      if (locale == templateLocale) return;
      if (arb['@@locale'] != locale) {
        findings.add('$locale: @@locale is ${arb['@@locale']}');
      }
      final Set<String> keys = _messageKeys(arb);
      for (final String key in templateKeys.difference(keys)) {
        findings.add('$locale:$key: missing');
      }
      for (final String key in keys.difference(templateKeys)) {
        findings.add('$locale:$key: not in template');
      }
      for (final String key in keys.intersection(templateKeys)) {
        final _Message? message = _parse(locale, key, arb[key], findings);
        final _Message? reference = templateMessages[key];
        if (message == null || reference == null) continue;
        if (!_sameSet(message.placeholders, reference.placeholders)) {
          findings.add(
            '$locale:$key: placeholders ${message.placeholders} != '
            '${reference.placeholders}',
          );
        }
        for (final MapEntry<String, Set<String>> select
            in reference.selectCases.entries) {
          final Set<String>? cases = message.selectCases[select.key];
          if (cases == null || !_sameSet(cases, select.value)) {
            findings.add(
              '$locale:$key: select ${select.key} cases $cases != '
              '${select.value}',
            );
          }
        }
        _checkPlurals(locale, key, message, findings);
      }
    });
    return findings;
  }

  static Set<String> _messageKeys(Map<String, Object?> arb) =>
      arb.keys.where((String key) => !key.startsWith('@')).toSet();

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  void _checkPlurals(
    String locale,
    String key,
    _Message message,
    List<String> findings,
  ) {
    final Set<String> required =
        requiredPluralForms[locale] ?? const <String>{'other'};
    for (final MapEntry<String, Set<String>> plural
        in message.pluralForms.entries) {
      final Set<String> forms = plural.value
          .map((String form) => form == '=1' ? 'one' : form)
          .toSet();
      final Set<String> missing = required.difference(forms);
      if (missing.isNotEmpty) {
        findings.add('$locale:$key: plural ${plural.key} lacks $missing');
      }
    }
  }

  _Message? _parse(
    String locale,
    String key,
    Object? value,
    List<String> findings,
  ) {
    if (value is! String || value.trim().isEmpty) {
      findings.add('$locale:$key: empty or not a string');
      return null;
    }
    try {
      final _IcuParser parser = _IcuParser(value);
      final _Message message = parser.parseMessage(topLevel: true);
      if (!parser.atEnd) throw const FormatException('trailing input');
      return message;
    } on FormatException catch (error) {
      findings.add('$locale:$key: malformed (${error.message})');
      return null;
    }
  }
}

final class _Message {
  final Set<String> placeholders = <String>{};
  final Map<String, Set<String>> pluralForms = <String, Set<String>>{};
  final Map<String, Set<String>> selectCases = <String, Set<String>>{};

  void absorb(_Message other) {
    placeholders.addAll(other.placeholders);
    other.pluralForms.forEach(
      (String k, Set<String> v) =>
          pluralForms.putIfAbsent(k, () => <String>{}).addAll(v),
    );
    other.selectCases.forEach(
      (String k, Set<String> v) =>
          selectCases.putIfAbsent(k, () => <String>{}).addAll(v),
    );
  }
}

final class _IcuParser {
  _IcuParser(this.source);

  final String source;
  int _at = 0;

  bool get atEnd => _at >= source.length;

  _Message parseMessage({bool topLevel = false}) {
    final _Message message = _Message();
    while (!atEnd) {
      final String char = source[_at];
      if (char == '{') {
        message.absorb(_argument());
      } else if (char == '}') {
        if (topLevel) throw const FormatException('unbalanced }');
        return message;
      } else {
        _at += 1;
      }
    }
    if (!topLevel) throw const FormatException('unclosed {');
    return message;
  }

  _Message _argument() {
    _expect('{');
    final String name = _identifier();
    _spaces();
    if (_peek('}')) {
      _at += 1;
      return _Message()..placeholders.add(name);
    }
    _expect(',');
    _spaces();
    final String kind = _identifier();
    _spaces();
    _expect(',');
    final _Message result = _Message()..placeholders.add(name);
    final Set<String> cases = <String>{};
    while (true) {
      _spaces();
      if (_peek('}')) {
        _at += 1;
        break;
      }
      final String selector = _selector();
      _spaces();
      _expect('{');
      result.absorb(parseMessage());
      _expect('}');
      if (!cases.add(selector)) {
        throw FormatException('duplicate case $selector');
      }
    }
    if (!cases.contains('other')) {
      throw FormatException('$name has no other case');
    }
    switch (kind) {
      case 'plural':
        result.pluralForms[name] = cases;
      case 'select':
        result.selectCases[name] = cases;
      default:
        throw FormatException('unknown argument type $kind');
    }
    return result;
  }

  String _identifier() {
    final int start = _at;
    while (!atEnd && RegExp(r'[A-Za-z0-9_]').hasMatch(source[_at])) {
      _at += 1;
    }
    if (start == _at) throw FormatException('identifier expected at $_at');
    return source.substring(start, _at);
  }

  String _selector() {
    final int start = _at;
    while (!atEnd && RegExp(r'[A-Za-z0-9_=-]').hasMatch(source[_at])) {
      _at += 1;
    }
    if (start == _at) throw FormatException('case expected at $_at');
    return source.substring(start, _at);
  }

  void _spaces() {
    while (!atEnd && source[_at].trim().isEmpty) {
      _at += 1;
    }
  }

  bool _peek(String char) => !atEnd && source[_at] == char;

  void _expect(String char) {
    if (!_peek(char)) throw FormatException('"$char" expected at $_at');
    _at += 1;
  }
}
