import '../../../../core/localization/l10n_context.dart';
import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/entities/scenario_logistics_draft.dart';
import '../../domain/entities/scenario_item_draft.dart';
import '../../domain/entities/scenario_draft_data.dart';
import '../../domain/entities/find_people_draft_data.dart';
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
  'createSessionPresetEveryday' => l10n.createSessionPresetEveryday,
  'createSessionPresetWeekdays' => l10n.createSessionPresetWeekdays,
  'createStepClassWorkshopBasicsDescription' =>
    l10n.createStepClassWorkshopBasicsDescription,
  'createStepClassWorkshopBasicsTitle' =>
    l10n.createStepClassWorkshopBasicsTitle,
  'createStepClassWorkshopLearningDescription' =>
    l10n.createStepClassWorkshopLearningDescription,
  'createStepClassWorkshopLearningTitle' =>
    l10n.createStepClassWorkshopLearningTitle,
  'createStepClassWorkshopParticipationDescription' =>
    l10n.createStepClassWorkshopParticipationDescription,
  'createStepClassWorkshopParticipationTitle' =>
    l10n.createStepClassWorkshopParticipationTitle,
  'createStepClassWorkshopScheduleDescription' =>
    l10n.createStepClassWorkshopScheduleDescription,
  'createStepClassWorkshopScheduleTitle' =>
    l10n.createStepClassWorkshopScheduleTitle,
  'createStepFindPeopleActivityDescription' =>
    l10n.createStepFindPeopleActivityDescription,
  'createStepFindPeopleActivityTitle' => l10n.createStepFindPeopleActivityTitle,
  'createStepFindPeopleGroupDescription' =>
    l10n.createStepFindPeopleGroupDescription,
  'createStepFindPeopleGroupTitle' => l10n.createStepFindPeopleGroupTitle,
  'createStepFindPeopleHostsDescription' =>
    l10n.createStepFindPeopleHostsDescription,
  'createStepFindPeopleHostsTitle' => l10n.createStepFindPeopleHostsTitle,
  'createStepFindPeopleMeetingDescription' =>
    l10n.createStepFindPeopleMeetingDescription,
  'createStepFindPeopleMeetingTitle' => l10n.createStepFindPeopleMeetingTitle,
  'createStepFindPeoplePublishDescription' =>
    l10n.createStepFindPeoplePublishDescription,
  'createStepFindPeoplePublishTitle' => l10n.createStepFindPeoplePublishTitle,
  'createStepFindPeopleScheduleDescription' =>
    l10n.createStepFindPeopleScheduleDescription,
  'createStepFindPeopleScheduleTitle' => l10n.createStepFindPeopleScheduleTitle,
  'createStepRouteDetailsDescription' => l10n.createStepRouteDetailsDescription,
  'createStepRouteDetailsTitle' => l10n.createStepRouteDetailsTitle,
  'createStepRouteEditorDescription' => l10n.createStepRouteEditorDescription,
  'createStepRouteEditorTitle' => l10n.createStepRouteEditorTitle,
  'createStepRouteMethodDescription' => l10n.createStepRouteMethodDescription,
  'createStepRouteMethodTitle' => l10n.createStepRouteMethodTitle,
  'createStepRouteProfileDescription' => l10n.createStepRouteProfileDescription,
  'createStepRouteProfileTitle' => l10n.createStepRouteProfileTitle,
  'createStepRouteReviewDescription' => l10n.createStepRouteReviewDescription,
  'createStepRouteReviewTitle' => l10n.createStepRouteReviewTitle,
  'createStepScenarioComposerDescription' =>
    l10n.createStepScenarioComposerDescription,
  'createStepScenarioComposerTitle' => l10n.createStepScenarioComposerTitle,
  'createStepScenarioContextDescription' =>
    l10n.createStepScenarioContextDescription,
  'createStepScenarioContextTitle' => l10n.createStepScenarioContextTitle,
  'createStepScenarioReviewDescription' =>
    l10n.createStepScenarioReviewDescription,
  'createStepScenarioReviewTitle' => l10n.createStepScenarioReviewTitle,
  'createStepSessionPriceAndBookingDescription' =>
    l10n.createStepSessionPriceAndBookingDescription,
  'createStepSessionPriceAndBookingTitle' =>
    l10n.createStepSessionPriceAndBookingTitle,
  'createStepSessionWhatWhereDescription' =>
    l10n.createStepSessionWhatWhereDescription,
  'createStepSessionWhatWhereTitle' => l10n.createStepSessionWhatWhereTitle,
  'createStepSessionWhenDescription' => l10n.createStepSessionWhenDescription,
  'createStepSessionWhenTitle' => l10n.createStepSessionWhenTitle,
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
    FindPeopleApprovalMode() => 'FindPeopleApprovalMode',
    FindPeopleConversationPolicy() => 'FindPeopleConversationPolicy',
    FindPeopleCostType() => 'FindPeopleCostType',
    FindPeopleExpenseSplitMode() => 'FindPeopleExpenseSplitMode',
    FindPeopleMeetingMode() => 'FindPeopleMeetingMode',
    FindPeopleParticipationGoal() => 'FindPeopleParticipationGoal',
    FindPeoplePublisherType() => 'FindPeoplePublisherType',
    FindPeopleScheduleMode() => 'FindPeopleScheduleMode',
    FindPeopleSeatFitPolicy() => 'FindPeopleSeatFitPolicy',
    FindPeopleSkillLevel() => 'FindPeopleSkillLevel',
    FindPeopleVerificationLevel() => 'FindPeopleVerificationLevel',
    FindPeopleVisibility() => 'FindPeopleVisibility',
    FindPeopleWaitlistPolicy() => 'FindPeopleWaitlistPolicy',
    ScenarioBudgetBasis() => 'ScenarioBudgetBasis',
    ScenarioFormat() => 'ScenarioFormat',
    ScenarioPace() => 'ScenarioPace',
    ScenarioPartyKind() => 'ScenarioPartyKind',
    ScenarioDateMode() => 'ScenarioDateMode',
    ScenarioPlannedTransportKind() => 'ScenarioPlannedTransportKind',
    ScenarioItemKind() => 'ScenarioItemKind',
    ScenarioScheduleFreshness() => 'ScenarioScheduleFreshness',
    ScenarioTravelMode() => 'ScenarioTravelMode',
    RouteSegmentSource() => 'RouteSegmentSource',
    RouteSegmentOperationState() => 'RouteSegmentOperationState',
    _ => 'unknown',
  };
  return l10n.createOption('${type}_${value.name}');
}
