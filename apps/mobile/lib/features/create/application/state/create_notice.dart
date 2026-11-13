import '../../../../shared/primitives/errors/coded_refusal.dart';
import '../../domain/usecases/generate_scenario_proposal_usecase.dart';

/// L4: stable codes the Create controller keeps in `CreateState.message`
/// and in the Scenario/Place helper error fields. The UI turns a code into
/// text (`createNoticeText`); no sentence lives in the controller.
abstract final class CreateNotice {
  static const String admissionLegacyReview = 'admission_legacy_review';
  static const String admissionPreviewStale = 'admission_preview_stale';
  static const String classificationChanged = 'classification_changed';
  static const String classificationRoleLimit = 'classification_role_limit';
  static const String collectionAcceptedSyncPending =
      'collection_accepted_sync_pending';
  static const String collectionArchivedSyncPending =
      'collection_archived_sync_pending';
  static const String collectionCreateNotAllowed =
      'collection_create_not_allowed';
  static const String collectionItemsRemovedSyncPending =
      'collection_items_removed_sync_pending';
  static const String collectionNotPublished = 'collection_not_published';
  static const String collectionPublicationDisabled =
      'collection_publication_disabled';
  static const String collectionPublishNotAllowed =
      'collection_publish_not_allowed';
  static const String collectionPublished = 'collection_published';
  static const String collectionPublishedSyncPending =
      'collection_published_sync_pending';
  static const String collectionRejectionReasonRequired =
      'collection_rejection_reason_required';
  static const String collectionSubmitted = 'collection_submitted';
  static const String draftSaveFailed = 'draft_save_failed';
  static const String draftSaved = 'draft_saved';
  static const String eventAccessContractUnsupported =
      'event_access_contract_unsupported';
  static const String placeDuplicatesReview = 'place_duplicates_review';
  static const String placeGalleryLimit = 'place_gallery_limit';
  static const String placeHelperFailed = 'place_helper_failed';
  static const String placeHelperStale = 'place_helper_stale';
  static const String placeSuggestionsApplied = 'place_suggestions_applied';
  static const String published = 'published';
  static const String publisherPageUnavailable = 'publisher_page_unavailable';
  static const String publisherUnavailable = 'publisher_unavailable';
  static const String rentalNewDraftFromListing =
      'rental_new_draft_from_listing';
  static const String requiredFields = 'required_fields';
  static const String routeActionForbidden = 'route_action_forbidden';
  static const String routeArchiveForbidden = 'route_archive_forbidden';
  static const String routeCommandRefused = 'route_command_refused';
  static const String routeCreateNotAllowed = 'route_create_not_allowed';
  static const String routeDecisionForbidden = 'route_decision_forbidden';
  static const String routeDraftSaved = 'route_draft_saved';
  static const String routeEditorLoading = 'route_editor_loading';
  static const String routeNewVersionCreated = 'route_new_version_created';
  static const String routeNewVersionUnavailable =
      'route_new_version_unavailable';
  static const String routeNotFound = 'route_not_found';
  static const String routeNotPublished = 'route_not_published';
  static const String routeNotReady = 'route_not_ready';
  static const String routePublicationUnavailable =
      'route_publication_unavailable';
  static const String routePublished = 'route_published';
  static const String routeQueueUnavailable = 'route_queue_unavailable';
  static const String routeSaveFailed = 'route_save_failed';
  static const String routeSegmentsBusy = 'route_segments_busy';
  static const String routeSubmitFailed = 'route_submit_failed';
  static const String routeSubmitted = 'route_submitted';
  static const String routeVersionApproved = 'route_version_approved';
  static const String routeVersionRejected = 'route_version_rejected';
  static const String routeWithdrawn = 'route_withdrawn';
  static const String scenarioAiProposalAdded = 'scenario_ai_proposal_added';
  static const String scenarioBlockingIssues = 'scenario_blocking_issues';
  static const String scenarioGenerationEmptyPrompt =
      'scenario_generation_empty_prompt';
  static const String scenarioGenerationInvalidProposal =
      'scenario_generation_invalid_proposal';
  static const String scenarioGenerationPromptTooLong =
      'scenario_generation_prompt_too_long';
  static const String scenarioOpenFailed = 'scenario_open_failed';
  static const String scenarioPreviewFailed = 'scenario_preview_failed';
  static const String scenarioPreviewStale = 'scenario_preview_stale';
  static const String scenarioPublicPublishDisabled =
      'scenario_public_publish_disabled';
  static const String scenarioTitleRequired = 'scenario_title_required';
  static const String scenarioUnavailable = 'scenario_unavailable';
  static const String stepRequiredFields = 'step_required_fields';
  static const String submitFailed = 'submit_failed';
  static const String submittedForReview = 'submitted_for_review';
  static const String templateActionFailed = 'template_action_failed';
  static const String templateApplied = 'template_applied';
  static const String templateDeleted = 'template_deleted';
  static const String templateInvalid = 'template_invalid';
  static const String templateRenamed = 'template_renamed';
  static const String templateSaved = 'template_saved';
  static const String templateStoreUnavailable = 'template_store_unavailable';
  static const String templateUpdated = 'template_updated';
  static const String transitItemMissing = 'transit_item_missing';
  static const String transitNotApplied = 'transit_not_applied';
  static const String transitOnlyOfficial = 'transit_only_official';
  static const String transitScenarioChanged = 'transit_scenario_changed';
  static const String transitServiceUnsafe = 'transit_service_unsafe';
  static const String warningsConfirm = 'warnings_confirm';

