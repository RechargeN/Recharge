import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/app/adapters/legacy_quick_plan_conversion_adapter.dart';
import 'package:recharge/features/discover/application/smart_search_parser.dart';
import 'package:recharge/features/discover/application/discover_runtime_defaults.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/state/discover_feed_state.dart';
import 'package:recharge/features/discover/data/models/discover_item_model.dart';
import 'package:recharge/features/discover/data/models/discover_query_model.dart';
import 'package:recharge/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:recharge/features/discover/data/datasources/discover_preferences_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:recharge/features/discover/data/repositories/discover_preferences_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/application/state/favorites_state.dart';
import 'package:recharge/features/favorites/data/models/favorite_item_model.dart';
import 'package:recharge/features/favorites/data/datasources/favorites_local_datasource.dart';
import 'package:recharge/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:recharge/features/scenarios/domain/entities/scenario_draft_entity.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';

Money eur(int minor) => Money(minorUnits: minor, currency: CurrencyCode.eur);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const storage = FlutterSecureStorage();

  test('feature prices reject negative deltas and unsupported writes', () {
    expect(() => pricedItem('negative', eur(-1)), throwsArgumentError);
    expect(() => step(eur(-1)), throwsArgumentError);
    final foreign = Money(minorUnits: 10, currency: CurrencyCode.parse('USD'));
    expect(
      () => DiscoverQueryModel.toMap(
        DiscoverQuery.defaults().copyWith(budgetMax: foreign),
      ),
      throwsA(isA<MoneyReadException>()),
    );
  });

  test(
    'Discover and Favorite legacy amounts preserve cents with explicit currency',
    () {
      expect(
        DiscoverItemModel.fromMap(
          itemRecord({'price_amount': 0.29}),
          legacyCurrencyCode: 'EUR',
        ).priceAmount,
        eur(29),
      );
      expect(
        () => DiscoverItemModel.fromMap(itemRecord({'price_amount': 0.29})),
        throwsA(isA<MoneyReadException>()),
      );
      final raw = favoriteRecord()
        ..remove('priceMinorUnits')
        ..remove('currencyCode');
      raw['priceAmount'] = 0.29;
      final restored = FavoriteItemModel.fromJson(
        raw,
        legacyCurrencyCode: 'EUR',
      );
      expect(restored.priceAmount, eur(29));
      expect(restored.toJson()['priceMinorUnits'], 29);
      expect(restored.toJson()['currencyCode'], 'EUR');
      expect(restored.toJson().containsKey('priceAmount'), isFalse);
    },
  );

  test(
    'canonical malformed price never falls back to a valid legacy amount',
    () {
      for (final invalid in <Object?>[
        null,
        '123',
        123.0,
        Money.maxSafeMinorUnits + 1,
      ]) {
        expect(
          () => DiscoverItemModel.fromMap(
            itemRecord({
              'price_minor_units': invalid,
              'price_amount': 1.23,
              'currency_code': 'EUR',
            }),
          ),
          throwsA(isA<MoneyReadException>()),
        );
        expect(
          () => FavoriteItemModel.fromJson(
            favoriteRecord()
              ..['priceMinorUnits'] = invalid
              ..['priceAmount'] = 1.23,
          ),
          throwsA(isA<MoneyReadException>()),
        );
      }
      for (final currency in <Object?>[null, 123, 'USD']) {
        expect(
          () => DiscoverItemModel.fromMap(
            itemRecord({'price_minor_units': 123, 'currency_code': currency}),
            legacyCurrencyCode: 'EUR',
          ),
          throwsA(isA<MoneyReadException>()),
        );
      }
      expect(
        () => DiscoverItemModel.fromMap(
          itemRecord({'price_minor_units': -1, 'currency_code': 'EUR'}),
        ),
        throwsA(isA<MoneyReadException>()),
      );
    },
  );

  test(
    'query writes minor units; canonical null and legacy context are distinct',
    () {
      final query = DiscoverQuery.defaults().copyWith(
        budgetMin: eur(29),
        budgetMax: eur(1234),
      );
      final map = DiscoverQueryModel.toMap(query);
      expect(map['budget_min_minor_units'], 29);
      expect(map['budget_max_minor_units'], 1234);
      expect(map['currency_code'], 'EUR');
      expect(map.containsKey('budget_max'), isFalse);
      DiscoverQuery restore(Map<String, Object?> value, {String? currency}) =>
          DiscoverQueryModel.fromMap(
            value,
            defaultMarketCityId: 'test',
            defaultCenterLat: 0,
            defaultCenterLng: 0,
            legacyCurrencyCode: currency,
          );
      expect(restore(map).budgetMax, eur(1234));
      expect(restore({'budget_max': 0.29}, currency: 'EUR').budgetMax, eur(29));
      expect(
        () => restore({'budget_max': 0.29}),
        throwsA(isA<MoneyReadException>()),
      );
      expect(
        restore({'budget_max_minor_units': null, 'budget_max': 12}).budgetMax,
        isNull,
      );
      expect(
        () => restore({
          'budget_max_minor_units': '123',
          'budget_max': 12,
          'currency_code': 'EUR',
        }),
        throwsA(isA<MoneyReadException>()),
      );
    },
  );

  test('query budgets reject mixed currency and invalid ranges', () {
    final query = DiscoverQuery.defaults();
    expect(
      () => query.copyWith(
        budgetMin: eur(1),
        budgetMax: Money(minorUnits: 2, currency: CurrencyCode.parse('USD')),
      ),
      throwsA(isA<MoneyArithmeticException>()),
    );
    expect(() => query.copyWith(budgetMax: eur(-1)), throwsArgumentError);
    expect(
      () => query.copyWith(budgetMin: eur(2), budgetMax: eur(1)),
      throwsArgumentError,
    );
  });

  test(
    'budget filter respects exact cents, currency, and explicit free state',
    () async {
      final remote = PriceRemote([
        DiscoverItemModel.fromMap(
          itemRecord({
            'id': 'below',
            'price_minor_units': 1000,
            'currency_code': 'EUR',
          }),
        ),
        DiscoverItemModel.fromMap(
          itemRecord({
            'id': 'edge',
            'price_minor_units': 1001,
            'currency_code': 'EUR',
          }),
        ),
        DiscoverItemModel.fromMap(
          itemRecord({
            'id': 'above',
            'price_minor_units': 1002,
            'currency_code': 'EUR',
          }),
        ),
        pricedItem(
          'foreign',
          Money(minorUnits: 1000, currency: CurrencyCode.parse('USD')),
        ),
        pricedItem('paid-zero', eur(0)),
      ]);
      final repository = DiscoverRepositoryImpl(
        remoteDataSource: remote,
        currency: CurrencyCode.eur,
      );
      final query = DiscoverQuery.defaults().copyWith(
        budgetMin: eur(1000),
        budgetMax: eur(1001),
        unlimitedRadius: true,
      );
      expect(
        (await repository.getFeed(query)).map((item) => item.id),
        unorderedEquals(['below', 'edge']),
      );
      expect(
        await repository.getFeed(
          DiscoverQuery.defaults().copyWith(
            freeOnly: true,
            unlimitedRadius: true,
          ),
        ),
        isEmpty,
      );
    },
  );

  test(
    'bad persisted query blocks replacement and leaves applied state unchanged',
    () async {
      final raw = jsonEncode({
        'query_version': 2,
        'budget_max_minor_units': 'bad',
        'budget_max': 10,
        'currency_code': 'EUR',
      });
      FlutterSecureStorage.setMockInitialValues({'discover.last_query': raw});
      final source = preferences();
      await expectLater(
        source.saveLastQuery(DiscoverQuery.defaults()),
        throwsA(isA<MoneyReadException>()),
      );
      final controller = DiscoverFeedController(
        getDiscoverFeedUseCase: GetDiscoverFeedUseCase(
          DiscoverRepositoryImpl(
            remoteDataSource: PriceRemote([]),
            currency: CurrencyCode.eur,
          ),
        ),
        discoverPreferencesRepository: DiscoverPreferencesRepositoryImpl(
          localDataSource: source,
        ),
        analyticsService: ConsoleAnalyticsService(),
        runtimeDefaults: const DiscoverRuntimeDefaults(
          timezoneId: 'UTC',
          originLat: 0,
          originLng: 0,
          currency: CurrencyCode.eur,
        ),
      );
      addTearDown(controller.dispose);
      await controller.ensureLoaded();
      expect(controller.state.status, DiscoverFeedStatus.error);
      await controller.applySearchConditions(budgetMax: eur(1234));
      expect(controller.state.appliedQuery.budgetMax, isNull);
      expect(controller.state.status, DiscoverFeedStatus.error);
      expect(await storage.read(key: 'discover.last_query'), raw);
    },
  );

  test(
    'bad favorite price blocks add/delete without success feedback or data loss',
    () async {
      final raw = jsonEncode([favoriteRecord()..['priceMinorUnits'] = 'bad']);
      FlutterSecureStorage.setMockInitialValues({'favorites_items_v1': raw});
      final repository = FavoritesRepositoryImpl(
        localDataSource: FavoritesLocalDataSource(
          storage,
          legacyCurrencyCode: 'EUR',
        ),
      );
      final controller = FavoritesController(
        getFavoritesUseCase: GetFavoritesUseCase(repository),
        addFavoriteUseCase: AddFavoriteUseCase(repository),
        removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
        analyticsService: ConsoleAnalyticsService(),
      );
      addTearDown(controller.dispose);
      await controller.loadFavorites();
      expect(controller.state.status, FavoritesStatus.error);
      expect(
        await controller.addFavorite(favorite(), sourceScreen: 'test'),
        isFalse,
      );
      expect(
        await controller.removeFavorite('favorite', sourceScreen: 'test'),
        isFalse,
      );
      expect(await storage.read(key: 'favorites_items_v1'), raw);
    },
  );

  test('future or malformed query schema cannot be overwritten', () async {
    for (final version in [99, 2.5, '2']) {
      final raw = jsonEncode({'query_version': version, 'future': true});
      FlutterSecureStorage.setMockInitialValues({'discover.last_query': raw});
      await expectLater(
        preferences().saveLastQuery(DiscoverQuery.defaults()),
        throwsFormatException,
      );
      expect(await storage.read(key: 'discover.last_query'), raw);
    }
  });

  test(
    'invalid nested saved and history queries survive attempted deletion',
    () async {
      for (final query in [
        'broken',
        {'query_version': 99},
        {'budget_max_minor_units': '123', 'currency_code': 'EUR'},
      ]) {
        final raw = jsonEncode([
          {'id': 'broken', 'query': query, 'prompt': 'test'},
        ]);
        FlutterSecureStorage.setMockInitialValues({
          'discover.saved_searches': raw,
          'discover.smart_search_history': raw,
        });
        await expectLater(
          preferences().deleteSavedSearch('broken'),
          throwsA(anyOf(isA<FormatException>(), isA<MoneyReadException>())),
        );
        await expectLater(
          preferences().deleteSmartSearchPrompt('broken'),
          throwsA(anyOf(isA<FormatException>(), isA<MoneyReadException>())),
        );
        expect(await storage.read(key: 'discover.saved_searches'), raw);
        expect(await storage.read(key: 'discover.smart_search_history'), raw);
      }
    },
  );

  test(
    'Smart Search uses exact locale decimal text and rejects excess scale',
    () {
      expect(
        parseSmartSearch(
          'under 12.34',
          currency: CurrencyCode.eur,
          locale: 'en',
        ).budgetMax,
        eur(1234),
      );
      expect(
        parseSmartSearch(
          'до 12,34',
          currency: CurrencyCode.eur,
          locale: 'ru',
        ).budgetMax,
        eur(1234),
      );
      expect(
        parseSmartSearch(
          'до 1 234,56',
          currency: CurrencyCode.eur,
          locale: 'ru',
        ).budgetMax,
        eur(123456),
      );
      expect(
        parseSmartSearch('under 10', currency: null, locale: 'en').budgetError,
        MoneyParseError.missingCurrency,
      );
      for (final text in [
        'under 12.345',
        'under 1e3',
        'under -1',
        'under 12.34.56',
        '12 USD',
      ]) {
        final parsed = parseSmartSearch(
          text,
          currency: CurrencyCode.eur,
          locale: 'en',
        );
        expect(parsed.budgetMax, isNull, reason: text);
        expect(parsed.budgetError, isNotNull, reason: text);
      }
    },
  );

  test(
    'Scenario totals and legacy conversion preserve cents and reject mixing',
    () {
      final draft = scenario([step(eur(29)), step(eur(101))]);
      expect(draft.totalPriceAmount, eur(130));
      final copied = const LegacyQuickPlanConversionAdapter().toSnapshot(
        draft: draft,
        ownerId: 'owner',
        title: 'Plan',
        timezoneId: 'UTC',
        currencyCode: 'EUR',
      );
      expect(copied.stops.map((stop) => stop.price), [eur(29), eur(101)]);
      expect(scenario([step(eur(0))]).isFree, isFalse);
      expect(
        () => scenario([
          step(eur(Money.maxSafeMinorUnits)),
          step(eur(1)),
        ]).totalPriceAmount,
        throwsA(isA<MoneyArithmeticException>()),
      );
      final foreign = scenario([
        step(Money(minorUnits: 10, currency: CurrencyCode.parse('USD'))),
      ]);
      expect(
        () => foreign.totalPriceAmount,
        throwsA(isA<MoneyArithmeticException>()),
      );
      expect(
        () => const LegacyQuickPlanConversionAdapter().toSnapshot(
          draft: foreign,
          ownerId: 'owner',
          title: 'Plan',
          timezoneId: 'UTC',
          currencyCode: 'EUR',
        ),
        throwsA(isA<MoneyArithmeticException>()),
      );
    },
  );
}

