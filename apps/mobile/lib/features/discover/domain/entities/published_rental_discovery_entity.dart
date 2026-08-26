/// Discover-owned read model for an active Rental listing (`DTL-OBJ-01`
/// §3.2/§17). Built once, on publish, by
/// `RentalPublicationDiscoveryAdapter` from Create's `RentalListing` —
/// Discover never imports `RentalListing`/`RentalDraftData` or any other
/// Create domain type, so every field here is a primitive, matching how
/// `PublishedCollectionDiscoveryEntity` stores enums as plain strings
/// rather than importing Create's enum types (OBJ-AC-05).
class PublishedRentalDiscoveryEntity {
  const PublishedRentalDiscoveryEntity({
    required this.rentalId,
    required this.publisherId,
    required this.publisherType,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.categoryId,
    required this.subcategoryId,
    this.brandModel,
    this.mediaRefs = const <String>[],
    required this.inventoryGroups,
    required this.totalUnitsAggregate,
    required this.publicAreaLabel,
    this.publicAddress,
    this.publicLatitude,
    this.publicLongitude,
    required this.publicGeoPrecisionMeters,
    required this.deliveryAvailable,
    this.deliveryRadiusKm,
    this.deliveryFeeMinor,
    this.deliveryTerms,
    required this.offeredMinMinutes,
    required this.offeredMaxMinutes,
    this.minRenterAge,
    required this.idRequiredAtHandover,
    this.usageRestrictions,
    this.safetyNotice,
    required this.currencyCode,
    required this.billingUnit,
    required this.rateSteps,
    required this.hasDeposit,
    this.depositAmountMinor,
    required this.damagePolicy,
    this.lateReturnPolicy,
    required this.cancellationPolicyId,
    this.cancellationPolicyNote,
    this.externalBookingUrl,
    required this.publishedAtUtc,
  });

  final String rentalId;
  final String publisherId;

  /// `user` / `page` — wire-safe name of Create's `PublisherType`. Lost in
  /// the first version of this entity (only `.id` was carried) — restored
  /// so a future Page-aware Discover feature is not forced to re-derive
  /// it from nothing.
  final String publisherType;

  final String title;
  final String shortDescription;
  final String fullDescription;
  final String categoryId;
  final String subcategoryId;
  final String? brandModel;
  final List<String> mediaRefs;

  final List<PublishedRentalInventoryGroupRef> inventoryGroups;
  final int totalUnitsAggregate;

  final String publicAreaLabel;
  final String? publicAddress;
  final double? publicLatitude;
  final double? publicLongitude;
  final int publicGeoPrecisionMeters;
  final bool deliveryAvailable;
  final double? deliveryRadiusKm;
  final int? deliveryFeeMinor;
  final String? deliveryTerms;

  final int offeredMinMinutes;
  final int offeredMaxMinutes;
  final int? minRenterAge;
  final bool idRequiredAtHandover;
  final String? usageRestrictions;
  final String? safetyNotice;

  final String currencyCode;

  /// `hour` / `day` / `week` — wire-safe name of Create's
  /// `RentalBillingUnit`, stored as a plain string.
  final String billingUnit;
  final List<PublishedRentalRateStepRef> rateSteps;
  final bool hasDeposit;
  final int? depositAmountMinor;
  final String damagePolicy;
  final String? lateReturnPolicy;
  final String cancellationPolicyId;
  final String? cancellationPolicyNote;

  final String? externalBookingUrl;
  final DateTime publishedAtUtc;

  /// A listing with no `available` group has nothing to rent — the
  /// results card/Details CTA collapse to "Currently unavailable" (§17.3,
  /// §17.5), not a broken empty page.
  bool get hasActiveInventory =>
      inventoryGroups.any((PublishedRentalInventoryGroupRef g) => g.isAvailable);

  bool get isCoherent =>
      rentalId.isNotEmpty && publisherId.isNotEmpty && title.isNotEmpty;
}

class PublishedRentalInventoryGroupRef {
  const PublishedRentalInventoryGroupRef({
    required this.id,
    required this.label,
    required this.quantity,
    required this.condition,
    this.sizeOrVariant,
    this.includedAccessories = const <String>[],
    required this.status,
  });

  final String id;
  final String label;
  final int quantity;

  /// `rentalNew` / `likeNew` / `good` / `worn` — wire-safe name of
  /// Create's `RentalCondition`.
  final String condition;
  final String? sizeOrVariant;
  final List<String> includedAccessories;

  /// `available` / `paused` / `retired` — wire-safe name of Create's
  /// `RentalUnitGroupStatus`.
  final String status;

  bool get isAvailable => status == 'available';
}

class PublishedRentalRateStepRef {
  const PublishedRentalRateStepRef({
    required this.minUnits,
    required this.unitPriceMinor,
  });

  final int minUnits;
  final int unitPriceMinor;
}
