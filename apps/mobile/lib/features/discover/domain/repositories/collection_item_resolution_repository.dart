import '../../../../shared/primitives/geo/geo_point.dart';
import '../entities/published_collection_discovery_entity.dart';

enum PublishedCollectionItemStatus { ready, unavailable }

/// Live card projection for one resolved item — always fresh, never the
/// authoring-time fallback snapshot (§3.5, §13).
class CollectionResolvedCardProjection {
  const CollectionResolvedCardProjection({
    required this.title,
    this.coverImage,
    this.categoryLabel,
    this.priceFromMinorUnits,
    this.currency,
  });

  final String title;
  final String? coverImage;
  final String? categoryLabel;
  final int? priceFromMinorUnits;
  final String? currency;
}

class CollectionResolvedItem {
  const CollectionResolvedItem({
    required this.ref,
    required this.status,
    this.card,
    this.publicMapPoint,
  });

  final PublishedCollectionItemRef ref;
  final PublishedCollectionItemStatus status;

  /// Null when [status] is `unavailable`.
  final CollectionResolvedCardProjection? card;

  /// Only ever a live public point for the current read — never persisted,
  /// never backfilled from a stale snapshot (§3.5, CLG-AC-28). Null when
  /// the source object has no public map point, is unavailable, or its
  /// location is private/approximate under its own type's privacy rules.
  final GeoPoint? publicMapPoint;
}

/// Discover-owned resolution for an already-*published* Collection's items
/// on the reader-facing Details page (§13, §14) — distinct from Create's
/// `CollectionCatalogSearchRepository.resolve`, which resolves items of a
/// still-unpublished *draft* during authoring preview. Batches by
/// `objectType` internally so Details never issues one read per item.
abstract interface class CollectionItemResolutionRepository {
  Future<Map<String, CollectionResolvedItem>> resolveMany(
    List<PublishedCollectionItemRef> refs,
  );
}
