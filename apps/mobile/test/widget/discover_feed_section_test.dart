import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/discover_providers.dart';
import 'package:recharge/features/discover/application/queries/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/presentation/widgets/discover_feed_section.dart';

void main() {
  testWidgets('renders feed cards in success state', (tester) async {
    final controller = DiscoverFeedController(
      getDiscoverFeedUseCase: GetDiscoverFeedUseCase(_FakeDiscoverRepository()),
      discoverPreferencesRepository: _FakeDiscoverPreferencesRepository(),
      analyticsService: _NoopAnalyticsService(),
    );
    await controller.loadFeed();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          discoverFeedControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DiscoverFeedSection(
              onOpenDetails: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Утренняя йога в парке'), findsOneWidget);
    expect(find.textContaining('км'), findsWidgets);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeDiscoverRepository implements DiscoverRepository {
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
  @override
  Future<DiscoverQuery?> loadLastQuery() async => null;

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {}
}
