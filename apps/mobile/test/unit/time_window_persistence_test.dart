import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/discover_preferences_local_datasource.dart';
import 'package:recharge/features/discover/data/models/discover_query_model.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final zones = TimezoneRepositoryImpl();
  const storage = FlutterSecureStorage();
  DiscoverPreferencesLocalDataSource source() =>
      DiscoverPreferencesLocalDataSource(
        storage,
        timezoneRepository: zones,
        defaultMarketCityId: 'test',
        defaultCenterLat: 1,
        defaultCenterLng: 2,
      );
  DiscoverQuery read(Map<String, Object?> map) => DiscoverQueryModel.fromMap(
    map,
    timezoneRepository: zones,
    defaultMarketCityId: 'test',
    defaultCenterLat: 1,
    defaultCenterLng: 2,
  );
  DiscoverQuery query() =>
      DiscoverQuery.defaults(marketCityId: 'test', centerLat: 1, centerLng: 2);
  TravelContext travel() => TravelContext(
    originType: TravelOriginType.manualPin,
    origin: const GeoPoint(latitude: 1, longitude: 2),
    transportMode: TransportMode.walking,
    includeReturnTrip: false,
  );
  Map<String, Object?> window() => {
    'start_at_utc': '2026-10-25T00:30:00.123456Z',
    'end_at_utc': '2026-10-25T01:30:00.123456Z',
    'resolved_at_utc': '2026-10-24T12:00:00.000Z',
    'timezone_id': 'Europe/Riga',
    'mode': 'exact',
    'flexibility_minutes': 0,
  };
  Map<String, Object?> record(Object? window, {int version = 2}) => {
    'query_version': version,
    'time_window': window,
    'travel_context': window == null ? null : travel().toMap(),
  };
  SavedSearchEntity saved() => SavedSearchEntity(
    id: 'saved',
    title: 'Test',
    subtitle: 'Test',
    query: query(),
    createdAtUtc: DateTime.utc(2026),
  );
  SmartSearchHistoryEntity recent() => SmartSearchHistoryEntity(
    id: 'recent',
    prompt: 'Test',
    query: query(),
    createdAtUtc: DateTime.utc(2026),
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'domain rejects local instants and malformed zones in release paths',
    () {
      TimeWindow build({
        DateTime? start,
        DateTime? end,
        DateTime? resolved,
        String zone = 'Europe/Riga',
      }) => TimeWindow(
        startAtUtc: start ?? DateTime.utc(2026),
        endAtUtc: end ?? DateTime.utc(2026, 1, 2),
        resolvedAtUtc: resolved ?? DateTime.utc(2025),
        timezoneId: zone,
        mode: TimeWindowMode.exact,
        flexibilityMinutes: 0,
      );
      expect(() => build(start: DateTime(2026)), throwsArgumentError);
      expect(() => build(end: DateTime(2026, 1, 2)), throwsArgumentError);
      expect(() => build(resolved: DateTime(2025)), throwsArgumentError);
      expect(() => build(zone: ' Europe/Riga'), throwsFormatException);
      expect(() => build(end: DateTime.utc(2026)), throwsArgumentError);
    },
  );

  test('legacy Z record keeps exact instants, zone and mode on roundtrip', () {
    for (final mode in TimeWindowMode.values) {
      final original = {
        ...window(),
        'mode': mode.name,
        'flexibility_minutes': mode == TimeWindowMode.flexible ? 30 : 0,
      };
      final restored = read(record(original));
      expect(
        restored.timeWindow!.startAtUtc,
        DateTime.utc(2026, 10, 25, 0, 30, 0, 123, 456),
      );
      expect(
        restored.timeWindow!.endAtUtc.difference(
          restored.timeWindow!.startAtUtc,
        ),
        const Duration(hours: 1),
      );
      expect(
        DiscoverQueryModel.toMap(
          restored,
          timezoneRepository: zones,
        )['time_window'],
        original,
      );
    }
  });

  test('unknown or missing validator fails closed on read and write', () {
    expect(
      () => DiscoverQueryModel.fromMap(
        record(window()),
        defaultMarketCityId: 'test',
        defaultCenterLat: 1,
        defaultCenterLng: 2,
      ),
      throwsFormatException,
    );
    final valid = read(record(window()));
    expect(() => DiscoverQueryModel.toMap(valid), throwsFormatException);
    final unknown = query().copyWith(
      travelContext: travel(),
      timeWindow: TimeWindow(
        startAtUtc: DateTime.utc(2026),
        endAtUtc: DateTime.utc(2026, 1, 2),
        resolvedAtUtc: DateTime.utc(2025),
        timezoneId: 'Unknown/Nowhere',
        mode: TimeWindowMode.exact,
        flexibilityMinutes: 0,
      ),
    );
    expect(
      () => DiscoverQueryModel.toMap(unknown, timezoneRepository: zones),
      throwsFormatException,
    );
  });

  final corruptWindows = <Object?>[
    'not a map',
    123,
    [],
    {...window(), 'mode': 'future'},
    {...window(), 'mode': null},
    {...window(), 'flexibility_minutes': 0.5},
    {...window(), 'flexibility_minutes': null},
    {...window(), 'flexibility_minutes': 30},
    {...window(), 'mode': 'flexible', 'flexibility_minutes': -1},
    {...window(), 'mode': 'flexible', 'flexibility_minutes': 0},
    {...window(), 'start_at_utc': '2026-10-25T00:30:00'},
    {...window(), 'end_at_utc': '2026-10-25T04:30:00+03:00'},
    {...window(), 'resolved_at_utc': '2026-02-30T12:00:00Z'},
    {...window(), 'resolved_at_utc': 1},
    {...window(), 'start_at_utc': window()['end_at_utc']},
    {...window(), 'timezone_id': 'Unknown/Nowhere'},
    {...window(), 'timezone_id': '+03:00'},
    {...window(), 'timezone_id': null},
    <String, Object?>{},
  ];
  test('invalid nested windows are never dropped or defaulted', () {
    for (final invalid in corruptWindows) {
      expect(
        () => read(record(invalid)),
        throwsFormatException,
        reason: '$invalid',
      );
    }
    expect(() => read(record(window(), version: 1)), throwsFormatException);
    expect(read(record(null, version: 1)).timeWindow, isNull);
  });

  test(
    'all malformed windows preserve last query on read and replacement',
    () async {
      for (final invalid in corruptWindows) {
        final raw = jsonEncode(record(invalid));
        FlutterSecureStorage.setMockInitialValues({'discover.last_query': raw});
        await expectLater(source().loadLastQuery(), throwsFormatException);
        await expectLater(
          source().saveLastQuery(query()),
          throwsFormatException,
        );
        expect(await storage.read(key: 'discover.last_query'), raw);
      }
      final raw = jsonEncode(record(window(), version: 1));
      FlutterSecureStorage.setMockInitialValues({'discover.last_query': raw});
      await expectLater(source().saveLastQuery(query()), throwsFormatException);
      expect(await storage.read(key: 'discover.last_query'), raw);
    },
  );

  test(
    'nested saved/history corruption blocks deletion and insertion',
    () async {
      for (final invalid in corruptWindows) {
        final raw = jsonEncode([
          {'id': 'bad', 'prompt': 'bad', 'query': record(invalid)},
        ]);
        FlutterSecureStorage.setMockInitialValues({
          'discover.saved_searches': raw,
          'discover.smart_search_history': raw,
        });
        await expectLater(
          source().deleteSavedSearch('bad'),
          throwsFormatException,
        );
        await expectLater(
          source().saveSavedSearch(saved()),
          throwsFormatException,
        );
        await expectLater(
          source().deleteSmartSearchPrompt('bad'),
          throwsFormatException,
        );
        await expectLater(
          source().saveSmartSearchPrompt(recent()),
          throwsFormatException,
        );
        expect(await storage.read(key: 'discover.saved_searches'), raw);
        expect(await storage.read(key: 'discover.smart_search_history'), raw);
      }
    },
  );

  test(
    'valid legacy reads preserve bytes for last, saved and recent queries',
    () async {
      for (final map in [record(window()), record(null, version: 1)]) {
        final rawQuery = jsonEncode(map);
        final nested = jsonEncode([
          {'id': 'old', 'prompt': 'old', 'query': map},
        ]);
        FlutterSecureStorage.setMockInitialValues({
          'discover.last_query': rawQuery,
          'discover.saved_searches': nested,
          'discover.smart_search_history': nested,
        });
        await source().loadLastQuery();
        await source().loadSavedSearches();
        await source().loadSmartSearchHistory();
        expect(await storage.read(key: 'discover.last_query'), rawQuery);
        expect(await storage.read(key: 'discover.saved_searches'), nested);
        expect(
          await storage.read(key: 'discover.smart_search_history'),
          nested,
        );
      }
    },
  );

  test(
    'canonical datasource writes and restores all three nested query paths',
    () async {
      final value = read(record(window()));
      await source().saveLastQuery(value);
      await source().saveSavedSearch(
        SavedSearchEntity(
          id: 'saved',
          title: 'Test',
          subtitle: 'Test',
          query: value,
          createdAtUtc: DateTime.utc(2026),
        ),
      );
      await source().saveSmartSearchPrompt(
        SmartSearchHistoryEntity(
          id: 'recent',
          prompt: 'Test',
          query: value,
          createdAtUtc: DateTime.utc(2026),
        ),
      );
      for (final restored in [
        await source().loadLastQuery(),
        (await source().loadSavedSearches()).single.query,
        (await source().loadSmartSearchHistory()).single.query,
      ]) {
        expect(
          DiscoverQueryModel.toMap(
            restored!,
            timezoneRepository: zones,
          )['time_window'],
          window(),
        );
      }
    },
  );
}
