// L4: inventory of user-visible string literals that are not yet localized.
//
// Usage (from apps/mobile):
//   dart run tool/l10n_inventory.dart            # summary by area
//   dart run tool/l10n_inventory.dart --json     # per-file counts (baseline)
//
// Heuristic, not a parser: a single-quoted literal counts when it contains
// Cyrillic, or a capitalized word followed by another word, and is not an
// import, a Key, a route path, a snake_case id or a line marked
// `// l10n-ignore`. False positives are possible (mock fixture data, brand
// names); the ratchet test only forbids growth.
import 'dart:convert';
import 'dart:io';

final RegExp _literal = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
final RegExp _cyrillic = RegExp(r'[Ѐ-ӿ]');
final RegExp _sentence = RegExp(r'[A-Z][a-z]+[ ,][A-Za-z]');
final RegExp _skipLine = RegExp(
  r"^\s*(import|export|part)\s|Key\(|key:\s*'|l10n-ignore|"
  r"track\(|debugPrint|throw |assert\(|RegExp\(|@JsonKey|"
  r"^\s*///|^\s*//",
);

/// User-visible literal count of one Dart [source].
int countUnlocalized(String source) {
  int count = 0;
  for (final String line in const LineSplitter().convert(source)) {
    if (_skipLine.hasMatch(line)) continue;
    for (final RegExpMatch match in _literal.allMatches(line)) {
      final String text = match.group(1)!;
      if (text.startsWith('/') || text.contains(r'${')) {
        if (!_cyrillic.hasMatch(text) && !_sentence.hasMatch(text)) continue;
      }
      if (_cyrillic.hasMatch(text) || _sentence.hasMatch(text)) count += 1;
    }
  }
  return count;
}

/// Per-file counts under `lib/`, skipping generated code and the l10n layer.
Map<String, int> scanLib(Directory lib) {
  final Map<String, int> counts = <String, int>{};
  final List<File> files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File file in files) {
    final String path = file.path.replaceAll(r'\', '/');
    if (path.contains('/generated/') || path.contains('/l10n/')) continue;
    final int count = countUnlocalized(file.readAsStringSync());
    if (count > 0) {
      counts[path.substring(path.indexOf('lib/'))] = count;
    }
  }
  return counts;
}

/// Area of a lib path: `features/<name>`, `app/<dir>` or `core/<dir>`.
String areaOf(String path) {
  final List<String> parts = path.split('/');
  return parts.length > 3 ? '${parts[1]}/${parts[2]}' : parts[1];
}

void main(List<String> args) {
  final Map<String, int> counts = scanLib(Directory('lib'));
  if (args.contains('--json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(counts));
    return;
  }
  final Map<String, int> byArea = <String, int>{};
  counts.forEach(
    (String path, int count) => byArea.update(
      areaOf(path),
      (int v) => v + count,
      ifAbsent: () => count,
    ),
  );
  final List<MapEntry<String, int>> rows = byArea.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final MapEntry<String, int> row in rows) {
    stdout.writeln('${row.value.toString().padLeft(5)}  ${row.key}');
  }
  stdout.writeln(
    '${counts.values.fold<int>(0, (int a, int b) => a + b).toString().padLeft(5)}'
    '  total in ${counts.length} files',
  );
}
