import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/datasources/gtfs_cache_datasource.dart';

void main() {
  late Directory temporaryDirectory;
  late GtfsCacheDataSource dataSource;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'recharge_gtfs_cache_',
    );
    dataSource = GtfsCacheDataSource(
      supportDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  CachedGtfsArchive archive(List<int> bytes, int revision) => CachedGtfsArchive(
    providerCode: 'lv_test',
    sourceUrl: 'https://example.test/$revision.zip',
    retrievedAtUtc: DateTime.utc(2026, 7, revision),
    sha256: sha256.convert(bytes).toString(),
    bytes: bytes,
  );

  test('reads a digest-verified cache snapshot', () async {
    await dataSource.write(archive(<int>[1, 2, 3], 1));

    final loaded = await dataSource.read('lv_test');

    expect(loaded, isNotNull);
    expect(loaded!.bytes, <int>[1, 2, 3]);
    expect(loaded.sourceUrl, 'https://example.test/1.zip');
  });

  test('inspection distinguishes a missing cache', () async {
    final result = await dataSource.inspect('lv_test');

    expect(result.status, GtfsCacheReadStatus.missing);
    expect(result.archive, isNull);
  });

  test('falls back to backup when current archive is corrupted', () async {
    await dataSource.write(archive(<int>[1, 2, 3], 1));
    await dataSource.write(archive(<int>[4, 5, 6], 2));
    final current = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      'scenario_gtfs${Platform.pathSeparator}lv_test.zip',
    );
    await current.writeAsBytes(<int>[9, 9, 9], flush: true);

    final loaded = await dataSource.read('lv_test');
    final inspected = await dataSource.inspect('lv_test');

    expect(loaded, isNotNull);
    expect(loaded!.bytes, <int>[1, 2, 3]);
    expect(loaded.sourceUrl, 'https://example.test/1.zip');
    expect(inspected.status, GtfsCacheReadStatus.ready);
    expect(inspected.archive?.sourceUrl, 'https://example.test/1.zip');
  });

  test('inspection reports corrupt when no valid pair survives', () async {
    final directory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}scenario_gtfs',
    );
    await directory.create(recursive: true);
    await File(
      '${directory.path}${Platform.pathSeparator}lv_test.zip',
    ).writeAsBytes(<int>[1, 2, 3]);

    final result = await dataSource.inspect('lv_test');

    expect(result.status, GtfsCacheReadStatus.corrupt);
    expect(result.archive, isNull);
  });

  test('rejects a mismatched digest before replacing cache', () async {
    await expectLater(
      dataSource.write(
        CachedGtfsArchive(
          providerCode: 'lv_test',
          sourceUrl: 'https://example.test/feed.zip',
          retrievedAtUtc: DateTime.utc(2026, 7, 31),
          sha256: 'not-a-digest',
          bytes: const <int>[1],
        ),
      ),
      throwsStateError,
    );
    expect(await dataSource.read('lv_test'), isNull);
  });
}
