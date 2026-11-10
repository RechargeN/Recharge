import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recharge/features/discover/data/datasources/discover_preferences_local_datasource.dart';
import 'package:recharge/features/discover/data/models/discover_query_model.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'saved and recent searches keep the same query across data roundtrip',
    () async {
      final source = DiscoverPreferencesLocalDataSource(
        const FlutterSecureStorage(),
        timezoneRepository: TimezoneRepositoryImpl(),
        defaultMarketCityId: 'test-market',
        defaultCenterLat: 1,
        defaultCenterLng: 2,
      );
      final query =
          DiscoverQuery.defaults(
            marketCityId: 'test-market',
            centerLat: 1,
            centerLng: 2,
          ).copyWith(
            queryText: 'walk',
            selectedCategoryIds: ['outdoor'],
            freeOnly: true,
            radiusMeters: 1234,
            manualAreaSelected: true,
          );
      await source.saveLastQuery(query);
      await source.saveSavedSearch(
        SavedSearchEntity(
          id: 'saved',
          title: 'Walk',
          subtitle: 'Park',
          query: query,
          createdAtUtc: DateTime.utc(2026),
        ),
      );
      await source.saveSmartSearchPrompt(
        SmartSearchHistoryEntity(
          id: 'recent',
          prompt: 'walk',
          query: query,
          createdAtUtc: DateTime.utc(2026),
        ),
      );
      final restored = [
        await source.loadLastQuery(),
        (await source.loadSavedSearches()).single.query,
        (await source.loadSmartSearchHistory()).single.query,
      ];
      for (final item in restored) {
        expect(
          DiscoverQueryModel.toMap(item!),
          DiscoverQueryModel.toMap(query),
        );
      }
    },
  );
  test(
    'legacy read uses explicit config without rewriting persisted query',
    () async {
      final raw = jsonEncode({'query_text': 'legacy', 'query_version': 1});
      FlutterSecureStorage.setMockInitialValues({'discover.last_query': raw});
      const storage = FlutterSecureStorage();
      final source = DiscoverPreferencesLocalDataSource(
        storage,
        timezoneRepository: TimezoneRepositoryImpl(),
        defaultMarketCityId: 'test-market',
        defaultCenterLat: 1,
        defaultCenterLng: 2,
      );
      final query = (await source.loadLastQuery())!;
      expect(query.marketCityId, 'test-market');
      expect(query.centerLat, 1);
      expect(query.centerLng, 2);
      expect(await storage.read(key: 'discover.last_query'), raw);
    },
  );
}
