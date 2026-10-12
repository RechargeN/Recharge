import '../entities/activity_draft_data.dart';
import '../entities/activity_validation_issue.dart';
import '../entities/create_draft_entity.dart';

/// Single domain validator for Recharge Activity, used identically in
/// preview, Submit, Publish and Update (RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md
/// v1.4 §9.1/§9.2). Blocking issues use [ActivityValidationSeverity.error];
/// non-blocking recommendations use [ActivityValidationSeverity.warning].
class ValidateActivityDraftUseCase {
  const ValidateActivityDraftUseCase();

  List<ActivityValidationIssue> call(
    CreateDraftEntity draft, {
    String activeMarketCurrencyCode = 'EUR',
  }) {
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

    void warning(String code, String sectionId, [String? fieldId]) {
      issues.add(
        ActivityValidationIssue(
          code: code,
          severity: ActivityValidationSeverity.warning,
          sectionId: sectionId,
          fieldId: fieldId,
          messageKey: 'activity.validation.$code',
        ),
      );
    }

    // --- Step 1: About (§8 Step 1) ---
    final String title = draft.title.trim();
    if (title.length < 5 || title.length > 80) {
      error('title_length', 'basics', 'title');
    }
    final String shortDescription = draft.shortDescription.trim();
    if (shortDescription.length < 20 || shortDescription.length > 180) {
      error('short_description_length', 'basics', 'shortDescription');
    }
    final String fullDescription = draft.fullDescription.trim();
    if (fullDescription.length > 1000) {
      error('full_description_length', 'basics', 'fullDescription');
    }
    if (draft.media.coverImage.isEmpty) {
      error('cover_image_required', 'basics', 'coverImage');
    }
    if (draft.mainCategory.trim().isEmpty || draft.subcategory.trim().isEmpty) {
      error('category_required', 'basics', 'categoryId');
    }
    // Subcategory-applicability (`subcategory_not_applicable`) and required
    // criteria fields (`criterion_required`) are appended by the caller
    // (`CreateController._activityIssues`) on top of these issues, mirroring
    // the established Place pattern — not duplicated here.

    // --- Step 2: Location & access (§8 Step 2) ---
    final ActivityLocationDraft location = activity.location;
    final double? lat = location.latitude;
    final double? lng = location.longitude;
    final bool hasFiniteCoordinates =
        lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
    if (!hasFiniteCoordinates) {
      error('location_coordinates_required', 'location', 'geo');
    }
    if (!location.pinConfirmed) {
      error('pin_confirmation_required', 'location', 'geo');
    }

    final String accessNotes = location.accessNotes.trim();
    if (accessNotes.isEmpty) {
      error('access_notes_required', 'location', 'accessNotes');
    } else if (accessNotes.length < 10 || accessNotes.length > 300) {
      error('access_notes_length', 'location', 'accessNotes');
    }

    final ActivityAccessCautionDraft? caution = location.accessCaution;
    if (caution != null && caution.isInformal) {
      final String note = (caution.note ?? '').trim();
      if (note.isEmpty) {
        error('access_caution_note_required', 'location', 'accessCautionNote');
      }
      warning('informal_access_notice', 'location', 'accessCautionNote');
    }

    if ((caution?.note ?? '').trim().runes.length > 200) {
      error('access_caution_note_length', 'location', 'accessCautionNote');
    }

    final ActivityOptionalContributionDraft? contribution =
        activity.optionalContribution;
    if (contribution != null) {
      final bool hasKind = contribution.kind != null;
      final String note = (contribution.note ?? '').trim();
      final bool hasNote = note.isNotEmpty;
      final bool hasAmount = contribution.amountHint != null;
      if (hasKind && !hasNote) {
        error('contribution_note_required', 'location', 'contributionNote');
      } else if (hasKind &&
          hasNote &&
          (note.length < 10 || note.length > 140)) {
        error('contribution_note_length', 'location', 'contributionNote');
      }
      if (hasAmount && !(hasKind && hasNote)) {
        error(
          'contribution_amount_needs_kind',
          'location',
          'contributionAmountHint',
        );
      }
      if (hasAmount) {
        final int amountMinor = contribution.amountHint!.amountMinor;
        if (amountMinor <= 0) {
          error(
            'contribution_amount_not_positive',
            'location',
            'contributionAmountHint',
          );
        }
        final String currency = contribution.amountHint!.currencyCode.trim();
        if (currency.isEmpty ||
            currency.toUpperCase() != activeMarketCurrencyCode.toUpperCase()) {
          error(
            'contribution_currency_unsupported',
            'location',
            'contributionAmountHint',
          );
        }
      }
    }

    // --- Step 3: When & for whom (§8 Step 3) ---
    final ActivityIntRangeDraft duration = activity.typicalDurationMinutes;
    if (duration.min <= 0) {
      error('duration_not_positive', 'whenFor', 'typicalDurationMinutes');
    }
    if (duration.min > duration.max) {
      error('duration_range_invalid', 'whenFor', 'typicalDurationMinutes');
    } else if (duration.min < 30 || duration.max > 240) {
      warning(
        'duration_out_of_recommended_range',
        'whenFor',
        'typicalDurationMinutes',
      );
    }

    final ActivityIntRangeDraft? groupSize = activity.suggestedGroupSize;
    if (groupSize != null) {
      if (groupSize.min <= 0) {
        error('group_size_not_positive', 'whenFor', 'suggestedGroupSize');
      }
      if (groupSize.min > groupSize.max) {
        error('group_size_range_invalid', 'whenFor', 'suggestedGroupSize');
      } else if (groupSize.min < 1 || groupSize.max > 10) {
        warning(
          'group_size_out_of_recommended_range',
          'whenFor',
          'suggestedGroupSize',
        );
      }
    }

    return issues;
  }
}
