import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class CachedGtfsArchive {
  const CachedGtfsArchive({
    required this.providerCode,
    required this.sourceUrl,
    required this.retrievedAtUtc,
    required this.sha256,
    required this.bytes,
  });

  final String providerCode;
  final String sourceUrl;
  final DateTime retrievedAtUtc;
  final String sha256;
  final List<int> bytes;
}

class GtfsCacheDataSource {
  GtfsCacheDataSource({required Future<Directory> Function() supportDirectory})
    : _supportDirectory = supportDirectory;

  final Future<Directory> Function() _supportDirectory;

  Future<CachedGtfsArchive?> read(String providerCode) async {
    _validateProviderCode(providerCode);
    final directory = await _cacheDirectory();
    final current = await _readPair(directory, providerCode, suffix: '');
    if (current != null) return current;
    return _readPair(directory, providerCode, suffix: '.bak');
  }

  Future<void> write(CachedGtfsArchive archive) async {
    _validateProviderCode(archive.providerCode);
    final actualDigest = sha256.convert(archive.bytes).toString();
    if (actualDigest != archive.sha256) {
      throw StateError('GTFS cache digest does not match archive bytes.');
    }
    final directory = await _cacheDirectory();
    final base = _basePath(directory, archive.providerCode);
    final zip = File('$base.zip');
    final manifest = File('$base.json');
    final zipTemp = File('$base.zip.tmp');
    final manifestTemp = File('$base.json.tmp');
    final zipBackup = File('$base.zip.bak');
    final manifestBackup = File('$base.json.bak');

    await zipTemp.writeAsBytes(archive.bytes, flush: true);
    await manifestTemp.writeAsString(
      jsonEncode(<String, Object?>{
        'schema_version': 1,
        'provider_code': archive.providerCode,
        'source_url': archive.sourceUrl,
        'retrieved_at_utc': archive.retrievedAtUtc.toUtc().toIso8601String(),
        'sha256': archive.sha256,
      }),
      flush: true,
    );

    final staged = await _readExplicitPair(
      zipTemp,
      manifestTemp,
      archive.providerCode,
    );
    if (staged == null) {
      throw StateError('Unable to validate staged GTFS cache.');
    }

    if (zipBackup.existsSync()) await zipBackup.delete();
    if (manifestBackup.existsSync()) await manifestBackup.delete();
    if (zip.existsSync()) await zip.rename(zipBackup.path);
    if (manifest.existsSync()) await manifest.rename(manifestBackup.path);
    try {
      await zipTemp.rename(zip.path);
      await manifestTemp.rename(manifest.path);
    } on Object {
      if (!zip.existsSync() && zipBackup.existsSync()) {
        await zipBackup.rename(zip.path);
      }
      if (!manifest.existsSync() && manifestBackup.existsSync()) {
        await manifestBackup.rename(manifest.path);
      }
      rethrow;
    }
  }

  Future<Directory> _cacheDirectory() async {
    final root = await _supportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}scenario_gtfs',
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<CachedGtfsArchive?> _readPair(
    Directory directory,
    String providerCode, {
    required String suffix,
  }) {
    final base = _basePath(directory, providerCode);
    return _readExplicitPair(
      File('$base.zip$suffix'),
      File('$base.json$suffix'),
      providerCode,
    );
  }

  Future<CachedGtfsArchive?> _readExplicitPair(
    File zip,
    File manifest,
    String expectedProviderCode,
  ) async {
    if (!zip.existsSync() || !manifest.existsSync()) return null;
    try {
      final json =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      if (json['schema_version'] != 1 ||
          json['provider_code'] != expectedProviderCode) {
        return null;
      }
      final sourceUrl = json['source_url'] as String?;
      final retrievedAt = DateTime.tryParse(
        json['retrieved_at_utc'] as String? ?? '',
      );
      final expectedDigest = json['sha256'] as String?;
      if (sourceUrl == null ||
          Uri.tryParse(sourceUrl)?.scheme != 'https' ||
          retrievedAt == null ||
          expectedDigest == null) {
        return null;
      }
      final bytes = await zip.readAsBytes();
      if (bytes.isEmpty || sha256.convert(bytes).toString() != expectedDigest) {
        return null;
      }
      return CachedGtfsArchive(
        providerCode: expectedProviderCode,
        sourceUrl: sourceUrl,
        retrievedAtUtc: retrievedAt.toUtc(),
        sha256: expectedDigest,
        bytes: List<int>.unmodifiable(bytes),
      );
    } on Object {
      return null;
    }
  }

  String _basePath(Directory directory, String providerCode) =>
      '${directory.path}${Platform.pathSeparator}$providerCode';

  void _validateProviderCode(String value) {
    if (!RegExp(r'^[a-z0-9_]{3,64}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'providerCode');
    }
  }
}
