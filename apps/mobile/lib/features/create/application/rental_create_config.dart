export '../domain/entities/rental_create_policy.dart';

class RentalCreateStepConfig {
  const RentalCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// Spec §13 — 8 content steps; preflight (auth/eligibility/template offer)
/// happens before this list and is not itself a step.
const List<RentalCreateStepConfig> rentalCreateSteps = <RentalCreateStepConfig>[
  RentalCreateStepConfig(
    id: 'listing',
    title: 'Listing and media',
    description: 'Title, category and cover for the item or fleet',
  ),
  RentalCreateStepConfig(
    id: 'inventory',
    title: 'Inventory',
    description: 'Groups of interchangeable units, condition and quantity',
  ),
  RentalCreateStepConfig(
    id: 'availability',
    title: 'Availability',
    description: 'Confirmed coverage window and manual occupancy blocks',
  ),
  RentalCreateStepConfig(
    id: 'handover',
    title: 'Handover and location',
    description: 'Pickup area, schedule and optional delivery',
  ),
  RentalCreateStepConfig(
    id: 'terms',
    title: 'Duration and safety',
    description: 'Offered duration range, age, ID and safety requirements',
  ),
  RentalCreateStepConfig(
    id: 'pricing',
    title: 'Pricing and deposit',
    description: 'Rate plan, deposit policy and damage/cancellation terms',
  ),
  RentalCreateStepConfig(
    id: 'fulfillment',
    title: 'External fulfillment and policies',
    description: 'External booking link and destination warning preview',
  ),
  RentalCreateStepConfig(
    id: 'review',
    title: 'Review and submit',
    description: 'Public/private preview, attestation and submission',
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
        'Follow all on-site safety briefing and gear requirements.',
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
