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
}
