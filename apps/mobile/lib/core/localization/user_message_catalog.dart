import '../../generated/l10n/app_localizations.dart';
import '../../shared/primitives/errors/coded_refusal.dart';

export '../../shared/primitives/errors/coded_refusal.dart';

/// A localized message for one stable code; `null` means the code is not an
/// error and nothing is shown (for example `eligible` or `rendered`).
typedef UserMessageOf = String Function(AppLocalizations l10n);

/// L4: stable code → localized message. It is the only place a code becomes
/// text. A code missing here is never shown as is: [message] returns the
/// safe generic text, and the code stays available to diagnostics through the
/// state that carried it. Messages name no person, reporter, private value or
/// provider detail; their parameters are numbers only.
abstract final class UserMessageCatalog {
  static String _generic(AppLocalizations l) => l.errorGeneric;
  static String _updateApp(AppLocalizations l) => l.errorUpdateApp;
  static String _invalid(AppLocalizations l) => l.errorInvalidRequest;
  static String _notAllowed(AppLocalizations l) => l.errorNotAllowed;
  static String _signIn(AppLocalizations l) => l.errorSignInRequired;
  static String _session(AppLocalizations l) => l.errorSessionExpired;
  static String _conflict(AppLocalizations l) => l.errorConflictRefresh;
  static String _unavailable(AppLocalizations l) =>
      l.errorTemporarilyUnavailable;
  static String _unknown(AppLocalizations l) => l.errorUnknownOutcome;
  static String _notFound(AppLocalizations l) => l.errorNotFound;
  static String _rateLimited(AppLocalizations l) => l.errorRateLimited;
  static String _featureOff(AppLocalizations l) => l.errorFeatureDisabled;
  static String _marketOff(AppLocalizations l) => l.errorMarketDisabled;
  static String _publisher(AppLocalizations l) =>
      l.contentErrorPublisherNotEligible;
  static String _verification(AppLocalizations l) =>
      l.contentErrorCreatorVerificationRequired;
  static String _membership(AppLocalizations l) =>
      l.contentErrorMembershipInactive;
  static String _importChanged(AppLocalizations l) => l.importErrorChanged;
  static String _draftRequired(AppLocalizations l) => l.localErrorDraftRequired;

  static final Map<String, UserMessageOf> _booking = <String, UserMessageOf>{
    'not_authenticated': _signIn,
    'not_authorized': _notAllowed,
    'forbidden': _notAllowed,
    'feature_disabled': _featureOff,
    'app_check_required': _updateApp,
    'session_refresh_required': (l) => l.errorSessionNotConfirmed,
    'session_revoked': _session,
    'session_expired': _session,
    'event_unavailable': (l) => l.bookingErrorEventUnavailable,
    'occurrence_cancelled': (l) => l.bookingErrorEventUnavailable,
    'pool_required': (l) => l.bookingErrorEventUnavailable,
    'pool_unavailable': (l) => l.bookingErrorEventUnavailable,
    'registration_not_open': (l) => l.bookingErrorRegistrationNotOpen,
    'registration_closed': (l) => l.bookingErrorRegistrationClosed,
    'eligibility_not_satisfied': (l) => l.bookingErrorEligibility,
    'invalid_guest_count': (l) => l.bookingErrorInvalidGuestCount,
    'sold_out': (l) => l.bookingErrorSoldOut,
    'already_active': (l) => l.bookingErrorAlreadyActive,
    'concurrency_cap_reached': (l) => l.bookingErrorBookingLimit,
    'active_booking_limit_reached': (l) => l.bookingErrorBookingLimit,
    'rate_limited': _rateLimited,
    'revision_conflict': (l) => l.bookingErrorRevisionConflict,
    'hold_expired': (l) => l.bookingErrorHoldExpired,
    'cancellation_deadline_passed': (l) =>
        l.bookingErrorCancellationDeadlinePassed,
    'reconfirmation_not_required': (l) =>
        l.bookingErrorReconfirmationNotRequired,
    'reconfirmation_deadline_passed': (l) =>
        l.bookingErrorReconfirmationDeadlinePassed,
    'material_revision_mismatch': (l) => l.bookingErrorMaterialRevisionMismatch,
    'idempotency_conflict': (l) => l.bookingErrorGeneric,
    'contention': _unavailable,
    'unsupported_schema': _updateApp,
    'temporarily_unavailable': _unavailable,
    'invalid_contract': _invalid,
  };

