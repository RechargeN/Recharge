// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Recharge';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonCheckAgain => 'Check again';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonOk => 'OK';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSignIn => 'Sign in';

  @override
  String get commonContinueAsGuest => 'Continue as guest';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameLv => 'Latviešu';

  @override
  String get languageNameRu => 'Русский';

  @override
  String get languageHint =>
      'Changes only the app language. Market, currency and event times stay the same.';

  @override
  String get navHome => 'Home';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navSmartSearch => 'Smart Search';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navProfile => 'Profile';

  @override
  String get navPage => 'Page';

  @override
  String get navContent => 'Content';

  @override
  String get navCreate => 'Create';

  @override
  String get navAccount => 'Account';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get commonSignInRequired => 'Sign in required';

  @override
  String get settingsLoadFailed => 'Settings could not be loaded';

  @override
  String get settingsSectionAccount => 'ACCOUNT AND WORKSPACE';

  @override
  String get settingsSwitchWorkspace => 'Switch workspace';

  @override
  String get settingsSwitchWorkspaceHint =>
      'Personal profile, Professional Pages and Admin access';

  @override
  String get settingsSectionContent => 'CONTENT & ACTIVITY';

  @override
  String get settingsSavedPlans => 'Saved plans';

  @override
  String get settingsSavedPlansHint => 'Saved ideas and personal plans';

  @override
  String get settingsSearch => 'Search and conditions';

  @override
  String get settingsSearchHint => 'Saved searches and discovery filters';

  @override
  String get settingsNotificationsHint => 'Inbox and route updates';

  @override
  String get settingsSectionPreferences => 'PREFERENCES';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsNotificationPreferences => 'Notification preferences';

  @override
  String get settingsSupport => 'Support / Help';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsProfileInformation => 'Profile information';

  @override
  String get settingsDisplayName => 'Display name';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsCity => 'City';

  @override
  String get settingsAvatar => 'Avatar URL/Path';

  @override
  String get settingsSaving => 'Saving…';

  @override
  String get settingsSaveProfile => 'Save profile';

  @override
  String get settingsProfileSaved => 'Profile saved';

  @override
  String get authSignInHeadline => 'Sign in to save and manage';

  @override
  String get authSignInToContinue => 'Sign in to continue';

  @override
  String get authSignInBody =>
      'Without signing in you can browse events and places. Signing in is needed for favorites, your profile and creating activities.';

  @override
  String get authScenarioRequiresSignIn =>
      'A personal Scenario is available only to a signed-in user.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'Enter your email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authSigningIn => 'Signing in…';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'Enter a valid email';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordTooShort => 'The password is too short';

  @override
  String get authErrorInvalidCredentials => 'Wrong email or password';

  @override
  String get authErrorTooManyAttempts => 'Too many attempts. Try again later';

  @override
  String get authErrorNetwork => 'No internet connection';

  @override
  String get authErrorGeneric => 'Could not sign in. Try again';

  @override
  String get authSessionExpired => 'Your session has expired. Sign in again.';

  @override
  String get authRestoringSession => 'Restoring your session…';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorOffline =>
      'No connection. Try again when you are back online.';

  @override
  String get errorOfflineSaved =>
      'No connection. Your request is saved and will not be duplicated.';

  @override
  String get errorUnknownOutcome =>
      'We could not confirm the result. Checking again will not repeat the action.';

  @override
  String get errorSessionNotConfirmed =>
      'Your session could not be confirmed. Try again.';

  @override
  String get errorSessionExpired => 'Your session has expired. Sign in again.';

  @override
  String get errorSignInRequired => 'Sign in to continue.';

  @override
  String get errorNotAllowed => 'You do not have access to this action.';

  @override
  String get errorUpdateApp =>
      'This version of the app is no longer supported. Update the app.';

  @override
  String get errorInvalidRequest =>
      'The request could not be processed. Update the app or try again.';

  @override
  String get errorRateLimited => 'Too many attempts. Try again shortly.';

  @override
  String errorRateLimitedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Too many attempts. Try again in $count seconds.',
      one: 'Too many attempts. Try again in $count second.',
    );
    return '$_temp0';
  }

  @override
  String get errorTemporarilyUnavailable =>
      'The service is temporarily unavailable. Try again later.';

  @override
  String get errorConflictRefresh =>
      'This was changed meanwhile. Refresh to see the current version.';

  @override
  String get errorNotFound => 'This is no longer available.';

  @override
  String get errorFeatureDisabled => 'This feature is not available yet.';

  @override
  String get errorMarketDisabled => 'This is not available in this region yet.';

  @override
  String get errorAccountRestricted => 'Your account is restricted.';

  @override
  String get errorAccessUpdating => 'Your access is being updated. Try again.';

  @override
  String get contentErrorPublisherNotEligible =>
      'You cannot publish on behalf of this profile or page.';

  @override
  String get contentErrorCreatorVerificationRequired =>
      'Publishing requires a verified creator account.';

  @override
  String get contentErrorCreatorVerificationUnavailable =>
      'Creator verification is temporarily unavailable.';

  @override
  String get contentErrorMembershipInactive =>
      'Your access to this page has ended.';

  @override
  String get contentErrorTypeDisabled =>
      'Publishing this type is not available yet.';

  @override
  String get contentErrorValidationFailed =>
      'Some fields need attention before publishing.';

  @override
  String get contentErrorMediaNotReady =>
      'Media is still being processed. Try again shortly.';

  @override
  String get contentErrorModerationRequired =>
      'This needs to be reviewed before it can be published.';

  @override
  String get contentErrorPublicationRestricted => 'Publication is restricted.';

  @override
  String get contentErrorStorageLimit => 'The storage limit has been reached.';

  @override
  String get contentErrorPrivacyConsentRequired =>
      'Your consent is required to continue.';

  @override
  String get contentErrorAgeEligibilityRequired =>
      'Age confirmation is required for this.';

  @override
  String get contentErrorNotAllowedLocally =>
      'This action is not available for this draft.';

  @override
  String get importErrorRollbackNotAllowed =>
      'This import can no longer be undone.';

  @override
  String get importErrorChanged =>
      'The import changed meanwhile. Refresh and try again.';

  @override
  String get importErrorRolledBack => 'This import was undone.';

  @override
  String get importErrorOriginalRemoved =>
      'The local original has already been removed.';

  @override
  String get mediaErrorUploadIncomplete =>
      'The upload did not complete. Upload the file again.';

  @override
  String get mediaErrorLimitExceeded =>
      'The file is too large or the limit has been reached.';

  @override
  String get mediaErrorAssetReferenced =>
      'This file is still in use and cannot be deleted.';

  @override
  String get mediaErrorRetryNotAllowed =>
      'This upload cannot be retried. Start a new upload.';

  @override
  String get bookingErrorSoldOut => 'This event is sold out.';

  @override
  String get bookingErrorBookingLimit =>
      'You have reached the limit of active bookings.';

  @override
  String get bookingErrorRegistrationNotOpen =>
      'Registration has not opened yet.';

  @override
  String get bookingErrorRegistrationClosed => 'Registration is closed.';

  @override
  String get bookingErrorCancellationDeadlinePassed =>
      'The cancellation deadline has passed.';

  @override
  String get bookingErrorReconfirmationDeadlinePassed =>
      'The confirmation deadline has passed.';

  @override
  String get bookingErrorMaterialRevisionMismatch =>
      'The event changed again. Refresh and confirm the new time.';

  @override
  String get bookingErrorReconfirmationNotRequired =>
      'No confirmation is needed now.';

  @override
  String get bookingErrorRevisionConflict =>
      'Your booking changed meanwhile. Refresh to see the current state.';

  @override
  String get bookingErrorAlreadyActive =>
      'You already have a booking for this event.';

  @override
  String get bookingErrorInvalidGuestCount =>
      'This number of seats is not allowed.';

  @override
  String get bookingErrorEventUnavailable =>
      'This event is not available for booking.';

  @override
  String get bookingErrorEligibility =>
      'You do not meet the conditions to book this event.';

  @override
  String get bookingErrorHoldExpired =>
      'The seat hold expired. Try booking again.';

  @override
  String get bookingErrorGeneric => 'The booking was not accepted.';

  @override
  String get bookingErrorLoadFailed => 'Booking could not be loaded.';

  @override
  String get bookingEndedMissedReconfirmation =>
      'Your booking was released because attendance was not confirmed in time.';

  @override
  String get bookingEndedEventCancelled =>
      'The organizer cancelled this event; your booking was cancelled.';

  @override
  String get bookingEndedOrganizerCancelled =>
      'The organizer cancelled your booking.';

  @override
  String get notificationFallbackTitle => 'Notification';

  @override
  String get notificationUnsupportedLocale =>
      'This notification is not available in your language.';

  @override
  String get notificationTemplateUnavailable =>
      'This notification can no longer be shown.';

  @override
  String get localErrorSaveRequired => 'Save the draft to the server first.';

  @override
  String get localErrorMediaMissing => 'Upload the required media first.';

  @override
  String get localErrorCoverRequired => 'Add a cover image first.';

  @override
  String get localErrorSubmissionRequired =>
      'Submit the draft for review first.';

  @override
  String get localErrorPublicationRequired => 'Publish it first.';

  @override
  String get localErrorPublisherRequired => 'Choose who publishes this first.';

  @override
  String get localErrorNoConflict =>
      'There is no newer server version to resolve.';

  @override
  String get localErrorForeignRecord =>
      'This draft belongs to another account.';

  @override
  String get localErrorEditingAfterPublication =>
      'Editing after publication is not available yet.';

  @override
  String get localErrorMediaRightsRequired =>
      'Confirm that you have the rights to this media.';

  @override
  String get localErrorDraftRequired => 'Create a draft in Create first.';

  @override
  String get localErrorDraftChanged => 'The draft changed. Save it again.';

  @override
  String get localErrorConsentMissing =>
      'Consent is missing. Give consent to continue.';

  @override
  String get localErrorShareUnavailable =>
      'Sharing is not available right now.';

  @override
  String get localErrorMediaUnavailable =>
      'Media upload is not available right now.';

  @override
  String get importErrorSessionOpen => 'An import is already in progress.';

  @override
  String get importErrorNoOpenSession => 'There is no import in progress.';

  @override
  String get importErrorNothingToImport => 'There is nothing to import.';

  @override
  String get importErrorNotImported => 'Nothing has been imported yet.';

  @override
  String get importErrorNotVerified =>
      'The import has not been checked on the server yet.';

  @override
  String get importErrorVerificationMismatch =>
      'The server copy does not match the local original. The original is kept.';

  @override
  String get importErrorServerCheckFailed =>
      'The server check did not pass. The original is kept.';

  @override
  String get importErrorOriginalMissing => 'The local original is missing.';

  @override
  String get importErrorLocalChanged =>
      'The local copy changed after import. Import it again.';

  @override
  String get profileLoadFailed => 'Profile could not be loaded';

  @override
  String get bookingTitle => 'Booking';

  @override
  String get bookingLoading => 'Loading your booking…';

  @override
  String get bookingSending => 'Sending your request…';

  @override
  String bookingStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'waitlisted': 'On the waitlist',
      'other': 'Inactive',
    });
    return '$_temp0';
  }

  @override
  String bookingSeatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return '$_temp0';
  }

  @override
  String bookingMine(String status, String seats) {
    return 'Your booking: $status · $seats';
  }

  @override
  String get bookingNone => 'You have no booking for this event.';

  @override
  String get bookingReconfirmRequired =>
      'The event changed. Please confirm your attendance.';

  @override
  String bookingReconfirmBy(String deadline) {
    return 'The event changed. Confirm your attendance by $deadline.';
  }

  @override
  String bookingSeatsSelector(int selected, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max seats',
      one: '$max seat',
    );
    return '$selected of $_temp0';
  }

  @override
  String bookingBookSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Book $count seats',
      one: 'Book $count seat',
    );
    return '$_temp0';
  }

  @override
  String get bookingConfirmAttendance => 'Confirm attendance';

  @override
  String get bookingCancel => 'Cancel booking';

  @override
  String get bookingFewerSeats => 'Fewer seats';

  @override
  String get bookingMoreSeats => 'More seats';

  @override
  String get publicationTestPath => 'Test publication path (local Emulator)';

  @override
  String publicationNoDraft(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'No Event draft in Create',
      'place': 'No Place draft in Create',
      'rental': 'No Rental draft in Create',
      'session': 'No Session draft in Create',
      'activity': 'No Activity draft in Create',
      'collection': 'No Collection draft in Create',
      'findPeople': 'No Find People draft in Create',
      'route': 'No Route draft in Create',
      'scenario': 'No Scenario draft in Create',
      'classWorkshop': 'No Class / Workshop draft in Create',
      'other': 'No draft in Create',
    });
    return '$_temp0';
  }

  @override
  String publicationMyObjects(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'My events',
      'place': 'My places',
      'rental': 'My rentals',
      'session': 'My sessions',
      'activity': 'My activities',
      'collection': 'My collections',
      'findPeople': 'My Find People requests',
      'route': 'My routes',
      'scenario': 'My scenarios',
      'classWorkshop': 'My classes and workshops',
      'other': 'My objects',
    });
    return '$_temp0';
  }

  @override
  String publicationMediaUploaded(int count) {
    return 'Media uploaded: $count';
  }

  @override
  String publicationRevision(String revision) {
    return 'Revision $revision';
  }

  @override
  String publicationPublishedVersion(String revision) {
    return 'Published version: $revision';
  }

  @override
  String publicationDraftRevision(String revision) {
    return 'Draft revision: $revision';
  }

  @override
  String publicationDraftRevisionPending(String revision) {
    return 'Draft revision: $revision — unpublished changes; review required';
  }

  @override
  String publicationConflict(String revision) {
    return 'The server has a newer version (revision $revision). Your edit is kept here; nothing was overwritten.';
  }

  @override
  String get publicationNotSaved => 'Not saved to the server';

  @override
  String get publicationNotSavedYet => 'Not saved to the server yet';

  @override
  String get publicationServerDraft => 'Saved as a server draft';

  @override
  String publicationServerRevision(String revision) {
    return 'Server revision $revision';
  }

  @override
  String get publicationNotPrepared => 'Not prepared';

  @override
  String publicationReviewState(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'draft': 'draft',
      'submitted': 'submitted',
      'under_review': 'under review',
      'revision_requested': 'changes requested',
      'rejected': 'rejected',
      'approved_for_publication': 'approved',
      'published': 'published',
      'superseded': 'superseded',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String publicationVisibilityState(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'unpublished': 'not published',
      'visible': 'visible',
      'withdrawn': 'hidden',
      'restricted': 'restricted',
      'archived': 'archived',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String publicationStatusLine(String review, String visibility) {
    return 'Review: $review; visibility: $visibility';
  }

  @override
  String publicationObjectUnavailable(String reason) {
    return 'Unavailable: $reason';
  }

  @override
  String get publicationSave => 'Save';

  @override
  String get publicationSaveToServer => 'Save to server';

  @override
  String get publicationUploadMedia => 'Upload media';

  @override
  String get publicationUploadCover => 'Upload cover';

  @override
  String get publicationSubmit => 'Submit';

  @override
  String get publicationPublish => 'Publish';

  @override
  String get publicationHide => 'Hide';

  @override
  String get publicationSaveMyVersion => 'Save my version';

  @override
  String get publicationActivatePublished => 'Activate published version';

  @override
  String get publicationEditInCreate => 'Edit in Create';

  @override
  String get publicationPrepare => 'Prepare';

  @override
  String get publicationShareLink => 'Share link';

  @override
  String get publicationRevokeLink => 'Revoke link';

  @override
  String get publicationCoverPermission =>
      'I have permission to use the cover image';

  @override
  String get publicationActivityCheckFields =>
      'Check the Activity fields in Create and submit again.';

  @override
  String get publicationCollectionItems => 'Items (server status)';

  @override
  String get findPeopleApproxArea =>
      'Others see only an approximate area (about 1 km). The exact meeting point stays private to you.';

  @override
  String get findPeopleConsentToPublish => 'Consent to publish';

  @override
  String get findPeopleWithdrawConsent => 'Withdraw consent';

  @override
  String get findPeopleConsentNone => 'Consent: not given';

  @override
  String findPeopleConsentState(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'revoked': 'Consent: withdrawn',
      'expired': 'Consent: expired',
      'other': 'Consent: inactive',
    });
    return '$_temp0';
  }

  @override
  String findPeopleConsentActiveUntil(String date) {
    return 'Consent: active until $date';
  }

  @override
  String routeHideEnds(int meters) {
    return 'Hide $meters m at both ends';
  }

  @override
  String get routeHiddenEndsUnknown => 'Hidden ends: unknown';

  @override
  String routeHiddenEnds(String start, String end) {
    return 'Hidden ends: start $start m, end $end m';
  }

  @override
  String get routeTrimRequired =>
      'Recorded GPS: hide at least 200 m at both ends before publishing';

  @override
  String get routeTrimEmpty =>
      'Too short to publish: nothing is left after hiding the ends';

  @override
  String get scenarioShareLost => 'Link issued, answer lost: issue a new link';

  @override
  String scenarioShareUntil(String date, String token) {
    return 'Unlisted link until $date: $token';
  }

  @override
  String collectionMemberStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'eligible': 'Available',
      'unavailable': 'Unavailable',
      'withheld': 'Withheld',
      'unknown': 'Unknown',
      'forbidden': 'Not accessible',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String publicationPageTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Event publication (test)',
      'place': 'Place publication (test)',
      'rental': 'Rental publication (test)',
      'session': 'Session publication (test)',
      'activity': 'Activity publication (test)',
      'collection': 'Collection publication (test)',
      'findPeople': 'Find People publication (test)',
      'route': 'Route publication (test)',
      'scenario': 'Scenario publication (test)',
      'classWorkshop': 'Class / Workshop publication (test)',
      'other': 'Publication (test)',
    });
    return '$_temp0';
  }

  @override
  String publicationSignIn(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Sign in to publish your Event draft',
      'place': 'Sign in to publish your Place draft',
      'rental': 'Sign in to publish your Rental draft',
      'session': 'Sign in to publish your Session draft',
      'activity': 'Sign in to publish your Activity draft',
      'collection': 'Sign in to publish your Collection draft',
      'findPeople': 'Sign in to publish your Find People draft',
      'route': 'Sign in to publish your Route',
      'scenario': 'Sign in to publish your Scenario',
      'classWorkshop': 'Sign in to publish your Class draft',
      'other': 'Sign in to publish your draft',
    });
    return '$_temp0';
  }

  @override
  String get publicationSaveCreateDraftFirst =>
      'Save your Create draft before editing this publication.';

  @override
  String get importPageTitle => 'Import local data (test)';

  @override
  String get commonCancel => 'Cancel';

  @override
  String createTypeName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Event',
      'place': 'Place',
      'rental': 'Rental',
      'session': 'Session',
      'activity': 'Activity',
      'collection': 'Collection',
      'findPeople': 'Find People',
      'route': 'Route',
      'scenario': 'Scenario',
      'classWorkshop': 'Class / Workshop',
      'other': 'Object',
    });
    return '$_temp0';
  }

  @override
  String get importSectionTitle => 'Import local data (local Emulator)';

  @override
  String get importNoSession => 'No import session';

  @override
  String importSessionStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'approved': 'Approved',
      'running': 'Running',
      'paused': 'Paused',
      'completed': 'Completed',
      'failed': 'Failed',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String importSessionProgress(String status, int done, int total) {
    return 'Session: $status, $done of $total';
  }

  @override
  String importPendingCleanups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deleted local copies still to record on the server',
      one: '$count deleted local copy still to record on the server',
    );
    return '$_temp0';
  }

  @override
  String get importFinishCleanup => 'Finish cleanup';

  @override
  String get importDryRun => 'Dry run';

  @override
  String get importApprove => 'Approve import';

  @override
  String get importRun => 'Run';

  @override
  String get importResume => 'Resume';

  @override
  String importClassification(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'create': 'will be created',
      'alreadyMapped': 'already imported',
      'conflict': 'changed since import',
      'unsupported': 'not supported',
      'blocked': 'blocked',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String importReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'type_not_importable': 'this type cannot be imported yet',
      'owner_mismatch': 'belongs to another account',
      'publisher_missing': 'no publisher chosen',
      'publisher_not_eligible': 'you cannot publish for this publisher',
      'local_id': 'has local-only links',
      'unsupported_capability': 'uses features not supported yet',
      'rolled_back': 'import was rolled back',
      'rollback_pending': 'rollback is waiting for the server',
      'cleanup_reserved': 'local copy is being deleted',
      'cleanup_pending': 'deletion still to record',
      'resume': 'import can be resumed',
      'local_changed_since_import': 'changed locally after import',
      'published_by_test_path': 'already published from this device',
      'other': 'other reason',
    });
    return '$_temp0';
  }

  @override
  String importCandidateLine(String type, String classification) {
    return '$type: $classification';
  }

  @override
  String importCandidateLineReason(
    String type,
    String classification,
    String reason,
  ) {
    return '$type: $classification ($reason)';
  }

  @override
  String importItemState(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'created': 'created',
      'mediaUploaded': 'media uploaded',
      'bodySaved': 'content saved',
      'verified': 'verified',
      'failed': 'failed',
      'rollbackPending': 'rollback pending',
      'rolledBack': 'rolled back',
      'cleanupReserved': 'local copy being deleted',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String importServerLine(String contentId, String state) {
    return 'Server $contentId: $state';
  }

  @override
  String importServerLineReason(String contentId, String state, String reason) {
    return 'Server $contentId: $state ($reason)';
  }

  @override
  String importRefused(String reason) {
    return 'Refused: $reason';
  }

  @override
  String importLocalCopy(String state) {
    return 'Local copy: $state';
  }

  @override
  String get importCleanupNotImported => 'kept (not imported)';

  @override
  String get importCleanupAwaitingVerification =>
      'kept (server copy not verified)';

  @override
  String get importCleanupAwaitingConfirmation =>
      'kept (confirm the server copy)';

  @override
  String importCleanupRecovery(String date) {
    return 'kept until $date';
  }

  @override
  String get importCleanupEligible => 'may be deleted';

  @override
  String get importCleanupReserved => 'being deleted (reserved on the server)';

  @override
  String get importCleanupDeleted => 'deleted';

  @override
  String get importCleanupRollbackPending =>
      'kept (rollback waiting for the server)';

  @override
  String get importCleanupRolledBack => 'kept (import rolled back)';

  @override
  String get importAgain => 'Import again';

  @override
  String get importKeepServerCopy => 'Keep the server copy';

  @override
  String get importFinishDeleting => 'Finish deleting local copy';

  @override
  String get importDeleteLocal => 'Delete local copy';

  @override
  String get importKeepLocal => 'Keep local copy';

  @override
  String get importRetryRollback => 'Retry rollback';

  @override
  String get importRollBack => 'Roll back import';

  @override
  String get importRollbackDialogTitle => 'Roll back this import?';

  @override
  String get importRollbackDialogBody =>
      'The imported server draft is closed for good. Your local copy stays and can be imported again later.';

  @override
  String get importRollbackConfirm => 'Roll back';

  @override
  String get notificationsReadAll => 'Mark all as read';

  @override
  String get notificationsLoadFailed => 'Notifications could not be loaded';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsSearchHint => 'Search notifications';

  @override
  String get notificationsClearSearch => 'Clear search';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterNew => 'New';

  @override
  String get notificationsFilterReminders => 'Reminders';

  @override
  String get notificationsFilterUpdates => 'Updates';

  @override
  String get notificationsFilterScenarios => 'Scenarios';

  @override
  String get notificationsActions => 'Notification actions';

  @override
  String get notificationsNoSearchResults => 'Nothing matches your search';

  @override
  String get notificationsFilterEmpty => 'Nothing in this filter yet';

  @override
  String get notificationsShowAll => 'Show all';

  @override
  String notificationDestination(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'legacy': 'Legacy notification',
      'routeMap': 'Route map',
      'map': 'Map',
      'details': 'Details',
      'saved': 'Saved plan',
      'search': 'Search',
      'publishStatus': 'Publish status',
      'create': 'Create',
      'creatorProfile': 'Creator profile',
      'discover': 'Discover',
      'other': 'Update',
    });
    return '$_temp0';
  }

  @override
  String notificationDestinationAction(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'legacy': 'Open',
      'routeMap': 'Open route',
      'map': 'Open map',
      'details': 'Open details',
      'saved': 'Open saved',
      'search': 'Search',
      'publishStatus': 'Open listing',
      'create': 'Open create',
      'creatorProfile': 'Open profile',
      'discover': 'Open feed',
      'other': 'Open',
    });
    return '$_temp0';
  }

  @override
  String get importSignIn => 'Sign in to import your local data';

  @override
  String get validationAPlaceInTheGuideIsNo =>
      'A place in the guide is no longer public. Remove or replace it.';

  @override
  String get validationAPlaceInTheGuideWasNot =>
      'A place in the guide was not found. Remove or replace it.';

  @override
  String get validationAddACoverImage => 'Add a cover image.';

  @override
  String get validationAddACoverPhoto => 'Add a cover photo.';

  @override
  String get validationAddAPricingNote => 'Add a pricing note.';

  @override
  String get validationAddASafetyNoticeForThisCategory =>
      'Add a safety notice for this category.';

  @override
  String get validationAddAShortDescription => 'Add a short description.';

  @override
  String get validationAddATitle => 'Add a title.';

  @override
  String get validationAddAnAddressOrALocationLabel =>
      'Add an address or a location label.';

  @override
  String get validationAddAtLeastThreePlaces => 'Add at least three places.';

  @override
  String get validationAddPlacesToTheGuide => 'Add places to the guide.';

  @override
  String get validationAddTheDeliveryFeeZeroIfFree =>
      'Add the delivery fee (zero if free).';

  @override
  String get validationAddTheEntryPrice => 'Add the entry price.';

  @override
  String get validationAddThePrices => 'Add the prices.';

  @override
  String get validationAddThePublicBusinessAddress =>
      'Add the public business address.';

  @override
  String get validationAddTheRentalTerms => 'Add the rental terms.';

  @override
  String get validationAddTheWeeklyOpeningHours =>
      'Add the weekly opening hours.';

  @override
  String get validationAddWhatYouRentOut => 'Add what you rent out.';

  @override
  String get validationCategoryDataIsUnavailableTryAgainLater =>
      'Category data is unavailable. Try again later.';

  @override
  String get validationCategoryRequirementsAreUnavailableTryAgainLater =>
      'Category requirements are unavailable. Try again later.';

  @override
  String get validationCheckTheAccessCaution => 'Check the access caution.';

  @override
  String get validationCheckTheAmount => 'Check the amount.';

  @override
  String get validationCheckTheBestTime => 'Check the best time.';

  @override
  String get validationCheckTheCategoryCriteria =>
      'Check the category criteria.';

  @override
  String get validationCheckTheContribution => 'Check the contribution.';

  @override
  String get validationCheckTheDescriptionLength =>
      'Check the description length.';

  @override
  String get validationCheckTheDeviceClockAndConfirmThe =>
      'Check the device clock and confirm the availability again.';

  @override
  String get validationCheckTheDurationRange => 'Check the duration range.';

  @override
  String get validationCheckTheEmailAddress => 'Check the email address.';

  @override
  String get validationCheckTheGalleryImages => 'Check the gallery images.';

  @override
  String get validationCheckTheGroupSize => 'Check the group size.';

  @override
  String get validationCheckTheLinkedPlace => 'Check the linked Place.';

  @override
  String get validationCheckTheOpeningTimes => 'Check the opening times.';

  @override
  String get validationCheckTheShortDescriptionLength =>
      'Check the short description length.';

  @override
  String get validationCheckTheTitleLength => 'Check the title length.';

  @override
  String get validationChooseACancellationPolicy =>
      'Choose a cancellation policy.';

  @override
  String get validationChooseACategory => 'Choose a category.';

  @override
  String get validationChooseAContributionKind => 'Choose a contribution kind.';

  @override
  String get validationChooseAKindForThisContribution =>
      'Choose a kind for this contribution.';

  @override
  String get validationChooseASeason => 'Choose a season.';

  @override
  String get validationChooseASubcategoryAvailableForActivity =>
      'Choose a subcategory available for Activity.';

  @override
  String get validationChooseASubcategoryAvailableForPlaces =>
      'Choose a subcategory available for places.';

  @override
  String get validationChooseASubcategoryFromTheCategoryList =>
      'Choose a subcategory from the category list.';

  @override
  String get validationChooseASubcategory => 'Choose a subcategory.';

  @override
  String get validationChooseATimeOfDay => 'Choose a time of day.';

  @override
  String get validationChooseAnOpeningHoursMode =>
      'Choose an opening-hours mode.';

  @override
  String get validationChooseHowTheOpeningHoursWork =>
      'Choose how the opening hours work.';

  @override
  String get validationChooseTheTextLanguage => 'Choose the text language.';

  @override
  String get validationChooseWhatKindOfPlaceItIs =>
      'Choose what kind of place it is.';

  @override
  String get validationChooseWhetherEntryIsFreeOrPaid =>
      'Choose whether entry is free or paid.';

  @override
  String get validationChooseYourRelationshipToThisPlace =>
      'Choose your relationship to this place.';

  @override
  String get validationCompleteThisCategoryCriterion =>
      'Complete this category criterion.';

  @override
  String get validationConfirmTheAvailabilityAgainItIsOlder =>
      'Confirm the availability again; it is older than a week.';

  @override
  String get validationConfirmTheCategory => 'Confirm the category.';

  @override
  String get validationConfirmTheMapPin => 'Confirm the map pin.';

  @override
  String get validationConfirmTheRentalStatements =>
      'Confirm the rental statements.';

  @override
  String get validationConfirmWhenTheItemsAreAvailable =>
      'Confirm when the items are available.';

  @override
  String get validationDescribeHowToGetThere => 'Describe how to get there.';

  @override
  String get validationDescribeTheDamagePolicy => 'Describe the damage policy.';

  @override
  String get validationDescribeTheHandover => 'Describe the handover.';

  @override
  String get validationDescribeTheInformalAccess =>
      'Describe the informal access.';

  @override
  String get validationDescribeTheOptionalContribution =>
      'Describe the optional contribution.';

  @override
  String get validationDoNotWriteTheTitleInCapitals =>
      'Do not write the title in capitals.';

  @override
  String get validationKeepContactsOutOfTheTitle =>
      'Keep contacts out of the title.';

  @override
  String get validationLinkedPlaceIsUnavailableForPublication =>
      'Linked Place is unavailable for publication.';

  @override
  String get validationMakeAtLeastOneItemAvailable =>
      'Make at least one item available.';

  @override
  String get validationMinimumMustNotExceedMaximum =>
      'Minimum must not exceed maximum.';

  @override
  String get validationNameTheArea => 'Name the area.';

  @override
  String get validationNameWhatYouRentOut => 'Name what you rent out.';

  @override
  String get validationOnlySavedPublishedPlacesCanBeAdded =>
      'Only saved, published places can be added.';

  @override
  String get validationOpeningTimesOverlap => 'Opening times overlap.';

  @override
  String get validationPlacesCouldNotBeCheckedTryAgain =>
      'Places could not be checked. Try again later.';

  @override
  String get validationRemoveDuplicateImages => 'Remove duplicate images.';

  @override
  String get validationRemoveSomeGalleryImages => 'Remove some gallery images.';

  @override
  String get validationRemoveSomePlaces => 'Remove some places.';

  @override
  String get validationRemoveThePartFromTheBookingLink =>
      'Remove the # part from the booking link.';

  @override
  String get validationReviewTheGuideAgainItChangedAfter =>
      'Review the guide again: it changed after the review.';

  @override
  String get validationReviewTheGuideBeforeSubmitting =>
      'Review the guide before submitting.';

  @override
  String get validationSaveTheDraftAgainBeforeSubmitting =>
      'Save the draft again before submitting.';

  @override
  String get validationSaveThePlacesInTheGuideBefore =>
      'Save the places in the guide before submitting.';

  @override
  String get validationSeasonalHoursAreNotSupportedYet =>
      'Seasonal hours are not supported yet.';

  @override
  String get validationSetTheLocation => 'Set the location.';

  @override
  String get validationSetTheMapPin => 'Set the map pin.';

  @override
  String get validationSetTheMinimumRenterAge => 'Set the minimum renter age.';

  @override
  String get validationSetTheTypicalDuration => 'Set the typical duration.';

  @override
  String get validationSetValidCoordinates => 'Set valid coordinates.';

  @override
  String get validationShortenACuratorNoteTo300Characters =>
      'Shorten a curator note to 300 characters.';

  @override
  String get validationShortenTheDescription => 'Shorten the description.';

  @override
  String get validationShowTheApproximateAreaAt500M =>
      'Show the approximate area at 500 m or coarser.';

  @override
  String get validationSomePlacesChangedStatusReviewTheGuide =>
      'Some places changed status. Review the guide again.';

  @override
  String get validationTheLinkedPlaceIsNoLongerPublic =>
      'The linked Place is no longer public. Remove or replace it.';

  @override
  String get validationTheLinkedPlaceWasNotFoundRemove =>
      'The linked Place was not found. Remove or replace it.';

  @override
  String get validationThePinIsOutsideTheServiceArea =>
      'The pin is outside the service area.';

  @override
  String get validationTheRentalRulesChangedConfirmTheStatements =>
      'The rental rules changed. Confirm the statements again.';

  @override
  String get validationThisCategoryCannotBeRentedOutHere =>
      'This category cannot be rented out here yet.';

  @override
  String get validationThisCategoryRequiresAnIDAtHandover =>
      'This category requires an ID at handover.';

  @override
  String get validationThisLanguageIsNotSupportedHere =>
      'This language is not supported here.';

  @override
  String get validationUse10140Characters => 'Use 10–140 characters.';

  @override
  String get validationUse10300Characters => 'Use 10–300 characters.';

  @override
  String get validationUse20180Characters => 'Use 20–180 characters.';

  @override
  String get validationUse3120Characters => 'Use 3–120 characters.';

  @override
  String get validationUse580Characters => 'Use 5–80 characters.';

  @override
  String get validationUse715DigitsOnlyAndSpaces =>
      'Use 7–15 digits; only + ( ) . - and spaces besides digits.';

  @override
  String get validationUseADeliveryRadiusUpTo50 =>
      'Use a delivery radius up to 50 km.';

  @override
  String get validationUseAPositiveAmount => 'Use a positive amount.';

  @override
  String get validationUseASecureHttpsBookingLink =>
      'Use a secure https booking link.';

  @override
  String get validationUseASecureHttpsLink => 'Use a secure https link.';

  @override
  String get validationUseAtMost1000Characters =>
      'Use at most 1000 characters.';

  @override
  String get validationUseAtMost12GalleryImages =>
      'Use at most 12 gallery images.';

  @override
  String get validationUseAtMost200Characters => 'Use at most 200 characters.';

  @override
  String get validationUseAtMost300Characters => 'Use at most 300 characters.';

  @override
  String get validationUsePositiveWholeMinutes => 'Use positive whole minutes.';

  @override
  String get validationUsePositiveWholeNumbers => 'Use positive whole numbers.';

  @override
  String get validationUseTheMarketCurrency => 'Use the market currency.';

  @override
  String get validationYourRelationshipToThePlaceDoesNot =>
      'Your relationship to the place does not match how it was added.';

  @override
  String get fieldLabelAddress => 'Address';

  @override
  String get fieldLabelArea => 'Area';

  @override
  String get fieldLabelAvailability => 'Availability';

  @override
  String get fieldLabelBookingLink => 'Booking link';

  @override
  String get fieldLabelCancellationPolicy => 'Cancellation policy';

  @override
  String get fieldLabelCategory => 'Category';

  @override
  String get fieldLabelCategoryCriteria => 'Category criteria';

  @override
  String get fieldLabelCoverImage => 'Cover image';

  @override
  String get fieldLabelCurrency => 'Currency';

  @override
  String get fieldLabelDamagePolicy => 'Damage policy';

  @override
  String get fieldLabelDeliveryFee => 'Delivery fee';

  @override
  String get fieldLabelDeliveryRadius => 'Delivery radius';

  @override
  String get fieldLabelDescription => 'Description';

  @override
  String get fieldLabelDraft => 'Draft';

  @override
  String get fieldLabelEmail => 'Email';

  @override
  String get fieldLabelEntry => 'Entry';

  @override
  String get fieldLabelEntryPrice => 'Entry price';

  @override
  String get fieldLabelGallery => 'Gallery';

  @override
  String get fieldLabelGuideReview => 'Guide review';

  @override
  String get fieldLabelHandover => 'Handover';

  @override
  String get fieldLabelHandoverAddress => 'Handover address';

  @override
  String get fieldLabelHandoverArea => 'Handover area';

  @override
  String get fieldLabelIDAtHandover => 'ID at handover';

  @override
  String get fieldLabelItems => 'Items';

  @override
  String get fieldLabelKindOfPlace => 'Kind of place';

  @override
  String get fieldLabelLocation => 'Location';

  @override
  String get fieldLabelMapPin => 'Map pin';

  @override
  String get fieldLabelMinimumAge => 'Minimum age';

  @override
  String get fieldLabelOpeningHours => 'Opening hours';

  @override
  String get fieldLabelPhone => 'Phone';

  @override
  String get fieldLabelPhotos => 'Photos';

  @override
  String get fieldLabelPlacesInTheGuide => 'Places in the guide';

  @override
  String get fieldLabelPrices => 'Prices';

  @override
  String get fieldLabelPricingNote => 'Pricing note';

  @override
  String get fieldLabelSafetyNotice => 'Safety notice';

  @override
  String get fieldLabelShortDescription => 'Short description';

  @override
  String get fieldLabelStatements => 'Statements';

  @override
  String get fieldLabelSubcategory => 'Subcategory';

  @override
  String get fieldLabelTerms => 'Terms';

  @override
  String get fieldLabelTextLanguage => 'Text language';

  @override
  String get fieldLabelTitle => 'Title';

  @override
  String get fieldLabelWebsite => 'Website';

  @override
  String get fieldLabelYourRelationship => 'Your relationship';

  @override
  String get validationNeededForServer => 'Needed for server publication';

  @override
  String get validationGeneralRefusal =>
      'The server refused this draft. Check the draft and try again.';

  @override
  String validationRequirementLine(String field, String message) {
    return '$field: $message';
  }

  @override
  String get detailsLinkCopied => 'Link copied';

  @override
  String get detailsSavedToFavorites => 'Saved to favorites';

  @override
  String get detailsCalendarExportFailed =>
      'Could not open the calendar export';

  @override
  String get detailsInterestMarked => 'Interest in the event noted';

  @override
  String get detailsCouldNotOpenLink => 'Could not open the link.';

  @override
  String get detailsBookingSiteFailed => 'Could not open the booking site';

  @override
  String get detailsEnrollmentSiteFailed =>
      'Could not open the enrollment site';

  @override
  String get detailsReportSent => 'Thank you. The report was sent for review.';

  @override
  String get detailsReportFailed => 'Could not send the report. Try again.';

  @override
  String get detailsRequestSent => 'Request sent';

  @override
  String get detailsPlaceTimezoneUnavailable =>
      'The place time zone is unavailable';

  @override
  String get detailsVisitWhen => 'When did you visit?';

  @override
  String detailsVisitAdded(String date) {
    return 'Added to Visit history · $date';
  }

  @override
  String get detailsVisitFailed => 'Could not update Visit history';

  @override
  String get detailsLoadFailed => 'Details could not be loaded';

  @override
  String get detailsUnavailable => 'Unavailable';

  @override
  String get detailsRouteUpdated => 'The route was updated';

  @override
  String get detailsRouteUnavailable => 'Route unavailable';

  @override
  String get detailsNoConnection => 'No connection';

  @override
  String get homeFree => 'Free';

  @override
  String get homeAnyTime => 'Any time';

  @override
  String get homeAnyArea => 'Any area';

  @override
  String homeRadiusKm(String km) {
    return '$km km';
  }

  @override
  String homeCardMeta(String price, String time, String venue) {
    return '$price · $time · $venue';
  }

  @override
  String get homeContinueRoute => 'Continue your route';

  @override
  String get homeSavedRoute => 'Saved route';

  @override
  String get homeContinueSavedSearch => 'Continue saved search';

  @override
  String get homeContinueSmartSearch => 'Continue smart search';

  @override
  String get homeSmartRoute => 'Smart route';

  @override
  String get homeCreateFromSavedSearch => 'Create listing from saved search';

  @override
  String get homeCreateFromSmartSearch => 'Create listing from smart search';

  @override
  String get homeNoActivities => 'No activities yet';

  @override
  String get homeViewAll => 'View all';

  @override
  String placeValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'address_or_label_required': 'Add an address or a location label.',
      'busy_time_notes_too_long': 'Shorten the busy-time notes.',
      'category_required': 'Choose a category.',
      'closure_end_invalid': 'The closure end must not be before its start.',
      'closure_note_too_long': 'Shorten the closure note.',
      'closure_start_required': 'Set when the closure starts.',
      'contact_url_invalid': 'Use a valid https link.',
      'contacts_missing': 'Add at least one contact.',
      'country_required': 'Choose the country.',
      'cover_required': 'Add a cover photo.',
      'details_missing': 'The place details are missing.',
      'email_invalid': 'Check the email address.',
      'entrance_hint_too_long': 'Shorten the entrance hint.',
      'entry_price_range_invalid':
          'The minimum price must not exceed the maximum.',
      'entry_price_required': 'Add the entry price.',
      'entry_type_unknown': 'Choose whether entry is free or paid.',
      'full_description_length': 'Shorten the description.',
      'gallery_limit': 'Remove some gallery photos.',
      'hours_exception_date_invalid': 'Check the special-day date.',
      'hours_exception_overlap': 'Special-day hours overlap.',
      'hours_exception_period_invalid': 'Check the special-day hours.',
      'hours_exception_period_required': 'Add hours for the special day.',
      'hours_exception_periods_not_allowed':
          'A closed special day has no hours.',
      'hours_exceptions_not_allowed':
          'Special days are not used in this hours mode.',
      'hours_mode_required': 'Choose how the opening hours work.',
      'hours_overlap': 'Opening times overlap.',
      'hours_period_invalid': 'Check the opening times.',
      'hours_period_required': 'Add the weekly opening hours.',
      'hours_periods_not_allowed': 'This hours mode has no weekly times.',
      'hours_unknown': 'The opening hours are not known yet.',
      'kind_required': 'Choose what kind of place it is.',
      'locale_unsupported': 'This language is not supported here.',
      'market_required': 'The place has no market yet.',
      'minimum_visit_invalid': 'Check the minimum visit time.',
      'minimum_visit_required': 'Set the minimum visit time.',
      'mixed_pricing_note_required': 'Add a pricing note for mixed entry.',
      'outside_market': 'The pin is outside the service area.',
      'permission_denied': 'You cannot publish this place.',
      'phone_invalid': 'Check the phone number.',
      'pin_approximate': 'The map pin is approximate.',
      'pin_invalid': 'Set valid coordinates.',
      'pin_unconfirmed': 'Confirm the map pin.',
      'price_negative': 'A price cannot be negative.',
      'pricing_note_too_long': 'Shorten the pricing note.',
      'pricing_url_invalid': 'Use a valid https price link.',
      'publisher_invalid': 'Choose who publishes this place.',
      'seasonal_not_supported': 'Seasonal hours are not supported yet.',
      'short_description_length':
          'Use 20–180 characters in the short description.',
      'spend_range_invalid': 'The minimum spend must not exceed the maximum.',
      'subcategory_required': 'Choose a subcategory.',
      'timezone_required': 'The place has no time zone.',
      'title_all_caps': 'Do not write the title in capitals.',
      'title_contact': 'Keep contacts out of the title.',
      'title_length': 'Use 3–120 characters in the title.',
      'visit_buffer_invalid': 'Check the visit buffer.',
      'visit_duration_invalid': 'Check the typical visit duration.',
      'other': 'Check this part of the place.',
    });
    return '$_temp0';
  }

  @override
  String placeValidationSection(String section) {
    String _temp0 = intl.Intl.selectLogic(section, {
      'identity': 'Basics',
      'category': 'Category',
      'location': 'Location',
      'contacts': 'Contacts',
      'hours': 'Opening hours',
      'pricing': 'Prices',
      'planning': 'Visit planning',
      'media': 'Photos',
      'other': 'Place',
    });
    return '$_temp0';
  }

  @override
  String get placeFinalChecks => 'Final checks';

  @override
  String sessionValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'session_category_not_allowed':
          'This category is not available for sessions.',
      'session_resource_missing': 'Name what is booked and set its time zone.',
      'session_timezone_invalid': 'Confirm the time zone.',
      'session_schedule_empty': 'Add at least one time slot.',
      'session_weekday_invalid': 'Check the weekdays.',
      'session_range_invalid': 'Check the start and end times.',
      'session_range_overlap': 'Time slots overlap.',
      'session_duration_out_of_range': 'Check the session length.',
      'session_buffer_out_of_range': 'Check the break between sessions.',
      'session_notice_out_of_range': 'Check the booking notice.',
      'session_projection_overflow':
          'The schedule creates too many sessions. Shorten it.',
      'session_exception_invalid': 'Check the exceptions.',
      'session_party_size_out_of_range': 'Check the group size.',
      'session_price_invalid': 'Check the price.',
      'session_booking_url_invalid': 'Use a secure https booking link.',
      'session_media_incomplete': 'Add the required photos.',
      'session_publisher_ineligible':
          'You cannot publish on behalf of this profile or page.',
      'session_legacy_review_required':
          'Review this older draft before publishing.',
      'session_no_offers_in_window': 'No sessions fall into the coming weeks.',
      'session_candidates_dropped_for_buffer':
          'Some times were skipped to keep the breaks.',
      'session_dst_slots_skipped':
          'Some times were skipped at the clock change.',
      'session_external_state_unknown':
          'The booking site state could not be checked.',
      'session_material_revision':
          'This change will ask booked guests to confirm again.',
      'session_category_criteria_incomplete': 'Complete the category criteria.',
      'other': 'Check this part of the session.',
    });
    return '$_temp0';
  }

  @override
  String get sessionFixBeforePublishing => 'Fix before publishing';

  @override
  String routeValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'route_too_short': 'The route is too short.',
      'route_too_long': 'The route is too long.',
      'route_duration_too_long': 'The route takes too long.',
      'loop_must_close': 'A loop must end where it starts.',
      'one_way_must_not_close': 'A one-way route must not end where it starts.',
      'out_and_back_must_return':
          'An out-and-back route must return to the start.',
      'anchors_too_few': 'Add more points to the route.',
      'segments_missing': 'Build the route between the points.',
      'manual_duration_reason_required':
          'Explain why you changed the duration.',
      'provider_license_disallows_publish':
          'This map data cannot be published.',
      'temporary_id_not_publishable': 'Save the route before publishing.',
      'family_segment': 'A route segment needs attention.',
      'family_waypoint': 'A point on the route needs attention.',
      'family_anchor': 'Check the route points.',
      'family_condition': 'Check the route conditions.',
      'family_duration': 'Check the route duration.',
      'family_data': 'The route data is out of date. Rebuild the route.',
      'other': 'Check this part of the route.',
    });
    return '$_temp0';
  }

  @override
  String routeValidationSection(String section) {
    String _temp0 = intl.Intl.selectLogic(section, {
      'route': 'Route',
      'geometry': 'Track',
      'metrics': 'Distance and time',
      'operations': 'Edits',
      'profile': 'Profile',
      'quality': 'Quality',
      'relations': 'Points',
      'sources': 'Sources',
      'waypoints': 'Points of interest',
      'conditions': 'Conditions',
      'other': 'Route',
    });
    return '$_temp0';
  }

  @override
  String routeIssueLine(String message, String section) {
    return '• $message — $section';
  }

  @override
  String classWorkshopEnrollmentReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'closed': 'Enrollment closed',
      'on_site': 'Enroll on site',
      'not_provided': 'No enrollment details',
      'other': 'Enrollment information',
    });
    return '$_temp0';
  }

  @override
  String scenarioValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'schema_version_unsupported': 'Scenario schema version is unsupported',
      'revision_negative': 'Revision cannot be negative',
      'default_timezone_invalid': 'Choose a valid IANA timezone',
      'display_currency_invalid':
          'Display currency must use a three-letter ISO code',
      'days_minimum': 'A Scenario must contain at least one calendar day',
      'days_limit': 'A Scenario can contain at most 30 days',
      'items_limit': 'A Scenario can contain at most 250 items',
      'unscheduled_items_limit': 'Keep at most 50 unscheduled items',
      'day_index_not_contiguous':
          'Day indices must form a continuous 0-based sequence',
      'day_item_duplicate': 'An item can appear only once in a day',
      'item_scheduled_multiple_days': 'An item can belong to only one day',
      'day_item_dangling': 'Day references a missing item',
      'item_day_mismatch': 'Item dayId must match its day membership',
      'unscheduled_item_duplicate': 'Unscheduled item ids must be unique',
      'unscheduled_item_dangling': 'Unscheduled list references a missing item',
      'unscheduled_item_has_day': 'An unscheduled item cannot belong to a day',
      'item_missing_from_day': 'Scheduled item must appear in its day itemIds',
      'item_orphaned': 'Item must be scheduled or explicitly unscheduled',
      'active_items_limit': 'A Scenario can contain at most 200 active items',
      'active_items_minimum': 'Add at least two active scheduled items',
      'temporary_id_not_materialized':
          'Temporary local ids must be replaced before saving',
      'temporary_catalog_reference':
          'Catalog references require permanent object ids',
      'private_location_in_distribution':
          'Private locations cannot enter a distributed payload',
      'mandatory_item_unscheduled': 'Mandatory items must be scheduled',
      'mandatory_source_unavailable':
          'Replace or remove the unavailable mandatory item',
      'start_requires_dated_mode': 'Starting a Scenario requires real dates',
      'party_size_invalid': 'Party size must be between 1 and 100',
      'children_count_invalid': 'Children count must fit the party size',
      'budget_invalid': 'Budget must be non-negative and use an ISO currency',
      'travel_modes_empty': 'Choose at least one allowed travel mode',
      'primary_travel_mode_not_allowed': 'Primary travel mode must be allowed',
      'vehicle_profile_invalid': 'Vehicle passenger seats must be valid',
      'travel_limit_negative': 'Travel limits cannot be negative',
      'day_id_missing': 'Day id is required',
      'dated_day_date_missing':
          'Dated Scenario days require a valid local date',
      'dated_day_timezone_missing':
          'Dated Scenario days require an IANA timezone',
      'template_day_has_date': 'Template days must not store real dates',
      'day_location_dangling': 'Day references a missing location',
      'location_invalid': 'Location requires an id and valid coordinates',
      'location_source_incomplete':
          'Location source type and id must be set together',
      'item_id_missing': 'Item id is required',
      'item_day_dangling': 'Item references a missing day',
      'item_location_dangling': 'Item references a missing location',
      'item_duration_missing': 'Item requires a positive duration',
      'mandatory_item_not_selected': 'Mandatory items are always selected',
      'alternative_group_missing': 'Alternative items require a group id',
      'alternative_group_unexpected':
          'Only alternative items can belong to an alternative group',
      'source_stale': 'Source snapshot is stale and should be refreshed',
      'source_unresolved':
          'Resolve the item source before distribution or start',
      'planned_schedule_stale':
          'Planned schedule is stale and must be rechecked',
      'item_source_incompatible': 'Item kind and source are incompatible',
      'schedule_date_mode_mismatch':
          'Schedule representation must match Scenario date mode',
      'template_day_range_invalid': 'Template day range is invalid',
      'fixed_start_missing': 'Fixed dated items require a start instant',
      'fixed_interval_invalid': 'Fixed end must be after fixed start',
      'window_bounds_missing':
          'Window schedule requires valid start and end times',
      'window_order_invalid': 'Same-day window end must be after its start',
      'window_day_offset_invalid': 'Window day offset can only be 0 or 1',
      'cost_component_invalid':
          'Cost component knowledge and amount are inconsistent',
      'cost_confidence_invalid':
          'Estimated price confidence must be between 0 and 1',
      'cost_confidence_unexpected': 'Only estimated prices can have confidence',
      'cost_basis_duplicate':
          'Price basis cannot be duplicated in one component',
      'cost_unknown': 'Item price is unknown',
      'cost_basis_overlap': 'Per-person price overlaps adult or child pricing',
      'alternative_limit':
          'Use at most 20 alternative groups with 5 items each',
      'alternative_multiple_selected':
          'Only one alternative can be selected in a group',
      'leg_reference_invalid':
          'Leg contains a dangling or incomplete reference',
      'leg_value_negative': 'Leg distance and duration cannot be negative',
      'manual_logistics': 'Travel time was entered manually',
      'schedule_snapshot_missing': 'Scheduled travel requires a plan snapshot',
      'schedule_stale': 'Planned schedule is stale and must be rechecked',
      'multi_day_format_disabled':
          'Weekend and trip formats require the multi-day capability',
      'multi_day_disabled':
          'Multi-day data is present while the capability is disabled',
      'item_capability_disabled':
          'Active item uses a disabled Scenario capability',
      'multi_currency_disabled':
          'Foreign-currency costs require the multi-currency capability',
      'day_id_duplicate': 'Identifiers must be unique',
      'location_id_duplicate': 'Identifiers must be unique',
      'item_id_duplicate': 'Identifiers must be unique',
      'leg_id_duplicate': 'Identifiers must be unique',
      'title_required': 'Give the Scenario a title',
      'data_missing': 'Scenario data is missing',
      'other': 'Check this part of the Scenario.',
    });
    return '$_temp0';
  }

  @override
  String findPeopleValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'details_missing': 'Find People details are missing',
      'category_required': 'Choose a category',
      'subcategory_required': 'Choose a subcategory',
      'tags_limit': 'Use no more than 8 tags',
      'languages_count': 'Choose 1–3 communication languages',
      'language_invalid': 'Language codes must use BCP-47 format',
      'house_rules_limit': 'Use no more than 10 house rules',
      'public_contact_forbidden':
          'Public text cannot contain contacts, payment links, or messenger handles',
      'single_slot_count': 'Single schedule requires exactly one slot',
      'poll_slot_count': 'Time poll requires at least two options',
      'recurring_slots':
          'Recurring schedule needs at least one materialized slot',
      'recurrence_rule': 'Add a recurrence rule',
      'recurrence_horizon': 'Recurring schedule must have a finite horizon',
      'occurrence_limit': 'Occurrence count must be between 2 and 52',
      'slot_duration': 'Each slot must last from 30 minutes to 24 hours',
      'slot_overlap': 'Schedule options cannot overlap',
      'poll_deadline': 'Poll deadline must be before the first option',
      'application_deadline':
          'Application deadline must be before the first meeting',
      'scheduled_publish': 'Scheduled publish must be before the first meeting',
      'meeting_name': 'Add a public meeting place',
      'public_area': 'Add a safe public area label',
      'public_geo': 'Add a valid approximate public map point',
      'exact_geo': 'Add a valid exact meeting point',
      'exact_address': 'Add the private exact address',
      'public_place': 'Confirm that the meeting point is a public place',
      'unsafe_location':
          'Private homes and residential access details are not allowed',
      'online_geo_forbidden':
          'Online requests cannot publish fake map coordinates or an address',
      'online_provider': 'Choose an online provider',
      'online_secret': 'Add a private session-scoped access reference',
      'offline_secret_forbidden':
          'In-person requests cannot contain online access data',
      'group_size': 'Group size must be between 2 and 20',
      'host_seats': 'Host seats must be lower than total group size',
      'party_disabled':
          'Single-person applications must reserve exactly one seat',
      'party_seats': 'Party applications can request 1–4 available seats',
      'questions_limit': 'Use no more than 8 application questions',
      'question_invalid': 'Every application question needs an ID and prompt',
      'invite_visibility':
          'Invite-only approval requires invite-only visibility',
      'visibility_approval':
          'Invite-only visibility requires invite-only approval',
      'estimated_cost':
          'Estimated cost requires a positive amount and currency',
      'cost_amount_forbidden': 'Only estimated cost can contain an amount',
      'expense_items': 'Itemized split requires planned expense items',
      'expense_invalid':
          'Every expense item needs an ID, category, and positive amount',
      'publisher': 'Publisher is required',
      'responsible_host': 'At least one responsible host is required',
      'page_host': 'A page request needs a responsible host',
      'cohost_grants': 'Co-host grants must use supported capabilities',
      'quiet_hours': 'Quiet-hour minutes must be between 0 and 1439',
      'safety_rules': 'Accept the Find People safety rules',
      'accuracy': 'Confirm that the request details are accurate',
      'adult_only': 'Confirm that this request is for adults 18+',
      'publisher_host_mismatch':
          'A personal request must include its owner as responsible host',
      'title_length': 'Check the title length',
      'shortDescription_length': 'Check the short description length',
      'fullDescription_length': 'Check the full description length',
      'equipmentNotes_length': 'Shorten the equipment notes',
      'accessibilityNotes_length': 'Shorten the accessibility notes',
      'houseRulesNote_length': 'Shorten the house rules note',
      'meetingInstructions_length': 'Shorten the meeting instructions',
      'costNote_length': 'Shorten the cost note',
      'other': 'Check this part of the request.',
    });
    return '$_temp0';
  }

  @override
  String findPeopleLengthIssue(String field, int min, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp1 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp2 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp3 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp4 = intl.Intl.selectLogic(field, {
      'title': 'Title must contain $min–$_temp0',
      'shortDescription': 'Short description must contain $min–$_temp1',
      'fullDescription': 'Full description must contain $min–$_temp2',
      'other': 'Use $min–$_temp3',
    });
    return '$_temp4';
  }

  @override
  String findPeopleMaxLengthIssue(String field, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp1 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp2 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp3 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp4 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp5 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    String _temp6 = intl.Intl.selectLogic(field, {
      'equipmentNotes': 'Equipment notes cannot exceed $_temp0',
      'accessibilityNotes': 'Accessibility notes cannot exceed $_temp1',
      'houseRulesNote': 'House rules note cannot exceed $_temp2',
      'meetingInstructions': 'Meeting instructions cannot exceed $_temp3',
      'costNote': 'Cost note cannot exceed $_temp4',
      'other': 'Use at most $_temp5',
    });
    return '$_temp6';
  }

  @override
  String eventValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'event_data_missing': 'Event details are unavailable. Reopen the draft.',
      'event_schema_unsupported':
          'This Event draft was created by a newer app version.',
      'event_publisher_unsupported':
          'This Event uses an unsupported publisher contract.',
      'event_publisher_required': 'Choose who publishes this Event.',
      'event_classification_unsupported':
          'This Event uses a classification from a newer app version.',
      'title_required': 'Add a title of at least 3 characters.',
      'taxonomy_required': 'Choose a category and subcategory.',
      'short_description_required':
          'Add a short description of at least 10 characters.',
      'cover_required': 'Add a cover image.',
      'cover_alt_required': 'Describe the cover image for accessibility.',
      'media_rights_required': 'Confirm that you may publish this media.',
      'gallery_alt_required': 'Describe every gallery image for accessibility.',
      'city_required': 'Choose the event city.',
      'location_required': 'Add an address or a clear meeting point.',
      'location_coordinates_required':
          'Place a valid map pin for the physical location.',
      'location_pin_unconfirmed': 'Confirm the physical location pin.',
      'online_access_required': 'Choose how attendees receive online access.',
      'public_online_url_invalid': 'Use a valid HTTPS online event URL.',
      'online_access_registration_conflict':
          'External online access requires external registration.',
      'timezone_required': 'Choose an IANA timezone.',
      'duration_invalid': 'Duration must be positive.',
      'local_start_date_invalid':
          'Use a valid local date in YYYY-MM-DD format.',
      'start_minute_invalid': 'Choose a valid local start time.',
      'all_day_duration_invalid':
          'All-day duration must be a whole number of days.',
      'multi_dates_required': 'Add at least one date.',
      'multi_date_invalid': 'Every date must use the YYYY-MM-DD format.',
      'recurrence_invalid': 'Configure a valid recurrence rule.',
      'recurrence_weekday_invalid': 'Weekdays must be between 1 and 7.',
      'recurrence_exception_invalid':
          'Every excluded date must use the YYYY-MM-DD format.',
      'recurrence_until_required': 'Choose the final local date.',
      'recurrence_until_invalid':
          'Use a valid final date in YYYY-MM-DD format.',
      'recurrence_count_required': 'Occurrence count must be positive.',
      'occurrences_required':
          'The schedule must produce at least one occurrence.',
      'future_occurrence_required': 'Add at least one future occurrence.',
      'age_min_invalid': 'Minimum age cannot be negative.',
      'age_max_invalid': 'Maximum age cannot be negative.',
      'age_range_invalid': 'Maximum age must not be below minimum age.',
      'free_price_conflict': 'Free events cannot collect a mandatory payment.',
      'fixed_price_required': 'Enter a positive fixed price.',
      'payment_mode_unavailable':
          'Choose onsite or external payment for this slice.',
      'pricing_capability_unavailable':
          'Ticket types and donations require a later capability slice.',
      'event_admission_unsupported':
          'This Event uses a newer or unsupported admission contract.',
      'event_inventory_unsupported':
          'This Event uses a newer or unsupported inventory contract.',
      'event_admission_required': 'Confirm the Event admission configuration.',
      'event_inventory_authority_required':
          'Confirm who, if anyone, owns Event inventory.',
      'internal_registration_v1_unsupported':
          'This configuration is outside local internal registration v1.',
      'external_booking_url_invalid': 'Use a valid HTTPS registration URL.',
      'internal_booking_unavailable':
          'Internal Booking is not enabled in this slice.',
      'private_access_unavailable':
          'Private access requires a later protected-access slice.',
      'event_access_contract_unsupported':
          'This Event uses a newer access contract and cannot be changed here.',
      'capacity_required': 'Enter a positive capacity.',
      'capacity_mode_conflict':
          'Unknown or unlimited capacity cannot store a numeric limit.',
      'admission_axes_incomplete':
          'Choose admission, registration and confirmation modes.',
      'open_entry_axes_conflict':
          'Open entry requires no registration and no confirmation.',
      'interest_policy_not_non_reserving':
          'Optional interest cannot create a booking or reserve inventory.',
      'guest_capacity_bypass_unsupported':
          'Guests must count against visitor capacity.',
      'guest_limit_required':
          'Plus-N guest policy requires a positive guest limit.',
      'guest_limit_mode_conflict':
          'Only Plus-N guest policy stores a custom guest limit.',
      'eligibility_rule_id_invalid':
          'Eligibility rules require unique stable IDs.',
      'eligibility_policy_ref_invalid':
          'Eligibility policy references cannot contain secret values.',
      'eligibility_policy_not_ready':
          'Eligibility policy reference is not available in this runtime.',
      'external_registration_handoff_required':
          'External registration requires a safe HTTPS handoff.',
      'cancellation_deadline_required':
          'Choose when cancellation closes before the start.',
      'cancellation_deadline_invalid':
          'Cancellation can close 0 to 10080 minutes before the start.',
      'guest_policy_required': 'Choose a guest policy, including \"none\".',
      'internal_registration_not_ready':
          'Internal registration is configuration-only until ECL-03.',
      'provider_confirmation_not_ready':
          'Provider-managed confirmation requires a verified provider.',
      'lottery_not_ready':
          'Lottery requires an application window and auditable selector.',
      'waitlist_not_ready':
          'Active waitlist requires finite authoritative inventory lifecycle.',
      'waitlist_offer_ttl_required':
          'Automatic waitlist requires a positive offer TTL.',
      'access_window_must_be_relative':
          'Multi-date and recurring access windows must be occurrence-relative.',
      'absolute_access_window_invalid':
          'Absolute access must open before it closes and close before start.',
      'access_window_kind_conflict':
          'The access window type does not match its values.',
      'relative_access_window_invalid':
          'Relative opening offset must be greater than closing offset.',
      'inventory_authority_none_conflict':
          'No inventory authority cannot own shapes or pools.',
      'inventory_primary_shape_required': 'Choose a primary inventory shape.',
      'inventory_pools_required':
          'Configured inventory authority requires at least one pool.',
      'inventory_shape_duplicate':
          'Primary shape cannot be repeated as an additional shape.',
      'inventory_pool_id_invalid': 'Inventory pools require unique stable IDs.',
      'inventory_pool_label_required':
          'Every inventory pool needs a public label.',
      'inventory_pool_shape_unconfigured':
          'Every pool shape must be selected in the inventory configuration.',
      'inventory_pool_capacity_required':
          'Known inventory pool capacity must be positive.',
      'inventory_pool_capacity_conflict':
          'Unknown or unlimited pool cannot store numeric capacity.',
      'inventory_pool_roles_required':
          'Role-based pools require neutral role IDs.',
      'inventory_pool_roles_invalid':
          'Role IDs must be unique neutral identifiers.',
      'inventory_pool_zone_required':
          'Zone and table pools require a stable public reference.',
      'inventory_provider_pool_ref_invalid':
          'Provider pool references must be opaque identifiers.',
      'inventory_pool_total_exceeds_event_capacity':
          'Pool capacity exceeds Event capacity.',
      'hybrid_onsite_pool_required':
          'Finite physical capacity requires a bounded onsite pool.',
      'assigned_seating_not_ready':
          'Assigned seating requires an authoritative hold API.',
      'recharge_inventory_not_ready':
          'Recharge inventory is configuration-only until ECL-03.',
      'external_inventory_not_ready':
          'External inventory requires verified provider references and freshness.',
      'event_archetype_required': 'Choose how this event is organized.',
      'primary_participation_required': 'Choose the attendee\'s primary role.',
      'additional_participation_limit':
          'Choose no more than three additional attendee roles.',
      'participation_mode_duplicate':
          'The primary role cannot also be an additional role.',
      'event_archetype_other_reason_required':
          'Explain the event mechanics when choosing Other.',
      'event_archetype_other_moderation_review':
          'Other mechanics will be reviewed after submission.',
      'other': 'Check this part of the Event.',
    });
    return '$_temp0';
  }

  @override
  String eventAdmissionPresetIssue(String field) {
    String _temp0 = intl.Intl.selectLogic(field, {
      'admissionMode': 'Choose RSVP or booking before applying this preset.',
      'confirmationMode':
          'Choose how registration is confirmed before applying this preset.',
      'registrationMode': 'Choose internal or external team registration.',
      'other': 'Choose the admission settings before applying this preset.',
    });
    return '$_temp0';
  }

  @override
  String collectionValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'details_missing': 'Collection details are missing',
      'title_required': 'Add a title',
      'area_required': 'Add an area or city',
      'min_items': 'Add more items',
      'duplicate_item': 'An item is added more than once',
      'orphan_section': 'An item points to a section that does not exist',
      'curator_note_length': 'Shorten the curator note',
      'composition_review_missing':
          'Review the live composition before publishing',
      'composition_review_stale':
          'Some unavailable items were not part of the last review',
      'curator_note_empty': 'Say why this item is in the Collection',
      'item_count_high':
          'This Collection has many items — consider grouping them into sections or splitting it',
      'self_publisher_share_high':
          'Most items in this Collection are your own — consider adding independent picks too',
      'other': 'Check this part of the Collection.',
    });
    return '$_temp0';
  }

  @override
  String collectionMinItemsIssue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return 'Add at least $_temp0';
  }

  @override
  String collectionCuratorNoteLengthIssue(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '$max character',
    );
    return 'Curator note cannot exceed $_temp0';
  }

  @override
  String collectionItemCountHighIssue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return 'This Collection has $_temp0 — consider grouping them into sections or splitting it';
  }

  @override
  String classWorkshopValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'offering_kind': 'Choose the offering kind',
      'title': 'Add a title',
      'short_description': 'Add a short description',
      'full_description': 'Add a full description',
      'media': 'Add a cover and confirm image rights',
      'outcomes': 'Add an outcome',
      'modules': 'Add a programme step',
      'prerequisites': 'Choose prerequisites or \"No prerequisites\"',
      'take_home_result': 'Describe the result participants take home',
      'instructor': 'Add the instructor name and bio',
      'instructor_bio': 'A masterclass needs the instructor bio',
      'occurrences': 'Check the dates',
      'timezone': 'Confirm the timezone',
      'legacy_schedule': 'Clear the old schedule before publishing',
      'location': 'Confirm the location',
      'safe_area_label': 'Add the public area label',
      'online_provider_label': 'Name the online provider',
      'price': 'Add the amount and what it covers',
      'enrollment': 'Add the external enrollment link',
      'other': 'Check this part of the class.',
    });
    return '$_temp0';
  }

  @override
  String classWorkshopOccurrencesIssue(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'single': 'A single class has exactly one date',
      'series': 'A series has at least two dates',
      'other': 'Check the dates',
    });
    return '$_temp0';
  }

  @override
  String createAvailabilityIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'buffers_negative': 'Buffers cannot be negative',
      'minimum_visit_required':
          'Minimum visit duration is required for partial attendance',
      'slots_required': 'Add at least one schedule slot',
      'slots_hours_conflict': 'Slots and opening hours cannot be combined',
      'opening_hours_required': 'Add at least one opening-hours rule',
      'availability_not_empty':
          'Availability data must be empty when kind is none',
      'slot_order_invalid': 'Slot end must be after start',
      'opening_rule_target_invalid':
          'Each rule needs either weekday or exception date',
      'opening_weekday_invalid': 'Weekday must be from 1 to 7',
      'opening_times_required': 'Open and close times are required',
      'other': 'Check this field',
    });
    return '$_temp0';
  }

  @override
  String quickPlanConversionIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'sourceNotFoundOrForbidden':
          'Quick Plan is unavailable or cannot be copied',
      'sourceRevisionMismatch': 'Quick Plan changed. Review it and try again',
      'selectionEmpty': 'Select at least one stop to expand',
      'stopUnavailable':
          'A stop is unavailable and must be resolved in Scenario',
      'privateNoteNotCopied': 'A private note was not copied',
      'legacySourceIdentityMissing':
          'A stop was copied as a private custom location because the old plan has no catalog object',
      'stopNotFound': 'Selected stop no longer exists',
      'other': 'Check this stop.',
    });
    return '$_temp0';
  }

  @override
  String activityValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'access_caution_note_length': 'Use at most 200 characters.',
      'access_caution_note_required': 'Describe the informal access.',
      'access_notes_length': 'Use 10–300 characters.',
      'access_notes_required': 'Describe how to get there.',
      'category_required': 'Choose a category.',
      'contribution_amount_not_positive': 'Use a positive amount.',
      'contribution_currency_unsupported': 'Use the market currency.',
      'contribution_note_length': 'Use 10–140 characters.',
      'contribution_note_required': 'Describe the optional contribution.',
      'cover_image_required': 'Add a cover image.',
      'duration_not_positive': 'Use positive whole minutes.',
      'duration_range_invalid': 'Minimum must not exceed maximum.',
      'full_description_length': 'Use at most 1000 characters.',
      'group_size_not_positive': 'Use positive whole numbers.',
      'group_size_range_invalid': 'Minimum must not exceed maximum.',
      'location_coordinates_required': 'Set valid coordinates.',
      'pin_confirmation_required': 'Confirm the map pin.',
      'short_description_length': 'Use 20–180 characters.',
      'subcategory_not_applicable':
          'Choose a subcategory available for Activity.',
      'title_length': 'Use 5–80 characters.',
      'contribution_amount_needs_kind': 'Choose a kind for this contribution',
      'criterion_required': 'Complete this category criterion',
      'details_missing': 'Activity details are missing',
      'duration_out_of_recommended_range':
          'The duration is outside the usual range for this category',
      'group_size_out_of_recommended_range':
          'The group size is outside the usual range for this category',
      'informal_access_notice':
          'This place has informal access. Describe it carefully',
      'other': 'Check this part of the activity.',
    });
    return '$_temp0';
  }

  @override
  String rentalValidationIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'title_length': 'Use 3–80 characters for the title',
      'short_description_length':
          'Use 20–240 characters for the short description',
      'full_description_length':
          'Use 50–4000 characters for the full description',
      'category_not_whitelisted': 'This category is not available for rentals',
      'category_not_confirmed': 'Confirm the category',
      'inventory_group_count': 'Add 1–50 groups of items',
      'no_available_group': 'Mark at least one group as available',
      'group_quantity_range': 'Quantity must be from 1 to 999',
      'group_size_required': 'Add the size for this group',
      'availability_timezone_missing': 'Choose the time zone',
      'availability_coverage_missing':
          'Say how availability is kept up to date',
      'block_unknown_group':
          'A blocked period refers to a group that does not exist',
      'block_interval_invalid': 'A blocked period must end after it starts',
      'pickup_place_name_missing': 'Add the pickup place name',
      'public_geo_missing': 'Set the public map point',
      'approximate_area_has_address':
          'An approximate area must not contain an exact address',
      'business_address_missing': 'Add the public business address',
      'opening_hours_missing': 'Add the opening hours',
      'delivery_radius_missing': 'Add the delivery radius',
      'delivery_fee_missing': 'Add the delivery fee (zero if free)',
      'duration_bounds_invalid': 'Check the minimum and maximum rental time',
      'billing_unit_exceeds_min_duration':
          'The billing unit cannot be longer than the minimum rental time',
      'min_renter_age_required': 'Set the minimum renter age for this category',
      'id_required_at_handover':
          'This category requires an ID check at handover',
      'safety_notice_required': 'Add a safety notice for this category',
      'currency_invalid': 'Use a three-letter currency code',
      'rate_steps_missing': 'Add the prices',
      'rate_first_step_not_one':
          'The first price step must start from one unit',
      'rate_steps_not_increasing': 'Price steps must go up in units',
      'rate_price_increases': 'A longer rental cannot cost more per unit',
      'rate_step_currency_or_sign': 'Use one currency and positive prices',
      'deposit_currency_mismatch': 'The deposit must use the price currency',
      'deposit_zero_requires_none':
          'A zero deposit cannot have a collection method',
      'deposit_nonzero_requires_method': 'Choose how the deposit is collected',
      'deposit_terms_missing': 'Add the deposit terms',
      'damage_policy_missing': 'Add the damage policy',
      'cancellation_policy_missing': 'Choose a cancellation policy',
      'external_url_missing': 'Add the booking link',
      'external_url_not_https': 'Use a secure https booking link',
      'attestation_incomplete': 'Confirm all statements before publishing',
      'other': 'Check this part of the rental.',
    });
    return '$_temp0';
  }

  @override
  String createNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'template_store_unavailable': 'Template storage is unavailable.',
      'template_saved': 'Template saved.',
      'template_renamed': 'Template renamed.',
      'template_updated': 'Template updated.',
      'template_deleted': 'Template deleted.',
      'template_applied': 'Template applied.',
      'template_invalid': 'This template is invalid.',
      'template_action_failed': 'The template action could not be completed.',
      'route_create_not_allowed': 'This account cannot create routes.',
      'collection_create_not_allowed':
          'This account cannot create collections.',
      'scenario_preview_stale': 'Scenario changed. Generate a fresh preview.',
      'scenario_preview_failed':
          'Could not build this local demo preview. Try again.',
      'scenario_title_required': 'Add a title before saving',
      'scenario_blocking_issues': 'Resolve the blocking Scenario issues',
      'scenario_unavailable': 'Scenario is no longer available.',
      'scenario_open_failed': 'Could not open this Scenario.',
      'scenario_public_publish_disabled':
          'Public Scenario publishing is not enabled yet. Save it to My Scenarios.',
      'classification_role_limit':
          'You can choose up to three additional roles',
      'classification_changed':
          'Classification changed. Review the current draft.',
      'admission_preview_stale':
          'Admission configuration changed. Preview the preset again.',
      'admission_legacy_review':
          'An older admission suggestion must be reviewed again.',
      'step_required_fields': 'Check the required fields of this step',
      'required_fields': 'Check the required fields',
      'place_helper_failed':
          'The local helper could not review this draft. Manual creation still works.',
      'place_suggestions_applied':
          'Local suggestions applied. Review them before publishing.',
      'place_helper_stale': 'The draft changed. Run the local review again.',
      'route_editor_loading': 'The Route editor is still loading.',
      'route_draft_saved': 'Route draft saved',
      'route_segments_busy': 'Wait until the segment operations finish.',
      'route_save_failed':
          'Could not save the Route. The draft stays in the form.',
      'draft_saved': 'Draft saved',
      'draft_save_failed': 'Could not save. Your data stays in the form.',
      'publisher_page_unavailable':
          'Publishing as this page is unavailable: access was revoked or restricted. The draft is saved.',
      'publisher_unavailable':
          'Publishing is unavailable for this owner. The draft is saved.',
      'place_duplicates_review': 'Review similar places before publishing',
      'warnings_confirm': 'Confirm the warnings before publishing',
      'submit_failed': 'Could not send. The draft is saved, try again.',
      'published': 'Published',
      'submitted_for_review': 'Sent for review',
      'route_publication_unavailable':
          'The Route publication service is unavailable.',
      'route_not_published': 'The Route was not published. The draft is saved.',
      'route_published': 'Route published.',
      'route_submitted': 'Route sent for review.',
      'route_action_forbidden': 'This Route action is not allowed.',
      'route_not_ready':
          'The Route is not ready yet. Check the highlighted parts.',
      'route_submit_failed': 'Could not send the Route. The draft is saved.',
      'route_queue_unavailable': 'The Route review queue is unavailable.',
      'route_version_approved': 'Route version approved and active.',
      'route_version_rejected': 'Route version rejected.',
      'route_decision_forbidden': 'This decision is not allowed.',
      'route_new_version_created':
          'A new version was created. The published Route has not changed yet.',
      'route_new_version_unavailable': 'A new version is unavailable.',
      'route_not_found': 'Route not found.',
      'route_withdrawn':
          'Route withdrawn from publication. Version history is kept.',
      'route_archive_forbidden': 'Archiving is not allowed.',
      'route_command_refused': 'The Route action was refused.',
      'transit_scenario_changed':
          'Scenario changed. Review the selected service and try again.',
      'transit_service_unsafe':
          'The selected service cannot be applied safely.',
      'transit_item_missing': 'The planned transport item no longer exists.',
      'transit_only_official':
          'Only an official schedule item can be replaced here.',
      'transit_not_applied': 'The selected service was not applied.',
      'rental_new_draft_from_listing':
          'A new draft was created from this listing.',
      'collection_publication_disabled':
          'Collection publishing is temporarily turned off.',
      'collection_publish_not_allowed':
          'This account cannot publish collections.',
      'collection_submitted': 'Collection sent for review.',
      'collection_published': 'Collection published.',
      'collection_published_sync_pending':
          'Collection published, but Discover has not finished updating yet.',
      'collection_not_published':
          'The Collection was not published. The draft is saved.',
      'collection_items_removed_sync_pending':
          'Items removed, but Discover has not finished updating yet.',
      'collection_archived_sync_pending':
          'Collection archived, but Discover has not finished updating yet.',
      'collection_rejection_reason_required':
          'Rejecting a Collection requires a reason.',
      'collection_accepted_sync_pending':
          'Collection accepted, but Discover has not finished updating yet.',
      'scenario_ai_proposal_added': 'AI proposal added to your Scenario.',
      'scenario_generation_empty_prompt':
          'Describe the plan you want to build.',
      'scenario_generation_prompt_too_long':
          'Keep the request under 500 characters.',
      'scenario_generation_invalid_proposal':
          'The local generator returned an invalid proposal.',
      'event_access_contract_unsupported':
          'This Event uses a newer access contract and cannot be changed here.',
      'place_gallery_limit': 'The Place gallery is full.',
      'other': 'Something went wrong. Please try again.',
    });
    return '$_temp0';
  }

  @override
  String createPlaceGalleryLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photo',
    );
    return 'You can keep up to $_temp0 in the Place gallery';
  }

  @override
  String createFieldIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'title_required': 'Enter a title',
      'category_required': 'Choose a category',
      'city_required': 'Enter a city',
      'cover_required': 'Add a cover image',
      'start_required': 'Choose the start date and time',
      'other': 'Check this field',
    });
    return '$_temp0';
  }

  @override
  String eventAccessDisclosure(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'localConfiguration':
          'Local configuration only. No booking or inventory is reserved.',
      'internalNotActive': 'Internal registration is not active until ECL-03.',
      'internalLocalStand':
          'Internal registration v1 is available only in the local testBackend stand: free, offline, instant confirmation. No booking is created by configuring this draft.',
      'providerConfirmationNotConnected':
          'Provider-managed confirmation is not connected.',
      'waitlistConfigurationOnly':
          'Waitlist is configuration-only; no queue is running.',
      'capacityIsConfiguration':
          'Capacity is configuration, not a live remaining balance.',
      'externalInventoryUnverified':
          'External inventory has no verified provider source.',
      'assignedSeatingUnavailable':
          'Assigned seating requires an authoritative hold API.',
      'other': 'This option is configuration only.',
    });
    return '$_temp0';
  }

  @override
  String scenarioTransitStatus(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'current': 'Feed snapshot was current when saved · not live',
      'stale': 'Stale feed snapshot · recheck required',
      'unknown': 'Feed freshness unknown · recheck required',
      'unavailable': 'Provenance or feed unavailable · saved data retained',
      'notApplicable': 'Entered manually · not verified',
      'other': 'Provenance or feed unavailable · saved data retained',
    });
    return '$_temp0';
  }

  @override
  String scenarioTransitWarning(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'manualNotVerified':
          'Planned schedule · not live. Manual values are not verified against an operator timetable.',
      'plannedNotLive': 'Planned schedule · not live.',
      'freshnessCurrent':
          'Current describes feed freshness when saved. It confirms neither service operation, delays nor punctuality.',
      'freshnessStale':
          'The saved feed snapshot is stale. Recheck the service before travel.',
      'freshnessUnknown':
          'Feed freshness is unknown. Do not treat the saved times as confirmed.',
      'freshnessUnavailable':
          'The saved item remains available, but its official provenance or feed cannot be verified.',
      'manualNoFreshness': 'Manual values have no official feed freshness.',
      'limitations':
          'Fare, tickets, seats, availability, delays and cancellations are unknown. Recheck with the operator before travel.',
      'other':
          'Fare, tickets, seats, availability, delays and cancellations are unknown. Recheck with the operator before travel.',
    });
    return '$_temp0';
  }

  @override
  String get scenarioTransitPlannedTransport => 'Planned transport';
}
