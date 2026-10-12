import '../domain/entities/content_validation_violation.dart';

const _known = <String, (String, String)>{
  "activity.title_length": ("/body/title", "Use 5–80 characters."),
  "activity.short_description_length": (
    "/body/shortDescription",
    "Use 20–180 characters.",
  ),
  "activity.full_description_length": (
    "/body/fullDescription",
    "Use at most 1000 characters.",
  ),
  "activity.category_required": ("/body/categoryId", "Choose a category."),
  "activity.subcategory_required": (
    "/body/subcategoryId",
    "Choose a subcategory.",
  ),
  "activity.subcategory_not_applicable": (
    "/body/subcategoryId",
    "Choose a subcategory available for Activity.",
  ),
  "activity.taxonomy_unavailable": (
    "/body/subcategoryId",
    "Category data is unavailable. Try again later.",
  ),
  "activity.criteria_registry_unavailable": (
    "/body/criteria",
    "Category requirements are unavailable. Try again later.",
  ),
  "activity.criteria_invalid": (
    "/body/criteria",
    "Check the category criteria.",
  ),
  "activity.cover_image_required": (
    "/body/media/coverImage",
    "Add a cover image.",
  ),
  "activity.gallery_invalid": (
    "/body/media/gallery",
    "Check the gallery images.",
  ),
  "activity.gallery_too_large": (
    "/body/media/gallery",
    "Use at most 12 gallery images.",
  ),
  "activity.media_duplicate": ("/body/media", "Remove duplicate images."),
  "activity.location_required": ("/body/location", "Set the location."),
  "activity.location_coordinates_required": (
    "/body/location",
    "Set valid coordinates.",
  ),
  "activity.pin_confirmation_required": (
    "/body/location/pinConfirmed",
    "Confirm the map pin.",
  ),
  "activity.address_line_length": (
    "/body/location/addressLine",
    "Use at most 300 characters.",
  ),
  "activity.access_notes_required": (
    "/body/location/accessNotes",
    "Describe how to get there.",
  ),
  "activity.access_notes_length": (
    "/body/location/accessNotes",
    "Use 10–300 characters.",
  ),
  "activity.linked_place_invalid": (
    "/body/location/linkedPlaceId",
    "Check the linked Place.",
  ),
  "activity.linked_place_unknown": ("/body/location/linkedPlaceId", "The linked Place was not found. Remove or replace it."),
  "activity.linked_place_forbidden": ("/body/location/linkedPlaceId", "The linked Place is no longer public. Remove or replace it."),
  "activity.linked_place_unresolved": (
    "/body/location/linkedPlaceId",
    "Linked Place is unavailable for publication.",
  ),
  "activity.access_caution_invalid": (
    "/body/location/accessCaution",
    "Check the access caution.",
  ),
  "activity.access_caution_note_required": (
    "/body/location/accessCaution/note",
    "Describe the informal access.",
  ),
  "activity.access_caution_note_length": (
    "/body/location/accessCaution/note",
    "Use at most 200 characters.",
  ),
  "activity.contribution_invalid": (
    "/body/optionalContribution",
    "Check the contribution.",
  ),
  "activity.contribution_kind": (
    "/body/optionalContribution/kind",
    "Choose a contribution kind.",
  ),
  "activity.contribution_note_required": (
    "/body/optionalContribution/note",
    "Describe the optional contribution.",
  ),
  "activity.contribution_note_length": (
    "/body/optionalContribution/note",
    "Use 10–140 characters.",
  ),
  "activity.contribution_inconsistent": (
    "/body/optionalContribution/kind",
    "Choose a kind for this contribution.",
  ),
  "activity.contribution_amount_invalid": (
    "/body/optionalContribution/amountHint",
    "Check the amount.",
  ),
  "activity.contribution_amount_not_positive": (
    "/body/optionalContribution/amountHint/amountMinor",
    "Use a positive amount.",
  ),
  "activity.contribution_currency_unsupported": (
    "/body/optionalContribution/amountHint/currencyCode",
    "Use the market currency.",
  ),
  "activity.duration_required": (
    "/body/typicalDurationMinutes",
    "Set the typical duration.",
  ),
  "activity.duration_invalid": (
    "/body/typicalDurationMinutes",
    "Check the duration range.",
  ),
  "activity.duration_not_positive": (
    "/body/typicalDurationMinutes",
    "Use positive whole minutes.",
  ),
  "activity.duration_range_invalid": (
    "/body/typicalDurationMinutes",
    "Minimum must not exceed maximum.",
  ),
  "activity.group_size_invalid": (
    "/body/suggestedGroupSize",
    "Check the group size.",
  ),
  "activity.group_size_not_positive": (
    "/body/suggestedGroupSize",
    "Use positive whole numbers.",
  ),
  "activity.group_size_range_invalid": (
    "/body/suggestedGroupSize",
    "Minimum must not exceed maximum.",
  ),
  "activity.best_time_invalid": ("/body/bestTime", "Check the best time."),
  "activity.best_time_of_day": (
    "/body/bestTime/timeOfDay",
    "Choose a time of day.",
  ),
  "activity.best_season": ("/body/bestTime/season", "Choose a season."),
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
      result[item.fieldPath] = 'Complete this category criterion.';
    }
  }
  return Map.unmodifiable(result);
}
