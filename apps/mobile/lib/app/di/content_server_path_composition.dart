import '../../features/create/application/content_server_path.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import 'collection_content_publication_composition.dart';
import 'place_publication_composition.dart';
import 'rental_publication_composition.dart';
import 'service_locator.dart';

/// The Create form's view of the server publication path (M1 stage 3, 3-Б):
/// live answers of the same test-entry guards that gate every command, and
/// the market currency of the Create runtime. Without a registered guard the
/// type stays off.
ContentServerPath contentServerPathFromDi() => ContentServerPath(
  isEnabled: (CreateObjectType type) => switch (type) {
    CreateObjectType.place =>
      sl.isRegistered<PlacePublicationTestEntryGuard>() &&
          sl<PlacePublicationTestEntryGuard>().allowed,
    CreateObjectType.rental =>
      sl.isRegistered<RentalPublicationTestEntryGuard>() &&
          sl<RentalPublicationTestEntryGuard>().allowed,
    CreateObjectType.collection =>
      sl.isRegistered<CollectionPublicationTestEntryGuard>() &&
          sl<CollectionPublicationTestEntryGuard>().allowed,
    _ => false,
  },
  marketCurrencyCode: sl.isRegistered<CreateRuntimeDefaults>()
      ? sl<CreateRuntimeDefaults>().currency
      : '',
);
