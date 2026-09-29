import '../entities/published_rental_discovery_entity.dart';

/// Read side of the Create→Discover boundary for Rental (`DTL-OBJ-01`
/// §3.2) — mirrors `PublishedCollectionDiscoveryPort`. Search/Feed/Details
/// read only through this port; they never see a Create draft.
abstract interface class PublishedRentalDiscoveryPort {
  Future<List<PublishedRentalDiscoveryEntity>> loadActiveRentals();
  Future<PublishedRentalDiscoveryEntity?> getActiveRental(String rentalId);
}
