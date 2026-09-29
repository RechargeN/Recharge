import '../entities/published_collection_discovery_entity.dart';

/// Read side of the Create→Discover boundary for Collection
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14) — mirrors
/// `PublishedRouteDiscoveryPort`. Search/Feed/Details read only through
/// this port; they never see a Create draft.
abstract interface class PublishedCollectionDiscoveryPort {
  Future<List<PublishedCollectionDiscoveryEntity>> loadActiveCollections();
  Future<PublishedCollectionDiscoveryEntity?> getActiveCollection(
    String collectionId,
  );
}
