import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:recharge/features/discover/data/datasources/published_route_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/models/discover_item_model.dart';
import 'package:recharge/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_route_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/repositories/published_route_discovery_port.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('active Route index survives a new local datasource instance', () async {
    final first = PublishedRouteDiscoveryLocalDataSource(
      const FlutterSecureStorage(),
    );
    await first.upsert(_route());

    final restored = await PublishedRouteDiscoveryLocalDataSource(
      const FlutterSecureStorage(),
    ).loadAll();

    expect(restored, hasLength(1));
    expect(restored.single.routeId, 'route-1');
    expect(restored.single.versionId, 'version-1');
    expect(restored.single.geometryHash, 'geometry-1');
    expect(restored.single.fullEncodedPolyline, '_p~iF~ps|U_ulLnnqC');
  });

  test('new active version replaces the previous searchable version', () async {
    final dataSource = PublishedRouteDiscoveryLocalDataSource(
      const FlutterSecureStorage(),
    );
    await dataSource.upsert(_route());
    await dataSource.upsert(
      _route(versionId: 'version-2', geometryHash: 'geometry-2'),
    );

    final restored = await dataSource.loadAll();

    expect(restored, hasLength(1));
    expect(restored.single.versionId, 'version-2');
    expect(restored.single.geometryHash, 'geometry-2');
  });

  test(
    'Route is absent from default feed and appears after explicit search',
    () async {
      final repository = DiscoverRepositoryImpl(
        remoteDataSource: _EmptyRemoteDataSource(),
        publishedRoutes: _RoutePort(_route()),
        currency: CurrencyCode.eur,
      );
      final defaults = DiscoverQuery.defaults(
        marketCityId: 'riga',
        centerLat: 56.9496,
        centerLng: 24.1052,
        nowUtc: DateTime.utc(2026, 7, 25),
      );

      expect(await repository.getFeed(defaults), isEmpty);

      final results = await repository.getFeed(
        defaults.copyWith(queryText: 'forest', sourceScreen: 'regular_search'),
      );

      expect(results, hasLength(1));
      expect(results.single.isPublishedRoute, isTrue);
      expect(results.single.publishedRoute?.versionId, 'version-1');
      expect(results.single.ctaLabel, 'Open Route');
    },
  );

  test('Route participates in category, radius and duration filters', () async {
    final repository = DiscoverRepositoryImpl(
      remoteDataSource: _EmptyRemoteDataSource(),
      publishedRoutes: _RoutePort(_route()),
      currency: CurrencyCode.eur,
    );
    final query = DiscoverQuery.defaults(
      marketCityId: 'riga',
      centerLat: 56.9496,
      centerLng: 24.1052,
      nowUtc: DateTime.utc(2026, 7, 25),
    );

    expect(
      await repository.getFeed(
        query.copyWith(
          selectedCategoryIds: const <String>['outdoor_nature_walking'],
          availableDurationMinutes: 60,
          sourceScreen: 'search_results',
        ),
      ),
      hasLength(1),
    );
    expect(
      await repository.getFeed(
        query.copyWith(
          selectedCategoryIds: const <String>['food_drinks'],
          sourceScreen: 'search_results',
        ),
      ),
      isEmpty,
    );
    expect(
      await repository.getFeed(
        query.copyWith(
          selectedCategoryIds: const <String>['outdoor_nature_walking'],
          availableDurationMinutes: 20,
          sourceScreen: 'search_results',
        ),
      ),
      isEmpty,
    );
  });

  test('Route details use the same active version and geometry hash', () async {
    final repository = DiscoverRepositoryImpl(
      remoteDataSource: _EmptyRemoteDataSource(),
      publishedRoutes: _RoutePort(_route()),
      currency: CurrencyCode.eur,
    );

    final details = await repository.getDetails('route-1');

    expect(details.publishedRoute?.versionId, 'version-1');
    expect(details.publishedRoute?.geometryHash, 'geometry-1');
    expect(details.publishedRoute?.isCoherent, isTrue);
  });
}

PublishedRouteDiscoveryEntity _route({
  String versionId = 'version-1',
  String geometryHash = 'geometry-1',
}) => PublishedRouteDiscoveryEntity(
  routeId: 'route-1',
  versionId: versionId,
  geometryHash: geometryHash,
  contentHash: 'content-$versionId',
  title: 'Forest walking Route',
  subtitle: 'A continuous trail through the forest.',
  city: 'Riga',
  marketCityId: 'riga',
  timezoneId: 'Europe/Riga',
  categoryId: 'outdoor_nature_walking',
  subcategoryId: 'walking_route',
  coverImage: 'asset://route.jpg',
  publisherName: 'Recharge',
  startPoint: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
  bounds: const GeoBounds(
    southwest: GeoPoint(latitude: 56.9496, longitude: 24.1052),
    northeast: GeoPoint(latitude: 56.9520, longitude: 24.1150),
  ),
  overviewEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
  fullEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
  encodingPrecision: 5,
  distanceMeters: 4200,
  durationSeconds: 2700,
  routingProfileId: 'walking',
  difficultyId: 'easy.v1',
  demoOnly: true,
  searchTokens: const <String>['forest', 'walking', 'route'],
  attributions: const <String>['OpenStreetMap contributors'],
  publishedAtUtc: DateTime.utc(2026, 7, 25, 10),
);

class _RoutePort implements PublishedRouteDiscoveryPort {
  const _RoutePort(this.route);

  final PublishedRouteDiscoveryEntity route;

  @override
  Future<PublishedRouteDiscoveryEntity?> getActiveRoute(String routeId) async =>
      routeId == route.routeId ? route : null;

  @override
  Future<List<PublishedRouteDiscoveryEntity>> loadActiveRoutes() async =>
      <PublishedRouteDiscoveryEntity>[route];
}

class _EmptyRemoteDataSource implements DiscoverRemoteDataSource {
  @override
  Future<List<DiscoverItemModel>> getFeedCandidates() async =>
      const <DiscoverItemModel>[];

  @override
  Future<DiscoverItemModel> getDetails(String itemId) {
    throw const DiscoverException(
      code: 'DISCOVER_NOT_FOUND',
      message: 'Not found',
    );
  }
}
