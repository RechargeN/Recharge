import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/state/discover_feed_state.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';

void main() {
  late _FakeDiscoverRepository repository;
  late DiscoverFeedController controller;

  setUp(() {
    repository = _FakeDiscoverRepository();
    controller = DiscoverFeedController(
      getDiscoverFeedUseCase: GetDiscoverFeedUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );
  });

  test('loadFeed success -> success state with items', () async {
    await controller.loadFeed();

    expect(controller.state.status, DiscoverFeedStatus.success);
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
      distanceKm: 1.2,
      isFree: true,
    );
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed() async {
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
        distanceKm: 1.2,
        isFree: true,
      ),
    ];
  }
}
