import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/details_lookup_registry.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/features/discover/data/datasources/published_find_people_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/find_people_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/details_lookup_port.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

void main() {
  test('canonical Find People ref resolves through its typed lookup', () async {
    final FindPeopleDetailsLookup lookup = FindPeopleDetailsLookup(
      PublishedFindPeopleDiscoveryLocalDataSource(),
    );
    final ResolveDetailsUseCase resolve = ResolveDetailsUseCase(
      DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
        CatalogObjectType.findPeople: lookup,
      }),
    );

    final DetailsResolution result = await resolve(
      const DetailsRouteTargetRef(
        CatalogObjectRef(
          objectType: CatalogObjectType.findPeople,
          objectId:
              PublishedFindPeopleDiscoveryLocalDataSource.morningRunRequestId,
        ),
      ),
    );

    expect(result.status, DetailsResolutionStatus.found);
    expect(result.ref?.objectType, CatalogObjectType.findPeople);
    expect(result.projection, isA<PublishedFindPeopleDiscoveryEntity>());
  });

  test(
    'unknown Find People id remains indistinguishable from not found',
    () async {
      final FindPeopleDetailsLookup lookup = FindPeopleDetailsLookup(
        PublishedFindPeopleDiscoveryLocalDataSource(),
      );
      final ResolveDetailsUseCase resolve = ResolveDetailsUseCase(
        DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
          CatalogObjectType.findPeople: lookup,
        }),
      );

      final DetailsResolution result = await resolve(
        const DetailsRouteTargetRef(
          CatalogObjectRef(
            objectType: CatalogObjectType.findPeople,
            objectId: 'missing',
          ),
        ),
      );

      expect(result.status, DetailsResolutionStatus.notFound);
      expect(result.ref, isNull);
      expect(result.projection, isNull);
    },
  );
}
