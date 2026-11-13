export '../domain/entities/rental_create_policy.dart';

class RentalCreateStepConfig {
  const RentalCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

/// Spec §13 — 8 content steps; preflight (auth/eligibility/template offer)
/// happens before this list and is not itself a step.
const List<RentalCreateStepConfig> rentalCreateSteps = <RentalCreateStepConfig>[
  RentalCreateStepConfig(
    id: 'listing',
    titleId: 'createStepRentalListingTitle',
    descriptionId: 'createStepRentalListingDescription',
  ),
  RentalCreateStepConfig(
    id: 'inventory',
    titleId: 'createStepRentalInventoryTitle',
    descriptionId: 'createStepRentalInventoryDescription',
  ),
  RentalCreateStepConfig(
    id: 'availability',
    titleId: 'createStepRentalAvailabilityTitle',
    descriptionId: 'createStepRentalAvailabilityDescription',
  ),
  RentalCreateStepConfig(
    id: 'handover',
    titleId: 'createStepRentalHandoverTitle',
    descriptionId: 'createStepRentalHandoverDescription',
  ),
  RentalCreateStepConfig(
    id: 'terms',
    titleId: 'createStepRentalTermsTitle',
    descriptionId: 'createStepRentalTermsDescription',
  ),
  RentalCreateStepConfig(
    id: 'pricing',
    titleId: 'createStepRentalPricingTitle',
    descriptionId: 'createStepRentalPricingDescription',
  ),
  RentalCreateStepConfig(
    id: 'fulfillment',
    titleId: 'createStepRentalFulfillmentTitle',
    descriptionId: 'createStepRentalFulfillmentDescription',
  ),
  RentalCreateStepConfig(
    id: 'review',
    titleId: 'createStepRentalReviewTitle',
    descriptionId: 'createStepRentalReviewDescription',
  ),
];

/// Adaptive per-category hint — a pre-filled *suggestion*, never an
/// automatic publish decision (spec §5, §7 category table).
class RentalAdaptiveHint {
  const RentalAdaptiveHint({
    required this.categoryId,
    this.suggestedMinRenterAge,
    this.suggestIdRequired = false,
    this.safetyNoticeTemplate,
    this.suggestedAccessories = const <String>[],
    this.suggestLongTerm = false,
  });

  final String categoryId;
  final int? suggestedMinRenterAge;
  final bool suggestIdRequired;
  final String? safetyNoticeTemplate;
  final List<String> suggestedAccessories;
  final bool suggestLongTerm;
}

const List<RentalAdaptiveHint> rentalAdaptiveHints = <RentalAdaptiveHint>[
  RentalAdaptiveHint(
    categoryId: 'sport',
    suggestedAccessories: <String>['helmet', 'lock', 'pump'],
  ),
  RentalAdaptiveHint(
    categoryId: 'water_activities',
    safetyNoticeTemplate:
        'A life jacket is included and required on the water.',
    suggestedAccessories: <String>['life jacket'],
  ),
  RentalAdaptiveHint(
    categoryId: 'winter_seasonal',
    suggestedAccessories: <String>['poles', 'helmet'],
  ),
  RentalAdaptiveHint(
    categoryId: 'adrenaline_entertainment',
    suggestedMinRenterAge: 18,
    safetyNoticeTemplate:
        'Follow all on-site safety briefing and gear requirements.', // l10n-ignore: prefill the owner edits
  ),
  RentalAdaptiveHint(
    categoryId: 'auto_moto',
    suggestedMinRenterAge: 21,
    suggestIdRequired: true,
    suggestLongTerm: true,
  ),
];

RentalAdaptiveHint? rentalAdaptiveHintFor(String categoryId) {
  for (final RentalAdaptiveHint hint in rentalAdaptiveHints) {
    if (hint.categoryId == categoryId) return hint;
  }
  return null;
}