  static final Map<String, UserMessageOf> _content = <String, UserMessageOf>{
    'unauthenticated': _signIn,
    'capability_denied': _notAllowed,
    'publisher_not_eligible': _publisher,
    'creator_verification_required': _verification,
    // ADR 0023: the new name of the same refusal.
    'identity_verification_required': _verification,
    'membership_inactive': _membership,
    'type_disabled': (l) => l.contentErrorTypeDisabled,
    'content_type_unsupported': (l) => l.contentErrorTypeDisabled,
    'source_revision_stale': _conflict,
    'validation_failed': (l) => l.contentErrorValidationFailed,
    'media_not_ready': (l) => l.contentErrorMediaNotReady,
    'moderation_required': (l) => l.contentErrorModerationRequired,
    'moderation_decision_stale': _conflict,
    'publication_restricted': (l) => l.contentErrorPublicationRestricted,
    'market_disabled': _marketOff,
    'policy_unavailable': _unavailable,
    'revision_conflict': _conflict,
    'idempotency_conflict': _generic,
    'unsupported_version': _updateApp,
    'unknown_outcome': _unknown,
    'not_found': _notFound,
    'invalid_contract': _invalid,
    'storage_limit_exceeded': (l) => l.contentErrorStorageLimit,
    'import_rollback_not_allowed': (l) => l.importErrorRollbackNotAllowed,
    'import_generation_mismatch': _importChanged,
    'import_rolled_back': (l) => l.importErrorRolledBack,
    'cleanup_reserved': _importChanged,
    'cleanup_not_reserved': _importChanged,
    'cleanup_token_mismatch': _importChanged,
    'original_removed': (l) => l.importErrorOriginalRemoved,
    'privacy_consent_required': (l) => l.contentErrorPrivacyConsentRequired,
    'age_eligibility_required': (l) => l.contentErrorAgeEligibilityRequired,
  };

  static final Map<String, UserMessageOf> _media = <String, UserMessageOf>{
    'unauthenticated': _signIn,
    'invalid_contract': _invalid,
    'unsupported_version': _updateApp,
    'capability_denied': _notAllowed,
    'membership_inactive': _membership,
    'market_disabled': _marketOff,
    'not_found': _notFound,
    'policy_unavailable': _unavailable,
    'family_unavailable': (l) => l.localErrorMediaUnavailable,
    'entity_scope_denied': _notAllowed,
    'session_expired': (l) => l.mediaErrorUploadIncomplete,
    'object_missing': (l) => l.mediaErrorUploadIncomplete,
    'upload_incomplete': (l) => l.mediaErrorUploadIncomplete,
    'generation_mismatch': (l) => l.mediaErrorUploadIncomplete,
    'signature_mismatch': (l) => l.mediaErrorUploadIncomplete,
    'limit_exceeded': (l) => l.mediaErrorLimitExceeded,
    'stale_revision': _conflict,
    'invalid_state': _conflict,
    'idempotency_conflict': _generic,
    'retry_not_allowed': (l) => l.mediaErrorRetryNotAllowed,
    'revision_conflict': _conflict,
    'unknown_outcome': _unknown,
    'asset_referenced': (l) => l.mediaErrorAssetReferenced,
  };

  static final Map<String, UserMessageOf?> _publisherEligibility =
      <String, UserMessageOf?>{
        'eligible': null,
        'account_inactive': (l) => l.errorAccountRestricted,
        'creator_verification_required': _verification,
        // ADR 0023: the new name of the same refusal.
        'identity_verification_required': _verification,
        'creator_verification_unavailable': (l) =>
            l.contentErrorCreatorVerificationUnavailable,
        'membership_inactive': _membership,
        'capability_denied': _notAllowed,
        'publisher_not_accessible': _publisher,
        'snapshot_stale': (l) => l.errorAccessUpdating,
      };

