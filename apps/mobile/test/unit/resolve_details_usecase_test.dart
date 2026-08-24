import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/details_lookup_registry.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/discover/data/repositories/discover_item_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_route_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/details_lookup_port.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_details_usecase.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

/// `docs/product/DTL_LINK_01_DEEP_LINK_MIGRATION_SLICE_SPEC.md` §3.4: hint
/// matched / hint diverged / not found, plus legacy-compatibility
/// classification (including the Route branch via `isPublishedRoute`).
void main() {
  group('ResolveDetailsUseCase — typed CatalogObjectRef input', () {
    test('hint matches the port\'s classification -> found', () async {
      final registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.event: _FakePort(
          classifiesAs: CatalogObjectType.event,
          items: <String, Object>{'evt-1': 'evt-1-payload'},
        ),
      });
      final useCase = ResolveDetailsUseCase(registry);

      final DetailsResolution result = await useCase(
        const DetailsRouteTargetRef(
          CatalogObjectRef(objectType: CatalogObjectType.event, objectId: 'evt-1'),
        ),
      );

      expect(result.status, DetailsResolutionStatus.found);
      expect(
        result.ref,
        const CatalogObjectRef(objectType: CatalogObjectType.event, objectId: 'evt-1'),
      );
      expect(result.projection, 'evt-1-payload');
    });

    test(
      'hint diverges from the port\'s classification -> notFound, no '
      'fallback scan across other ports',
      () async {
        // The registered port answers to `event`, but the object it
        // actually returns classifies as `route` — exactly the
        // Event/Activity/Place/Route shared-port scenario.
        final _FakePort sharedPort = _FakePort(
          classifiesAs: CatalogObjectType.route,
          items: <String, Object>{'itm-1': 'itm-1-payload'},
        );
        final registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
          CatalogObjectType.event: sharedPort,
        });
        final useCase = ResolveDetailsUseCase(registry);

        final DetailsResolution result = await useCase(
          const DetailsRouteTargetRef(
            CatalogObjectRef(objectType: CatalogObjectType.event, objectId: 'itm-1'),
          ),
        );

        expect(result.status, DetailsResolutionStatus.notFound);
        expect(result.ref, isNull);
        expect(result.projection, isNull);
      },
    );

    test('no loader registered for objectType -> notFound', () async {
      final useCase = ResolveDetailsUseCase(
        DetailsLookupRegistry(const <CatalogObjectType, DetailsLookupPort>{}),
      );

      final DetailsResolution result = await useCase(
        const DetailsRouteTargetRef(
          CatalogObjectRef(objectType: CatalogObjectType.rental, objectId: 'r-1'),
        ),
      );

      expect(result.status, DetailsResolutionStatus.notFound);
    });

    test('lookup finds nothing -> notFound', () async {
      final registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.place: _FakePort(
          classifiesAs: CatalogObjectType.place,
          items: const <String, Object>{},
        ),
      });
      final useCase = ResolveDetailsUseCase(registry);

      final DetailsResolution result = await useCase(
        const DetailsRouteTargetRef(
          CatalogObjectRef(objectType: CatalogObjectType.place, objectId: 'missing'),
        ),
      );

      expect(result.status, DetailsResolutionStatus.notFound);
    });
  });

  group('ResolveDetailsUseCase — legacy input compatibility', () {
    test(
      'legacy discover item id resolves through the shared event-keyed '
      'port, classified after the fact',
      () async {
        final _FakePort sharedPort = _FakePort(
          classifiesAs: CatalogObjectType.route,
          items: <String, Object>{'legacy-1': 'route-payload'},
        );
        final registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
          CatalogObjectType.event: sharedPort,
          CatalogObjectType.activity: sharedPort,
          CatalogObjectType.place: sharedPort,
          CatalogObjectType.route: sharedPort,
        });
        final useCase = ResolveDetailsUseCase(registry);

        final DetailsResolution result = await useCase(
          const DetailsRouteTargetLegacyDiscoverItem('legacy-1'),
        );

        expect(result.status, DetailsResolutionStatus.found);
        expect(
          result.ref,
          const CatalogObjectRef(objectType: CatalogObjectType.route, objectId: 'legacy-1'),
        );
      },
    );

    test('legacy discover item id that does not exist -> notFound', () async {
      final registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.event: _FakePort(
          classifiesAs: CatalogObjectType.event,
          items: const <String, Object>{},
        ),
      });
      final useCase = ResolveDetailsUseCase(registry);

      final DetailsResolution result = await useCase(
        const DetailsRouteTargetLegacyDiscoverItem('missing'),
      );

      expect(result.status, DetailsResolutionStatus.notFound);
    });

    test('legacy collection id always resolves as collection', () async {
      final registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.collection: _FakePort(
          classifiesAs: CatalogObjectType.collection,
          items: <String, Object>{'col-1': 'collection-payload'},
        ),
      });
      final useCase = ResolveDetailsUseCase(registry);

      final DetailsResolution result = await useCase(
        const DetailsRouteTargetLegacyCollection('col-1'),
      );

      expect(result.status, DetailsResolutionStatus.found);
      expect(
        result.ref,
        const CatalogObjectRef(objectType: CatalogObjectType.collection, objectId: 'col-1'),
      );
      expect(result.projection, 'collection-payload');
    });
  });

  group(
    'ResolveDetailsUseCase — real DiscoverItemDetailsLookup wiring '
    '(proves the isPublishedRoute classification, not just a fake stand-in)',
    () {
      test(
        'a published-route item resolves as route via legacy input',
        () async {
          final registry = _registryFor(_FakeDiscoverRepository(<String, DiscoverItemEntity>{
            'route-1': _routeItem('route-1'),
          }));
          final useCase = ResolveDetailsUseCase(registry);

          final DetailsResolution result = await useCase(
            const DetailsRouteTargetLegacyDiscoverItem('route-1'),
          );

          expect(result.status, DetailsResolutionStatus.found);
          expect(result.ref!.objectType, CatalogObjectType.route);
        },
      );

      test('a plain activity item resolves as activity via legacy input', () async {
        final registry = _registryFor(_FakeDiscoverRepository(<String, DiscoverItemEntity>{
          'act-1': _activityItem('act-1'),
        }));
        final useCase = ResolveDetailsUseCase(registry);

        final DetailsResolution result = await useCase(
          const DetailsRouteTargetLegacyDiscoverItem('act-1'),
        );

        expect(result.status, DetailsResolutionStatus.found);
        expect(result.ref!.objectType, CatalogObjectType.activity);
      });

      test(
        'a typed activity ref against an item that is actually a route '
        '-> notFound (hint/actual mismatch, real classify wiring)',
        () async {
          final registry = _registryFor(_FakeDiscoverRepository(<String, DiscoverItemEntity>{
            'route-2': _routeItem('route-2'),
          }));
          final useCase = ResolveDetailsUseCase(registry);

          final DetailsResolution result = await useCase(
            const DetailsRouteTargetRef(
              CatalogObjectRef(objectType: CatalogObjectType.activity, objectId: 'route-2'),
            ),
          );

          expect(result.status, DetailsResolutionStatus.notFound);
        },
      );
    },
  );
}

