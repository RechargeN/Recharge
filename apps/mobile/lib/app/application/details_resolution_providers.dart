import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/data/repositories/collection_details_lookup.dart';
import '../../features/discover/data/repositories/class_workshop_details_lookup.dart';
import '../../features/discover/domain/repositories/published_class_workshop_discovery_port.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/data/repositories/bookable_session_details_lookup.dart';
import '../../features/discover/data/repositories/discover_item_details_lookup.dart';
import '../../features/discover/data/repositories/event_details_lookup.dart';
import '../../features/discover/data/repositories/find_people_details_lookup.dart';
import '../../features/discover/data/repositories/rental_details_lookup.dart';
import '../../features/discover/domain/repositories/details_lookup_port.dart';
import '../../features/discover/domain/repositories/published_collection_discovery_port.dart';
import '../../features/discover/domain/repositories/published_bookable_session_discovery_port.dart';
import '../../features/discover/domain/repositories/published_event_discovery_port.dart';
import '../../features/discover/domain/repositories/published_find_people_discovery_port.dart';
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
/// (`DTL-LINK-01` §1.2/AC-07, extended by `DTL-OBJ-01` §4 and
/// `DTL-EVT-01` §3): Activity/Place/Route (one shared port), Collection,
/// Rental, Event, Find People and — since `DTL-SES-01` — Bookable Session
/// on typed ports. DTL-CLS-01 also registers Class/Workshop. Scenario is absent —
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
  final DetailsLookupPort eventLookup = EventDetailsLookup(
    sl<PublishedEventDiscoveryPort>(),
  );
  final DetailsLookupPort findPeopleLookup = FindPeopleDetailsLookup(
    sl<PublishedFindPeopleDiscoveryPort>(),
  );
  final DetailsLookupPort bookableSessionLookup = BookableSessionDetailsLookup(
    sl<PublishedBookableSessionDiscoveryPort>(),
  );
  final DetailsLookupPort classWorkshopLookup = ClassWorkshopDetailsLookup(
    sl<PublishedClassWorkshopDiscoveryPort>(),
    sl<TimezoneRepository>(),
  );
  return DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
    // Event now resolves through its own typed projection
    // (`PublishedEventDiscoveryEntity`), not the legacy
    // `discoverItemLookup` — Activity/Place/Route are unaffected
    // (`DTL-EVT-01` §2.5).
    CatalogObjectType.event: eventLookup,
    CatalogObjectType.findPeople: findPeopleLookup,
    CatalogObjectType.session: bookableSessionLookup,
    CatalogObjectType.classWorkshop: classWorkshopLookup,
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