  static final Map<String, UserMessageOf> _platform = <String, UserMessageOf>{
    'invalid_argument': _invalid,
    'unauthenticated': _signIn,
    'permission_denied': _notAllowed,
    'not_found': _notFound,
    'conflict': _conflict,
    'idempotency_conflict': _generic,
    'failed_precondition': _conflict,
    'rate_limited': _rateLimited,
    'unavailable': _unavailable,
    'deadline_exceeded': _unknown,
    'unsupported_client': _updateApp,
    'unsupported_contract': _updateApp,
    'unsupported_schema': _updateApp,
    'stale_revision': _conflict,
    'internal': _generic,
  };

  static final Map<String, UserMessageOf?> _contentTranslation =
      <String, UserMessageOf?>{
        'unauthenticated': (l) => l.contentTranslationErrorSignIn,
        'request_invalid': (l) => l.contentTranslationErrorProvider,
        'translation_disabled': (l) => l.contentTranslationErrorDisabled,
        'same_language': (l) => l.contentTranslationErrorSameLanguage,
        'unsupported_locale': (l) => l.contentTranslationErrorUnsupported,
        'source_unavailable': (l) => l.contentTranslationErrorSource,
        'revision_changed': (l) => l.contentTranslationErrorRevision,
        'quota_exceeded': (l) => l.contentTranslationErrorQuota,
        'budget_exhausted': (l) => l.contentTranslationErrorBudget,
        'provider_unavailable': (l) => l.contentTranslationErrorProvider,
      };

  static final Map<String, UserMessageOf?> _notificationContent =
      <String, UserMessageOf?>{
        'rendered': null,
        'unsupported_locale': (l) => l.notificationUnsupportedLocale,
        'template_unavailable': (l) => l.notificationTemplateUnavailable,
      };

  /// L4.8: what the shared callable transport refuses in every module.
  static final Map<String, UserMessageOf> _moduleTransport =
      <String, UserMessageOf>{
        'app_check_required': _updateApp,
        'feature_disabled': _featureOff,
        'permission_denied': _notAllowed,
        'temporarily_unavailable': _unavailable,
        'unauthenticated': _signIn,
      };

  static String _accountChanged(AppLocalizations l) => l.errorAccountChanged;
  static String _publicationActive(AppLocalizations l) =>
      l.errorPublicationActive;

  // L4.8: "gone" and "not yours" share `errorNotFound` on purpose, so a
  // message never reveals that somebody else's object exists (BCK-03 §14).
  static final Map<String, UserMessageOf> _library = <String, UserMessageOf>{
    ..._moduleTransport,
    'cursor_invalid': _conflict,
    'idempotency_conflict': _conflict,
    'object_unavailable': _notFound,
    'owner_changed': _accountChanged,
    'place_timezone_invalid': (l) => l.libraryErrorPlaceTimezone,
    'processing_restricted': (l) => l.errorProcessingRestricted,
    'request_invalid': _invalid,
    'revision_conflict': _conflict,
    'snapshot_changed': _conflict,
    'visit_date_future': (l) => l.libraryErrorVisitFuture,
  };

  static final Map<String, UserMessageOf> _quickPlan = <String, UserMessageOf>{
    ..._moduleTransport,
    'access_denied': _notFound,
    'access_revoked': _notFound,
    'deleted': _notFound,
    'id_collision': _conflict,
    'idempotency_conflict': _conflict,
    'invite_limit': (l) => l.quickPlanErrorInviteLimit,
    'owner_changed': _accountChanged,
    'request_invalid': _invalid,
    'revision_conflict': _conflict,
    'target_unavailable': _notFound,
  };

