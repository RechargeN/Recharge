import '../../features/create/domain/entities/rental_listing.dart';
import '../../features/create/domain/repositories/rental_publication_index_sink.dart';
import '../../features/discover/data/datasources/published_rental_discovery_local_datasource.dart';
import '../../features/discover/domain/entities/published_rental_discovery_entity.dart';
import '../../features/discover/domain/repositories/published_rental_discovery_port.dart';

/// The one composition boundary between Create and Discover for Rental
/// (`DTL-OBJ-01` §3.4) — mirrors `CollectionPublicationDiscoveryAdapter`.
/// Create depends on `RentalPublicationIndexSink` only; Discover depends
/// on `PublishedRentalDiscoveryPort` only; this class is the only file
/// that imports both sides.
class RentalPublicationDiscoveryAdapter
    implements RentalPublicationIndexSink, PublishedRentalDiscoveryPort {
  const RentalPublicationDiscoveryAdapter(this._localDataSource);

  final PublishedRentalDiscoveryLocalDataSource _localDataSource;

  @override
  Future<void> activate(RentalPublishedVersion version) {
    final RentalListing listing = version.listing;
    return _localDataSource.upsert(
      PublishedRentalDiscoveryEntity(
        rentalId: listing.id,
        publisherId: listing.publisherRef.id,
        title: listing.title,
        shortDescription: listing.shortDescription,
        fullDescription: listing.fullDescription,
        categoryId: listing.categoryId,
        subcategoryId: listing.subcategoryId,
        brandModel: listing.brandModel,
        mediaRefs: listing.mediaRefs,
        inventoryGroups: listing.inventoryGroups
            .map(
              (group) => PublishedRentalInventoryGroupRef(
                id: group.id,
                label: group.label,
                quantity: group.quantity,
                condition: group.condition.name,
                sizeOrVariant: group.sizeOrVariant,
                includedAccessories: group.includedAccessories,
                status: group.status.name,
              ),
            )
            .toList(growable: false),
        totalUnitsAggregate: listing.totalUnitsAggregate,
        publicAreaLabel: listing.publicAreaLabel,
        publicAddress: listing.publicAddress,
        publicLatitude: listing.publicLatitude,
        publicLongitude: listing.publicLongitude,
        publicGeoPrecisionMeters: listing.publicGeoPrecisionMeters,
        deliveryAvailable: listing.deliveryAvailable,
        deliveryRadiusKm: listing.deliveryRadiusKm,
        deliveryFeeMinor: listing.deliveryFeeMinor,
        deliveryTerms: listing.deliveryTerms,
        offeredMinMinutes: listing.offeredMinMinutes,
        offeredMaxMinutes: listing.offeredMaxMinutes,
        minRenterAge: listing.minRenterAge,
        idRequiredAtHandover: listing.idRequiredAtHandover,
        usageRestrictions: listing.usageRestrictions,
        safetyNotice: listing.safetyNotice,
        currencyCode: listing.currencyCode,
        billingUnit: listing.billingUnit.name,
        rateSteps: listing.rateSteps
            .map(
              (step) => PublishedRentalRateStepRef(
                minUnits: step.minUnits,
                unitPriceMinor: step.unitPrice.amountMinor,
              ),
            )
            .toList(growable: false),
        hasDeposit: listing.hasDeposit,
        depositAmountMinor: listing.depositAmountMinor,
        damagePolicy: listing.damagePolicy,
        lateReturnPolicy: listing.lateReturnPolicy,
        cancellationPolicyId: listing.cancellationPolicyId,
        cancellationPolicyNote: listing.cancellationPolicyNote,
        externalBookingUrl: listing.externalBookingUrl,
        publishedAtUtc: version.publishedAtUtc,
      ),
    );
  }

  @override
  Future<void> archive(String rentalId) => _localDataSource.remove(rentalId);

  @override
  Future<PublishedRentalDiscoveryEntity?> getActiveRental(
    String rentalId,
  ) async {
    final List<PublishedRentalDiscoveryEntity> rentals =
        await _localDataSource.loadAll();
    for (final PublishedRentalDiscoveryEntity rental in rentals) {
      if (rental.rentalId == rentalId) return rental;
    }
    return null;
  }

  @override
  Future<List<PublishedRentalDiscoveryEntity>> loadActiveRentals() =>
      _localDataSource.loadAll();
}
