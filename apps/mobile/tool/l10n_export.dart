// L4.7: export of every UI string for the native-speaker review (G06).
//
// Usage (from apps/mobile):
//   dart run tool/l10n_export.dart <output.csv>
//
// One row per ARB key: key, description, placeholders, en, lv, ru, review
// status and where the key is used (lib/ files). The CSV is UTF-8 with a
// BOM so spreadsheet apps open lv/ru text correctly. The output must lie
// outside the repository: the export is a review copy, never committed.
import 'dart:convert';
import 'dart:io';

const List<String> _languages = <String>['en', 'lv', 'ru'];

Map<String, dynamic> _arb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Root of the git repository that holds [start], or null.
Directory? _repoRoot(Directory start) {
  Directory dir = start.absolute;
  while (true) {
    if (Directory('${dir.path}/.git').existsSync() ||
        File('${dir.path}/.git').existsSync()) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

bool _isInside(String path, Directory root) {
  String norm(String p) => p.replaceAll(r'\', '/').toLowerCase();
  final String file = norm(File(path).absolute.path);
  final String base = norm(root.absolute.path);
  return file == base || file.startsWith(base.endsWith('/') ? base : '$base/');
}

/// Key → lib files that read `<receiver>.<key>` (`context.l10n`, a passed
/// `AppLocalizations`, a lookup result).
Map<String, Set<String>> _usages(Iterable<String> keys) {
  final Map<String, Set<String>> usages = <String, Set<String>>{
    for (final String key in keys) key: <String>{},
  };
  final RegExp call = RegExp(r'\.\s*([a-z][a-zA-Z0-9]*)\b');
  for (final FileSystemEntity entity in Directory(
    'lib',
  ).listSync(recursive: true)) {
    final String path = entity.path.replaceAll(r'\', '/');
    if (entity is! File ||
        !path.endsWith('.dart') ||
        path.contains('/generated/')) {
      continue;
    }
    for (final RegExpMatch match in call.allMatches(
      entity.readAsStringSync(),
    )) {
      usages[match.group(1)!]?.add(path);
    }
  }
  return usages;
}

String _cell(String value) => '"${value.replaceAll('"', '""')}"';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/l10n_export.dart <output.csv>');
    exitCode = 64;
    return;
  }
  final String output = args.single;
  final Directory? root = _repoRoot(Directory.current);
  if (root != null && _isInside(output, root)) {
    stderr.writeln(
      'refusing to write inside the repository (${root.path}); '
      'the review export is never committed',
    );
    exitCode = 65;
    return;
  }
  final Map<String, Map<String, dynamic>> arbs = <String, Map<String, dynamic>>{
    for (final String language in _languages) language: _arb(language),
  };
  final List<String> keys = arbs['en']!.keys
      .where((String key) => !key.startsWith('@'))
      .toList();
  final Map<String, Set<String>> usages = _usages(keys);
  final StringBuffer csv = StringBuffer('﻿')
    ..writeln(
      <String>[
        'key',
        'description',
        'placeholders',
        'en',
        'lv',
        'ru',
        'lv_status',
        'ru_status',
        'used_in',
      ].map(_cell).join(','),
    );
  for (final String key in keys) {
    final Object? meta = arbs['en']!['@$key'];
    final Map<String, dynamic> metadata = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};
    final Object? placeholders = metadata['placeholders'];
    csv.writeln(
      <String>[
        key,
        (metadata['description'] as String?) ?? '',
        placeholders is Map ? placeholders.keys.join(' ') : '',
        for (final String language in _languages)
          (arbs[language]![key] as String?) ?? '',
        // L4.7: no lv/ru string has been reviewed by a native speaker yet.
        'unreviewed',
        'unreviewed',
        (usages[key]!.toList()..sort()).join(' '),
      ].map(_cell).join(','),
    );
  }
  File(output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(csv.toString());
  stdout.writeln('${keys.length} keys → $output');
}