  static final Map<String, UserMessageOf> _scenario = <String, UserMessageOf>{
    ..._moduleTransport,
    'access_revoked': _notFound,
    'actor_changed': _accountChanged,
    'conversion_invalid': _invalid,
    'distribution_invalid': _invalid,
    'id_collision': _conflict,
    'idempotency_conflict': _conflict,
    'intent_not_found': _notFound,
    'membership_conflict': _conflict,
    'not_found': _notFound,
    'not_found_or_forbidden': _notFound,
    'publication_active': _publicationActive,
    'recipient_unavailable': _notFound,
    'request_invalid': _invalid,
    'revision_conflict': _conflict,
    'source_revision_conflict': _conflict,
    'source_unavailable': _notFound,
    'token_expired': (l) => l.scenarioErrorLinkExpired,
  };

  static final Map<String, UserMessageOf> _route = <String, UserMessageOf>{
    ..._moduleTransport,
    'deleted': _notFound,
    'distribution_limit': (l) => l.routeErrorDistributionLimit,
    'id_collision': _conflict,
    'idempotency_conflict': _conflict,
    'invalid_geometry': (l) => l.routeErrorGeometry,
    'license_blocked': (l) => l.routeErrorLicense,
    'not_found': _notFound,
    'owner_changed': _accountChanged,
    'payload_too_large': (l) => l.routeErrorTooLarge,
    'point_limit_exceeded': (l) => l.routeErrorTooManyPoints,
    'privacy_trim_empty': (l) => l.routeTrimEmpty,
    'privacy_trim_invalid': (l) => l.routeErrorTrimInvalid,
    'privacy_trim_required': (l) => l.routeTrimRequired,
    'provenance_unverified': (l) => l.routeErrorProvenance,
    'publication_active': _publicationActive,
    'request_invalid': _invalid,
    'revision_conflict': _conflict,
    'title_required': (l) => l.routeErrorTitleRequired,
  };

  static final Map<String, UserMessageOf> _privacyIntake =
      <String, UserMessageOf>{
        'access_denied': _notAllowed,
        'idempotency_conflict': _conflict,
        'invalid_contract': _invalid,
        'request_not_found': _notFound,
        'revision_conflict': _conflict,
        'subject_mismatch': _notAllowed,
      };

  static final Map<String, UserMessageOf> _identitySession =
      <String, UserMessageOf>{
        'account_blocked': (l) => l.identityErrorAccountBlocked,
        'account_creation_disabled': _featureOff,
        'account_restricted': (l) => l.identityErrorAccountRestricted,
        'app_check_required': _updateApp,
        'capability_denied': _notAllowed,
        'contention': _unavailable,
        'creator_verification_required': _verification,
        // ADR 0023: the new name of the same refusal.
        'identity_verification_required': _verification,
        'creator_verification_unavailable': _unavailable,
        'feature_disabled': _featureOff,
        'invalid_contract': _invalid,
        'invalid_transition': _conflict,
        'membership_inactive': _membership,
        'not_found_or_not_accessible': _notFound,
        'policy_unavailable': _unavailable,
        'provider_assertion_invalid': _signIn,
        'provider_subject_conflict': _notAllowed,
        'publisher_not_accessible': _publisher,
        'rate_limited': _rateLimited,
        'recent_auth_required': (l) => l.identityErrorRecentAuth,
        'revision_conflict': _conflict,
        'session_expired': _session,
        'session_limit_reached': (l) => l.identityErrorSessionLimit,
        'session_revoked': _session,
        'snapshot_stale': _conflict,
        'temporarily_unavailable': _unavailable,
        'unauthenticated': _signIn,
        'unsupported_schema': _updateApp,
      };

  /// Firebase callable status names as the transport reports them.
  static final Map<String, UserMessageOf> _clientTransport =
      <String, UserMessageOf>{
        'unavailable': (l) => l.errorOffline,
        'offline': (l) => l.errorOffline,
        'deadline-exceeded': _unknown,
        'unknown': _unknown,
        'unknown_outcome': _unknown,
        'unauthenticated': _signIn,
        'permission-denied': _notAllowed,
        'not-found': _notFound,
        'failed-precondition': _conflict,
        'resource-exhausted': _rateLimited,
        'invalid-argument': _invalid,
        'internal': _generic,
        'session_unavailable': (l) => l.errorSessionNotConfirmed,
        'answer_invalid': _invalid,
      };