  /// Photos a Place gallery can keep; [placeGalleryLimit] shows it.
  static const int placeGalleryMaxPhotos = 12;

  /// The code for a local Scenario generation refusal.
  /// L4.8: a server refusal in `CreateState.message`, read by `CreateTexts`.
  static const String refusalPrefix = 'refusal:';
  static String forRefusal(CodedRefusal refusal) =>
      '$refusalPrefix${refusal.messageFamily.name}:${refusal.code}';

  static String forScenarioGeneration(ScenarioGenerationFailureCode code) =>
      switch (code) {
        ScenarioGenerationFailureCode.emptyPrompt =>
          scenarioGenerationEmptyPrompt,
        ScenarioGenerationFailureCode.promptTooLong =>
          scenarioGenerationPromptTooLong,
        ScenarioGenerationFailureCode.invalidProposal =>
          scenarioGenerationInvalidProposal,
      };

  /// Every code (contract tests).
  static const Set<String> all = <String>{
    admissionLegacyReview,
    admissionPreviewStale,
    classificationChanged,
    classificationRoleLimit,
    collectionAcceptedSyncPending,
    collectionArchivedSyncPending,
    collectionCreateNotAllowed,
    collectionItemsRemovedSyncPending,
    collectionNotPublished,
    collectionPublicationDisabled,
    collectionPublishNotAllowed,
    collectionPublished,
    collectionPublishedSyncPending,
    collectionRejectionReasonRequired,
    collectionSubmitted,
    draftSaveFailed,
    draftSaved,
    eventAccessContractUnsupported,
    placeDuplicatesReview,
    placeGalleryLimit,
    placeHelperFailed,
    placeHelperStale,
    placeSuggestionsApplied,
    published,
    publisherPageUnavailable,
    publisherUnavailable,
    rentalNewDraftFromListing,
    requiredFields,
    routeActionForbidden,
    routeArchiveForbidden,
    routeCommandRefused,
    routeCreateNotAllowed,
    routeDecisionForbidden,
    routeDraftSaved,
    routeEditorLoading,
    routeNewVersionCreated,
    routeNewVersionUnavailable,
    routeNotFound,
    routeNotPublished,
    routeNotReady,
    routePublicationUnavailable,
    routePublished,
    routeQueueUnavailable,
    routeSaveFailed,
    routeSegmentsBusy,
    routeSubmitFailed,
    routeSubmitted,
    routeVersionApproved,
    routeVersionRejected,
    routeWithdrawn,
    scenarioAiProposalAdded,
    scenarioBlockingIssues,
    scenarioGenerationEmptyPrompt,
    scenarioGenerationInvalidProposal,
    scenarioGenerationPromptTooLong,
    scenarioOpenFailed,
    scenarioPreviewFailed,
    scenarioPreviewStale,
    scenarioPublicPublishDisabled,
    scenarioTitleRequired,
    scenarioUnavailable,
    stepRequiredFields,
    submitFailed,
    submittedForReview,
    templateActionFailed,
    templateApplied,
    templateDeleted,
    templateInvalid,
    templateRenamed,
    templateSaved,
    templateStoreUnavailable,
    templateUpdated,
    transitItemMissing,
    transitNotApplied,
    transitOnlyOfficial,
    transitScenarioChanged,
    transitServiceUnsafe,
    warningsConfirm,
  };
}
