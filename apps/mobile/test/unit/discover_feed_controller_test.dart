import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/queries/discover_query.dart';
import 'package:recharge/features/discover/application/state/discover_feed_state.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
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
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeDiscoverRepository implements DiscoverRepository {
  bool shouldFail = false;
  bool shouldReturnEmpty = false;

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

  @override
  Future<DiscoverQuery?> loadLastQuery() async => _saved;

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {
    _saved = query;
  }
}