  static final Map<String, UserMessageOf> _clientLocal =
      <String, UserMessageOf>{
        'not_allowed': (l) => l.contentErrorNotAllowedLocally,
        'save_required': (l) => l.localErrorSaveRequired,
        'media_missing': (l) => l.localErrorMediaMissing,
        'cover_required': (l) => l.localErrorCoverRequired,
        'submission_required': (l) => l.localErrorSubmissionRequired,
        'publication_required': (l) => l.localErrorPublicationRequired,
        'publisher_required': (l) => l.localErrorPublisherRequired,
        'no_conflict': (l) => l.localErrorNoConflict,
        'foreign_record': (l) => l.localErrorForeignRecord,
        'editing_after_publication_not_supported': (l) =>
            l.localErrorEditingAfterPublication,
        'media_rights_required': (l) => l.localErrorMediaRightsRequired,
        'activity_draft_changed': (l) => l.localErrorDraftChanged,
        'consent_missing': (l) => l.localErrorConsentMissing,
        'share_token_unavailable': (l) => l.localErrorShareUnavailable,
        'media_unavailable': (l) => l.localErrorMediaUnavailable,
        // MEDIA-PICK-01 §9: the photo picker and its client copy.
        'media_unsupported': (l) => l.localErrorMediaUnsupported,
        'media_decode_failed': (l) => l.localErrorMediaDecodeFailed,
        'media_too_large': (l) => l.localErrorMediaTooLarge,
        'media_storage_full': (l) => l.localErrorMediaStorageFull,
        'media_permission_denied': (l) => l.localErrorMediaPermissionDenied,
        'place_draft_required': _draftRequired,
        'event_draft_required': _draftRequired,
        'rental_draft_required': _draftRequired,
        'session_draft_required': _draftRequired,
        'activity_draft_required': _draftRequired,
        'collection_draft_required': _draftRequired,
        'find_people_draft_required': _draftRequired,
        'class_workshop_draft_required': _draftRequired,
        'session_open': (l) => l.importErrorSessionOpen,
        'no_open_session': (l) => l.importErrorNoOpenSession,
        'nothing_to_import': (l) => l.importErrorNothingToImport,
        'not_imported': (l) => l.importErrorNotImported,
        'not_verified': (l) => l.importErrorNotVerified,
        'verification_mismatch': (l) => l.importErrorVerificationMismatch,
        'server_check_failed': (l) => l.importErrorServerCheckFailed,
        'original_missing': (l) => l.importErrorOriginalMissing,
        'local_changed_since_import': (l) => l.importErrorLocalChanged,
        'rollback_not_allowed': (l) => l.importErrorRollbackNotAllowed,
        // L4.8: what the module sync clients raise themselves.
        'actor_changed': _accountChanged,
        'explicit_self_report_required': _invalid,
        'import_not_reappliable': (l) => l.localErrorImportNotReappliable,
        'intent_rejected': _conflict,
        'invalid_response': _invalid,
        'journal_capacity_exceeded': (l) => l.localErrorStorageFull,
        'owner_changed': _accountChanged,
        'page_limit_exceeded': _invalid,
        'public_object_reference_required': _invalid,
        'test_entry_disabled': _featureOff,
        'transport_unavailable': _unavailable,
      };

