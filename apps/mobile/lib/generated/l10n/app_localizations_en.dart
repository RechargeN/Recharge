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
}
