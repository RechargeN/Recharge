import '../entities/activity_draft_data.dart';
import '../entities/activity_validation_issue.dart';
import '../entities/create_draft_entity.dart';

class ValidateActivityDraftUseCase {
  const ValidateActivityDraftUseCase();

  List<ActivityValidationIssue> call(CreateDraftEntity draft) {
    if (draft.objectType != CreateObjectType.activity) {
      return const <ActivityValidationIssue>[];
    }
    final ActivityDraftData? activity = draft.activityData;
    if (activity == null) {
      return const <ActivityValidationIssue>[
        ActivityValidationIssue(
          code: 'details_missing',
          severity: ActivityValidationSeverity.error,
          sectionId: 'basics',
          messageKey: 'activity.validation.details_missing',
        ),
      ];
    }

    final List<ActivityValidationIssue> issues = <ActivityValidationIssue>[];
    void error(String code, String sectionId, [String? fieldId]) {
      issues.add(
        ActivityValidationIssue(
          code: code,
          severity: ActivityValidationSeverity.error,
          sectionId: sectionId,
          fieldId: fieldId,
          messageKey: 'activity.validation.$code',
        ),
      );
    }

    final ActivityLocationDraft location = activity.location;
    if (location.accessNotes.trim().isEmpty) {
      error('access_notes_required', 'location', 'accessNotes');
    }
    final ActivityAccessCautionDraft? caution = location.accessCaution;
    if (caution != null &&
        caution.isInformal &&
        (caution.note == null || caution.note!.trim().isEmpty)) {
      error('access_caution_note_required', 'location', 'accessCautionNote');
    }

    final ActivityOptionalContributionDraft? contribution =
        activity.optionalContribution;
    if (contribution != null) {
      final bool hasKind = contribution.kind != null;
      final bool hasNote =
          contribution.note != null && contribution.note!.trim().isNotEmpty;
      final bool hasAmount = contribution.amountHint != null;
      if (hasKind && !hasNote) {
        error('contribution_note_required', 'location', 'contributionNote');
      }
      if (hasAmount && !(hasKind && hasNote)) {
        error(
          'contribution_amount_needs_kind',
          'location',
          'contributionAmountHint',
        );
      }
    }

    if (activity.typicalDurationMinutes.min >
        activity.typicalDurationMinutes.max) {
      error('duration_range_invalid', 'whenFor', 'typicalDurationMinutes');
    }
    final ActivityIntRangeDraft? groupSize = activity.suggestedGroupSize;
    if (groupSize != null && groupSize.min > groupSize.max) {
      error('group_size_range_invalid', 'whenFor', 'suggestedGroupSize');
    }

    // MediaEntity.coverImage is a non-nullable String; empty string means
    // "no cover set" (see media_entity.dart / CreateDraftEntity.defaults()).
    if (draft.media.coverImage.isEmpty) {
      error('cover_image_required', 'basics', 'coverImage');
    }

    return issues;
  }
}
