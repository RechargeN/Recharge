import '../entities/collection_publication_data.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14. The write side of the
/// Create→Discover boundary — Create calls this after a successful publish;
/// it never reaches into Discover's own read models directly. The
/// app-level `CollectionPublicationDiscoveryAdapter` implements this on top
/// of Discover's local datasource, mirroring `PublishedRouteDiscoveryPort`.
abstract interface class CollectionPublicationIndexSink {
  Future<void> activate(PublishedCollectionVersion version);
  Future<void> archive(String collectionId);
}
