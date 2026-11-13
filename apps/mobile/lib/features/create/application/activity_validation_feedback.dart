// L4: values are ARB message ids (`validation*`); the UI resolves them.
import '../domain/entities/content_validation_violation.dart';

const _known = <String, (String, String)>{
  "activity.title_length": ("/body/title", 'validationUse580Characters'),
  "activity.short_description_length": (
    "/body/shortDescription",
    'validationUse20180Characters',
  ),
  "activity.full_description_length": (
    "/body/fullDescription",
    'validationUseAtMost1000Characters',
  ),
  "activity.category_required": (
    "/body/categoryId",
    'validationChooseACategory',
  ),
  "activity.subcategory_required": (
    "/body/subcategoryId",
    'validationChooseASubcategory',
  ),
  "activity.subcategory_not_applicable": (
    "/body/subcategoryId",
    'validationChooseASubcategoryAvailableForActivity',
  ),
  "activity.taxonomy_unavailable": (
    "/body/subcategoryId",
    'validationCategoryDataIsUnavailableTryAgainLater',
  ),
  "activity.criteria_registry_unavailable": (
    "/body/criteria",
    'validationCategoryRequirementsAreUnavailableTryAgainLater',
  ),
  "activity.criteria_invalid": (
    "/body/criteria",
    'validationCheckTheCategoryCriteria',
  ),
  "activity.cover_image_required": (
    "/body/media/coverImage",
    'validationAddACoverImage',
  ),
  "activity.gallery_invalid": (
    "/body/media/gallery",
    'validationCheckTheGalleryImages',
  ),
  "activity.gallery_too_large": (
    "/body/media/gallery",
    'validationUseAtMost12GalleryImages',
  ),
  "activity.media_duplicate": (
    "/body/media",
    'validationRemoveDuplicateImages',
  ),
  "activity.location_required": ("/body/location", 'validationSetTheLocation'),
  "activity.location_coordinates_required": (
    "/body/location",
    'validationSetValidCoordinates',
  ),
  "activity.pin_confirmation_required": (
    "/body/location/pinConfirmed",
    'validationConfirmTheMapPin',
  ),
  "activity.address_line_length": (
    "/body/location/addressLine",
    'validationUseAtMost300Characters',
  ),
  "activity.access_notes_required": (
    "/body/location/accessNotes",
    'validationDescribeHowToGetThere',
  ),
  "activity.access_notes_length": (
    "/body/location/accessNotes",
    'validationUse10300Characters',
  ),
  "activity.linked_place_invalid": (
    "/body/location/linkedPlaceId",
    'validationCheckTheLinkedPlace',
  ),
  "activity.linked_place_unknown": (
    "/body/location/linkedPlaceId",
    'validationTheLinkedPlaceWasNotFoundRemove',
  ),
  "activity.linked_place_forbidden": (
    "/body/location/linkedPlaceId",
    'validationTheLinkedPlaceIsNoLongerPublic',
  ),
  "activity.linked_place_unresolved": (
    "/body/location/linkedPlaceId",
    'validationLinkedPlaceIsUnavailableForPublication',
  ),
  "activity.access_caution_invalid": (
    "/body/location/accessCaution",
    'validationCheckTheAccessCaution',
  ),
  "activity.access_caution_note_required": (
    "/body/location/accessCaution/note",
    'validationDescribeTheInformalAccess',
  ),
  "activity.access_caution_note_length": (
    "/body/location/accessCaution/note",
    'validationUseAtMost200Characters',
  ),
  "activity.contribution_invalid": (
    "/body/optionalContribution",
    'validationCheckTheContribution',
  ),
  "activity.contribution_kind": (
    "/body/optionalContribution/kind",
    'validationChooseAContributionKind',
  ),
  "activity.contribution_note_required": (
    "/body/optionalContribution/note",
    'validationDescribeTheOptionalContribution',
  ),
  "activity.contribution_note_length": (
    "/body/optionalContribution/note",
    'validationUse10140Characters',
  ),
  "activity.contribution_inconsistent": (
    "/body/optionalContribution/kind",
    'validationChooseAKindForThisContribution',
  ),
  "activity.contribution_amount_invalid": (
    "/body/optionalContribution/amountHint",
    'validationCheckTheAmount',
  ),
  "activity.contribution_amount_not_positive": (
    "/body/optionalContribution/amountHint/amountMinor",
    'validationUseAPositiveAmount',
  ),
  "activity.contribution_currency_unsupported": (
    "/body/optionalContribution/amountHint/currencyCode",
    'validationUseTheMarketCurrency',
  ),
  "activity.duration_required": (
    "/body/typicalDurationMinutes",
    'validationSetTheTypicalDuration',
  ),
  "activity.duration_invalid": (
    "/body/typicalDurationMinutes",
    'validationCheckTheDurationRange',
  ),
  "activity.duration_not_positive": (
    "/body/typicalDurationMinutes",
    'validationUsePositiveWholeMinutes',
  ),
  "activity.duration_range_invalid": (
    "/body/typicalDurationMinutes",
    'validationMinimumMustNotExceedMaximum',
  ),
  "activity.group_size_invalid": (
    "/body/suggestedGroupSize",
    'validationCheckTheGroupSize',
  ),
  "activity.group_size_not_positive": (
    "/body/suggestedGroupSize",
    'validationUsePositiveWholeNumbers',
  ),
  "activity.group_size_range_invalid": (
    "/body/suggestedGroupSize",
    'validationMinimumMustNotExceedMaximum',
  ),
  "activity.best_time_invalid": (
    "/body/bestTime",
    'validationCheckTheBestTime',
  ),
  "activity.best_time_of_day": (
    "/body/bestTime/timeOfDay",
    'validationChooseATimeOfDay',
  ),
  "activity.best_season": ("/body/bestTime/season", 'validationChooseASeason'),
};

Map<String, String> activityFieldFeedback(
  List<ContentValidationViolation> violations,
) {
  final result = <String, String>{};
  for (final item in violations) {
    final known = _known[item.code];
    if (known != null && known.$1 == item.fieldPath) {
      result[item.fieldPath] = known.$2;
    }
    if (item.code == 'activity.criterion_required' &&
        const [
          '/body/criteria/difficulty',
          '/body/criteria/equipment_provided',
          '/body/criteria/swimming_required',
        ].contains(item.fieldPath)) {
      result[item.fieldPath] = 'validationCompleteThisCategoryCriterion';
    }
  }
  return Map.unmodifiable(result);
}
