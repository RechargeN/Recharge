import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/details_lookup_registry.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/features/discover/data/repositories/class_workshop_details_lookup.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/published_class_workshop_discovery_port.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';
import '../fixtures/class_workshop_details_fixture.dart';

void main() {
  test(
    'typed Class resolves; wrong id, wrong type and Scenario fail closed',
    () async {
      final lookup = ClassWorkshopDetailsLookup(
        _Port(classWorkshopFixture()),
        TimezoneRepositoryImpl(),
      );
      final resolve = ResolveDetailsUseCase(
        DetailsLookupRegistry({
          CatalogObjectType.classWorkshop: lookup,
          CatalogObjectType.event: lookup,
        }),
      );
      Future<DetailsResolution> get(CatalogObjectType type, String id) =>
          resolve(
            DetailsRouteTargetRef(
              CatalogObjectRef(objectType: type, objectId: id),
            ),
          );
      expect(
        (await get(CatalogObjectType.classWorkshop, 'class-1')).projection,
        isA<PublishedClassWorkshopDiscoveryEntity>(),
      );
      for (final ref in [
        (CatalogObjectType.classWorkshop, 'wrong'),
        (CatalogObjectType.event, 'class-1'),
        (CatalogObjectType.scenario, 'class-1'),
      ]) {
        final result = await get(ref.$1, ref.$2);
        expect(result.status, DetailsResolutionStatus.notFound);
        expect(result.projection, isNull);
      }
    },
  );
  test(
    'invalid IANA timezone and missing data fail closed before renderer',
    () async {
      final lookup = ClassWorkshopDetailsLookup(
        _Port(
          classWorkshopFixture(
            schedule: ClassWorkshopAnnouncedSchedule([
              classOccurrence(timezone: 'Not/AZone'),
            ]),
          ),
        ),
        TimezoneRepositoryImpl(),
      );
      expect(await lookup.lookup('class-1'), isNull);
      expect(
        await ClassWorkshopDetailsLookup(
          _Port(null),
          TimezoneRepositoryImpl(),
        ).lookup('missing'),
        isNull,
      );
    },
  );
}

class _Port implements PublishedClassWorkshopDiscoveryPort {
  _Port(this.value);
  final PublishedClassWorkshopDiscoveryEntity? value;
  @override
  Future<PublishedClassWorkshopDiscoveryEntity?> getActiveClassWorkshop(
    String offeringId,
  ) async => value;
}