Map<String, Object?> itemRecord(Map<String, Object?> price) => {
  'id': 'item',
  'title': 'Item',
  'subtitle': '',
  'city': 'Test',
  'category': 'test',
  'starts_at_utc': '2026-11-02T00:00:00Z',
  'latitude': 0,
  'longitude': 0,
  'distance_km': 0,
  'is_free': false,
  ...price,
};
DiscoverItemModel pricedItem(String id, Money price) => DiscoverItemModel(
  id: id,
  title: id,
  subtitle: '',
  city: 'Test',
  category: 'test',
  startsAtUtc: DateTime.utc(2026),
  latitude: 0,
  longitude: 0,
  priceAmount: price,
  distanceKm: 0,
  isFree: false,
  relevanceScore: 0,
);
FavoriteItemEntity favorite() => FavoriteItemEntity(
  id: 'favorite',
  title: 'Favorite',
  subtitle: '',
  city: 'Test',
  category: 'test',
  startsAtUtc: DateTime.utc(2026),
  distanceKm: 0,
  priceAmount: eur(1234),
  isFree: false,
  savedAtUtc: DateTime.utc(2026),
  targetRoute: null,
);
Map<String, dynamic> favoriteRecord() =>
    FavoriteItemModel.fromEntity(favorite()).toJson();
