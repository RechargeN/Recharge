import '../../../../shared/primitives/geo/geo_point.dart';
import '../../domain/entities/published_collection_discovery_entity.dart';
import '../../domain/repositories/collection_item_resolution_repository.dart';

/// Local/mock implementation for the stabilization slice
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14). Its fixtures deliberately
/// mirror `CollectionCatalogSearchMockDatasource`'s demo catalog by id, so a
/// Collection assembled from that picker resolves to something real here
/// too. A production implementation dispatches per `objectType` to
/// Discover's own Place/Route/Bookable Session/Class-Workshop/Rental read
/// repositories instead of an in-file fixture table.
class CollectionItemResolutionRepositoryImpl
    implements CollectionItemResolutionRepository {
  const CollectionItemResolutionRepositoryImpl();

  @override
  Future<Map<String, CollectionResolvedItem>> resolveMany(
    List<PublishedCollectionItemRef> refs,
  ) async {
    return <String, CollectionResolvedItem>{
      for (final PublishedCollectionItemRef ref in refs)
        ref.stableKey: _resolveOne(ref),
    };
  }

  CollectionResolvedItem _resolveOne(PublishedCollectionItemRef ref) {
    final _MockResolvedFixture? fixture = _defaultFixtures[ref.stableKey];
    if (fixture == null) {
      return CollectionResolvedItem(
        ref: ref,
        status: PublishedCollectionItemStatus.unavailable,
      );
    }
    return CollectionResolvedItem(
      ref: ref,
      status: PublishedCollectionItemStatus.ready,
      card: fixture.card,
      publicMapPoint: fixture.publicMapPoint,
    );
  }

  static final Map<String, _MockResolvedFixture> _defaultFixtures =
      <String, _MockResolvedFixture>{
        'place:place_demo_1': _MockResolvedFixture(
          card: const CollectionResolvedCardProjection(
            title: 'House of the Blackheads',
            categoryLabel: 'old_town',
          ),
          publicMapPoint: const GeoPoint(latitude: 56.9469, longitude: 24.1064),
        ),
        'place:place_demo_2': _MockResolvedFixture(
          card: const CollectionResolvedCardProjection(
            title: 'Central Market',
            categoryLabel: 'old_town',
          ),
          publicMapPoint: const GeoPoint(latitude: 56.9459, longitude: 24.1075),
        ),
        'route:route_demo_1': _MockResolvedFixture(
          card: const CollectionResolvedCardProjection(
            title: 'Old Riga walking loop',
            categoryLabel: 'old_town',
          ),
          publicMapPoint: const GeoPoint(latitude: 56.9475, longitude: 24.1052),
        ),
        'bookableSession:session_demo_1': _MockResolvedFixture(
          card: const CollectionResolvedCardProjection(
            title: 'Riverside sauna session',
            categoryLabel: 'agenskalns',
            priceFromMinorUnits: 3500,
            currency: 'EUR',
          ),
          publicMapPoint: const GeoPoint(latitude: 56.9412, longitude: 24.0876),
        ),
        'classWorkshop:workshop_demo_1': _MockResolvedFixture(
          card: const CollectionResolvedCardProjection(
            title: 'Ceramics workshop',
            categoryLabel: 'miera_iela',
            priceFromMinorUnits: 4500,
            currency: 'EUR',
          ),
          publicMapPoint: const GeoPoint(latitude: 56.9548, longitude: 24.1301),
        ),
        'rental:rental_demo_1': _MockResolvedFixture(
          card: const CollectionResolvedCardProjection(
            title: 'City bike rental',
            categoryLabel: 'old_town',
            priceFromMinorUnits: 1200,
            currency: 'EUR',
          ),
          publicMapPoint: const GeoPoint(latitude: 56.9481, longitude: 24.1058),
        ),
      };
}

class _MockResolvedFixture {
  const _MockResolvedFixture({required this.card, this.publicMapPoint});

  final CollectionResolvedCardProjection card;
  final GeoPoint? publicMapPoint;
}
