import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/queries/discover_query.dart';
import 'package:recharge/features/discover/application/state/discover_feed_state.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';

void main() {
  late _FakeDiscoverRepository repository;
  late DiscoverFeedController controller;

  setUp(() {
    repository = _FakeDiscoverRepository();
    controller = DiscoverFeedController(
      getDiscoverFeedUseCase: GetDiscoverFeedUseCase(repository),
      discoverPreferencesRepository: _FakeDiscoverPreferencesRepository(),
      analyticsService: _NoopAnalyticsService(),
    );
  });

  test('loadFeed success -> ready state with items', () async {
    await controller.loadFeed();

    expect(controller.state.status, DiscoverFeedStatus.ready);
    expect(controller.state.items, isNotEmpty);
  });

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
      budgetMax: 10,
      radiusMeters: 20000,
      unlimitedRadius: false,
    );

    expect(controller.state.appliedQuery.queryText, 'yoga');
    expect(
      controller.state.appliedQuery.selectedCategoryIds,
      <String>['wellness'],
    );
    expect(controller.state.appliedQuery.freeOnly, isTrue);
    expect(controller.state.appliedQuery.budgetMax, 10);
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
      budgetMax: 10,
    );

    await controller.resetSearchConditions();

    expect(controller.state.appliedQuery.queryText, isEmpty);
    expect(controller.state.appliedQuery.selectedCategoryIds, isEmpty);
    expect(controller.state.appliedQuery.freeOnly, isFalse);
    expect(controller.state.appliedQuery.budgetMax, isNull);
    expect(repository.requestCount, 2);
  });

  test('saved search operations persist, apply, and delete conditions',
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
    expect(
      controller.state.appliedQuery.selectedCategoryIds,
      <String>['wellness'],
    );
    expect(controller.state.appliedQuery.freeOnly, isTrue);

    await controller.deleteSavedSearch(controller.state.savedSearches.first.id);

    expect(controller.state.savedSearches, isEmpty);
  });

  test('smart search history persists, applies, and deletes prompts', () async {
    final DiscoverQuery query = DiscoverQuery.defaults().copyWith(
      queryText: 'museum',
      selectedCategoryIds: const <String>['art'],
      budgetMax: 10,
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
    expect(controller.state.appliedQuery.budgetMax, 10);

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
      priceAmount: 0,
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
      return const <DiscoverItemEntity>[];
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
        priceAmount: 0,
        distanceKm: 1.2,
        isFree: true,
        relevanceScore: 0.8,
      ),
    ];
  }
}

class _FakeDiscoverPreferencesRepository implements DiscoverPreferencesRepository {
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
    _savedSearches.removeWhere((SavedSearchEntity item) => item.id == search.id);
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
