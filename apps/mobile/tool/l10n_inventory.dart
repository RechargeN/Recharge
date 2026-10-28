// L4: inventory of user-visible string literals that are not yet localized.
//
// Usage (from apps/mobile):
//   dart run tool/l10n_inventory.dart            # totals, layers, areas
//   dart run tool/l10n_inventory.dart --json     # interface-only per-file counts (baseline)
//
// Heuristic, not a parser: a single-quoted literal counts when it contains
// Cyrillic, or a capitalized word followed by another word, and is not an
// import, a Key, a route path, a snake_case id or a line marked
// `// l10n-ignore`. False positives are possible (brand names); the ratchet
// test only forbids growth.
//
// Files in [nonInterfaceFiles] are scanned but kept out of the interface
// count: their literals are mock data, parser vocabulary or data-format
// errors, not UI copy. Each entry names its reason; the ratchet test checks
// every entry still exists and none of them is a presentation file.
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

const String _mockData =
    'mock data: seeded objects stand in for user and server content';

/// Non-interface files (path under `lib/`, or a directory ending in `/`)
/// with the reason they are not UI copy.
const Map<String, String> nonInterfaceFiles = <String, String>{
  'lib/features/discover/data/datasources/discover_remote_datasource.dart':
      _mockData,
  'lib/features/create/data/datasources/scenario_proposal_mock_datasource.dart':
      _mockData,
  'lib/features/create/data/datasources/catalog_object_picker_mock_datasource.dart':
      _mockData,
  'lib/features/create/data/datasources/place_enrichment_mock_datasource.dart':
      _mockData,
  'lib/features/create/data/datasources/collection_catalog_search_mock_datasource.dart':
      _mockData,
  'lib/features/create/data/datasources/place_duplicate_mock_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_bookable_session_discovery_local_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_class_workshop_discovery_local_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_collection_discovery_local_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_event_discovery_local_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_find_people_discovery_local_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_rental_discovery_local_datasource.dart':
      _mockData,
  'lib/features/discover/data/datasources/published_route_discovery_local_datasource.dart':
      _mockData,
  'lib/features/notifications/data/repositories/notifications_repository_impl.dart':
      'mock data: seed notifications stand in for server-rendered text',
  'lib/app/testing/':
      'test fixtures: seeded objects for default-off test entries',
  'lib/features/discover/application/smart_search_parser.dart':
      'parser vocabulary: keywords matched in the query, never displayed',
  'lib/features/create/data/routing/demo_route_graph.dart':
      'demo route graph: local fixture network and its internal errors',
  'lib/features/create/data/routing/demo_route_graph_adapter.dart':
      'demo route graph: local fixture network and its internal errors',
  'lib/features/create/data/routing/demo_route_graph_asset_loader.dart':
      'demo route graph: local fixture network and its internal errors',
  'lib/features/create/data/datasources/gtfs_cache_datasource.dart':
      'GTFS parsing: feed format tokens and parser errors',
  'lib/features/create/data/gtfs/gtfs_archive_parser.dart':
      'GTFS parsing: feed format tokens and parser errors',
  'lib/features/create/data/gtfs/gtfs_csv_reader.dart':
      'GTFS parsing: feed format tokens and parser errors',
  'lib/features/create/data/gtfs/gtfs_parser_executor.dart':
      'GTFS parsing: feed format tokens and parser errors',
  'lib/features/create/data/gtfs/gtfs_schedule_index.dart':
      'GTFS parsing: feed format tokens and parser errors',
};

/// The architecture layers reported separately; anything else is `other`.
const List<String> layers = <String>[
  'presentation',
  'application',
  'domain',
  'data',
];

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

/// Whether [path] is listed in [nonInterfaceFiles] (file or directory).
bool isNonInterface(String path) => nonInterfaceFiles.keys.any(
  (String entry) =>
      entry.endsWith('/') ? path.startsWith(entry) : path == entry,
);

/// [counts] without the [nonInterfaceFiles].
Map<String, int> interfaceOnly(Map<String, int> counts) => <String, int>{
  for (final MapEntry<String, int> entry in counts.entries)
    if (!isNonInterface(entry.key)) entry.key: entry.value,
};

/// Per-file counts of interface files only (the ratchet baseline).
Map<String, int> scanInterface(Directory lib) => interfaceOnly(scanLib(lib));

/// Area of a lib path: `features/<name>`, `app/<dir>` or `core/<dir>`.
String areaOf(String path) {
  final List<String> parts = path.split('/');
  return parts.length > 3 ? '${parts[1]}/${parts[2]}' : parts[1];
}

/// Layer of a lib path: the first [layers] directory in it, else `other`.
String layerOf(String path) {
  final List<String> parts = path.split('/');
  for (final String part in parts.take(parts.length - 1)) {
    if (layers.contains(part)) return part;
  }
  return 'other';
}

int _sum(Iterable<int> values) => values.fold<int>(0, (int a, int b) => a + b);

Map<String, int> _groupBy(
  Map<String, int> counts,
  String Function(String path) keyOf,
) {
  final Map<String, int> grouped = <String, int>{};
  counts.forEach(
    (String path, int count) => grouped.update(
      keyOf(path),
      (int v) => v + count,
      ifAbsent: () => count,
    ),
  );
  return grouped;
}

void _writeRow(int value, String label) =>
    stdout.writeln('${value.toString().padLeft(5)}  $label');

void main(List<String> args) {
  final Map<String, int> all = scanLib(Directory('lib'));
  final Map<String, int> interface = interfaceOnly(all);
  if (args.contains('--json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(interface));
    return;
  }
  final int nonInterfaceFileCount = all.length - interface.length;
  _writeRow(_sum(all.values), 'whole inventory in ${all.length} files');
  _writeRow(
    _sum(all.values) - _sum(interface.values),
    'non-interface (listed) in $nonInterfaceFileCount files',
  );
  _writeRow(
    _sum(interface.values),
    'interface only in ${interface.length} files',
  );
  stdout.writeln('\nBy layer (whole / interface only):');
  final Map<String, int> allByLayer = _groupBy(all, layerOf);
  final Map<String, int> interfaceByLayer = _groupBy(interface, layerOf);
  for (final String layer in <String>[...layers, 'other']) {
    stdout.writeln(
      '${(allByLayer[layer] ?? 0).toString().padLeft(5)} '
      '/ ${(interfaceByLayer[layer] ?? 0).toString().padLeft(5)}  $layer',
    );
  }
  stdout.writeln('\nInterface only, by area:');
  final List<MapEntry<String, int>> rows = _groupBy(
    interface,
    areaOf,
  ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final MapEntry<String, int> row in rows) {
    _writeRow(row.value, row.key);
  }
}
