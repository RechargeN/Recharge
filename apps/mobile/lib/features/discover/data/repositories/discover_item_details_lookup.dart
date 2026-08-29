import '../../../../shared/models/catalog_object_ref.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/repositories/details_lookup_port.dart';
import '../../domain/usecases/get_discover_details_usecase.dart';

/// [DetailsLookupPort] wrapping the already-existing
/// `GetDiscoverDetailsUseCase`/`DiscoverRepository.getDetails` — serves
/// Event, Activity, Place and Route (`DTL-LINK-01` §1.1.2). One instance is
/// registered under all four `CatalogObjectType` keys in
/// `details_resolution_providers.dart`: it is the same single repository
/// call for all of them today, so registering it four times is not
/// duplicated data access — it is one port answering to four labels,
/// classified after the fact.
class DiscoverItemDetailsLookup implements DetailsLookupPort {
  const DiscoverItemDetailsLookup(this._getDetails);

  final GetDiscoverDetailsUseCase _getDetails;

  @override
  Future<DiscoverItemEntity?> lookup(String objectId) async {
    try {
      return await _getDetails(objectId);
    } on Object {
      // Mirrors discover_details_page.dart's pre-DTL-LINK-01 error
      // handling: any load failure (including "not found") degrades to a
      // safe absence, never a thrown exception reaching the resolver.
      return null;
    }
  }

  @override
  CatalogObjectType classify(Object projection) {
    return (projection as DiscoverItemEntity).catalogObjectType;
  }
}
