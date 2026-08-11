import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

Future<List<int>> buildGtfsFixtureArchive({
  Map<String, String> overrides = const <String, String>{},
  Map<String, String> extraFiles = const <String, String>{},
}) async {
  final root = Directory('test/fixtures/gtfs/basic');
  final files = <String, String>{};
  for (final file in root.listSync().whereType<File>()) {
    files[file.uri.pathSegments.last] = await file.readAsString();
  }
  files
    ..addAll(overrides)
    ..addAll(extraFiles);

  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('Unable to encode GTFS test fixture.');
  }
  return encoded;
}