DiscoverPreferencesLocalDataSource preferences() =>
    DiscoverPreferencesLocalDataSource(
      const FlutterSecureStorage(),
      timezoneRepository: TimezoneRepositoryImpl(),
      defaultMarketCityId: 'test',
      defaultCenterLat: 0,
      defaultCenterLng: 0,
      legacyCurrencyCode: 'EUR',
    );
ScenarioStepEntity step(Money price) => ScenarioStepEntity(
  id: 'stop-${price.minorUnits}',
  title: 'Stop',
  subtitle: '',
  category: 'test',
  durationMinutes: 5,
  distanceKm: 0,
  priceAmount: price,
  isFree: false,
  latitude: 0,
  longitude: 0,
);
ScenarioDraftEntity scenario(List<ScenarioStepEntity> steps) =>
    ScenarioDraftEntity(
      id: 'scenario',
      revision: 1,
      currency: CurrencyCode.eur,
      mood: ScenarioMood.calm,
      maxDurationMinutes: 60,
      freeOnly: false,
      walkingOnly: true,
      sourcePrompt: '',
      steps: steps,
    );

class PriceRemote implements DiscoverRemoteDataSource {
  PriceRemote(this.items);
  final List<DiscoverItemModel> items;
  @override
  Future<List<DiscoverItemModel>> getFeedCandidates() async => items;
  @override
  Future<DiscoverItemModel> getDetails(String itemId) async =>
      items.singleWhere((item) => item.id == itemId);
}
