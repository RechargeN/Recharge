import '../entities/collection_item_draft.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §10. Read-only projection of the
/// existing published catalog — this port never creates a second search
/// index; the mock/impl adapters reuse Discover's own fixtures.
abstract interface class CollectionCatalogSearchRepository {
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  );

  /// Authoring-time preview resolution for items already in the draft, so
  /// the coordinator can build a fresh `CollectionCompositionReview` before
  /// publish (§2, §7 Шаг 5). This is distinct from Discover's
  /// `CollectionItemResolutionRepository`, which resolves an already
  /// *published* Collection's items for the reader-facing Details page —
  /// that one belongs to `features/discover` per the §14 domain boundary.
  /// Missing refs are simply absent from the result map, not an error.
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  );
}

class CollectionCatalogSearchQuery {
  const CollectionCatalogSearchQuery({
    required this.text,
    required this.allowedTypes,
    required this.marketCityId,
    this.categoryId,
    this.areaId,
    this.areaLabel,
    this.excludeRefs = const <CollectionObjectRef>{},
  });

  final String text;
  final Set<CollectionCatalogObjectType> allowedTypes;
  final String marketCityId;
  final String? categoryId;

  /// Exact-match ranking boost, checked before [areaLabel] (§10).
  final String? areaId;

  /// Secondary, normalized-text ranking boost when no [areaId] is known on
  /// one side. Never a hard filter — objects outside the area are never
  /// hidden, only ranked lower (Вопрос 10).
  final String? areaLabel;

  /// Already-added items in the current draft, so the picker does not
  /// re-offer them (§10) — `addItem` still rejects duplicates defensively.
  final Set<CollectionObjectRef> excludeRefs;
}

class CollectionCatalogSearchResult {
  const CollectionCatalogSearchResult({
    required this.ref,
    required this.snapshot,
  });

  final CollectionObjectRef ref;
  final CollectionItemSnapshotDraft snapshot;
}
