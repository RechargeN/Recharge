import '../../features/discover/domain/repositories/details_lookup_port.dart';
import '../../shared/models/catalog_object_ref.dart';

/// `objectType → DetailsLookupPort` registry (`DTL-LINK-01` §1.1.3).
///
/// Architecturally distinct from the presentation renderer registry
/// (`DetailsRendererRegistry`, `features/discover/presentation/shell/
/// details_renderer.dart`, `DTL-FND-01`): that one answers "which widget
/// renders an already-resolved family"; this one answers "where does the
/// data for a given `objectType` come from, and how do I confirm it".
/// The two are never merged into one class
/// (`docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11, third-round
/// finding on presentation-registry-as-data-authority).
class DetailsLookupRegistry {
  DetailsLookupRegistry(Map<CatalogObjectType, DetailsLookupPort> ports)
    : _ports = Map<CatalogObjectType, DetailsLookupPort>.of(ports);

  final Map<CatalogObjectType, DetailsLookupPort> _ports;

  /// Returns the port registered for [objectType], or `null` if this
  /// slice hasn't registered a loader for it yet (Session/Find People/
  /// Class-Workshop/Rental/Scenario — `DTL-LINK-01` §1.2). A missing
  /// registration is a legitimate, expected `notFound` outcome here, not a
  /// wiring bug — unlike `DetailsRendererRegistry.build`, which throws for
  /// a missing family because every family it's asked for is expected to
  /// already be resolved and real.
  DetailsLookupPort? portFor(CatalogObjectType objectType) =>
      _ports[objectType];
}
