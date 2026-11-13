import '../../domain/entities/collection_item_draft.dart';
import '../../domain/repositories/collection_catalog_search_repository.dart';

/// Deterministic local/mock catalog for the stabilization slice
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §10, §15). It intentionally does
/// not read Discover's real fixtures — pulling directly from another
/// feature's data layer would create the exact cross-feature coupling the
/// boundary gate flags — so it owns a small, self-contained demo catalog
/// covering all five CLG-CRT-01 types.
///
/// This is a plain datasource, not a `CollectionCatalogSearchRepository`
/// itself — see `CollectionCatalogSearchRepositoryImpl` for the seam a real
/// backend adapter will later replace.
class CollectionCatalogSearchMockDatasource {
  CollectionCatalogSearchMockDatasource({
    List<CollectionCatalogSearchResult>? fixtures,
  }) : _fixtures = fixtures ?? _defaultFixtures;

  final List<CollectionCatalogSearchResult> _fixtures;

  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) async {
    final String needle = query.text.trim().toLowerCase();
    final List<CollectionCatalogSearchResult> matches = _fixtures
        .where((CollectionCatalogSearchResult result) {
          if (!query.allowedTypes.contains(result.ref.objectType)) return false;
          if (query.excludeRefs.contains(result.ref)) return false;
          if (needle.isEmpty) return true;
          return result.snapshot.title.toLowerCase().contains(needle) ||
              (result.snapshot.categoryLabel?.toLowerCase().contains(needle) ??
                  false);
        })
        .toList(growable: false);

    // Ranking boost, not a filter (Вопрос 10): area-matching results move
    // up, nothing outside the area is hidden.
    final String? areaId = query.areaId;
    final String? areaLabel = query.areaLabel?.trim().toLowerCase();
    final List<CollectionCatalogSearchResult> sorted =
        List<CollectionCatalogSearchResult>.of(matches);
    if (areaId != null || (areaLabel != null && areaLabel.isNotEmpty)) {
      sorted.sort((
        CollectionCatalogSearchResult a,
        CollectionCatalogSearchResult b,
      ) {
        final int scoreA = _areaScore(a, areaId, areaLabel);
        final int scoreB = _areaScore(b, areaId, areaLabel);
        return scoreB.compareTo(scoreA);
      });
    }
    return sorted;
  }

  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) async {
    final Map<String, CollectionCatalogSearchResult> byKey =
        <String, CollectionCatalogSearchResult>{
          for (final CollectionCatalogSearchResult result in _fixtures)
            result.ref.stableKey: result,
        };
    return <String, CollectionCatalogSearchResult>{
      for (final CollectionObjectRef ref in refs)
        if (byKey.containsKey(ref.stableKey))
          ref.stableKey: byKey[ref.stableKey]!,
    };
  }

  int _areaScore(
    CollectionCatalogSearchResult result,
    String? areaId,
    String? areaLabel,
  ) {
    final String? resultCategory = result.snapshot.categoryLabel?.toLowerCase();
    if (areaId != null && resultCategory == areaId) return 2;
    if (areaLabel != null && (resultCategory?.contains(areaLabel) ?? false)) {
      return 1;
    }
    return 0;
  }

  static final List<CollectionCatalogSearchResult> _defaultFixtures =
      <CollectionCatalogSearchResult>[
        const CollectionCatalogSearchResult(
          ref: CollectionObjectRef(
            objectId: 'place_demo_1',
            objectType: CollectionCatalogObjectType.place,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'House of the Blackheads',
            categoryLabel: 'old_town',
            priceFromMinorUnits: 0,
            currency: 'EUR',
          ),
        ),
        const CollectionCatalogSearchResult(
          ref: CollectionObjectRef(
            objectId: 'place_demo_2',
            objectType: CollectionCatalogObjectType.place,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'Central Market',
            categoryLabel: 'old_town',
            priceFromMinorUnits: 0,
            currency: 'EUR',
          ),
        ),
        const CollectionCatalogSearchResult(
          ref: CollectionObjectRef(
            objectId: 'route_demo_1',
            objectType: CollectionCatalogObjectType.route,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'Old Riga walking loop',
            categoryLabel: 'old_town',
            priceFromMinorUnits: 0,
            currency: 'EUR',
          ),
        ),
        const CollectionCatalogSearchResult(
          ref: CollectionObjectRef(
            objectId: 'session_demo_1',
            objectType: CollectionCatalogObjectType.bookableSession,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'Riverside sauna session',
            categoryLabel: 'agenskalns',
            priceFromMinorUnits: 3500,
            currency: 'EUR',
          ),
        ),
        const CollectionCatalogSearchResult(
          ref: CollectionObjectRef(
            objectId: 'workshop_demo_1',
            objectType: CollectionCatalogObjectType.classWorkshop,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'Ceramics workshop',
            categoryLabel: 'miera_iela',
            priceFromMinorUnits: 4500,
            currency: 'EUR',
          ),
        ),
        const CollectionCatalogSearchResult(
          ref: CollectionObjectRef(
            objectId: 'rental_demo_1',
            objectType: CollectionCatalogObjectType.rental,
          ),
          snapshot: CollectionItemSnapshotDraft(
            title: 'City bike rental',
            categoryLabel: 'old_town',
            priceFromMinorUnits: 1200,
            currency: 'EUR',
          ),
        ),
      ];
}
