import '../entities/create_draft_entity.dart';
import '../entities/rental_create_policy.dart';
import '../entities/rental_draft_data.dart';
import '../entities/rental_validation_issue.dart';

/// Implements the §14 validation contract of
/// `docs/product/RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md`. Pure and
/// side-effect free; the same validator runs for preview, submit and
/// update — UI-side checks are only early feedback (mirrors
/// `ValidatePlaceDraftUseCase`).
class ValidateRentalDraftUseCase {
  const ValidateRentalDraftUseCase();

  List<RentalValidationIssue> call(
    CreateDraftEntity draft, {
    RentalCreatePolicy policy = RentalCreatePolicy.safeFallback,
  }) {
    if (draft.objectType != CreateObjectType.rental ||
        draft.rentalData == null) {
      return const <RentalValidationIssue>[];
    }
    final RentalDraftData rental = draft.rentalData!;
    final List<RentalValidationIssue> issues = <RentalValidationIssue>[];

    _validateListing(rental, policy, issues);
    _validateInventory(rental, policy, issues);
    _validateAvailability(rental, issues);
    _validateHandover(rental, issues);
    _validateTerms(rental, policy, issues);
    _validatePricing(rental, issues);
    _validateFulfillment(rental, issues);
    _validateAttestation(rental, issues);

    return issues;
  }

