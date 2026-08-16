import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/gtfs/gtfs_archive_parser.dart';
import 'package:recharge/features/create/data/gtfs/gtfs_parser_executor.dart';
import 'package:recharge/features/create/data/gtfs/gtfs_schedule_index.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';

import '../support/gtfs_test_fixture.dart';

void main() {
  const parser = GtfsArchiveParser();
  final retrievedAt = DateTime.utc(2026, 7, 31, 8);

  Future<GtfsScheduleIndex> parseFixture({
    Map<String, String> overrides = const <String, String>{},
  }) async {
    final bytes = await buildGtfsFixtureArchive(overrides: overrides);
    return parser.parse(
      archiveBytes: bytes,
      providerCode: 'lv_test',
      providerDisplayName: 'Test Transit',
      licenseName: 'CC0 1.0',
      sourceUrl: 'https://example.test/gtfs.zip',
      retrievedAtUtc: retrievedAt,
      freshnessMaxAge: const Duration(days: 2),
      nowUtc: retrievedAt,
    );
  }

  test('parses quoted CSV and indexes parent-station platforms', () async {
    final index = await parseFixture();

    final stops = index.searchStops('rīga central');
    expect(
      stops.map((stop) => stop.id),
      containsAll(<String>['station_a', 'platform_a']),
    );

    final result = index.searchServices(
      const ScenarioTransitSearchQuery(
        originStopId: 'station_a',
        destinationStopId: 'stop_c',
        serviceDate: ScenarioTransitLocalDate(2026, 7, 30),
        departAfter: ScenarioTransitTime(23 * 3600),
      ),
    );

    expect(result, hasLength(1));
    expect(result.single.origin.id, 'platform_a');
    expect(result.single.departure.hhmm, '23:55');
    expect(result.single.arrival.hhmm, '24:50');
    expect(result.single.arrival.dayOffset, 1);
    expect(result.single.serviceDate.iso8601, '2026-07-30');
    expect(result.single.durationMinutes, 55);
    expect(result.single.agencyName, 'Latvia, Test Transit');
    expect(result.single.manifest.freshness, ScenarioTransitFreshness.current);
  });

  test('calendar removal overrides weekly service', () async {
    final index = await parseFixture();
    final result = index.searchServices(
      const ScenarioTransitSearchQuery(
        originStopId: 'platform_a',
        destinationStopId: 'stop_c',
        serviceDate: ScenarioTransitLocalDate(2026, 7, 31),
      ),
    );
    expect(result, isEmpty);
  });

  test(
    'calendar addition creates service on an otherwise inactive day',
    () async {
      final index = await parseFixture();
      final result = index.searchServices(
        const ScenarioTransitSearchQuery(
          originStopId: 'station_a',
          destinationStopId: 'stop_b',
          serviceDate: ScenarioTransitLocalDate(2026, 8, 1),
        ),
      );
      expect(result, hasLength(1));
      expect(result.single.tripId, 'trip_added');
    },
  );

  test('does not return a trip when destination precedes origin', () async {
    final index = await parseFixture();
    final result = index.searchServices(
      const ScenarioTransitSearchQuery(
        originStopId: 'stop_c',
        destinationStopId: 'station_a',
        serviceDate: ScenarioTransitLocalDate(2026, 7, 30),
      ),
    );
    expect(result, isEmpty);
  });

  test('exact trip filter never substitutes another direct service', () async {
    final index = await parseFixture();
    final exact = index.searchServices(
      const ScenarioTransitSearchQuery(
        originStopId: 'station_a',
        destinationStopId: 'stop_c',
        serviceDate: ScenarioTransitLocalDate(2026, 7, 30),
        exactTripId: 'trip_late',
      ),
    );
    final missing = index.searchServices(
      const ScenarioTransitSearchQuery(
        originStopId: 'station_a',
        destinationStopId: 'stop_c',
        serviceDate: ScenarioTransitLocalDate(2026, 7, 30),
        exactTripId: 'trip_missing',
      ),
    );

    expect(exact.single.tripId, 'trip_late');
    expect(missing, isEmpty);
  });

  test('rejects missing required GTFS headers', () async {
    expect(
      () => parseFixture(
        overrides: const <String, String>{
          'routes.txt': 'route_id,route_short_name\nroute,1\n',
        },
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an archive that exceeds configured expansion limits', () async {
    final bytes = await buildGtfsFixtureArchive();
    const restricted = GtfsArchiveParser(
      limits: GtfsArchiveLimits(maxUncompressedBytes: 1),
    );
    expect(
      () => restricted.parse(
        archiveBytes: bytes,
        providerCode: 'lv_test',
        providerDisplayName: 'Test Transit',
        licenseName: 'CC0 1.0',
        sourceUrl: 'https://example.test/gtfs.zip',
        retrievedAtUtc: retrievedAt,
        freshnessMaxAge: const Duration(days: 1),
        nowUtc: retrievedAt,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses a national feed payload outside the caller isolate', () async {
    final bytes = await buildGtfsFixtureArchive();
    const executor = GtfsParserExecutor();

    final index = await executor.parse(
      archiveBytes: bytes,
      providerCode: 'lv_test',
      providerDisplayName: 'Test Transit',
      licenseName: 'CC0 1.0',
      sourceUrl: 'https://example.test/gtfs.zip',
      retrievedAtUtc: retrievedAt,
      freshnessMaxAge: const Duration(days: 2),
      nowUtc: retrievedAt,
    );

    expect(index.stopCount, 4);
    expect(index.tripCount, 2);
  });
}
