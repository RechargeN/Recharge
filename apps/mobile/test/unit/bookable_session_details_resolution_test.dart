import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/details_lookup_registry.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/features/discover/data/datasources/published_bookable_session_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/bookable_session_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/details_lookup_port.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

void main() {
  test('Session registration leaves canonical Scenario fail closed', () async {
    final resolve = ResolveDetailsUseCase(
      DetailsLookupRegistry({
        CatalogObjectType.session: BookableSessionDetailsLookup(
          PublishedBookableSessionDiscoveryLocalDataSource(),
        ),
      }),
    );
    final result = await resolve(
      const DetailsRouteTargetRef(
        CatalogObjectRef(
          objectType: CatalogObjectType.scenario,
          objectId: PublishedBookableSessionDiscoveryLocalDataSource
              .personalTrainingSessionId,
        ),
      ),
    );
    expect(result.status, DetailsResolutionStatus.notFound);
    expect(result.projection, isNull);
  });

  test('wrong id and wrong type both fail closed without a fallback', () async {
    final fixture = (await PublishedBookableSessionDiscoveryLocalDataSource()
        .getActiveBookableSession(
          PublishedBookableSessionDiscoveryLocalDataSource
              .personalTrainingSessionId,
        ))!;
    final lookup = BookableSessionDetailsLookup(
      PublishedBookableSessionDiscoveryLocalDataSource(
        fixtureBuilders: {
          'wrong-id': () => fixture,
          fixture.sessionId: () => fixture,
        },
      ),
    );
    final resolve = ResolveDetailsUseCase(
      DetailsLookupRegistry({
        CatalogObjectType.session: lookup,
        CatalogObjectType.event: lookup,
      }),
    );
    for (final ref in [
      const CatalogObjectRef(
        objectType: CatalogObjectType.session,
        objectId: 'wrong-id',
      ),
      CatalogObjectRef(
        objectType: CatalogObjectType.event,
        objectId: fixture.sessionId,
      ),
    ]) {
      final result = await resolve(DetailsRouteTargetRef(ref));
      expect(result.status, DetailsResolutionStatus.notFound);
      expect(result.projection, isNull);
    }
  });

  test('canonical Session ref resolves through its typed lookup', () async {
    final BookableSessionDetailsLookup lookup = BookableSessionDetailsLookup(
      PublishedBookableSessionDiscoveryLocalDataSource(
        clock: () => DateTime.utc(2026, 9, 7, 10),
      ),
    );
    final ResolveDetailsUseCase resolve = ResolveDetailsUseCase(
      DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.session: lookup,
      }),
    );

    final DetailsResolution result = await resolve(
      const DetailsRouteTargetRef(
        CatalogObjectRef(
          objectType: CatalogObjectType.session,
          objectId: PublishedBookableSessionDiscoveryLocalDataSource
              .personalTrainingSessionId,
        ),
      ),
    );

    expect(result.status, DetailsResolutionStatus.found);
    expect(result.ref?.objectType, CatalogObjectType.session);
    expect(result.projection, isA<PublishedBookableSessionDiscoveryEntity>());
  });

  test('unknown Session id remains indistinguishable from not found', () async {
    final BookableSessionDetailsLookup lookup = BookableSessionDetailsLookup(
      PublishedBookableSessionDiscoveryLocalDataSource(),
    );
    final ResolveDetailsUseCase resolve = ResolveDetailsUseCase(
      DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.session: lookup,
      }),
    );

    final DetailsResolution result = await resolve(
      const DetailsRouteTargetRef(
        CatalogObjectRef(
          objectType: CatalogObjectType.session,
          objectId: 'missing',
        ),
      ),
    );

    expect(result.status, DetailsResolutionStatus.notFound);
    expect(result.ref, isNull);
    expect(result.projection, isNull);
  });
}
