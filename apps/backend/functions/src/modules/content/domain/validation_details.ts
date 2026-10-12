import type { ContentValidationViolationV1 } from '../../../contracts/content_v1.js';

// Public allowlist: never send raw issue suffixes, supplied keys or values.
const activityFields: Readonly<Record<string, string>> = {
  'activity.title_length': '/body/title',
  'activity.short_description_length': '/body/shortDescription',
  'activity.full_description_length': '/body/fullDescription',
  'activity.category_required': '/body/categoryId',
  'activity.subcategory_required': '/body/subcategoryId',
  'activity.subcategory_not_applicable': '/body/subcategoryId',
  'activity.taxonomy_unavailable': '/body/subcategoryId',
  'activity.criteria_registry_unavailable': '/body/criteria',
  'activity.criteria_invalid': '/body/criteria',
  'activity.cover_image_required': '/body/media/coverImage',
  'activity.gallery_invalid': '/body/media/gallery',
  'activity.gallery_too_large': '/body/media/gallery',
  'activity.media_duplicate': '/body/media',
  'activity.location_required': '/body/location',
  'activity.location_coordinates_required': '/body/location',
  'activity.pin_confirmation_required': '/body/location/pinConfirmed',
  'activity.address_line_length': '/body/location/addressLine',
  'activity.access_notes_required': '/body/location/accessNotes',
  'activity.access_notes_length': '/body/location/accessNotes',
  'activity.linked_place_invalid': '/body/location/linkedPlaceId',
  'activity.linked_place_unresolved': '/body/location/linkedPlaceId',
  'activity.linked_place_unknown': '/body/location/linkedPlaceId',
  'activity.linked_place_forbidden': '/body/location/linkedPlaceId',
  'activity.access_caution_invalid': '/body/location/accessCaution',
  'activity.access_caution_note_required': '/body/location/accessCaution/note',
  'activity.access_caution_note_length': '/body/location/accessCaution/note',
  'activity.contribution_invalid': '/body/optionalContribution',
  'activity.contribution_kind': '/body/optionalContribution/kind',
  'activity.contribution_note_required': '/body/optionalContribution/note',
  'activity.contribution_note_length': '/body/optionalContribution/note',
  'activity.contribution_inconsistent': '/body/optionalContribution/kind',
  'activity.contribution_amount_invalid': '/body/optionalContribution/amountHint',
  'activity.contribution_amount_not_positive': '/body/optionalContribution/amountHint/amountMinor',
  'activity.contribution_currency_unsupported':
    '/body/optionalContribution/amountHint/currencyCode',
  'activity.duration_required': '/body/typicalDurationMinutes',
  'activity.duration_invalid': '/body/typicalDurationMinutes',
  'activity.duration_not_positive': '/body/typicalDurationMinutes',
  'activity.duration_range_invalid': '/body/typicalDurationMinutes',
  'activity.group_size_invalid': '/body/suggestedGroupSize',
  'activity.group_size_not_positive': '/body/suggestedGroupSize',
  'activity.group_size_range_invalid': '/body/suggestedGroupSize',
  'activity.best_time_invalid': '/body/bestTime',
  'activity.best_time_of_day': '/body/bestTime/timeOfDay',
  'activity.best_season': '/body/bestTime/season',
};
const publicCriteria = new Set(['difficulty', 'equipment_provided', 'swimming_required']);

export function publicValidationDetails(
  issues: readonly string[],
): readonly ContentValidationViolationV1[] {
  const details = new Map<string, ContentValidationViolationV1>();
  for (const issue of issues) {
    let code = issue;
    let fieldPath = Object.hasOwn(activityFields, issue) ? activityFields[issue] : undefined;
    if (issue.startsWith('activity.criterion_required:')) {
      const field = issue.slice('activity.criterion_required:'.length);
      if (publicCriteria.has(field)) {
        code = 'activity.criterion_required';
        fieldPath = `/body/criteria/${field}`;
      }
    }
    if (fieldPath !== undefined && details.size < 50)
      details.set(`${code}:${fieldPath}`, { code, fieldPath });
  }
  return Object.freeze([...details.values()].map((item) => Object.freeze(item)));
}
