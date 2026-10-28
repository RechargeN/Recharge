import '../../../../core/localization/l10n_context.dart';
import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/event_admission.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/event_inventory.dart';
import '../../domain/entities/place_draft_data.dart';
import '../../domain/entities/rental_draft_data.dart';

/// L4: Create config message ids (step titles and descriptions) → text.
/// Config files keep ids, never sentences; an unknown id shows nothing
/// readable rather than the id itself.
String createFormText(AppLocalizations l10n, String id) => switch (id) {
  'createStepPlaceIdentityTitle' => l10n.createStepPlaceIdentityTitle,
  'createStepPlaceIdentityDescription' =>
    l10n.createStepPlaceIdentityDescription,
  'createStepPlaceVisitTitle' => l10n.createStepPlaceVisitTitle,
  'createStepPlaceVisitDescription' => l10n.createStepPlaceVisitDescription,
  'createStepPlacePublishTitle' => l10n.createStepPlacePublishTitle,
  'createStepPlacePublishDescription' => l10n.createStepPlacePublishDescription,
  'createStepEventBasicsMediaTitle' => l10n.createStepEventBasicsMediaTitle,
  'createStepEventBasicsMediaDescription' =>
    l10n.createStepEventBasicsMediaDescription,
  'createStepEventLocationScheduleTitle' =>
    l10n.createStepEventLocationScheduleTitle,
  'createStepEventLocationScheduleDescription' =>
    l10n.createStepEventLocationScheduleDescription,
  'createStepEventRequirementsTitle' => l10n.createStepEventRequirementsTitle,
  'createStepEventRequirementsDescription' =>
    l10n.createStepEventRequirementsDescription,
  'createStepEventPriceParticipantsTitle' =>
    l10n.createStepEventPriceParticipantsTitle,
  'createStepEventPriceParticipantsDescription' =>
    l10n.createStepEventPriceParticipantsDescription,
  'createStepEventPreviewPublishTitle' =>
    l10n.createStepEventPreviewPublishTitle,
  'createStepEventPreviewPublishDescription' =>
    l10n.createStepEventPreviewPublishDescription,
  'createStepActivityBasicsTitle' => l10n.createStepActivityBasicsTitle,
  'createStepActivityBasicsDescription' =>
    l10n.createStepActivityBasicsDescription,
  'createStepActivityLocationTitle' => l10n.createStepActivityLocationTitle,
  'createStepActivityLocationDescription' =>
    l10n.createStepActivityLocationDescription,
  'createStepActivityWhenForTitle' => l10n.createStepActivityWhenForTitle,
  'createStepActivityWhenForDescription' =>
    l10n.createStepActivityWhenForDescription,
  'createStepActivityPublishTitle' => l10n.createStepActivityPublishTitle,
  'createStepActivityPublishDescription' =>
    l10n.createStepActivityPublishDescription,
  'createStepCollectionBasicsTitle' => l10n.createStepCollectionBasicsTitle,
  'createStepCollectionBasicsDescription' =>
    l10n.createStepCollectionBasicsDescription,
  'createStepCollectionItemsTitle' => l10n.createStepCollectionItemsTitle,
  'createStepCollectionItemsDescription' =>
    l10n.createStepCollectionItemsDescription,
  'createStepCollectionCuratorNotesTitle' =>
    l10n.createStepCollectionCuratorNotesTitle,
  'createStepCollectionCuratorNotesDescription' =>
    l10n.createStepCollectionCuratorNotesDescription,
  'createStepCollectionBudgetTitle' => l10n.createStepCollectionBudgetTitle,
  'createStepCollectionBudgetDescription' =>
    l10n.createStepCollectionBudgetDescription,
  'createStepCollectionPublishTitle' => l10n.createStepCollectionPublishTitle,
  'createStepCollectionPublishDescription' =>
    l10n.createStepCollectionPublishDescription,
  'createStepRentalListingTitle' => l10n.createStepRentalListingTitle,
  'createStepRentalListingDescription' =>
    l10n.createStepRentalListingDescription,
  'createStepRentalInventoryTitle' => l10n.createStepRentalInventoryTitle,
  'createStepRentalInventoryDescription' =>
    l10n.createStepRentalInventoryDescription,
  'createStepRentalAvailabilityTitle' => l10n.createStepRentalAvailabilityTitle,
  'createStepRentalAvailabilityDescription' =>
    l10n.createStepRentalAvailabilityDescription,
  'createStepRentalHandoverTitle' => l10n.createStepRentalHandoverTitle,
  'createStepRentalHandoverDescription' =>
    l10n.createStepRentalHandoverDescription,
  'createStepRentalTermsTitle' => l10n.createStepRentalTermsTitle,
  'createStepRentalTermsDescription' => l10n.createStepRentalTermsDescription,
  'createStepRentalPricingTitle' => l10n.createStepRentalPricingTitle,
  'createStepRentalPricingDescription' =>
    l10n.createStepRentalPricingDescription,
  'createStepRentalFulfillmentTitle' => l10n.createStepRentalFulfillmentTitle,
  'createStepRentalFulfillmentDescription' =>
    l10n.createStepRentalFulfillmentDescription,
  'createStepRentalReviewTitle' => l10n.createStepRentalReviewTitle,
  'createStepRentalReviewDescription' => l10n.createStepRentalReviewDescription,
  _ => '',
};

/// A Create form option label for a stable enum [value] (L4). The value's
/// type picks the family; the text never shows the raw enum name.
String createOptionText(AppLocalizations l10n, Enum value) {
  final String type = switch (value) {
    EventCapacityMode() => 'EventCapacityMode',
    EventFormat() => 'EventFormat',
    EventOnlineAccessMode() => 'EventOnlineAccessMode',
    EventPaymentCollectionMode() => 'EventPaymentCollectionMode',
    EventPricingMode() => 'EventPricingMode',
    EventRecurrenceEndMode() => 'EventRecurrenceEndMode',
    EventRecurrenceFrequency() => 'EventRecurrenceFrequency',
    EventRegistrationMode() => 'EventRegistrationMode',
    EventScheduleMode() => 'EventScheduleMode',
    EventVisibility() => 'EventVisibility',
    EventAdmissionPreset() => 'EventAdmissionPreset',
    AdmissionMode() => 'AdmissionMode',
    ConfirmationMode() => 'ConfirmationMode',
    WaitlistPromotionMode() => 'WaitlistPromotionMode',
    GuestPolicyMode() => 'GuestPolicyMode',
    EligibilityRuleKind() => 'EligibilityRuleKind',
    EventAccessWindowKind() => 'EventAccessWindowKind',
    InventoryShape() => 'InventoryShape',
    InventoryChannel() => 'InventoryChannel',
    InventoryAuthority() => 'InventoryAuthority',
    ActivityContributionKind() => 'ActivityContributionKind',
    ActivitySeason() => 'ActivitySeason',
    ActivityTimeOfDay() => 'ActivityTimeOfDay',
    PlaceOperationalStatus() => 'PlaceOperationalStatus',
    RentalLocationDisclosure() => 'RentalLocationDisclosure',
    RentalScheduleMode() => 'RentalScheduleMode',
    RentalBillingUnit() => 'RentalBillingUnit',
    RentalCondition() => 'RentalCondition',
    RentalDepositCollectionMethod() => 'RentalDepositCollectionMethod',
    VisibilityType() => 'VisibilityType',
    PublishStatus() => 'PublishStatus',
    _ => 'unknown',
  };
  return l10n.createOption('${type}_${value.name}');
}