  static Map<String, UserMessageOf?> _family(UserMessageFamily family) =>
      switch (family) {
        UserMessageFamily.booking => _booking,
        UserMessageFamily.content => _content,
        UserMessageFamily.media => _media,
        UserMessageFamily.publisherEligibility => _publisherEligibility,
        UserMessageFamily.platform => _platform,
        UserMessageFamily.notificationContent => _notificationContent,
        UserMessageFamily.library => _library,
        UserMessageFamily.quickPlan => _quickPlan,
        UserMessageFamily.scenario => _scenario,
        UserMessageFamily.route => _route,
        UserMessageFamily.privacyIntake => _privacyIntake,
        UserMessageFamily.identitySession => _identitySession,
        UserMessageFamily.contentTranslation => _contentTranslation,
        UserMessageFamily.clientTransport => _clientTransport,
        UserMessageFamily.clientLocal => _clientLocal,
      };

  /// Every code the catalog dispositions for [family] (contract tests).
  static Set<String> codes(UserMessageFamily family) =>
      Set<String>.unmodifiable(_family(family).keys);

  static bool isRegistered(UserMessageFamily family, String code) =>
      _family(family).containsKey(code);

  /// The message for [code] in [family]; null for a non-error code; the
  /// generic text for an unknown code.
  static String? message(
    AppLocalizations l10n,
    UserMessageFamily family,
    String? code,
  ) {
    final Map<String, UserMessageOf?> messages = _family(family);
    if (code != null && messages.containsKey(code)) {
      return messages[code]?.call(l10n);
    }
    return _generic(l10n);
  }

  /// A Booking refusal; [retryAfterSeconds] adds the server's wait hint.
  static String booking(
    AppLocalizations l10n,
    String? code, {
    int? retryAfterSeconds,
  }) {
    if (code == 'rate_limited' && retryAfterSeconds != null) {
      return l10n.errorRateLimitedSeconds(retryAfterSeconds);
    }
    if (code != null && _booking.containsKey(code)) {
      return _booking[code]!(l10n);
    }
    return l10n.bookingErrorGeneric;
  }

  /// L4.8: the session transport writes `session_expired` as `session-expired`
  /// before module clients see it; both spell the same code.
  static String? _withoutHyphens(Map<String, Object?> messages, String code) {
    final String spoken = code.replaceAll('-', '_');
    return spoken != code && messages.containsKey(spoken) ? spoken : null;
  }

  /// L4.8: the words for a refusal of [family]: its own code, then a Session
  /// code, a client-raised code or a transport status. An unknown code gives
  /// [fallback], the text the screen shows for any other failure.
  static String refusal(
    AppLocalizations l10n,
    UserMessageFamily family,
    String code, {
    required String fallback,
  }) {
    for (final Map<String, UserMessageOf?> messages
        in <Map<String, UserMessageOf?>>[
          _family(family),
          _identitySession,
          _clientLocal,
          _clientTransport,
        ]) {
      if (messages.containsKey(code)) {
        return messages[code]?.call(l10n) ?? fallback;
      }
      final String? spoken = _withoutHyphens(messages, code);
      if (spoken != null) return messages[spoken]?.call(l10n) ?? fallback;
    }
    return fallback;
  }

  /// [refusal] for any caught [error]; anything without a code gives [fallback].
  static String forError(
    AppLocalizations l10n,
    Object? error, {
    required String fallback,
  }) => error is CodedRefusal
      ? refusal(l10n, error.messageFamily, error.code, fallback: fallback)
      : fallback;

  /// A Create publication/import message: the code may come from Content,
  /// Media, the transport or the client itself (in that order).
  static String publication(AppLocalizations l10n, String code) {
    for (final Map<String, UserMessageOf?> messages
        in <Map<String, UserMessageOf?>>[
          _content,
          _media,
          _clientLocal,
          _clientTransport,
          _platform,
          _route,
          _identitySession,
        ]) {
      if (messages.containsKey(code)) {
        return messages[code]?.call(l10n) ?? _generic(l10n);
      }
      final String? spoken = _withoutHyphens(messages, code);
      if (spoken != null) return messages[spoken]?.call(l10n) ?? _generic(l10n);
    }
    if (code.startsWith('cleanup_')) return _importChanged(l10n);
    if (code.startsWith('unsupported_capability')) return _featureOff(l10n);
    return _generic(l10n);
  }
}
