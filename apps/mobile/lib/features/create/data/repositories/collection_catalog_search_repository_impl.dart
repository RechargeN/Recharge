import '../../domain/entities/collection_item_draft.dart';
import '../../domain/repositories/collection_catalog_search_repository.dart';
import '../datasources/collection_catalog_search_mock_datasource.dart';

class CollectionCatalogSearchRepositoryImpl
    implements CollectionCatalogSearchRepository {
  const CollectionCatalogSearchRepositoryImpl({required this.datasource});

  final CollectionCatalogSearchMockDatasource datasource;

  @override
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) {
    return datasource.search(query);
  }

  @override
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) {
    return datasource.resolve(refs);
  }
}
