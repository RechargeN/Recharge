import '../entities/rental_draft_data.dart';
import '../entities/rental_listing.dart';

/// Builds the public `RentalListing` projection from an authoring
/// `RentalDraftData` (spec §17.1). This is the concrete, directly-testable
/// enforcement point for AC 12: `RentalListing` has no field capable of
/// holding exact private address/geo/instructions/notes, and this function
/// never reads `RentalPrivateAuthoringData` — private data cannot leak
/// here even by mistake, only by adding a new field to `RentalListing`
/// itself (which a reviewer would catch).
class BuildRentalPublicProjectionUseCase {
  const BuildRentalPublicProjectionUseCase();

  RentalListing call({required String id, required RentalDraftData draft}) {
    final RentalHandoverDraft handover = draft.handover;
    final bool showBusinessAddress =
        handover.disclosure == RentalLocationDisclosure.publicBusinessAddress;
    return RentalListing(
      id: id,
      publisherRef: draft.publisherRef,
      title: draft.title,
      shortDescription: draft.shortDescription,
      fullDescription: draft.fullDescription,
      categoryId: draft.categoryId,
      subcategoryId: draft.subcategoryId,
      brandModel: draft.brandModel,
      mediaRefs: List<String>.unmodifiable(draft.mediaRefs),
      inventoryGroups: List<RentalInventoryGroup>.unmodifiable(
        draft.inventoryGroups,
      ),
      totalUnitsAggregate: draft.totalUnitsAggregate,
      publicAreaLabel: handover.publicAreaLabel,
      publicAddress: showBusinessAddress ? handover.publicAddress : null,
      publicLatitude: handover.publicLatitude,
      publicLongitude: handover.publicLongitude,
      publicGeoPrecisionMeters: handover.publicGeoPrecisionMeters,
      deliveryAvailable: handover.deliveryAvailable,
      deliveryRadiusKm: handover.deliveryRadiusKm,
      deliveryFeeMinor: handover.deliveryFee?.amountMinor,
      deliveryTerms: handover.deliveryTerms,
      offeredMinMinutes: draft.terms.offeredMinMinutes,
      offeredMaxMinutes: draft.terms.offeredMaxMinutes,
      minRenterAge: draft.terms.minRenterAge,
      idRequiredAtHandover: draft.terms.idRequiredAtHandover,
      usageRestrictions: draft.terms.usageRestrictions,
      safetyNotice: draft.terms.safetyNotice,
      currencyCode: draft.pricing.currencyCode,
      billingUnit: draft.pricing.billingUnit,
      rateSteps: List<RentalRateStep>.unmodifiable(draft.pricing.rateSteps),
      hasDeposit: !draft.pricing.deposit.isZero,
      depositAmountMinor: draft.pricing.deposit.amount.amountMinor,
      damagePolicy: draft.pricing.damagePolicy,
      lateReturnPolicy: draft.pricing.lateReturnPolicy,
      cancellationPolicyId: draft.pricing.cancellationPolicyId,
      cancellationPolicyNote: draft.pricing.cancellationPolicyNote,
      externalBookingUrl: draft.fulfillment.externalBookingUrl,
    );
  }
}
