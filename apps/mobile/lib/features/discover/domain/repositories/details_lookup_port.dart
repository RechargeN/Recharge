import '../../../../shared/models/catalog_object_ref.dart';

/// Application-layer contract: one [DetailsLookupPort] instance can be
/// registered under one or more [CatalogObjectType] keys in a
/// `DetailsLookupRegistry` (`app/application/details_lookup_registry.dart`,
/// `DTL-LINK-01`). It is the *only* thing that reads a public projection
/// for Details resolution — never the presentation renderer registry
/// (`docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11).
///
/// Deliberately not generic (`DetailsLookupPort<T>`): a registry keyed by
/// [CatalogObjectType] needs one non-generic handle it can call uniformly,
/// and Dart has no clean way to store a heterogeneous collection of
/// differently-generic-typed values behind one interface. Callers that
/// need the concrete shape do so after [classify] has told them which
/// family they're holding.
abstract interface class DetailsLookupPort {
  /// Fetches the object by [objectId], or `null` if it does not exist or
  /// is not publicly visible. Never throws for "not found" — a
  /// [DetailsLookupPort] implementation must catch its own
  /// not-found/moderation-hidden signal and return `null` instead (see
  /// `DetailsScreenState.unavailable`/`notFound`,
  /// `features/discover/presentation/shell/details_shell.dart`, `DTL-D10`).
  Future<Object?> lookup(String objectId);

  /// Determines the actual [CatalogObjectType] of a non-null [lookup]
  /// result. A port that only ever resolves to one type may ignore
  /// [projection] and return a constant; a port that serves several types
  /// from one underlying data source (e.g. Event/Activity/Place/Route, all
  /// backed by the same `DiscoverRepository.getDetails`) inspects
  /// [projection] to tell them apart — mirroring how today's code already
  /// distinguishes them (`item.isPublishedRoute`/`item.objectKind`).
  CatalogObjectType classify(Object projection);
}
