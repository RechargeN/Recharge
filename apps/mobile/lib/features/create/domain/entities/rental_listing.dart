import 'rental_draft_data.dart';

/// The public projection of a published Rental listing (spec §17.1).
///
/// Deliberately a *smaller*, distinct shape from `RentalDraftData` — it
/// contains only fields approved for public display. There is no field on
/// this class capable of holding exact private address/geo, handover
/// instructions or authoring notes; that is what makes the AC-12 guarantee
/// checkable by construction, not just by convention. Built only via
/// `BuildRentalPublicProjectionUseCase`.
class RentalListing {
  const RentalListing({
    required this.id,
    required this.publisherRef,
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
  });

  final String id;
  final PublisherRef publisherRef;

  final String title;
  final String shortDescription;
  final String fullDescription;
  final String categoryId;
  final String subcategoryId;
  final String? brandModel;
  final List<String> mediaRefs;

  final List<RentalInventoryGroup> inventoryGroups;
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
  final RentalBillingUnit billingUnit;
  final List<RentalRateStep> rateSteps;
  final bool hasDeposit;
  final int? depositAmountMinor;
  final String damagePolicy;
  final String? lateReturnPolicy;
  final String cancellationPolicyId;
  final String? cancellationPolicyNote;

  final String? externalBookingUrl;
}
