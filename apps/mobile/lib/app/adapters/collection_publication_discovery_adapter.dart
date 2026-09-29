import '../../features/create/domain/entities/collection_publication_data.dart';
import '../../features/create/domain/repositories/collection_publication_index_sink.dart';
import '../../features/discover/data/datasources/published_collection_discovery_local_datasource.dart';
import '../../features/discover/domain/entities/published_collection_discovery_entity.dart';
import '../../features/discover/domain/repositories/published_collection_discovery_port.dart';

/// The one composition boundary between Create and Discover for Collection
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §14) — mirrors
/// `RoutePublicationDiscoveryAdapter`. Create depends on
/// `CollectionPublicationIndexSink` only; Discover depends on
/// `PublishedCollectionDiscoveryPort` only; this class is the only file
/// that imports both sides.
class CollectionPublicationDiscoveryAdapter
    implements CollectionPublicationIndexSink, PublishedCollectionDiscoveryPort {
  const CollectionPublicationDiscoveryAdapter(this._localDataSource);

  final PublishedCollectionDiscoveryLocalDataSource _localDataSource;

  @override
  Future<void> activate(PublishedCollectionVersion version) {
    final CollectionPublishBundle bundle = version.bundle;
    return _localDataSource.upsert(
      PublishedCollectionDiscoveryEntity(
        collectionId: bundle.collectionId,
        versionId: bundle.collectionVersionId,
        title: bundle.title,
        shortDescription: bundle.shortDescription,
        publisherName: bundle.publisherRef.id,
        marketCityId: bundle.marketCityId,
        areaLabel: bundle.areaLabel,
        areaId: bundle.areaId,
        budgetTier: bundle.budgetTier?.name,
        coverImage: bundle.coverMediaId ?? '',
        sections: bundle.sections
            .map(
              (section) => PublishedCollectionSectionRef(
                id: section.id,
                title: section.title,
                order: section.order,
              ),
            )
            .toList(growable: false),
        items: bundle.items
            .map(
              (item) => PublishedCollectionItemRef(
                objectId: item.ref.objectId,
                objectType: item.ref.objectType.name,
                sectionId: item.sectionId,
                order: item.order,
                curatorNote: item.curatorNote,
                highlight: item.highlight,
              ),
            )
            .toList(growable: false),
        publishedAtUtc: version.publishedAtUtc,
      ),
    );
  }

  @override
  Future<void> archive(String collectionId) =>
      _localDataSource.remove(collectionId);

  @override
  Future<PublishedCollectionDiscoveryEntity?> getActiveCollection(
    String collectionId,
  ) async {
    final List<PublishedCollectionDiscoveryEntity> collections =
        await _localDataSource.loadAll();
    for (final PublishedCollectionDiscoveryEntity collection in collections) {
      if (collection.collectionId == collectionId) return collection;
    }
    return null;
  }

  @override
  Future<List<PublishedCollectionDiscoveryEntity>> loadActiveCollections() =>
      _localDataSource.loadAll();
}
