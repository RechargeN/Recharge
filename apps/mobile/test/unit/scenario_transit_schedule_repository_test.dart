import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/create/data/datasources/gtfs_cache_datasource.dart';
import 'package:recharge/features/create/data/datasources/latvia_gtfs_datasource.dart';
import 'package:recharge/features/create/data/repositories/scenario_transit_schedule_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';

import '../support/gtfs_test_fixture.dart';

void main() {
  const provider = LatviaGtfsProviderConfig(
    code: 'lv_test',
    displayName: 'Test Transit',
    sourceUrl: 'https://example.test/gtfs.zip',
    licenseName: 'CC0 1.0',
    freshnessMaxAge: Duration(days: 2),
  );
  final now = DateTime.utc(2026, 7, 31, 8);
  late Directory temporaryDirectory;
  late GtfsCacheDataSource cache;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'recharge_gtfs_repository_',
    );
    cache = GtfsCacheDataSource(
      supportDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  ScenarioTransitScheduleRepositoryImpl repository({
    required http.Client client,
    bool networkEnabled = true,
  }) => ScenarioTransitScheduleRepositoryImpl(
    registry: LatviaGtfsProviderRegistry(
      networkRefreshEnabled: networkEnabled,
      providers: const <LatviaGtfsProviderConfig>[provider],
    ),
    remoteDataSource: LatviaGtfsRemoteDataSource(
      client: client,
      nowUtc: () => now,
    ),
    cacheDataSource: cache,
    parseInBackground: false,
    nowUtc: () => now,
  );

  test('invalid refresh preserves the last-known-good snapshot', () async {
    final validBytes = await buildGtfsFixtureArchive();
    final first = repository(
      client: MockClient(
        (request) async => http.Response.bytes(
          validBytes,
          200,
          request: request,
          headers: const <String, String>{'content-type': 'application/zip'},
        ),
      ),
    );
    final firstManifest = await first.refreshProvider('lv_test');

    final failing = repository(
      client: MockClient(
        (request) async =>
            http.Response.bytes(<int>[1, 2, 3], 200, request: request),
      ),
    );
    await expectLater(
      failing.refreshProvider('lv_test'),
      throwsA(
        isA<ScenarioTransitScheduleException>().having(
          (error) => error.code,
          'code',
          ScenarioTransitScheduleFailureCode.invalidFeed,
        ),
      ),
    );

    final recovered = await failing.loadLastKnownGood('lv_test');
    expect(recovered, isNotNull);
    expect(recovered!.sha256, firstManifest.sha256);
  });

  test('kill switch blocks network but still allows cached reads', () async {
    final validBytes = await buildGtfsFixtureArchive();
    final enabled = repository(
      client: MockClient(
        (request) async =>
            http.Response.bytes(validBytes, 200, request: request),
      ),
    );
    await enabled.refreshProvider('lv_test');

    var networkCalled = false;
    final disabled = repository(
      networkEnabled: false,
      client: MockClient((request) async {
        networkCalled = true;
        return http.Response('', 500, request: request);
      }),
    );
    await expectLater(
      disabled.refreshProvider('lv_test'),
      throwsA(
        isA<ScenarioTransitScheduleException>().having(
          (error) => error.code,
          'code',
          ScenarioTransitScheduleFailureCode.networkDisabled,
        ),
      ),
    );
    expect(networkCalled, isFalse);
    expect(await disabled.loadLastKnownGood('lv_test'), isNotNull);
  });

  test(
    'provider discovery and cache inspection are provider-neutral',
    () async {
      final subject = repository(
        client: MockClient((request) async => http.Response('', 500)),
      );

      expect(subject.providers.single.code, 'lv_test');
      expect(subject.providers.single.displayName, 'Test Transit');
      expect(subject.providers.single.refreshEnabled, isTrue);
      expect(
        (await subject.inspectCache('lv_test')).status,
        ScenarioTransitCacheStatus.missing,
      );
    },
  );

  test('network client failure is exposed as typed offline failure', () async {
    final subject = repository(
      client: MockClient((request) async {
        throw http.ClientException('offline', request.url);
      }),
    );

    await expectLater(
      subject.refreshProvider('lv_test'),
      throwsA(
        isA<ScenarioTransitScheduleException>().having(
          (error) => error.code,
          'code',
          ScenarioTransitScheduleFailureCode.offline,
        ),
      ),
    );
  });

  test('concurrent refresh calls share one download and parse', () async {
    final validBytes = await buildGtfsFixtureArchive();
    var requests = 0;
    final subject = repository(
      client: MockClient((request) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response.bytes(validBytes, 200, request: request);
      }),
    );

    final results = await Future.wait(<Future<Object>>[
      subject.refreshProvider('lv_test'),
      subject.refreshProvider('lv_test'),
    ]);

    expect(requests, 1);
    expect(results[0], same(results[1]));
  });
}
