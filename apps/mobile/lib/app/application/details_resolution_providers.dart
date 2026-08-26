import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/data/repositories/collection_details_lookup.dart';
import '../../features/discover/data/repositories/discover_item_details_lookup.dart';
import '../../features/discover/data/repositories/rental_details_lookup.dart';
import '../../features/discover/domain/repositories/details_lookup_port.dart';
import '../../features/discover/domain/repositories/published_collection_discovery_port.dart';
import '../../features/discover/domain/repositories/published_rental_discovery_port.dart';
import '../../features/discover/domain/usecases/get_discover_details_usecase.dart';
import '../../shared/models/catalog_object_ref.dart';
import '../di/service_locator.dart';
import 'details_lookup_registry.dart';
import 'resolve_details_usecase.dart';

/// App-level composition, not `features/discover/application/` — the same
/// placement rule `collection_discover_providers.dart` and
/// `scenario_object_intake_providers.dart` already follow, since this
/// registry spans more than one feature's read side (Discover items today,
/// Collection today, further families in later `DTL-*` slices).
///
/// Registers loaders for exactly the families this slice provides
/// (`DTL-LINK-01` §1.2/AC-07, extended by `DTL-OBJ-01` §4):
/// Event/Activity/Place/Route (one shared port), Collection, and Rental.
/// Session/Find People/Class-Workshop/Scenario are deliberately absent —
/// `_registry.portFor(...)` returning `null` for them is the correct, safe
/// `notFound` behavior until a later slice registers a loader for one of
/// them.
final detailsLookupRegistryProvider = Provider<DetailsLookupRegistry>((ref) {
  final DetailsLookupPort discoverItemLookup = DiscoverItemDetailsLookup(
    sl<GetDiscoverDetailsUseCase>(),
  );
  final DetailsLookupPort collectionLookup = CollectionDetailsLookup(
    sl<PublishedCollectionDiscoveryPort>(),
  );
  final DetailsLookupPort rentalLookup = RentalDetailsLookup(
    sl<PublishedRentalDiscoveryPort>(),
  );
  return DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
    CatalogObjectType.event: discoverItemLookup,
    CatalogObjectType.activity: discoverItemLookup,
    CatalogObjectType.place: discoverItemLookup,
    CatalogObjectType.route: discoverItemLookup,
    CatalogObjectType.collection: collectionLookup,
    CatalogObjectType.rental: rentalLookup,
  });
});

final resolveDetailsUseCaseProvider = Provider<ResolveDetailsUseCase>((ref) {
  return ResolveDetailsUseCase(ref.watch(detailsLookupRegistryProvider));
});

/// Resolves one [DetailsRouteTarget]. `autoDispose` + `family`: a
/// resolution is keyed to the specific target it was asked to resolve and
/// has no reason to survive after the screen asking for it goes away —
/// same lifecycle shape as `discoverDetailsProvider`
/// (`features/discover/application/discover_providers.dart`).
final resolveDetailsProvider = FutureProvider.autoDispose
    .family<DetailsResolution, DetailsRouteTarget>((ref, target) {
      return ref.watch(resolveDetailsUseCaseProvider)(target);
    });
