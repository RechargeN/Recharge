import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/application/discover_providers.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/saved_search_entity.dart';
import 'package:recharge/features/discover/domain/entities/smart_search_history_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_preferences_repository.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'package:recharge/features/discover/presentation/pages/smart_search_page.dart';

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('renders a separate typed and voice Smart Search', (
    tester,
  ) async {
    await tester.pumpWidget(_SmartSearchTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Smart Search'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('smart-search-input')),
      findsOneWidget,
    );
    expect(find.byTooltip('Голосовой запрос'), findsOneWidget);
    expect(find.text('Популярные запросы'), findsOneWidget);
    expect(find.text('Начать поиск'), findsOneWidget);
    expect(find.text('Search Recharge'), findsNothing);
    expect(find.text('Conditions'), findsNothing);
  });

  fullPageTestWidgets('parses a typed prompt and opens shared results', (
    tester,
  ) async {
    await tester.pumpWidget(_SmartSearchTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('smart-search-input')),
      'museum today under 10 near 5 km',
    );
    await tester.pumpAndSettle();

    expect(find.text('Понятые параметры'), findsOneWidget);
    expect(find.text('up to 10.00'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);

    await tester.ensureVisible(find.text('Начать поиск'));
    await tester.tap(find.text('Начать поиск'));
    await tester.pumpAndSettle();

    expect(find.text('Results page'), findsOneWidget);
    expect(find.text('smart_search'), findsOneWidget);
    expect(find.text('museum'), findsOneWidget);
    expect(find.text('art_culture_museums'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  fullPageTestWidgets('restores the original Smart Search prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      _SmartSearchTestApp(
        initialLocation:
            '${RouteNames.smartSearch}?prompt=museum%20today%20under%2010',
      ),
    );
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('smart-search-input')),
    );
    expect(field.controller?.text, 'museum today under 10');
    expect(find.text('Понятые параметры'), findsOneWidget);
  });
}

class _SmartSearchTestApp extends StatelessWidget {
  _SmartSearchTestApp({this.initialLocation = RouteNames.smartSearch});

  final String initialLocation;
  final _FakePreferencesRepository _preferences = _FakePreferencesRepository();

  @override
  Widget build(BuildContext context) {
    final DiscoverFeedController controller = DiscoverFeedController(
      getDiscoverFeedUseCase: GetDiscoverFeedUseCase(_FakeDiscoverRepository()),
      discoverPreferencesRepository: _preferences,
      analyticsService: _NoopAnalyticsService(),
    );
    return ProviderScope(
      overrides: <Override>[
        discoverFeedControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: <RouteBase>[
            GoRoute(
              path: RouteNames.smartSearch,
              builder: (context, state) =>
                  SmartSearchPage(seedParameters: state.uri.queryParameters),
            ),
            GoRoute(
              path: RouteNames.discoverResults,
              builder: (context, state) => Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('Results page'),
                    Text(state.uri.queryParameters['source'] ?? ''),
                    Text(state.uri.queryParameters['q'] ?? ''),
                    Text(state.uri.queryParameters['category'] ?? ''),
                    Text(state.uri.queryParameters['budgetMax'] ?? ''),
                    Text(state.uri.queryParameters['radius'] ?? ''),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeDiscoverRepository implements DiscoverRepository {
  @override
  Future<DiscoverItemEntity> getDetails(String itemId) {
    throw UnimplementedError();
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return const <DiscoverItemEntity>[];
  }
}

class _FakePreferencesRepository implements DiscoverPreferencesRepository {
  DiscoverQuery? _lastQuery;
  final List<SmartSearchHistoryEntity> _history = <SmartSearchHistoryEntity>[];

  @override
  Future<void> deleteSavedSearch(String id) async {}

  @override
  Future<void> deleteSmartSearchPrompt(String id) async {
    _history.removeWhere((SmartSearchHistoryEntity item) => item.id == id);
  }

  @override
  Future<DiscoverQuery?> loadLastQuery() async => _lastQuery;

  @override
  Future<List<SavedSearchEntity>> loadSavedSearches() async {
    return const <SavedSearchEntity>[];
  }

  @override
  Future<List<SmartSearchHistoryEntity>> loadSmartSearchHistory() async {
    return List<SmartSearchHistoryEntity>.of(_history);
  }

  @override
  Future<void> saveLastQuery(DiscoverQuery query) async {
    _lastQuery = query;
  }

  @override
  Future<void> saveSavedSearch(SavedSearchEntity search) async {}

  @override
  Future<void> saveSmartSearchPrompt(SmartSearchHistoryEntity item) async {
    _history
      ..removeWhere((SmartSearchHistoryEntity current) => current.id == item.id)
      ..insert(0, item);
  }
}
