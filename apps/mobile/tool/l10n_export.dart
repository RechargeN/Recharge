// L4.7: export of every UI string for the native-speaker review (G06).
//
// Usage (from apps/mobile):
//   dart run tool/l10n_export.dart <output.csv>
//
// One row per ARB key: key, description, placeholders, en, lv, ru, review
// status and where the key is used (lib/ files). The CSV is UTF-8 with a
// BOM so spreadsheet apps open lv/ru text correctly. The output must lie
// outside the repository: the export is a review copy, never committed.
//
//   dart run tool/l10n_export.dart --review <lv|ru> <output.csv>
//
// One reviewer's package (BCK20-OD-02): key, screen context, source (en),
// translation, exact revision, and empty `verdict` (Accept, Amend or Reject)
// and `comment` columns for the reviewer to fill in.
import 'dart:convert';
import 'dart:io';

const List<String> _languages = <String>['en', 'lv', 'ru'];
const List<String> _translated = <String>['lv', 'ru'];

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
  final bool review = args.length == 3 && args.first == '--review';
  if (!(args.length == 1 || (review && _translated.contains(args[1])))) {
    stderr.writeln(
      'usage: dart run tool/l10n_export.dart [--review <lv|ru>] <output.csv>',
    );
    exitCode = 64;
    return;
  }
  final String output = args.last;
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
  if (review) {
    _writeReviewPackage(output, args[1], keys, arbs, usages);
    return;
  }
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

/// The exact revision the package was cut from: commit and ARB content hash.
String _revision(String language) {
  final ProcessResult head = Process.runSync('git', <String>[
    'rev-parse',
    '--short',
    'HEAD',
  ]);
  final ProcessResult arb = Process.runSync('git', <String>[
    'hash-object',
    'lib/l10n/app_$language.arb',
  ]);
  return '${(head.stdout as String).trim()}:'
      '${(arb.stdout as String).trim().substring(0, 12)}';
}

void _writeReviewPackage(
  String output,
  String language,
  List<String> keys,
  Map<String, Map<String, dynamic>> arbs,
  Map<String, Set<String>> usages,
) {
  final String revision = _revision(language);
  final StringBuffer csv = StringBuffer('\uFEFF')
    ..writeln(
      <String>[
        'key',
        'context',
        'used_in',
        'source_en',
        'translation_$language',
        'revision',
        'verdict',
        'comment',
      ].map(_cell).join(','),
    );
  for (final String key in keys) {
    final Object? meta = arbs['en']!['@$key'];
    csv.writeln(
      <String>[
        key,
        meta is Map<String, dynamic>
            ? (meta['description'] as String?) ?? ''
            : '',
        (usages[key]!.toList()..sort()).join(' '),
        (arbs['en']![key] as String?) ?? '',
        (arbs[language]![key] as String?) ?? '',
        revision,
        '',
        '',
      ].map(_cell).join(','),
    );
  }
  File(output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(csv.toString());
  stdout.writeln('${keys.length} keys for $language review → $output');
}