  void _validateListing(
    RentalDraftData rental,
    RentalCreatePolicy policy,
    List<RentalValidationIssue> issues,
  ) {
    if (rental.title.trim().length < 3 || rental.title.trim().length > 80) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_title_length',
          sectionId: 'rental_listing',
          fieldId: 'title',
          messageKey: 'rental.validation.title_length',
        ),
      );
    }
    final int shortLen = rental.shortDescription.trim().length;
    if (shortLen < 20 || shortLen > 240) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_short_description_length',
          sectionId: 'rental_listing',
          fieldId: 'shortDescription',
          messageKey: 'rental.validation.short_description_length',
        ),
      );
    }
    final int fullLen = rental.fullDescription.trim().length;
    if (fullLen < 50 || fullLen > 4000) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_full_description_length',
          sectionId: 'rental_listing',
          fieldId: 'fullDescription',
          messageKey: 'rental.validation.full_description_length',
        ),
      );
    }
    if (!policy.categoryWhitelist.contains(rental.categoryId)) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_category_not_whitelisted',
          sectionId: 'rental_listing',
          fieldId: 'categoryId',
          messageKey: 'rental.validation.category_not_whitelisted',
        ),
      );
    }
    if (!rental.categoryConfirmed) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_category_not_confirmed',
          severity: RentalValidationSeverity.warning,
          sectionId: 'rental_listing',
          fieldId: 'categoryConfirmed',
          messageKey: 'rental.validation.category_not_confirmed',
        ),
      );
    }
  }

  void _validateInventory(
    RentalDraftData rental,
    RentalCreatePolicy policy,
    List<RentalValidationIssue> issues,
  ) {
    if (rental.inventoryGroups.isEmpty || rental.inventoryGroups.length > 50) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_inventory_group_count',
          sectionId: 'rental_inventory',
          messageKey: 'rental.validation.inventory_group_count',
        ),
      );
    }
    final bool hasAvailableGroup = rental.inventoryGroups.any(
      (RentalInventoryGroup g) => g.status == RentalUnitGroupStatus.available,
    );
    if (rental.inventoryGroups.isNotEmpty && !hasAvailableGroup) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_no_available_group',
          sectionId: 'rental_inventory',
          messageKey: 'rental.validation.no_available_group',
        ),
      );
    }
    final bool sizeRequired = policy.sizeVariantRequiredCategoryIds.contains(
      rental.categoryId,
    );
    for (final RentalInventoryGroup group in rental.inventoryGroups) {
      if (group.quantity < 1 || group.quantity > 999) {
        issues.add(
          RentalValidationIssue(
            code: 'rental_group_quantity_range',
            sectionId: 'rental_inventory',
            fieldId: 'quantity',
            messageKey: 'rental.validation.group_quantity_range',
            messageParams: <String, Object?>{'groupId': group.id},
          ),
        );
      }
      if (sizeRequired &&
          (group.sizeOrVariant == null ||
              group.sizeOrVariant!.trim().isEmpty)) {
        issues.add(
          RentalValidationIssue(
            code: 'rental_group_size_required',
            sectionId: 'rental_inventory',
            fieldId: 'sizeOrVariant',
            messageKey: 'rental.validation.group_size_required',
            messageParams: <String, Object?>{'groupId': group.id},
          ),
        );
      }
    }
  }

  void _validateAvailability(
    RentalDraftData rental,
    List<RentalValidationIssue> issues,
  ) {
    if (rental.availability.timeZoneId.trim().isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_availability_timezone_missing',
          sectionId: 'rental_availability',
          fieldId: 'timeZoneId',
          messageKey: 'rental.validation.availability_timezone_missing',
        ),
      );
    }
    if (rental.availability.coverage == null) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_availability_coverage_missing',
          sectionId: 'rental_availability',
          messageKey: 'rental.validation.availability_coverage_missing',
        ),
      );
    }
    final Set<String> groupIds = rental.inventoryGroups
        .map((RentalInventoryGroup g) => g.id)
        .toSet();
    for (final RentalAvailabilityBlock block in rental.availability.blocks) {
      if (!groupIds.contains(block.groupId)) {
        issues.add(
          RentalValidationIssue(
            code: 'rental_block_unknown_group',
            sectionId: 'rental_availability',
            messageKey: 'rental.validation.block_unknown_group',
            messageParams: <String, Object?>{'blockId': block.id},
          ),
        );
      }
      if (!block.startsAtUtc.isBefore(block.endsAtUtc)) {
        issues.add(
          RentalValidationIssue(
            code: 'rental_block_interval_invalid',
            sectionId: 'rental_availability',
            messageKey: 'rental.validation.block_interval_invalid',
            messageParams: <String, Object?>{'blockId': block.id},
          ),
        );
      }
    }
  }

  void _validateHandover(
    RentalDraftData rental,
    List<RentalValidationIssue> issues,
  ) {
    final RentalHandoverDraft handover = rental.handover;
    if (handover.pickupPlaceName.trim().isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_pickup_place_name_missing',
          sectionId: 'rental_handover',
          fieldId: 'pickupPlaceName',
          messageKey: 'rental.validation.pickup_place_name_missing',
        ),
      );
    }
    if (!handover.hasPublicGeo) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_public_geo_missing',
          sectionId: 'rental_handover',
          fieldId: 'publicGeo',
          messageKey: 'rental.validation.public_geo_missing',
        ),
      );
    }
    if (handover.disclosure == RentalLocationDisclosure.approximateArea &&
        handover.publicAddress != null &&
        handover.publicAddress!.trim().isNotEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_approximate_area_has_address',
          sectionId: 'rental_handover',
          fieldId: 'publicAddress',
          messageKey: 'rental.validation.approximate_area_has_address',
        ),
      );
    }
    if (handover.disclosure == RentalLocationDisclosure.publicBusinessAddress &&
        (handover.publicAddress == null ||
            handover.publicAddress!.trim().isEmpty)) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_business_address_missing',
          sectionId: 'rental_handover',
          fieldId: 'publicAddress',
          messageKey: 'rental.validation.business_address_missing',
        ),
      );
    }
    if (handover.scheduleMode == RentalScheduleMode.openingHours &&
        handover.openingHours.isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_opening_hours_missing',
          sectionId: 'rental_handover',
          fieldId: 'openingHours',
          messageKey: 'rental.validation.opening_hours_missing',
        ),
      );
    }
    if (handover.deliveryAvailable) {
      if (handover.deliveryRadiusKm == null ||
          handover.deliveryRadiusKm! <= 0) {
        issues.add(
          const RentalValidationIssue(
            code: 'rental_delivery_radius_missing',
            sectionId: 'rental_handover',
            fieldId: 'deliveryRadiusKm',
            messageKey: 'rental.validation.delivery_radius_missing',
          ),
        );
      }
      if (handover.deliveryFee == null) {
        issues.add(
          const RentalValidationIssue(
            code: 'rental_delivery_fee_missing',
            sectionId: 'rental_handover',
            fieldId: 'deliveryFee',
            messageKey: 'rental.validation.delivery_fee_missing',
          ),
        );
      }
    }
  }

  void _validateTerms(
    RentalDraftData rental,
    RentalCreatePolicy policy,
    List<RentalValidationIssue> issues,
  ) {
    final RentalTerms terms = rental.terms;
    final bool boundsOrdered =
        policy.absoluteMinMinutes <= terms.offeredMinMinutes &&
        terms.offeredMinMinutes <= terms.offeredMaxMinutes &&
        terms.offeredMaxMinutes <= policy.absoluteMaxMinutes;
    if (!boundsOrdered) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_duration_bounds_invalid',
          sectionId: 'rental_terms',
          messageKey: 'rental.validation.duration_bounds_invalid',
        ),
      );
    }
    if (rental.pricing.billingUnit.minutes > terms.offeredMinMinutes) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_billing_unit_exceeds_min_duration',
          sectionId: 'rental_terms',
          messageKey: 'rental.validation.billing_unit_exceeds_min_duration',
        ),
      );
    }
    if (policy.minRenterAgeRequiredCategoryIds.contains(rental.categoryId) &&
        terms.minRenterAge == null) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_min_renter_age_required',
          sectionId: 'rental_terms',
          fieldId: 'minRenterAge',
          messageKey: 'rental.validation.min_renter_age_required',
        ),
      );
    }
    if (policy.idRequiredCategoryIds.contains(rental.categoryId) &&
        !terms.idRequiredAtHandover) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_id_required_at_handover',
          severity: RentalValidationSeverity.warning,
          sectionId: 'rental_terms',
          fieldId: 'idRequiredAtHandover',
          messageKey: 'rental.validation.id_required_at_handover',
        ),
      );
    }
    if (policy.safetyNoticeRequiredCategoryIds.contains(rental.categoryId) &&
        (terms.safetyNotice == null || terms.safetyNotice!.trim().isEmpty)) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_safety_notice_required',
          sectionId: 'rental_terms',
          fieldId: 'safetyNotice',
          messageKey: 'rental.validation.safety_notice_required',
        ),
      );
    }
  }

  void _validatePricing(
    RentalDraftData rental,
    List<RentalValidationIssue> issues,
  ) {
    final RentalPricingPolicy pricing = rental.pricing;
    if (pricing.currencyCode.trim().length != 3) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_currency_invalid',
          sectionId: 'rental_pricing',
          fieldId: 'currencyCode',
          messageKey: 'rental.validation.currency_invalid',
        ),
      );
    }
    if (pricing.rateSteps.isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_rate_steps_missing',
          sectionId: 'rental_pricing',
          fieldId: 'rateSteps',
          messageKey: 'rental.validation.rate_steps_missing',
        ),
      );
    } else {
      if (pricing.rateSteps.first.minUnits != 1) {
        issues.add(
          const RentalValidationIssue(
            code: 'rental_rate_first_step_not_one',
            sectionId: 'rental_pricing',
            fieldId: 'rateSteps',
            messageKey: 'rental.validation.rate_first_step_not_one',
          ),
        );
      }
      for (int i = 1; i < pricing.rateSteps.length; i++) {
        final RentalRateStep prev = pricing.rateSteps[i - 1];
        final RentalRateStep curr = pricing.rateSteps[i];
        if (curr.minUnits <= prev.minUnits) {
          issues.add(
            const RentalValidationIssue(
              code: 'rental_rate_steps_not_increasing',
              sectionId: 'rental_pricing',
              fieldId: 'rateSteps',
              messageKey: 'rental.validation.rate_steps_not_increasing',
            ),
          );
        }
        if (curr.unitPrice.amountMinor > prev.unitPrice.amountMinor) {
          issues.add(
            const RentalValidationIssue(
              code: 'rental_rate_price_increases',
              sectionId: 'rental_pricing',
              fieldId: 'rateSteps',
              messageKey: 'rental.validation.rate_price_increases',
            ),
          );
        }
      }
      for (final RentalRateStep step in pricing.rateSteps) {
        if (step.unitPrice.currencyCode != pricing.currencyCode ||
            step.unitPrice.amountMinor < 0) {
          issues.add(
            const RentalValidationIssue(
              code: 'rental_rate_step_currency_or_sign',
              sectionId: 'rental_pricing',
              fieldId: 'rateSteps',
              messageKey: 'rental.validation.rate_step_currency_or_sign',
            ),
          );
        }
      }
    }

    final RentalDepositPolicy deposit = pricing.deposit;
    if (deposit.amount.currencyCode != pricing.currencyCode) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_deposit_currency_mismatch',
          sectionId: 'rental_pricing',
          fieldId: 'deposit',
          messageKey: 'rental.validation.deposit_currency_mismatch',
        ),
      );
    }
    if (deposit.isZero &&
        deposit.collectionMethod != RentalDepositCollectionMethod.none) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_deposit_zero_requires_none',
          sectionId: 'rental_pricing',
          fieldId: 'deposit',
          messageKey: 'rental.validation.deposit_zero_requires_none',
        ),
      );
    }
    if (!deposit.isZero) {
      if (deposit.collectionMethod == RentalDepositCollectionMethod.none) {
        issues.add(
          const RentalValidationIssue(
            code: 'rental_deposit_nonzero_requires_method',
            sectionId: 'rental_pricing',
            fieldId: 'deposit',
            messageKey: 'rental.validation.deposit_nonzero_requires_method',
          ),
        );
      }
      if (deposit.terms == null || deposit.terms!.trim().isEmpty) {
        issues.add(
          const RentalValidationIssue(
            code: 'rental_deposit_terms_missing',
            sectionId: 'rental_pricing',
            fieldId: 'deposit',
            messageKey: 'rental.validation.deposit_terms_missing',
          ),
        );
      }
    }
    if (pricing.damagePolicy.trim().isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_damage_policy_missing',
          sectionId: 'rental_pricing',
          fieldId: 'damagePolicy',
          messageKey: 'rental.validation.damage_policy_missing',
        ),
      );
    }
    if (pricing.cancellationPolicyId.trim().isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_cancellation_policy_missing',
          sectionId: 'rental_pricing',
          fieldId: 'cancellationPolicyId',
          messageKey: 'rental.validation.cancellation_policy_missing',
        ),
      );
    }
  }

  void _validateFulfillment(
    RentalDraftData rental,
    List<RentalValidationIssue> issues,
  ) {
    final String? url = rental.fulfillment.externalBookingUrl;
    if (url == null || url.trim().isEmpty) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_external_url_missing',
          sectionId: 'rental_fulfillment',
          fieldId: 'externalBookingUrl',
          messageKey: 'rental.validation.external_url_missing',
        ),
      );
      return;
    }
    final Uri? parsed = Uri.tryParse(url.trim());
    final bool isHttps =
        parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty;
    if (!isHttps) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_external_url_not_https',
          sectionId: 'rental_fulfillment',
          fieldId: 'externalBookingUrl',
          messageKey: 'rental.validation.external_url_not_https',
        ),
      );
    }
  }

  void _validateAttestation(
    RentalDraftData rental,
    List<RentalValidationIssue> issues,
  ) {
    if (!rental.attestation.isComplete) {
      issues.add(
        const RentalValidationIssue(
          code: 'rental_attestation_incomplete',
          sectionId: 'rental_attestation',
          messageKey: 'rental.validation.attestation_incomplete',
        ),
      );
    }
  }
}
