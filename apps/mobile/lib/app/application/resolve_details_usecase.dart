import '../../shared/models/catalog_object_ref.dart';
import 'details_lookup_registry.dart';

/// What `details_route_parser.dart` (router-only) hands to
/// [ResolveDetailsUseCase] — never resolved or verified by the parser
/// itself, only recognized as one of the three known Details route shapes.
/// A `sealed` union is correct here: this is a closed, application-local
/// input shape with no legitimate reason for external extension (compare
/// `DetailsScreenState` in `features/discover/presentation/shell/
/// details_shell.dart`, which is `sealed` for the same reason;
/// `DetailsRenderer`/`DetailsLookupPort` are deliberately *not* sealed
/// because those are genuine per-slice extension points).
sealed class DetailsRouteTarget {
  const DetailsRouteTarget();
}

/// The canonical, typed shape: `/discover/details/:objectType/:objectId`.
/// The only shape the canonical route itself ever produces.
class DetailsRouteTargetRef extends DetailsRouteTarget {
  const DetailsRouteTargetRef(this.ref);

  final CatalogObjectRef ref;
}

/// Legacy `/discover/details/:itemId` — no explicit type in the URI.
/// Resolved the same way today's `DiscoverDetailsPage` implicitly does:
/// one call to the Event/Activity/Place/Route port, classified after the
/// fact.
class DetailsRouteTargetLegacyDiscoverItem extends DetailsRouteTarget {
  const DetailsRouteTargetLegacyDiscoverItem(this.itemId);

  final String itemId;
}

/// Legacy `/collection/details/:collectionId` — the route shape itself
/// already fixes `objectType: collection` (`DTL-LINK-01` §1.1.4).
class DetailsRouteTargetLegacyCollection extends DetailsRouteTarget {
  const DetailsRouteTargetLegacyCollection(this.collectionId);

  final String collectionId;
}

enum DetailsResolutionStatus { found, notFound }

/// Outcome of [ResolveDetailsUseCase.call]. `notFound` is deliberately the
/// *only* failure outcome (`docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md`
/// §12, `DTL-D10`): a missing loader, a load miss, and a hint/actual-type
/// mismatch are all folded into the same safe outcome so a caller —
/// and, downstream, a viewer — cannot distinguish "wrong type guess" from
/// "genuinely doesn't exist" from "no loader registered for this type
/// yet". That collapsing is intentional, not a shortcut.
class DetailsResolution {
  const DetailsResolution._({required this.status, this.ref, this.projection});

  const DetailsResolution.found(CatalogObjectRef ref, Object projection)
    : this._(
        status: DetailsResolutionStatus.found,
        ref: ref,
        projection: projection,
      );

  const DetailsResolution.notFound()
    : this._(status: DetailsResolutionStatus.notFound);

  final DetailsResolutionStatus status;

  /// Non-null only when [status] is [DetailsResolutionStatus.found]. Carries
  /// the *actual*, verified `objectType` — for [DetailsRouteTargetRef]
  /// input this always equals the input ref; for the two legacy inputs it
  /// is the type this use case just determined.
  final CatalogObjectRef? ref;

  /// Non-null only when [status] is [DetailsResolutionStatus.found]. The
  /// raw projection a `DetailsLookupPort.lookup` returned — untyped here
  /// because the registry holds heterogeneous port types (see
  /// `DetailsLookupPort`'s own doc comment); a caller that needs the
  /// concrete shape does so knowing [ref]'s `objectType`.
  final Object? projection;
}

/// Application-layer resolver (`DTL-LINK-01` §1.1.4). The one place that
/// decides "does this id actually denote an object of this type" — never
/// the router (parses only) and never the presentation renderer registry
/// (dispatches only). See `DISCOVER_DETAILS_SYSTEM_SPEC.md` §11's
/// three-way split.
class ResolveDetailsUseCase {
  const ResolveDetailsUseCase(this._registry);

  final DetailsLookupRegistry _registry;

  Future<DetailsResolution> call(DetailsRouteTarget target) {
    return switch (target) {
      DetailsRouteTargetRef(:final ref) => _resolveTyped(ref),
      DetailsRouteTargetLegacyDiscoverItem(:final itemId) =>
        _resolveLegacyDiscoverItem(itemId),
      DetailsRouteTargetLegacyCollection(:final collectionId) =>
        _resolveLegacyCollection(collectionId),
    };
  }

  Future<DetailsResolution> _resolveTyped(CatalogObjectRef ref) async {
    final port = _registry.portFor(ref.objectType);
    if (port == null) return const DetailsResolution.notFound();
    final Object? projection = await port.lookup(ref.objectId);
    if (projection == null) return const DetailsResolution.notFound();
    // The hint/actual mismatch check itself — never a trial-and-error scan
    // across other ports when this fails (DTL-D09/§11: enumeration leak).
    if (port.classify(projection) != ref.objectType) {
      return const DetailsResolution.notFound();
    }
    return DetailsResolution.found(ref, projection);
  }

  Future<DetailsResolution> _resolveLegacyDiscoverItem(String itemId) async {
    // Event/Activity/Place/Route are all registered to the *same* port
    // instance in details_resolution_providers.dart, so any one of the
    // four keys reaches it — `event` is used here purely as that shared
    // instance's canonical lookup key, not as a type guess.
    final port = _registry.portFor(CatalogObjectType.event);
    if (port == null) return const DetailsResolution.notFound();
    final Object? projection = await port.lookup(itemId);
    if (projection == null) return const DetailsResolution.notFound();
    final CatalogObjectType actual = port.classify(projection);
    return DetailsResolution.found(
      CatalogObjectRef(objectType: actual, objectId: itemId),
      projection,
    );
  }

  Future<DetailsResolution> _resolveLegacyCollection(
    String collectionId,
  ) async {
    final port = _registry.portFor(CatalogObjectType.collection);
    if (port == null) return const DetailsResolution.notFound();
    final Object? projection = await port.lookup(collectionId);
    if (projection == null) return const DetailsResolution.notFound();
    return DetailsResolution.found(
      CatalogObjectRef(
        objectType: CatalogObjectType.collection,
        objectId: collectionId,
      ),
      projection,
    );
  }
}
