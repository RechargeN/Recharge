import '../../shared/models/catalog_object_ref.dart';
import '../application/resolve_details_usecase.dart';
import 'route_names.dart';

/// Parses a Details path into a [DetailsRouteTarget] — **parsing only**,
/// never resolution (`docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11:
/// "Router парсит URI... ничего не резолвит сам"). Returns `null` when
/// [path] matches none of the three known Details route shapes; callers
/// treat that as a routing miss, not a Details-specific `notFound` (that
/// distinction belongs to [ResolveDetailsUseCase]/`DetailsScreenState`).
///
/// Recognizes, in order:
/// 1. Canonical: `/discover/details/:objectType/:objectId`
/// 2. Legacy: `/discover/details/:itemId` (no explicit type)
/// 3. Legacy: `/collection/details/:collectionId`
///
/// Must reproduce today's legacy route shapes byte-for-byte
/// (`DTL-LINK-01` §1.1.6) — it does not reinvent or narrow them.
DetailsRouteTarget? parseDetailsRoutePath(String path) {
  final List<String> segments = Uri.parse(path).pathSegments;
  final List<String> discoverDetailsPrefix = Uri.parse(
    RouteNames.discoverDetails,
  ).pathSegments;
  final List<String> collectionDetailsPrefix = Uri.parse(
    RouteNames.collectionDetails,
  ).pathSegments;

  if (_startsWith(segments, discoverDetailsPrefix)) {
    final List<String> rest = segments.sublist(discoverDetailsPrefix.length);
    if (rest.length == 2) {
      final String objectTypeSegment = rest[0];
      final String objectId = rest[1];
      if (objectId.isEmpty) return null;
      final CatalogObjectType? objectType = catalogObjectTypeFromTaxonomyId(
        objectTypeSegment,
      );
      if (objectType == null) return null;
      return DetailsRouteTargetRef(
        CatalogObjectRef(objectType: objectType, objectId: objectId),
      );
    }
    if (rest.length == 1) {
      final String itemId = rest[0];
      if (itemId.isEmpty) return null;
      return DetailsRouteTargetLegacyDiscoverItem(itemId);
    }
    return null;
  }

  if (_startsWith(segments, collectionDetailsPrefix)) {
    final List<String> rest = segments.sublist(
      collectionDetailsPrefix.length,
    );
    if (rest.length == 1) {
      final String collectionId = rest[0];
      if (collectionId.isEmpty) return null;
      return DetailsRouteTargetLegacyCollection(collectionId);
    }
    return null;
  }

  return null;
}

bool _startsWith(List<String> segments, List<String> prefix) {
  if (segments.length < prefix.length) return false;
  for (int i = 0; i < prefix.length; i += 1) {
    if (segments[i] != prefix[i]) return false;
  }
  return true;
}