DetailsLookupRegistry _registryFor(DiscoverRepository repository) {
  final DiscoverItemDetailsLookup lookup = DiscoverItemDetailsLookup(
    GetDiscoverDetailsUseCase(repository),
  );
  return DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
    CatalogObjectType.event: lookup,
    CatalogObjectType.activity: lookup,
    CatalogObjectType.place: lookup,
    CatalogObjectType.route: lookup,
  });
}

class _FakePort implements DetailsLookupPort {
  _FakePort({required this.classifiesAs, required Map<String, Object> items})
    : _items = items;

  final CatalogObjectType classifiesAs;
  final Map<String, Object> _items;

  @override
  Future<Object?> lookup(String objectId) async => _items[objectId];

  @override
  CatalogObjectType classify(Object projection) => classifiesAs;
}

class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this._items);

  final Map<String, DiscoverItemEntity> _items;

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async {
    final DiscoverItemEntity? item = _items[itemId];
    if (item == null) {
      throw const DiscoverException(
        code: 'DISCOVER_NOT_FOUND',
        message: 'Not found',
      );
    }
    return item;
  }

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    return _items.values.toList(growable: false);
  }
}

DiscoverItemEntity _activityItem(String id) {
  return DiscoverItemEntity(
    id: id,
    title: 'Activity $id',
    subtitle: 'subtitle',
    city: 'Riga',
    category: 'wellness',
    startsAtUtc: DateTime.utc(2026, 8, 1),
    latitude: 56.9,
    longitude: 24.1,
    priceAmount: 0,
    distanceKm: 1,
    isFree: true,
    objectKind: DiscoverObjectKind.activity,
  );
}

DiscoverItemEntity _routeItem(String id) {
  return DiscoverItemEntity(
    id: id,
    title: 'Route $id',
    subtitle: 'A continuous trail.',
    city: 'Riga',
    category: 'outdoor_nature_walking',
    startsAtUtc: DateTime.utc(2026, 8, 1),
    latitude: 56.9,
    longitude: 24.1,
    priceAmount: 0,
    distanceKm: 1,
    isFree: true,
    objectKind: DiscoverObjectKind.route,
    publishedRoute: PublishedRouteDiscoveryEntity(
      routeId: id,
      versionId: 'v1',
      geometryHash: 'hash',
      contentHash: 'content-v1',
      title: 'Route $id',
      subtitle: 'A continuous trail.',
      city: 'Riga',
      marketCityId: 'riga',
      timezoneId: 'Europe/Riga',
      categoryId: 'outdoor_nature_walking',
      subcategoryId: 'walking_route',
      coverImage: 'asset://route.jpg',
      publisherName: 'Recharge',
      startPoint: const GeoPoint(latitude: 56.9, longitude: 24.1),
      bounds: const GeoBounds(
        southwest: GeoPoint(latitude: 56.9, longitude: 24.1),
        northeast: GeoPoint(latitude: 56.95, longitude: 24.15),
      ),
      overviewEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
      fullEncodedPolyline: '_p~iF~ps|U_ulLnnqC',
      encodingPrecision: 5,
      distanceMeters: 4200,
      durationSeconds: 2700,
      routingProfileId: 'walking',
      difficultyId: 'easy.v1',
      demoOnly: true,
      searchTokens: const <String>['forest', 'walking'],
      attributions: const <String>['OpenStreetMap contributors'],
      publishedAtUtc: DateTime.utc(2026, 7, 25, 10),
    ),
  );
}
