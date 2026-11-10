import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/features/discover/application/discover_runtime_defaults.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/application/state/discover_feed_state.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/shared/primitives/geo/geo_point.dart';
import 'package:recharge/features/discover/domain/usecases/build_time_window_usecase.dart';
import 'package:recharge/features/discover/domain/repositories/timezone_repository.dart';
import 'package:recharge/shared/primitives/time/local_date.dart';

DiscoverQuery timedQuery(TimeWindowMode mode) =>
    DiscoverQuery.defaults().copyWith(
      timeWindow: TimeWindow(
        startAtUtc: DateTime.utc(2026, 10, 25, 0, 30, 0, 123, 456),
        endAtUtc: DateTime.utc(2026, 10, 25, 1, 30, 0, 123, 456),
        resolvedAtUtc: DateTime.utc(2026, 10, 24),
        timezoneId: 'Europe/Riga',
        mode: mode,
        flexibilityMinutes: mode == TimeWindowMode.flexible ? 30 : 0,
      ),
      travelContext: TravelContext(
        originType: TravelOriginType.manualPin,
        origin: const GeoPoint(latitude: 56.95, longitude: 24.1),
        transportMode: TransportMode.transit,
        includeReturnTrip: true,
      ),
    );

void main() {
  late _FakeDiscoverRepository repository;
  late DiscoverFeedController controller;

  setUp(() {
    repository = _FakeDiscoverRepository();
    controller = DiscoverFeedController(
      getDiscoverFeedUseCase: GetDiscoverFeedUseCase(repository),
      discoverPreferencesRepository: _FakeDiscoverPreferencesRepository(),
      analyticsService: _NoopAnalyticsService(),
      timezoneRepository: TimezoneRepositoryImpl(),
      buildTimeWindow: BuildTimeWindowUseCase(TimezoneRepositoryImpl()),
      runtimeDefaults: const DiscoverRuntimeDefaults(
        timezoneId: 'Europe/Riga',
        originLat: 56.9496,
        originLng: 24.1052,
        currency: CurrencyCode.eur,
      ),
    );
  });

  test('loadFeed success -> ready state with items', () async {
    await controller.loadFeed();

    expect(controller.state.status, DiscoverFeedStatus.ready);
    expect(controller.state.items, isNotEmpty);
  });

  test('new editor defaults use configured zone across the local midnight', () {
    final values = controller.timeEditorValues(
      nowUtc: DateTime.utc(2026, 7, 20, 20, 45),
    );
    expect(values.timezoneId, 'Europe/Riga');
    expect(values.start.date, LocalDate(2026, 7, 21));
    expect(values.start.minutesSinceMidnight, 15);
    expect(values.end.date, LocalDate(2026, 7, 21));
    expect(values.end.minutesSinceMidnight, 105);
    expect(
      () => controller.timeEditorValues(nowUtc: DateTime(2026)),
      throwsArgumentError,
    );
  });

  test(
    'unchanged editor preserves precise instants and a late overlap offset',
    () {
      final original = TimeWindow(
        startAtUtc: DateTime.utc(2026, 10, 25, 1, 15, 22, 123, 456),
        endAtUtc: DateTime.utc(2026, 10, 25, 2, 15, 33, 456, 789),
        resolvedAtUtc: DateTime.utc(2026, 10, 24),
        timezoneId: 'Europe/Riga',
        mode: TimeWindowMode.exact,
        flexibilityMinutes: 0,
      );
      controller.stageSearchConditions(
        timeWindow: original,
        travelContext: timedQuery(TimeWindowMode.exact).travelContext,
      );
      final values = controller.timeEditorValues(window: original);
      expect(values.start.minutesSinceMidnight, 195);
      final error = controller.stageTimeWindowSelection(
        mode: original.mode,
        startLocal: values.start,
        endLocal: values.end,
        timezoneId: values.timezoneId,
        flexibilityMinutes: 0,
        originType: TravelOriginType.manualPin,
        originLat: 56.95,
        originLng: 24.1,
        transportMode: TransportMode.transit,
        includeReturnTrip: true,
      );
      expect(error, isNull);
      expect(controller.state.draftQuery.timeWindow, same(original));
      expect(controller.state.draftQuery.dateFrom, original.startAtUtc);
      expect(controller.state.draftQuery.dateTo, original.endAtUtc);
      final flexError = controller.stageTimeWindowSelection(
        mode: TimeWindowMode.flexible,
        startLocal: values.start,
        endLocal: values.end,
        timezoneId: values.timezoneId,
        flexibilityMinutes: 30,
        originType: TravelOriginType.manualPin,
        originLat: 56.95,
        originLng: 24.1,
        transportMode: TransportMode.transit,
        includeReturnTrip: true,
      );
      expect(flexError, isNull);
      expect(
        controller.state.draftQuery.timeWindow!.startAtUtc,
        original.startAtUtc,
      );
      expect(
        controller.state.draftQuery.timeWindow!.endAtUtc,
        original.endAtUtc,
      );
      expect(controller.state.draftQuery.timeWindow!.flexibilityMinutes, 30);
    },
  );

  test(
    'changed local fields resolve the selected zone instead of market zone',
    () {
      final date = LocalDate(2026, 7, 20);
      final start = LocalDateTimeValue(
        date: date,
        minutesSinceMidnight: 600,
        weekday: date.weekday,
      );
      final end = start.addMinutes(60);
      final error = controller.stageTimeWindowSelection(
        mode: TimeWindowMode.exact,
        timezoneId: 'Pacific/Honolulu',
        startLocal: start,
        endLocal: end,
        flexibilityMinutes: 0,
        nowUtc: DateTime.utc(2026, 7, 19),
        originType: TravelOriginType.currentLocation,
        transportMode: TransportMode.walking,
        includeReturnTrip: false,
      );
      expect(error, isNull);
      expect(
        controller.state.draftQuery.timeWindow!.startAtUtc,
        DateTime.utc(2026, 7, 20, 20),
      );
      expect(
        controller.state.draftQuery.timeWindow!.timezoneId,
        'Pacific/Honolulu',
      );
      final editor = controller.timeEditorValues(
        window: controller.state.draftQuery.timeWindow,
      );
      expect(editor.start.compareTo(start), 0);
      expect(editor.timezoneId, 'Pacific/Honolulu');
    },
  );

  test(
    'gap, unknown zone and local now failures leave previous query intact',
    () {
      final initial = controller.state.draftQuery;
      final date = LocalDate(2026, 3, 29);
      final gap = LocalDateTimeValue(
        date: date,
        minutesSinceMidnight: 210,
        weekday: date.weekday,
      );
      for (final (zone, now) in [
        ('Europe/Riga', DateTime.utc(2026)),
        ('Unknown/Nowhere', DateTime.utc(2026)),
        ('Europe/Riga', DateTime(2026)),
      ]) {
        final error = controller.stageTimeWindowSelection(
          mode: TimeWindowMode.exact,
          timezoneId: zone,
          nowUtc: now,
          startLocal: gap,
          endLocal: gap.addMinutes(60),
          flexibilityMinutes: 0,
          originType: TravelOriginType.currentLocation,
          transportMode: TransportMode.walking,
          includeReturnTrip: false,
        );
        expect(error, isNotNull);
        expect(controller.state.draftQuery, same(initial));
      }
    },
  );

  test('time routes roundtrip every mode, zone, precision and travel', () {
    for (final mode in TimeWindowMode.values) {
      final query = timedQuery(mode);
      final seed = DiscoverFeedController.timeRouteParameters(query);
      final restored = controller.decodeTimeRouteParameters(seed);
      expect(restored.window!.startAtUtc, query.timeWindow!.startAtUtc);
      expect(restored.window!.endAtUtc, query.timeWindow!.endAtUtc);
      expect(restored.window!.resolvedAtUtc, query.timeWindow!.resolvedAtUtc);
      expect(restored.window!.timezoneId, 'Europe/Riga');
      expect(restored.window!.mode, mode);
      expect(
        restored.window!.flexibilityMinutes,
        query.timeWindow!.flexibilityMinutes,
      );
      expect(restored.travel!.origin, query.travelContext!.origin);
      expect(restored.travel!.transportMode, TransportMode.transit);
      expect(restored.travel!.includeReturnTrip, isTrue);
      expect(restored.from, query.timeWindow!.startAtUtc);
      expect(restored.to, query.timeWindow!.endAtUtc);
    }
  });

  test(
    'invalid coupled time routes fail without changing controller state',
    () {
      final valid = DiscoverFeedController.timeRouteParameters(
        timedQuery(TimeWindowMode.exact),
      );
      final state = controller.state;
      final invalid = <Map<String, String>>[
        for (final key in valid.keys) Map.of(valid)..remove(key),
        {...valid, 'timeMode': 'future'},
        {...valid, 'timezone': 'Unknown/Nowhere'},
        {...valid, 'timezone': 'Europe/Riga\n'},
        {...valid, 'timeStart': '2026-10-25T00:30:00'},
        {...valid, 'timeEnd': '2026-10-25T04:30:00+03:00'},
        {...valid, 'resolvedAt': '2026-02-30T00:00:00Z'},
        {...valid, 'timeEnd': valid['timeStart']!},
        {...valid, 'flexibility': '0.5'},
        {...valid, 'flexibility': '-1'},
        {...valid, 'flexibility': '999999999999999999999999'},
        {...valid, 'flexibility': '30'},
        {...valid, 'timeMode': 'flexible'},
        {...valid, 'originLat': 'NaN'},
        {...valid, 'originLng': '181'},
        {...valid, 'originType': 'future'},
        {...valid, 'transport': 'future'},
        {...valid, 'returnTrip': 'false'},
        {...valid, 'dateFrom': '2026-01-01T00:00:00Z'},
        {...valid, 'dateTo': '2026-01-01T00:00:00Z'},
      ];
      for (final seed in invalid) {
        expect(
          () => controller.decodeTimeRouteParameters(seed),
          throwsFormatException,
          reason: '$seed',
        );
        expect(controller.state, same(state));
      }
      expect(repository.requestCount, 0);
    },
  );

  test(
    'routes without windows keep explicit UTC dates and reject invalid bounds',
    () {
      final empty = controller.decodeTimeRouteParameters({});
      expect(empty.window, isNull);
      expect(empty.travel, isNull);
      expect(empty.from, isNull);
      final valid = controller.decodeTimeRouteParameters({
        'dateFrom': '2026-01-01T00:00:00Z',
      });
      expect(valid.from, DateTime.utc(2026));
      for (final seed in [
        {'dateFrom': '2026-01-01'},
        {'dateTo': '2026-01-01T00:00:00+00:00'},
        {'dateFrom': '2026-01-02T00:00:00Z', 'dateTo': '2026-01-01T00:00:00Z'},
      ]) {
        expect(
          () => controller.decodeTimeRouteParameters(seed),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'missing timezone service never grants a time route a fallback zone',
    () {
      final withoutZones = DiscoverFeedController(
        getDiscoverFeedUseCase: GetDiscoverFeedUseCase(repository),
        discoverPreferencesRepository: _FakeDiscoverPreferencesRepository(),
        analyticsService: _NoopAnalyticsService(),
        runtimeDefaults: const DiscoverRuntimeDefaults(
          timezoneId: 'Europe/Riga',
          originLat: 1,
          originLng: 2,
          currency: CurrencyCode.eur,
        ),
      );
      addTearDown(withoutZones.dispose);
      expect(
        () => withoutZones.decodeTimeRouteParameters(
          DiscoverFeedController.timeRouteParameters(
            timedQuery(TimeWindowMode.exact),
          ),
        ),
        throwsFormatException,
      );
      expect(withoutZones.decodeTimeRouteParameters({}).window, isNull);
    },
  );

  test('loadFeed empty -> empty state', () async {
    repository.shouldReturnEmpty = true;

    await controller.loadFeed();

    expect(controller.state.status, DiscoverFeedStatus.empty);
    expect(controller.state.items, isEmpty);
  });

  test('loadFeed failure -> error state', () async {
    repository.shouldFail = true;

    await controller.loadFeed();

    expect(controller.state.status, DiscoverFeedStatus.error);
    expect(controller.state.message, isNotNull);
  });

  test('stage area -> applySearchArea triggers reload', () async {
    await controller.loadFeed();
    controller.stageMapCenter(lat: 56.55, lng: 27.38);

    expect(controller.state.searchAreaDirty, isTrue);

    await controller.applySearchArea();

    expect(controller.state.searchAreaDirty, isFalse);
    expect(controller.state.appliedQuery.centerLat, closeTo(56.55, 0.0001));
  });

  test('stage radius -> applySearchArea updates map radius', () async {
    await controller.loadFeed();

    controller.stageRadius(radiusMeters: 20000, unlimited: false);

    expect(controller.state.searchAreaDirty, isTrue);
    expect(controller.state.draftQuery.radiusMeters, 20000);

    await controller.applySearchArea();

    expect(controller.state.searchAreaDirty, isFalse);
    expect(controller.state.appliedQuery.radiusMeters, 20000);
    expect(controller.state.appliedQuery.unlimitedRadius, isFalse);
  });

  test('applySearchConditions updates query and reloads once', () async {
    await controller.applySearchConditions(
      queryText: ' yoga ',
      selectedCategoryIds: const <String>['wellness'],
      freeOnly: true,
      budgetMax: Money(minorUnits: 1000, currency: CurrencyCode.eur),
      radiusMeters: 20000,
      unlimitedRadius: false,
    );

    expect(controller.state.appliedQuery.queryText, 'yoga');
    expect(controller.state.appliedQuery.selectedCategoryIds, <String>[
      'wellness',
    ]);
    expect(controller.state.appliedQuery.freeOnly, isTrue);
    expect(
      controller.state.appliedQuery.budgetMax,
      Money(minorUnits: 1000, currency: CurrencyCode.eur),
    );
    expect(controller.state.appliedQuery.radiusMeters, 20000);
    expect(repository.requestCount, 1);
    expect(repository.lastQuery?.queryText, 'yoga');
  });

  test('applySearchConditions can seed map center and selected item', () async {
    await controller.applySearchConditions(
      queryText: ' yoga ',
      selectedCategoryIds: const <String>['wellness'],
      radiusMeters: 5000,
      unlimitedRadius: false,
      centerLat: 56.52,
      centerLng: 27.36,
      manualAreaSelected: true,
      selectedItemId: 'evt_1',
    );

    expect(controller.state.appliedQuery.queryText, 'yoga');
    expect(controller.state.appliedQuery.radiusMeters, 5000);
    expect(controller.state.appliedQuery.unlimitedRadius, isFalse);
    expect(controller.state.appliedQuery.centerLat, closeTo(56.52, 0.0001));
    expect(controller.state.appliedQuery.centerLng, closeTo(27.36, 0.0001));
    expect(controller.state.appliedQuery.manualAreaSelected, isTrue);
    expect(controller.state.selectedItemId, 'evt_1');
    expect(controller.state.selectedItem?.id, 'evt_1');
    expect(repository.requestCount, 1);
    expect(repository.lastQuery?.centerLat, closeTo(56.52, 0.0001));
    expect(repository.lastQuery?.centerLng, closeTo(27.36, 0.0001));
  });

  test('resetSearchConditions clears filters and reloads', () async {
    await controller.applySearchConditions(
      queryText: 'art',
      selectedCategoryIds: const <String>['art'],
      freeOnly: true,
      budgetMax: Money(minorUnits: 1000, currency: CurrencyCode.eur),
    );

    await controller.resetSearchConditions();

    expect(controller.state.appliedQuery.queryText, isEmpty);
    expect(controller.state.appliedQuery.selectedCategoryIds, isEmpty);
    expect(controller.state.appliedQuery.freeOnly, isFalse);
    expect(controller.state.appliedQuery.budgetMax, isNull);
    expect(repository.requestCount, 2);
  });

  test(
    'saved search operations persist, apply, and delete conditions',
    () async {
      await controller.applySearchConditions(
        queryText: ' yoga ',
        selectedCategoryIds: const <String>['wellness'],
        freeOnly: true,
        radiusMeters: 5000,
      );

      await controller.saveCurrentSearch();

      expect(controller.state.savedSearches, hasLength(1));
      expect(controller.state.savedSearches.first.title, 'Yoga');

      await controller.resetSearchConditions();
      expect(controller.state.appliedQuery.queryText, isEmpty);

      await controller.applySavedSearch(controller.state.savedSearches.first);

      expect(controller.state.appliedQuery.queryText, 'yoga');
      expect(controller.state.appliedQuery.selectedCategoryIds, <String>[
        'wellness',
      ]);
      expect(controller.state.appliedQuery.freeOnly, isTrue);

      await controller.deleteSavedSearch(
        controller.state.savedSearches.first.id,
      );

      expect(controller.state.savedSearches, isEmpty);
    },
  );

  test('smart search history persists, applies, and deletes prompts', () async {
    final DiscoverQuery query = DiscoverQuery.defaults().copyWith(
      queryText: 'museum',
      selectedCategoryIds: const <String>['art'],
      budgetMax: Money(minorUnits: 1000, currency: CurrencyCode.eur),
      radiusMeters: 5000,
    );

    await controller.saveSmartSearchPrompt(
      prompt: 'museum today under 10',
      query: query,
    );

    expect(controller.state.smartSearchHistory, hasLength(1));
    expect(
      controller.state.smartSearchHistory.first.prompt,
      'museum today under 10',
    );

    await controller.applySmartSearchHistory(
      controller.state.smartSearchHistory.first,
    );

    expect(controller.state.appliedQuery.queryText, 'museum');
    expect(controller.state.appliedQuery.selectedCategoryIds, <String>['art']);
    expect(
      controller.state.appliedQuery.budgetMax,
      Money(minorUnits: 1000, currency: CurrencyCode.eur),
    );

    await controller.deleteSmartSearchPrompt(
      controller.state.smartSearchHistory.first.id,
    );

    expect(controller.state.smartSearchHistory, isEmpty);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeDiscoverRepository implements DiscoverRepository {
  bool shouldFail = false;
  bool shouldReturnEmpty = false;
  int requestCount = 0;
  DiscoverQuery? lastQuery;

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async {
    return DiscoverItemEntity(
      id: itemId,
      title: 'Details',
      subtitle: 'Subtitle',
      city: 'Москва',
      category: 'wellness',
      startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
      latitude: 56.5099,
      longitude: 27.3332,
      priceAmount: Money(minorUnits: 0, currency: CurrencyCode.eur),
      distanceKm: 1.2,
      isFree: true,
      relevanceScore: 0.7,
    );
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    requestCount += 1;
    lastQuery = query;
    if (shouldFail) {
      throw const DiscoverException(
        code: 'NETWORK_UNAVAILABLE',
        message: 'network',
      );
    }
    if (shouldReturnEmpty) {
      return <DiscoverItemEntity>[];
    }

    return <DiscoverItemEntity>[
      DiscoverItemEntity(
        id: 'evt_1',
        title: 'Утренняя йога в парке',
        subtitle: 'Легкая практика',
        city: 'Москва',
        category: 'wellness',
        startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
        latitude: query.centerLat,
        longitude: query.centerLng,
        priceAmount: Money(minorUnits: 0, currency: CurrencyCode.eur),
        distanceKm: 1.2,
        isFree: true,
        relevanceScore: 0.8,
      ),
    ];
  }
}

class _FakeDiscoverPreferencesRepository
    implements DiscoverPreferencesRepository {
  DiscoverQuery? _saved;
  final List<SavedSearchEntity> _savedSearches = <SavedSearchEntity>[];
  final List<SmartSearchHistoryEntity> _smartSearchHistory =
      <SmartSearchHistoryEntity>[];

  @override
  Future<DiscoverQuery?> loadLastQuery() async => _saved;

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {
    _saved = query;
  }

  @override
  Future<List<SavedSearchEntity>> loadSavedSearches() async {
    return List<SavedSearchEntity>.of(_savedSearches);
  }

  @override
  Future<void> saveSavedSearch(SavedSearchEntity search) async {
    _savedSearches.removeWhere(
      (SavedSearchEntity item) => item.id == search.id,
    );
    _savedSearches.insert(0, search);
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    _savedSearches.removeWhere((SavedSearchEntity item) => item.id == id);
  }

  @override
  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory() async {
    return List<SmartSearchHistoryEntity>.of(_smartSearchHistory);
  }

  @override
  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item) async {
    _smartSearchHistory.removeWhere(
      (SmartSearchHistoryEntity current) => current.id == item.id,
    );
    _smartSearchHistory.insert(0, item);
  }

  @override
  Future<void> deleteSmartSearchPrompt(String id) async {
    _smartSearchHistory.removeWhere(
      (SmartSearchHistoryEntity item) => item.id == id,
    );
  }
}
