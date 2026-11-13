import '../entities/rental_listing.dart';

/// The write side of the Create→Discover boundary for Rental
/// (`DTL-OBJ-01` §3.1) — Create calls this after a successful direct
/// publish (`RNT-PUB-01`); it never reaches into Discover's own read
/// models directly. The app-level `RentalPublicationDiscoveryAdapter`
/// implements this on top of Discover's local datasource, mirroring
/// `RoutePublicationIndexSink`/`CollectionPublicationIndexSink`.
abstract interface class RentalPublicationIndexSink {
  Future<void> activate(RentalPublishedVersion version);
  Future<void> archive(String rentalId);
}

/// The active, immutable version of a published Rental listing — what
/// [RentalPublicationIndexSink.activate] receives, and what the app-level
/// `RentalPublicationDiscoveryAdapter` reads to build the Discover-owned
/// `PublishedRentalDiscoveryEntity`. Create never hands `RentalListing`
/// itself to Discover.
class RentalPublishedVersion {
  const RentalPublishedVersion({
    required this.listing,
    required this.publishedAtUtc,
  });

  final RentalListing listing;
  final DateTime publishedAtUtc;

  String get rentalId => listing.id;
}
