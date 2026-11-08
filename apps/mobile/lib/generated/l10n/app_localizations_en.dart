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
  String get createMediaChoosePhoto => 'Choose photo';

  @override
  String get createMediaTakePhoto => 'Take photo';

  @override
  String get createMediaPreparing => 'Preparing photo…';

  @override
  String get createMediaCoverSelected => 'Cover photo selected';

  @override
  String get localErrorMediaUnsupported =>
      'This image can\'t be used. Choose a photo.';

  @override
  String get localErrorMediaDecodeFailed =>
      'This image couldn\'t be opened. Try another one.';

  @override
  String get localErrorMediaTooLarge =>
      'This image is too large even after compression.';

  @override
  String get localErrorMediaStorageFull =>
      'Not enough space for draft photos. Remove some photos.';

  @override
  String get localErrorMediaPermissionDenied =>
      'Allow camera access in Settings to take a photo.';

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
  String get publicationTestPathDevCloud => 'Test publication path (dev cloud)';

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

  @override
  String get createFormHoursNotSelected => 'Hours not selected';

  @override
  String get createFormOpeningHoursUnknown => 'Opening hours unknown';

  @override
  String get createFormSeasonalHours => 'Seasonal hours';

  @override
  String get createFormRegularOpeningHours => 'Regular opening hours';

  @override
  String get createFormNotSelected => 'Not selected';

  @override
  String get createFormNoEntryTicketConcept => 'No entry ticket concept';

  @override
  String get createFormFreePaidAreas => 'Free and paid areas';

  @override
  String get createFormPaidEntry => 'Paid entry';

  @override
  String get createFormFreeEntry => 'Free entry';

  @override
  String get createFormLocalCurator => 'Local curator';

  @override
  String get createFormStaffMember => 'Staff member';

  @override
  String get createFormUntitledPlace => 'Untitled place';

  @override
  String get createFormPreview => 'Preview';

  @override
  String get createFormReviewPlace => 'Review this Place';

  @override
  String get createFormApplySuggestions => 'Apply suggestions';

  @override
  String get createFormDiscard => 'Discard';

  @override
  String createFormCouldImproveLaterProposalMissingrecommendedfieldidsJoin(
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count details',
      one: '$count detail',
    );
    return 'Could improve later: $_temp0';
  }

  @override
  String createFormEstimatedVisitMin(int count) {
    return 'Estimated visit: $count min';
  }

  @override
  String get createFormEditableDescriptionDraft => 'Editable description draft';

  @override
  String get createFormSuggestedCategory => 'Suggested category';

  @override
  String get createFormReviewDraftSuggestTaxonomyMatchIdentify =>
      'Review this draft, suggest a taxonomy match and identify useful missing details. Nothing is published automatically.';

  @override
  String get createFormLocalDemo => 'Local demo';

  @override
  String get createFormFinishWithAi => 'Finish with AI';

  @override
  String get createFormCreatePlace => 'Create a place';

  @override
  String get createFormSaveFailedRetryAvailable =>
      'Save failed • retry available';

  @override
  String get createFormUnsavedChanges => 'Unsaved changes';

  @override
  String get createFormSendReview => 'Send for review';

  @override
  String get createFormBack => 'Back';

  @override
  String get createFormDifferentPlace => 'This is a different place';

  @override
  String get createFormCouldPlaceAlreadyExist =>
      'Could this place already exist?';

  @override
  String get createFormAdd => 'Add';

  @override
  String get createFormGalleryImageUrlPath => 'Gallery image URL/path';

  @override
  String get createFormAddGalleryImages => 'Add gallery images';

  @override
  String get createFormCoverImageUrlPathRecommended =>
      'Cover image URL/path (recommended)';

  @override
  String get createFormCoverImageUrlPath => 'Cover image URL/path *';

  @override
  String get createFormCoverRequiredGalleryOptional =>
      'A cover is required. Gallery is optional.';

  @override
  String get createFormPhotos => 'Photos';

  @override
  String get createFormOfficialBookingLandingPage =>
      'Official booking landing page';

  @override
  String get createFormPublicEmail => 'Public email';

  @override
  String get createFormPublicPhone => 'Public phone';

  @override
  String get createFormOfficialWebsite => 'Official website';

  @override
  String get createFormAddOnlyOfficialPublicDetailsHttps =>
      'Add only official public details. HTTPS links are required.';

  @override
  String get createFormOptionalPublicContacts => 'Optional public contacts';

  @override
  String get createFormOfficialPricingUrlHttps =>
      'Official pricing URL (https)';

  @override
  String get createFormPricingNote => 'Pricing note';

  @override
  String get createFormPricingExplanation => 'Pricing explanation *';

  @override
  String get createFormTypicalSpend => 'Typical spend to';

  @override
  String get createFormTypicalSpendFrom => 'Typical spend from';

  @override
  String createFormEntry(String value) {
    return 'Entry to, $value';
  }

  @override
  String createFormEntryFrom(String value) {
    return 'Entry from, $value *';
  }

  @override
  String get createFormEntryPriceTypicalSpendAreSeparate =>
      'Entry price and typical spend are separate concepts.';

  @override
  String get createFormPrice => 'Price';

  @override
  String get createFormUnset => 'Unset';

  @override
  String get createFormYes => 'Yes';

  @override
  String get createFormChooseYesUnknownUnsetNeverTreated =>
      'Choose Yes or Unknown. Unset is never treated as No.';

  @override
  String get createFormAmenities => 'Amenities';

  @override
  String get createFormExitBuffer => 'Exit buffer';

  @override
  String get createFormArrivalBuffer => 'Arrival buffer';

  @override
  String get createFormWeatherDependent => 'Weather dependent';

  @override
  String get createFormMinimumMinutes => 'Minimum minutes';

  @override
  String get createFormRecommendedMinutes => 'Recommended minutes';

  @override
  String get createFormTheseValuesImproveTimeFitWithout =>
      'These values improve time-fit without changing opening hours.';

  @override
  String get createFormHelpPeoplePlanVisit => 'Help people plan the visit';

  @override
  String get createFormAddInterval => 'Add interval';

  @override
  String get createFormClosesNextDay => 'Closes next day';

  @override
  String get createFormCloseHhMm => 'Close HH:mm';

  @override
  String get createFormOpenHhMm => 'Open HH:mm';

  @override
  String get createFormDay => 'Day';

  @override
  String get createFormClosedFrom => 'Closed from *';

  @override
  String get createFormCurrentOperationalStatus => 'Current operational status';

  @override
  String get createFormAddClosedDay => 'Add closed day';

  @override
  String get createFormCustomHours => 'Custom hours';

  @override
  String get createFormClosedAllDay => 'Closed all day';

  @override
  String get createFormDateExceptions => 'Date exceptions';

  @override
  String get createFormRemovePeriod => 'Remove period';

  @override
  String get createFormHoursUnknown => 'Hours unknown';

  @override
  String get createFormRegularSchedule => 'Regular schedule';

  @override
  String get createFormHoursMode2 => 'Hours mode';

  @override
  String get createFormHoursMode => 'Hours mode *';

  @override
  String get createFormUnknownBetterThanInventedHours =>
      'Unknown is better than invented hours.';

  @override
  String get createFormWhenCanPeopleVisit => 'When can people visit?';

  @override
  String get createFormAddMoreVisitInformation => 'Add more visit information';

  @override
  String get createFormAddOnlyInformationThatUsefulPlace =>
      'Add only information that is useful for this place.';

  @override
  String get createFormOptionalVisitDetails => 'Optional visit details';

  @override
  String get createFormAddOpeningAccessHours => 'Add opening or access hours';

  @override
  String get createFormAddHoursOnlyWhenPlaceReally =>
      'Add hours only when this place really has them.';

  @override
  String get createFormAccessRestrictions => 'Access restrictions';

  @override
  String get createFormHowFindPlace => 'How to find this place';

  @override
  String get createFormAddDirections => 'Add directions';

  @override
  String get createFormRequiredWhenThereNoPostalAddress =>
      'Required when there is no postal address.';

  @override
  String get createFormLocationLabel => 'Location label';

  @override
  String get createFormFormattedAddress => 'Formatted address';

  @override
  String get createFormConfirmPin => 'Confirm this pin';

  @override
  String get createFormPinConfirmed => 'Pin confirmed';

  @override
  String get createFormTapMapConfirmRepresentativePoint =>
      'Tap the map and confirm the representative point.';

  @override
  String get createFormWhere => 'Where is it?';

  @override
  String get createFormChange => 'Change';

  @override
  String get createFormCancel => 'Cancel';

  @override
  String get createFormCompatibleCategoryDetailsWillKeptFields =>
      'Compatible category details will be kept. Fields that do not belong to the new profile will be removed from publication.';

  @override
  String get createFormChangeCategory => 'Change category?';

  @override
  String get createFormCategoryDetails => 'Category details';

  @override
  String get createFormContentLanguage => 'Content language';

  @override
  String get createFormPublicLandmarksDoNotRequireOwnership =>
      'Public landmarks do not require an ownership claim.';

  @override
  String get createFormCommunityContribution => 'Community contribution';

  @override
  String get createFormYourRelationship => 'Your relationship';

  @override
  String get createFormDetailedDescription => 'Detailed description';

  @override
  String get createFormOptionalDescriptionLanguageAttribution =>
      'Optional description, language and attribution';

  @override
  String get createFormMoreAboutPlace => 'More about this place';

  @override
  String get createFormYouCanAddImproveLater =>
      'You can add or improve this later.';

  @override
  String get createFormPlaceName => 'Place name *';

  @override
  String get createFormChooseCategoryFormKeepsOnlyRelevant =>
      'Choose a category and the form keeps only relevant fields.';

  @override
  String get createFormWhatPlace => 'What is this place?';

  @override
  String get createFormCreatePlaceCapabilityRequiredEditPublish =>
      'You need permission to create places to edit or publish.';

  @override
  String get createFormPlaceDataBeingPrepared =>
      'Place data is being prepared…';

  @override
  String get createFormScenarioRoute => 'Scenario route';

  @override
  String createFormStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '$count stop',
    );
    return '$_temp0';
  }

  @override
  String get createFormRechargeIdea => 'Recharge idea';

  @override
  String get createFormMapRoute => 'Map route';

  @override
  String get createFormEditRoute => 'Edit route';

  @override
  String get createFormScenarioRouteSeed => 'Scenario route seed';

  @override
  String createFormSeededFrom(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'details': 'Seeded from details',
      'saved_search': 'Seeded from saved search',
      'search': 'Seeded from search conditions',
      'smart_search': 'Seeded from smart search',
      'profile': 'Seeded from profile workspace',
      'scenario': 'Seeded from scenario route',
      'map': 'Seeded from map area',
      'other': 'Seeded from Recharge',
    });
    return '$_temp0';
  }

  @override
  String get createFormNoLimit => 'No limit';

  @override
  String get createFormCapacityUnknown => 'Capacity unknown';

  @override
  String createFormOnsiteBuffersMin(int start, int end) {
    return 'Onsite buffers: $start / $end min';
  }

  @override
  String get createFormAllowPartialAttendance => 'Allow partial attendance';

  @override
  String get createFormDuration => 'Duration';

  @override
  String get createFormNoOpeningHoursYet => 'No opening hours yet';

  @override
  String get createFormAddSlot => 'Add slot';

  @override
  String get createFormScheduleSlots => 'Schedule slots';

  @override
  String get createFormNone => 'None';

  @override
  String get createFormHours => 'Hours';

  @override
  String get createFormSchedule => 'Schedule';

  @override
  String get createFormNoCategoriesMatchSearch =>
      'No categories match this search.';

  @override
  String get createFormActivityCriteria => 'Activity criteria';

  @override
  String get createFormScenarioTaxonomy => 'Scenario taxonomy';

  @override
  String get createFormConvertRental => 'Convert to rental';

  @override
  String get createFormKeepSession => 'Keep session';

  @override
  String get createFormLegacyOfferWasMigratedSafelyAs =>
      'This legacy offer was migrated safely as a Bookable session. Choose Rental only if equipment or transport is being rented.';

  @override
  String get createFormCouldRental => 'Could this be a rental?';

  @override
  String get createFormRechargeCreate => 'Recharge Create';

  @override
  String get createFormSaveDraft => 'Save draft';

  @override
  String get createFormCoverImage => 'Cover image *';

  @override
  String get createFormFullDescription => 'Full description';

  @override
  String get createFormShortDescription => 'Short description';

  @override
  String get createFormAddress => 'Address';

  @override
  String get createFormSubcategory => 'Subcategory';

  @override
  String get createFormMainCategory => 'Main category *';

  @override
  String get createFormNotSaved => 'Not saved';

  @override
  String get createFormText => 'Sign-in required';

  @override
  String get createFormSubmitReview => 'Submit for review';

  @override
  String get createFormNotProhibitedUnsafeItem =>
      'This is not a prohibited/unsafe item';

  @override
  String get createFormListingAccurate => 'This listing is accurate';

  @override
  String get createFormPublicPreview => 'Public preview';

  @override
  String get createFormYouWillLeaveRechargeGoCheck =>
      'You will leave Recharge and go to an external site to check availability.';

  @override
  String get createFormExternalBookingUrlHttps =>
      'External booking URL (https)';

  @override
  String get createFormLateReturnPolicy => 'Late return policy';

  @override
  String get createFormDamagePolicy => 'Damage policy';

  @override
  String get createFormDepositTerms => 'Deposit terms';

  @override
  String get createFormCollectionMethod => 'Collection method';

  @override
  String get createFormAddRateStep => 'Add rate step';

  @override
  String get createFormBillingUnit => 'Billing unit';

  @override
  String get createFormUsageRestrictions => 'Usage restrictions';

  @override
  String get createFormSafetyNotice => 'Safety notice';

  @override
  String get createFormMinimumRenterAge => 'Minimum renter age';

  @override
  String get createFormMaxDurationMin => 'Max duration (min)';

  @override
  String get createFormMinDurationMin => 'Min duration (min)';

  @override
  String get createFormApply => 'Apply';

  @override
  String get createFormSuggestedDefaultsCategory =>
      'Suggested defaults for this category';

  @override
  String get createFormDeliveryFeeMinorUnits => 'Delivery fee (minor units)';

  @override
  String get createFormDeliveryRadiusKm => 'Delivery radius (km)';

  @override
  String get createFormOfferDelivery => 'Offer delivery';

  @override
  String get createFormByArrangement => 'By arrangement';

  @override
  String get createFormOpeningHours => 'Opening hours';

  @override
  String get createFormPickupSchedule => 'Pickup schedule';

  @override
  String get createFormPublicBusinessAddress => 'Public business address';

  @override
  String get createFormApproximateAreaDefault => 'Approximate area (default)';

  @override
  String get createFormLocationDisclosure => 'Location disclosure';

  @override
  String get createFormLongitude => 'Longitude';

  @override
  String get createFormLatitude => 'Latitude';

  @override
  String get createFormPublicAreaLabel => 'Public area label';

  @override
  String get createFormPickupPlaceName => 'Pickup place name';

  @override
  String get createFormThatWouldExceedGroupCapacity =>
      'That would exceed the group capacity.';

  @override
  String get createFormBlockDateRange => 'Block a date range';

  @override
  String get createFormConfirmCalendar => 'Confirm calendar';

  @override
  String get createFormRechargeCannotSeeExternalBookingsConfirm =>
      'Recharge cannot see external bookings — confirm this is up to date.';

  @override
  String get createFormCalendarNotConfirmedYet => 'Calendar not confirmed yet';

  @override
  String get createFormAddAnotherItemType => 'Add another item type';

  @override
  String get createFormRemove => 'Remove';

  @override
  String get createFormDuplicate => 'Duplicate';

  @override
  String get createFormCondition => 'Condition';

  @override
  String get createFormQuantity => 'Quantity';

  @override
  String get createFormLabel => 'Label';

  @override
  String get createFormCategory => 'Category';

  @override
  String get createFormTitle => 'Title';

  @override
  String get createFormNext => 'Next';

  @override
  String get createFormCreateRentalCapabilityRequiredEditPublish =>
      'You need permission to create rentals to edit or publish.';

  @override
  String get createFormRentalDataBeingPrepared =>
      'Rental data is being prepared…';

  @override
  String createFormRemoveGalleryImage(int count) {
    return 'Remove gallery image $count';
  }

  @override
  String createFormGalleryImageDescription(int count) {
    return 'Gallery image $count description *';
  }

  @override
  String get createFormAddGalleryImage => 'Add gallery image';

  @override
  String get createFormPublishableLocalMockModerationPipeline =>
      'Publishable on local/mock moderation pipeline';

  @override
  String get createFormUntitledEvent => 'Untitled event';

  @override
  String get createFormVisibility => 'Visibility';

  @override
  String get createFormExternalHttpsRegistrationUrl =>
      'External HTTPS registration URL';

  @override
  String get createFormRegistration => 'Registration';

  @override
  String get createFormMaximumParticipants => 'Maximum participants';

  @override
  String get createFormCapacity => 'Capacity';

  @override
  String get createFormPaymentCollection => 'Payment collection';

  @override
  String get createFormPricing => 'Pricing';

  @override
  String get createFormPartialAttendanceAllowed => 'Partial attendance allowed';

  @override
  String get createFormPetsAllowed => 'Pets allowed';

  @override
  String get createFormKidsAllowed => 'Kids allowed';

  @override
  String get createFormFamilyFriendly => 'Family friendly';

  @override
  String get createFormMaximumAge => 'Maximum age';

  @override
  String get createFormMinimumAge => 'Minimum age';

  @override
  String get createFormWhatAttendeesShouldKnowBring =>
      'What attendees should know or bring';

  @override
  String get createFormExcludedDatesCommaSeparated =>
      'Excluded dates, comma-separated';

  @override
  String get createFormOccurrenceCount => 'Occurrence count';

  @override
  String get createFormUntilLocalDate => 'Until local date';

  @override
  String get createFormEnds => 'Ends';

  @override
  String get createFormEveryNPeriods => 'Every N periods';

  @override
  String get createFormRepeat => 'Repeat';

  @override
  String get createFormDatesSeparatedByCommas => 'Dates separated by commas';

  @override
  String get createFormDurationMinutes => 'Duration in minutes';

  @override
  String get createFormDurationMinutes14401Day =>
      'Duration in minutes (1440 = 1 day)';

  @override
  String get createFormLocalStartTimeHhMm => 'Local start time (HH:mm)';

  @override
  String get createFormFirstLocalDateYyyyMmDd =>
      'First local date (YYYY-MM-DD)';

  @override
  String get createFormScheduleMode => 'Schedule mode';

  @override
  String get createFormPublicHttpsEventUrl => 'Public HTTPS event URL *';

  @override
  String get createFormOnlineAccess => 'Online access';

  @override
  String get createFormConfirmPhysicalLocationPin =>
      'Confirm this physical location pin *';

  @override
  String get createFormMeetingPointInstructions => 'Meeting point instructions';

  @override
  String get createFormVenue => 'Venue';

  @override
  String get createFormFormat => 'Format';

  @override
  String get createFormCoverDescriptionScreenReaders =>
      'Cover description for screen readers *';

  @override
  String get createFormShortDescription2 => 'Short description *';

  @override
  String get createFormEventTitle => 'Event title *';

  @override
  String get createFormEventDraftUnavailableReopenCreateHub =>
      'Event draft is unavailable. Reopen Create Hub.';

  @override
  String get createFormClosesAtUtcIso8601 => 'Closes at UTC (ISO 8601)';

  @override
  String get createFormOpensAtUtcIso8601 => 'Opens at UTC (ISO 8601)';

  @override
  String get createFormCloseMinutesBeforeOccurrence =>
      'Close minutes before occurrence';

  @override
  String get createFormOpenMinutesBeforeOccurrence =>
      'Open minutes before occurrence';

  @override
  String get createFormWindowType => 'Window type';

  @override
  String get createFormEnableWindow => 'Enable window';

  @override
  String get createFormNotConfigured => 'Not configured';

  @override
  String get createFormRemoveEligibilityRule => 'Remove eligibility rule';

  @override
  String get createFormPublicExplanationNoSecrets =>
      'Public explanation (no secrets)';

  @override
  String get createFormAddEligibilityRule => 'Add eligibility rule';

  @override
  String get createFormRuleKind => 'Rule kind';

  @override
  String get createFormNeverEnterAccessCodesIdentitiesPrivate =>
      'Never enter access codes, identities or private documents.';

  @override
  String get createFormEligibility => 'Eligibility';

  @override
  String get createFormSalesAtDoor => 'Sales at the door';

  @override
  String get createFormRegistrationAtDoor => 'Registration at the door';

  @override
  String get createFormOnsiteAdmissionAllowed => 'Onsite admission allowed';

  @override
  String get createFormDoesNotBookReserveInventory =>
      'Does not book or reserve inventory';

  @override
  String get createFormMaximumGuestsPerRegistration =>
      'Maximum guests per registration *';

  @override
  String get createFormGuestPolicy => 'Guest policy';

  @override
  String get createFormFuturePromotionPolicy => 'Future promotion policy';

  @override
  String get createFormPreviewOnlyNoQueuePromotionRuns =>
      'Preview only — no queue or promotion runs';

  @override
  String get createFormConfigureWaitlist => 'Configure waitlist';

  @override
  String get createFormApplicationWindow => 'Application window';

  @override
  String get createFormCancellationClosesNMinutesBeforeStart =>
      'Cancellation closes N minutes before the start *';

  @override
  String get createFormRegistrationWindow => 'Registration window';

  @override
  String get createFormExternalHttpsRegistrationUrl2 =>
      'External HTTPS registration URL *';

  @override
  String get createFormConfirmationMode => 'Confirmation mode *';

  @override
  String get createFormRegistrationMode => 'Registration mode *';

  @override
  String get createFormAdmissionMode => 'Admission mode *';

  @override
  String get createFormApplyNormalizedFields => 'Apply normalized fields';

  @override
  String get createFormConfigurationPreset => 'Configuration preset';

  @override
  String get createFormConfirmSuggestion => 'Confirm suggestion';

  @override
  String get createFormLegacyRegistrationPreservedButAdmissionConfirmation =>
      'Legacy registration is preserved, but admission and confirmation still require explicit choices.';

  @override
  String get createFormOpenEntryWithNoRegistrationConfirmation =>
      'Open entry with no registration or confirmation.';

  @override
  String get createFormLegacyDraftSuggestionNotApplied =>
      'Legacy draft suggestion — not applied';

  @override
  String get createFormAdmissionRegistrationConfirmationAreIndependentLocal =>
      'Admission, registration and confirmation are independent. This local configuration does not create a booking.';

  @override
  String get createFormAdmission => 'Admission';

  @override
  String get createFormEventAdmissionConfiguration =>
      'Event admission configuration';

  @override
  String get createFormSaveDraftReturn => 'Save draft & return';

  @override
  String get createFormPreviewPublish => 'Preview and publish';

  @override
  String get createFormSuggestGroupSize => 'Suggest a group size';

  @override
  String get createFormTypicalDurationMaxMinutes =>
      'Typical duration, max (minutes)';

  @override
  String get createFormTypicalDurationMinMinutes =>
      'Typical duration, min (minutes)';

  @override
  String get createFormBestSeasonOptional => 'Best season (optional)';

  @override
  String get createFormBestTimeDayOptional => 'Best time of day (optional)';

  @override
  String get createFormWhenBestHowLongDoesTake =>
      'When is it best, and how long does it take?';

  @override
  String get createFormApproximateAmountOptional =>
      'Approximate amount (optional)';

  @override
  String get createFormEGCoffeeCounterOptional =>
      'e.g. “Coffee on the counter, optional”';

  @override
  String get createFormOther => 'Other';

  @override
  String get createFormDonation => 'Donation';

  @override
  String get createFormContributionKind => 'Contribution kind';

  @override
  String get createFormCustomaryLeaveSomethingHere =>
      'It is customary to leave something here';

  @override
  String get createFormWhatKnowBeforeYouGo => 'What to know before you go';

  @override
  String get createFormNotOfficialSpot => 'This is not an official spot';

  @override
  String get createFormAccessNotes => 'Access notes';

  @override
  String get createFormAddressLineOptional => 'Address line (optional)';

  @override
  String get createFormWhereHowDoIGetThere =>
      'Where is it, and how do I get there?';

  @override
  String get createFormMorePlaces => 'More Places';

  @override
  String get createFormNoMatchingPlacesPage =>
      'No matching Places on this page.';

  @override
  String get createFormSearchPlaces => 'Search Places';

  @override
  String get createFormSearchPublishedPlaces => 'Search published Places';

  @override
  String get createFormLinkedPlaceUnavailableRemoveReplaceLink =>
      'Linked Place is unavailable. Remove or replace the link.';

  @override
  String get createFormRemoveLinkedPlace => 'Remove linked Place';

  @override
  String get createFormSelectedPlace => 'A Place is linked';

  @override
  String get createFormLinkedPlaceOptional => 'Linked Place (optional)';

  @override
  String get createFormCoverImageUrl => 'Cover image URL';

  @override
  String get createFormFullDescriptionOptional => 'Full description (optional)';

  @override
  String get createFormAboutActivity => 'About this activity';

  @override
  String get createFormCheckActivityFieldsSubmitAgain =>
      'Check the Activity fields and submit again.';

  @override
  String get createFormEditingDraftOnlyPublishedVersionStays =>
      'Editing draft only. The published version stays unchanged until review and publication.';

  @override
  String get createFormLoadingRechargeActivityDraft =>
      'Loading Recharge Activity draft…';

  @override
  String get createFormPublishedRoute => 'Published route';

  @override
  String get createFormDraftSummaryUnavailableSession =>
      'Draft summary is unavailable in this session.';

  @override
  String get createFormMapArea => 'Map area';

  @override
  String get createFormSearchSimilar => 'Search similar';

  @override
  String get createFormProfile => 'Profile';

  @override
  String get createFormHome => 'Home';

  @override
  String get createFormNextSteps => 'Next steps';

  @override
  String get createFormRouteMap => 'Route map';

  @override
  String get createFormWalking => 'Walking';

  @override
  String get createFormFree => 'Free';

  @override
  String get createFormArchive => 'Archive';

  @override
  String get createFormCreateNewVersion => 'Create new version';

  @override
  String get createFormReviewRequest => 'Review request';

  @override
  String get createFormGeometryHash => 'Geometry hash';

  @override
  String get createFormVersionId => 'Version ID';

  @override
  String get createFormRouteId => 'Route ID';

  @override
  String get createFormImmutableVersionAwaitingApproval =>
      'Immutable version awaiting approval';

  @override
  String get createFormActiveImmutableRouteVersion =>
      'Active immutable Route version';

  @override
  String get createFormYourPublishActionWasHandledCreate =>
      'Your publish action was handled. Create another listing or return to Home.';

  @override
  String get createFormSentModeration => 'Sent to moderation';

  @override
  String get createFormPublishProcessed => 'Publish processed';

  @override
  String get createFormRoutePublished => 'Route published';

  @override
  String get createFormCreateAnother => 'Create another';

  @override
  String get createFormCreateAnotherEvent => 'Create another Event';

  @override
  String get createFormCreateAnotherFrom =>
      'Create another from the last template';

  @override
  String get createFormOpenRouteModerationQueue =>
      'Open Route moderation queue';

  @override
  String get createFormPublishStatus => 'Publish status';

  @override
  String get createFormCouldNotRemove =>
      'Could not remove the item. Try again.';

  @override
  String get createFormRemoveWithoutReview => 'Remove without review';

  @override
  String get createFormRemovingItemHereAppliesInstantlyNo =>
      'Removing an item here applies instantly, with no moderation round trip. Adding or editing text still needs a new reviewed version — use Publish above for that.';

  @override
  String get createFormPublish => 'Publish';

  @override
  String get createFormAcknowledgeComposition => 'Acknowledge composition';

  @override
  String get createFormCompositionReviewed => 'Composition reviewed';

  @override
  String get createFormRefreshLivePreview => 'Refresh live preview';

  @override
  String get createFormSomeItemsAreNoLongerAvailable =>
      'Some items are no longer available — review before publishing.';

  @override
  String get createFormNotEnoughPricedItemsYetSuggest =>
      'Not enough priced items yet to suggest a budget.';

  @override
  String get createFormSuggestFromItemPrices => 'Suggest from item prices';

  @override
  String get createFormNotSet => 'Not set';

  @override
  String get createFormBudgetIndicator => 'Budget indicator';

  @override
  String get createFormCuratorNotes => 'Curator notes';

  @override
  String get createFormItems => 'Items';

  @override
  String get createFormOneReferencePointWholeGuideNot =>
      'One reference point for the whole guide — not an item location.';

  @override
  String get createFormAreaAnchor => 'Area anchor';

  @override
  String get createFormTypeSearchTapMapBelow7 =>
      'Type to search, or tap the map below';

  @override
  String get createFormAreaCity => 'Area or city';

  @override
  String get createFormShortPitch => 'Short pitch';

  @override
  String get createFormCollectionDraftDataBeingPrepared =>
      'Collection draft data is being prepared…';

  @override
  String get createFormCollectionDraftBeingPrepared =>
      'Collection draft is being prepared…';

  @override
  String get createFormPreparingCollectionDraft =>
      'Preparing Collection draft…';

  @override
  String get createFormRemovePool => 'Remove pool';

  @override
  String get createFormMovePoolDown => 'Move pool down';

  @override
  String get createFormMovePoolUp => 'Move pool up';

  @override
  String get createFormNeutralRoleIdsCommaSeparated =>
      'Neutral role IDs, comma-separated';

  @override
  String get createFormCapacityMode => 'Capacity mode';

  @override
  String get createFormChannel => 'Channel';

  @override
  String get createFormShape => 'Shape';

  @override
  String get createFormPublicPoolLabel => 'Public pool label';

  @override
  String get createFormUnnamedPool => 'Unnamed pool';

  @override
  String get createFormAddPool => 'Add pool';

  @override
  String get createFormPoolCapacity => 'Pool capacity';

  @override
  String get createFormAdditionalViewsSameInventory =>
      'Additional views of the same inventory';

  @override
  String get createFormPrimaryInventoryShape => 'Primary inventory shape *';

  @override
  String get createFormInventoryAuthority => 'Inventory authority';

  @override
  String get createFormMaximumParticipants2 => 'Maximum participants *';

  @override
  String get createFormEventCapacity => 'Event capacity';

  @override
  String get createFormCapacityDeclaredLimitNotLiveParticipant =>
      'Capacity is a declared limit. It is not a live participant count or transactional inventory balance.';

  @override
  String get createFormEventInventoryConfiguration =>
      'Event inventory configuration';

  @override
  String get createFormConfirm => 'Confirm';

  @override
  String get createFormSave => 'Save';

  @override
  String get createFormTemplateName => 'Template name';

  @override
  String get createFormActiveDraftsPublishedEventsWillNot =>
      'Active drafts and published Events will not be affected.';

  @override
  String get createFormDeleteTemplate => 'Delete template?';

  @override
  String get createFormReusableContentWillReplacedWithCurrent =>
      'The reusable content will be replaced with the current Event.';

  @override
  String get createFormReplaceTemplate => 'Replace template?';

  @override
  String get createFormRenameTemplate => 'Rename template';

  @override
  String get createFormDelete => 'Delete';

  @override
  String get createFormReplaceWithCurrent => 'Replace with current';

  @override
  String get createFormRename => 'Rename';

  @override
  String get createFormTemplateActions => 'Template actions';

  @override
  String get createFormLastTemplate => 'Last template';

  @override
  String get createFormUntitledEvent2 => 'Untitled Event';

  @override
  String get createFormNoTemplatesYetSaveCurrentEvent =>
      'No templates yet. Save the current Event to reuse it.';

  @override
  String get createFormYourEventTemplates => 'Your Event templates';

  @override
  String get createFormSaveEventTemplate => 'Save Event template';

  @override
  String get createFormNextCreateAnotherEventWillUse =>
      'Next “Create another Event” will use the selected template.';

  @override
  String get createFormSaveCurrent => 'Save current';

  @override
  String get createFormChooseManage => 'Choose or manage';

  @override
  String get createFormEventTemplates => 'Event templates';

  @override
  String get createFormClearClassification => 'Clear classification';

  @override
  String get createFormAdditionalRolesUp3 => 'Additional roles (up to 3)';

  @override
  String get createFormPrimaryAttendeeRole => 'Primary attendee role *';

  @override
  String get createFormExplainEventMechanics => 'Explain the event mechanics *';

  @override
  String get createFormEventMechanics => 'Event mechanics *';

  @override
  String get createFormUseSuggestion => 'Use suggestion';

  @override
  String get createFormOnlySuggestionConfirmChooseAnother =>
      'This is only a suggestion. Confirm it or choose another.';

  @override
  String get createFormMechanicsAttendeeRolesAreIndependentFrom =>
      'Mechanics and attendee roles are independent from the category, format, access and price.';

  @override
  String get createFormHowDoesEventWork => 'How does this event work?';

  @override
  String get createFormEventClassification => 'Event classification';

  @override
  String get createFormSectionTitle => 'Section title';

  @override
  String get createFormNewSection => 'New section';

  @override
  String get createFormNoLongerAvailable => 'No longer available';

  @override
  String get createFormNoItemsYet => 'No items yet.';

  @override
  String get createFormRemoveSection => 'Remove section';

  @override
  String createFormCollection(int count) {
    return 'In this Collection ($count)';
  }

  @override
  String get createFormResults => 'Results';

  @override
  String get createFormSearch => 'Search';

  @override
  String get createFormSearchPlaceRouteBookableSessionClass =>
      'Search Place, Route, Bookable Session, Class/Workshop, Rental';

  @override
  String get createFormChooseTypeOpenItsCreationPage =>
      'Choose a type to open its creation page.';

  @override
  String get createFormWhatDoYouWantCreate => 'What do you want to create?';

  @override
  String get createFormCreateHub => 'Create Hub';

  @override
  String get createFormRefreshPreview => 'Refresh preview';

  @override
  String get createFormCheckingLocalFixture => 'Checking local fixture…';

  @override
  String get createFormLocalMockPreviewNotLiveAvailability =>
      'Local mock preview — not live availability';

  @override
  String get createFormLocalMockAvailabilityPreview =>
      'Local mock availability preview';

  @override
  String get createFormDuplicateListing => 'Duplicate this listing';

  @override
  String get createFormSaveCurrentAsTemplate => 'Save current as template';

  @override
  String get createFormUse => 'Use';

  @override
  String get createFormNoSavedTemplatesYet => 'No saved templates yet.';

  @override
  String get createFormTemplates => 'Templates';

  @override
  String get createFormWhyHere => 'Why is it here?';

  @override
  String get createFormFeatured => 'Featured';

  @override
  String get createFormAddItemsPreviousStepFirst =>
      'Add items in the previous step first.';

  @override
  String createFormUpToPrice(String price) {
    return 'up to $price';
  }

  @override
  String createFormDistanceKm(String km) {
    return '$km km';
  }

  @override
  String createFormMinutes(int count) {
    return '$count min';
  }

  @override
  String get createFormOwner => 'Owner';

  @override
  String get createFormVisitor => 'Visitor';

  @override
  String get createFormUnknown => 'Unknown';

  @override
  String get createFormOpen247 => 'Open 24/7';

  @override
  String get createStepPlaceIdentityTitle => 'About';

  @override
  String get createStepPlaceIdentityDescription =>
      'Name, category and only the details this place needs';

  @override
  String get createStepPlaceVisitTitle => 'Visit';

  @override
  String get createStepPlaceVisitDescription =>
      'Confirmed map point and relevant visit information';

  @override
  String get createStepPlacePublishTitle => 'Publish';

  @override
  String get createStepPlacePublishDescription =>
      'Readiness, optional improvements and final checks';

  @override
  String get createStepEventBasicsMediaTitle => 'Basics';

  @override
  String get createStepEventBasicsMediaDescription =>
      'Identity, category, description and media';

  @override
  String get createStepEventLocationScheduleTitle => 'When & where';

  @override
  String get createStepEventLocationScheduleDescription =>
      'Format, location, timezone and occurrences';

  @override
  String get createStepEventRequirementsTitle => 'Requirements';

  @override
  String get createStepEventRequirementsDescription =>
      'Audience, amenities and participation rules';

  @override
  String get createStepEventPriceParticipantsTitle => 'Price & people';

  @override
  String get createStepEventPriceParticipantsDescription =>
      'Money, admission, capacity and inventory';

  @override
  String get createStepEventPreviewPublishTitle => 'Publish';

  @override
  String get createStepEventPreviewPublishDescription =>
      'Preview, readiness and moderation submission';

  @override
  String get createStepActivityBasicsTitle => 'About';

  @override
  String get createStepActivityBasicsDescription => 'Title, category and media';

  @override
  String get createStepActivityLocationTitle => 'Location';

  @override
  String get createStepActivityLocationDescription =>
      'Where to go and how to get there';

  @override
  String get createStepActivityWhenForTitle => 'When & for whom';

  @override
  String get createStepActivityWhenForDescription =>
      'Best time, duration and group size';

  @override
  String get createStepActivityPublishTitle => 'Publish';

  @override
  String get createStepActivityPublishDescription => 'Preview and send';

  @override
  String get createStepCollectionBasicsTitle => 'Basics & media';

  @override
  String get createStepCollectionBasicsDescription =>
      'Title, pitch, cover and area';

  @override
  String get createStepCollectionItemsTitle => 'Items';

  @override
  String get createStepCollectionItemsDescription =>
      'Search and add existing places, routes and more';

  @override
  String get createStepCollectionCuratorNotesTitle => 'Curator notes';

  @override
  String get createStepCollectionCuratorNotesDescription =>
      'Say why each item is here and pick your highlights';

  @override
  String get createStepCollectionBudgetTitle => 'Budget & publisher';

  @override
  String get createStepCollectionBudgetDescription =>
      'Set a budget hint, publisher, market and visibility';

  @override
  String get createStepCollectionPublishTitle => 'Preview & publish';

  @override
  String get createStepCollectionPublishDescription =>
      'Review the composition and send';

  @override
  String get createStepRentalListingTitle => 'Listing and media';

  @override
  String get createStepRentalListingDescription =>
      'Title, category and cover for the item or fleet';

  @override
  String get createStepRentalInventoryTitle => 'Inventory';

  @override
  String get createStepRentalInventoryDescription =>
      'Groups of interchangeable units, condition and quantity';

  @override
  String get createStepRentalAvailabilityTitle => 'Availability';

  @override
  String get createStepRentalAvailabilityDescription =>
      'Confirmed coverage window and manual occupancy blocks';

  @override
  String get createStepRentalHandoverTitle => 'Handover and location';

  @override
  String get createStepRentalHandoverDescription =>
      'Pickup area, schedule and optional delivery';

  @override
  String get createStepRentalTermsTitle => 'Duration and safety';

  @override
  String get createStepRentalTermsDescription =>
      'Offered duration range, age, ID and safety requirements';

  @override
  String get createStepRentalPricingTitle => 'Pricing and deposit';

  @override
  String get createStepRentalPricingDescription =>
      'Rate plan, deposit policy and damage/cancellation terms';

  @override
  String get createStepRentalFulfillmentTitle =>
      'External fulfillment and policies';

  @override
  String get createStepRentalFulfillmentDescription =>
      'External booking link and destination warning preview';

  @override
  String get createStepRentalReviewTitle => 'Review and submit';

  @override
  String get createStepRentalReviewDescription =>
      'Public/private preview, attestation and submission';

  @override
  String createPlacePolicyLabel(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'simplePoi': 'Simple point of interest',
      'publicSpace': 'Public space',
      'naturalDestination': 'Natural destination',
      'culturalVenue': 'Cultural venue',
      'hospitality': 'Food or hospitality venue',
      'activityVenue': 'Activity or service venue',
      'paidAttraction': 'Managed attraction',
      'balanced': 'General place',
      'other': 'General place',
    });
    return '$_temp0';
  }

  @override
  String createPlacePolicyDescription(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'simplePoi':
          'A landmark people can identify and visit without managed access.',
      'publicSpace': 'An open public area with optional access restrictions.',
      'naturalDestination':
          'A natural point or area where access facts may be unknown.',
      'culturalVenue': 'A managed museum, gallery, cinema or cultural venue.',
      'hospitality':
          'A managed venue where spend matters but admission does not.',
      'activityVenue':
          'A managed venue with optional booking, spend and facilities.',
      'paidAttraction':
          'A managed attraction that may have admission and facilities.',
      'balanced': 'A safe fallback with no invented opening or pricing facts.',
      'other': 'A safe fallback with no invented opening or pricing facts.',
    });
    return '$_temp0';
  }

  @override
  String createAmenityLabel(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'wheelchair_accessible': 'Wheelchair accessible',
      'accessible_toilet': 'Accessible toilet',
      'parking': 'Parking',
      'bike_parking': 'Bike parking',
      'public_transport_nearby': 'Public transport nearby',
      'public_transport': 'Public transport nearby',
      'family_friendly': 'Family friendly',
      'baby_changing': 'Baby changing',
      'pets_allowed': 'Pets allowed',
      'toilet': 'Toilet',
      'wifi': 'Wi-Fi',
      'drinking_water': 'Drinking water',
      'food_available': 'Food available',
      'outdoor_seating': 'Outdoor seating',
      'shelter': 'Weather shelter',
      'weather_shelter': 'Weather shelter',
      'first_aid': 'First aid',
      'shower': 'Shower',
      'towels': 'Towels provided',
      'changing_room': 'Changing room',
      'equipment_provided': 'Equipment provided',
      'other': 'Amenity',
    });
    return '$_temp0';
  }

  @override
  String createAmenityGroup(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'accessibility': 'Accessibility',
      'audience': 'Audience',
      'facilities': 'Facilities',
      'family': 'Family',
      'food': 'Food',
      'outdoor': 'Outdoor',
      'pets': 'Pets',
      'safety': 'Safety',
      'transport': 'Transport',
      'wellness': 'Wellness',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String get createFormSaved => 'Saved';

  @override
  String get createFormSaving => 'Saving…';

  @override
  String createOption(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'EventCapacityMode_known': 'Known limit',
      'EventCapacityMode_unknown': 'Unknown',
      'EventCapacityMode_unlimited': 'Unlimited',
      'EventFormat_offline': 'In person',
      'EventFormat_online': 'Online',
      'EventFormat_hybrid': 'Hybrid',
      'EventOnlineAccessMode_publicLink': 'Public link',
      'EventOnlineAccessMode_externalRegistration': 'External registration',
      'EventOnlineAccessMode_internalBooking': 'Internal booking',
      'EventPaymentCollectionMode_none': 'No payment',
      'EventPaymentCollectionMode_onsite': 'On site',
      'EventPaymentCollectionMode_external': 'External',
      'EventPaymentCollectionMode_internal': 'In Recharge',
      'EventPricingMode_free': 'Free',
      'EventPricingMode_fixed': 'Fixed price',
      'EventPricingMode_ticketTypes': 'Ticket types',
      'EventPricingMode_donation': 'Donation',
      'EventRecurrenceEndMode_never': 'Never',
      'EventRecurrenceEndMode_untilDate': 'On a date',
      'EventRecurrenceEndMode_occurrenceCount': 'After a number of times',
      'EventRecurrenceFrequency_daily': 'Daily',
      'EventRecurrenceFrequency_weekly': 'Weekly',
      'EventRecurrenceFrequency_monthly': 'Monthly',
      'EventRecurrenceFrequency_yearly': 'Yearly',
      'EventRegistrationMode_none': 'No registration',
      'EventRegistrationMode_external': 'External',
      'EventRegistrationMode_internal': 'In Recharge',
      'EventScheduleMode_oneTime': 'One time',
      'EventScheduleMode_multiDate': 'Several dates',
      'EventScheduleMode_recurring': 'Recurring',
      'EventVisibility_public': 'Public',
      'EventVisibility_unlisted': 'By link',
      'EventVisibility_private': 'Private',
      'EventAdmissionPreset_noRegistration': 'No registration',
      'EventAdmissionPreset_freeRsvp': 'Free RSVP',
      'EventAdmissionPreset_organizerApplication':
          'Application to the organizer',
      'EventAdmissionPreset_externalRegistration': 'External registration',
      'EventAdmissionPreset_externalTickets': 'External tickets',
      'EventAdmissionPreset_rechargeTickets': 'Recharge tickets',
      'EventAdmissionPreset_teamRegistration': 'Team registration',
      'AdmissionMode_openEntry': 'Open entry',
      'AdmissionMode_rsvp': 'RSVP',
      'AdmissionMode_booking': 'Booking',
      'AdmissionMode_application': 'Application',
      'AdmissionMode_ticket': 'Ticket',
      'AdmissionMode_teamRegistration': 'Team registration',
      'ConfirmationMode_none': 'No confirmation',
      'ConfirmationMode_instant': 'Instant',
      'ConfirmationMode_manualApproval': 'Manual approval',
      'ConfirmationMode_lottery': 'Lottery',
      'ConfirmationMode_providerManaged': 'By the provider',
      'WaitlistPromotionMode_organizerManaged': 'By the organizer',
      'WaitlistPromotionMode_fifoAutomatic': 'Automatic, first come',
      'GuestPolicyMode_none': 'No guests',
      'GuestPolicyMode_plusOne': 'Plus one',
      'GuestPolicyMode_plusN': 'Plus N',
      'GuestPolicyMode_namedGuestsOnly': 'Named guests only',
      'EligibilityRuleKind_invitation': 'Invitation',
      'EligibilityRuleKind_accessCode': 'Access code',
      'EligibilityRuleKind_membership': 'Membership',
      'EligibilityRuleKind_allowlist': 'Guest list',
      'EligibilityRuleKind_qualification': 'Qualification',
      'EligibilityRuleKind_accreditation': 'Accreditation',
      'EligibilityRuleKind_ageRequirement': 'Age requirement',
      'EligibilityRuleKind_waiver': 'Waiver',
      'EventAccessWindowKind_absolute': 'Fixed dates',
      'EventAccessWindowKind_occurrenceRelative': 'Relative to each date',
      'InventoryShape_generalCapacity': 'General capacity',
      'InventoryShape_sharedTicketPool': 'Shared ticket pool',
      'InventoryShape_separateTicketPools': 'Separate ticket pools',
      'InventoryShape_zones': 'Zones',
      'InventoryShape_assignedSeating': 'Assigned seats',
      'InventoryShape_teamSlots': 'Team slots',
      'InventoryShape_participantRoles': 'Participant roles',
      'InventoryShape_roleBalancedSlots': 'Role-balanced slots',
      'InventoryShape_tableInventory': 'Tables',
      'InventoryShape_timeSlotInventory': 'Time slots',
      'InventoryChannel_onsite': 'On site',
      'InventoryChannel_online': 'Online',
      'InventoryChannel_any': 'Any',
      'InventoryAuthority_none': 'Nobody',
      'InventoryAuthority_recharge': 'Recharge',
      'InventoryAuthority_externalProvider': 'External provider',
      'ActivityContributionKind_purchase': 'Purchase',
      'ActivityContributionKind_donation': 'Donation',
      'ActivityContributionKind_other': 'Other',
      'ActivitySeason_winter': 'Winter',
      'ActivitySeason_spring': 'Spring',
      'ActivitySeason_summer': 'Summer',
      'ActivitySeason_autumn': 'Autumn',
      'ActivitySeason_any': 'Any season',
      'ActivityTimeOfDay_morning': 'Morning',
      'ActivityTimeOfDay_afternoon': 'Afternoon',
      'ActivityTimeOfDay_evening': 'Evening',
      'ActivityTimeOfDay_night': 'Night',
      'ActivityTimeOfDay_any': 'Any time',
      'PlaceOperationalStatus_operating': 'Operating',
      'PlaceOperationalStatus_temporarilyClosed': 'Temporarily closed',
      'PlaceOperationalStatus_permanentlyClosed': 'Permanently closed',
      'RentalLocationDisclosure_approximateArea': 'Approximate area (default)',
      'RentalLocationDisclosure_publicBusinessAddress':
          'Public business address',
      'RentalScheduleMode_openingHours': 'Opening hours',
      'RentalScheduleMode_byArrangement': 'By arrangement',
      'RentalBillingUnit_hour': 'Per hour',
      'RentalBillingUnit_day': 'Per day',
      'RentalBillingUnit_week': 'Per week',
      'RentalCondition_rentalNew': 'New',
      'RentalCondition_likeNew': 'Like new',
      'RentalCondition_good': 'Good',
      'RentalCondition_worn': 'Worn',
      'RentalDepositCollectionMethod_none': 'No deposit',
      'RentalDepositCollectionMethod_atHandover': 'At handover',
      'RentalDepositCollectionMethod_externalProvider': 'External provider',
      'RentalDepositCollectionMethod_other': 'Other',
      'VisibilityType_public': 'Public',
      'VisibilityType_unlisted': 'By link',
      'VisibilityType_private': 'Private',
      'PublishStatus_draft': 'Draft',
      'PublishStatus_pendingReview': 'Pending review',
      'PublishStatus_published': 'Published',
      'PublishStatus_archived': 'Archived',
      'PublishStatus_hidden': 'Hidden',
      'PublishStatus_deleted': 'Deleted',
      'FindPeopleApprovalMode_manual': 'Host approves',
      'FindPeopleApprovalMode_automatic': 'Automatic',
      'FindPeopleApprovalMode_inviteOnly': 'Invite only',
      'FindPeopleConversationPolicy_acceptedOnly': 'Accepted participants only',
      'FindPeopleConversationPolicy_applicantsAndAccepted':
          'Applicants and accepted',
      'FindPeopleCostType_free': 'Free',
      'FindPeopleCostType_estimated': 'Estimated cost',
      'FindPeopleCostType_unknown': 'Unknown',
      'FindPeopleExpenseSplitMode_none': 'No split',
      'FindPeopleExpenseSplitMode_equal': 'Split equally',
      'FindPeopleExpenseSplitMode_itemized': 'By item',
      'FindPeopleExpenseSplitMode_settleLater': 'Settle later',
      'FindPeopleMeetingMode_inPerson': 'In person',
      'FindPeopleMeetingMode_online': 'Online',
      'FindPeopleMeetingMode_hybrid': 'Hybrid',
      'FindPeopleParticipationGoal_social': 'Socialising',
      'FindPeopleParticipationGoal_practice': 'Practice',
      'FindPeopleParticipationGoal_teamUp': 'Team up',
      'FindPeopleParticipationGoal_sharedTrip': 'Shared trip',
      'FindPeopleParticipationGoal_accountability': 'Keep each other going',
      'FindPeopleParticipationGoal_other': 'Other',
      'FindPeoplePublisherType_user': 'Personal profile',
      'FindPeoplePublisherType_page': 'Professional page',
      'FindPeopleScheduleMode_single': 'One time',
      'FindPeopleScheduleMode_timePoll': 'Time poll',
      'FindPeopleScheduleMode_recurring': 'Recurring',
      'FindPeopleSeatFitPolicy_strictOrder': 'Strict order',
      'FindPeopleSeatFitPolicy_firstFitting': 'First that fits',
      'FindPeopleSkillLevel_any': 'Any level',
      'FindPeopleSkillLevel_beginner': 'Beginner',
      'FindPeopleSkillLevel_intermediate': 'Intermediate',
      'FindPeopleSkillLevel_advanced': 'Advanced',
      'FindPeopleVerificationLevel_none': 'No verification',
      'FindPeopleVerificationLevel_phone': 'Phone',
      'FindPeopleVerificationLevel_identityDocument': 'Identity document',
      'FindPeopleVerificationLevel_organization': 'Organisation',
      'FindPeopleVisibility_public': 'Public',
      'FindPeopleVisibility_unlisted': 'By link',
      'FindPeopleVisibility_inviteOnly': 'Invite only',
      'FindPeopleWaitlistPolicy_firstCome': 'First come',
      'FindPeopleWaitlistPolicy_hostReview': 'Host review',
      'ScenarioBudgetBasis_wholeGroup': 'Whole group',
      'ScenarioBudgetBasis_perPerson': 'Per person',
      'ScenarioFormat_city': 'City',
      'ScenarioFormat_day': 'Day',
      'ScenarioFormat_weekend': 'Weekend',
      'ScenarioFormat_trip': 'Trip',
      'ScenarioPace_relaxed': 'Relaxed',
      'ScenarioPace_balanced': 'Balanced',
      'ScenarioPace_intensive': 'Intensive',
      'ScenarioPartyKind_solo': 'Solo',
      'ScenarioPartyKind_couple': 'Couple',
      'ScenarioPartyKind_friends': 'Friends',
      'ScenarioPartyKind_family': 'Family',
      'ScenarioPartyKind_group': 'Group',
      'ScenarioPartyKind_mixed': 'Mixed',
      'ScenarioPlannedTransportKind_bus': 'Bus',
      'ScenarioPlannedTransportKind_train': 'Train',
      'ScenarioPlannedTransportKind_tram': 'Tram',
      'ScenarioPlannedTransportKind_trolleybus': 'Trolleybus',
      'ScenarioPlannedTransportKind_ferry': 'Ferry',
      'ScenarioPlannedTransportKind_flight': 'Flight',
      'ScenarioPlannedTransportKind_other': 'Other',
      'ScenarioTravelMode_walking': 'Walking',
      'ScenarioTravelMode_bicycle': 'Bicycle',
      'ScenarioTravelMode_car': 'Own car',
      'ScenarioTravelMode_taxi': 'Taxi',
      'ScenarioTravelMode_transit': 'Public transport',
      'ScenarioTravelMode_other': 'Other',
      'ScenarioDateMode_template': 'Flexible template',
      'ScenarioDateMode_dated': 'Dated trip',
      'ScenarioItemKind_visit': 'Visit',
      'ScenarioItemKind_event': 'Event',
      'ScenarioItemKind_activity': 'Activity',
      'ScenarioItemKind_route': 'Route',
      'ScenarioItemKind_bookableSession': 'Session',
      'ScenarioItemKind_stay': 'Stay',
      'ScenarioItemKind_plannedTransport': 'Planned transport',
      'ScenarioItemKind_timeBlock': 'Time block',
      'RouteSegmentSource_routed': 'Routed',
      'RouteSegmentSource_generated': 'Generated',
      'RouteSegmentSource_freehand': 'Freehand',
      'RouteSegmentSource_recordedGps': 'Recorded GPS',
      'RouteSegmentSource_importedGpx': 'Imported GPX',
      'RouteSegmentSource_intentionalDirect': 'Intentional direct line',
      'RouteSegmentSource_fallbackDirect': 'Direct line (fallback)',
      'RouteSegmentOperationState_ready': 'Ready',
      'RouteSegmentOperationState_routing': 'Routing',
      'RouteSegmentOperationState_failed': 'Failed',
      'RouteSegmentOperationState_stale': 'Needs update',
      'ScenarioScheduleFreshness_current': 'Current when saved',
      'ScenarioScheduleFreshness_stale': 'Stale',
      'ScenarioScheduleFreshness_unknown': 'Unknown',
      'ScenarioScheduleFreshness_notApplicable': 'Not applicable',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String get createFormCityRequired => 'City *';

  @override
  String get createFormLatitudeRequired => 'Latitude *';

  @override
  String get createFormLongitudeRequired => 'Longitude *';

  @override
  String get createFormCategoryRequired => 'Category *';

  @override
  String get createFormSubcategoryRequired => 'Subcategory *';

  @override
  String get createFormTitleRequired => 'Title *';

  @override
  String createFormOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dates',
      one: '$count date',
    );
    return '$_temp0';
  }

  @override
  String createFormAdmissionLine(String value) {
    return 'Admission: $value';
  }

  @override
  String createFormVisibilityLine(String value) {
    return 'Visibility: $value';
  }

  @override
  String createFormBlockingIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems block publishing',
      one: '$count problem blocks publishing',
    );
    return '$_temp0';
  }

  @override
  String get createFormSending => 'Sending…';

  @override
  String get createFormPublishing => 'Publishing…';

  @override
  String get createFormGroup => 'Group';

  @override
  String get createFormNoTitleYet => '(no title yet)';

  @override
  String createFormUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '$count unit',
    );
    return '$_temp0';
  }

  @override
  String createFormDepositLine(String price) {
    return 'Deposit: $price';
  }

  @override
  String get createFormGroupMaxPeople => 'Group, max people';

  @override
  String createFormPublisherLine(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'user': 'Publisher: your profile',
      'page': 'Publisher: a professional page',
      'other': 'Publisher: not set',
    });
    return '$_temp0';
  }

  @override
  String get createFormDraft => 'Draft';

  @override
  String get createFormDetails => 'Details';

  @override
  String get createFormAvailability => 'Availability';

  @override
  String get createFormClosed => 'Closed';

  @override
  String createObjectTypeName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Event',
      'activity': 'Recharge activity',
      'route': 'Route',
      'place': 'Place',
      'session': 'Bookable session',
      'scenario': 'Scenario',
      'quickPlan': 'Legacy Quick Plan',
      'findPeople': 'Find people',
      'classWorkshop': 'Class / workshop',
      'rental': 'Rental / equipment',
      'collection': 'Collection / guide',
      'other': 'Object',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypeDescription(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Public activity with time, place, and attendees',
      'activity': 'Lightweight activity such as a walk or reset',
      'route': 'Continuous track with anchors, segments and route details',
      'place': 'A permanent physical place, venue, public space or landmark',
      'session': 'Time-based service, class, table, court, or session',
      'scenario': 'City, day, weekend or trip plan made of independent stops',
      'quickPlan': 'Personal lightweight plan kept for read compatibility',
      'findPeople': 'Find company for a specific activity',
      'classWorkshop': 'A guided class, workshop, or hands-on experience',
      'rental': 'Equipment or transport available for rent',
      'collection': 'A curated collection of places and ideas',
      'other': 'Create an object',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypeLocationLabel(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Venue',
      'activity': 'Where to go',
      'route': 'Start point',
      'place': 'Place name',
      'session': 'Bookable venue',
      'scenario': 'Area or city',
      'quickPlan': 'Meeting place',
      'findPeople': 'Meeting place',
      'classWorkshop': 'Class venue',
      'rental': 'Pickup place',
      'collection': 'Area',
      'other': 'Location',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypePriceLabel(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Ticket or entry price',
      'activity': '',
      'route': 'Route budget',
      'place': 'Typical spend',
      'session': 'Booking price',
      'scenario': 'Scenario budget',
      'quickPlan': 'Expected spend',
      'findPeople': 'Expected spend',
      'classWorkshop': 'Participation price',
      'rental': 'Rental price',
      'collection': 'Collection budget',
      'other': 'Price',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypeNewTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'New event',
      'activity': 'New recharge activity',
      'route': 'New route',
      'place': 'New place',
      'session': 'New bookable session',
      'scenario': 'New scenario',
      'quickPlan': 'New legacy quick plan',
      'findPeople': 'New find people',
      'classWorkshop': 'New class / workshop',
      'rental': 'New rental / equipment',
      'collection': 'New collection / guide',
      'other': 'New object',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypeCreateTitle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Create Event',
      'activity': 'Create Recharge activity',
      'route': 'Create Route',
      'place': 'Create Place',
      'session': 'Create Bookable session',
      'scenario': 'Create Scenario',
      'quickPlan': 'Create Legacy Quick Plan',
      'findPeople': 'Create Find people',
      'classWorkshop': 'Create Class / workshop',
      'rental': 'Create Rental / equipment',
      'collection': 'Create Collection / guide',
      'other': 'Create',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypeFreeToggle(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Free event',
      'activity': 'Free recharge activity',
      'route': 'Free route',
      'place': 'Free place',
      'session': 'Free bookable session',
      'scenario': 'Free scenario',
      'quickPlan': 'Free legacy quick plan',
      'findPeople': 'Free find people',
      'classWorkshop': 'Free class / workshop',
      'rental': 'Free rental / equipment',
      'collection': 'Free collection / guide',
      'other': 'Free',
    });
    return '$_temp0';
  }

  @override
  String createObjectTypeStartUtc(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'event': 'Event start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'activity':
          'Recharge activity start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'route': 'Route start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'place': 'Place start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'session':
          'Bookable session start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'scenario': 'Scenario start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'quickPlan':
          'Legacy Quick Plan start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'findPeople':
          'Find people start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'classWorkshop':
          'Class / workshop start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'rental':
          'Rental / equipment start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'collection':
          'Collection / guide start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *',
      'other': 'Start date and time, UTC *',
    });
    return '$_temp0';
  }

  @override
  String createFormNowStatus(String value) {
    return 'Now: $value.';
  }

  @override
  String createFindPeopleFindPeople(int done, int total) {
    return 'Find People · $done/$total';
  }

  @override
  String get createFindPeopleSaveError => 'Save error';

  @override
  String get createFindPeopleUnsavedChanges => 'Unsaved changes';

  @override
  String get createFindPeopleContinue => 'Continue';

  @override
  String get createFindPeopleSaveDraft => 'Save draft';

  @override
  String get createFindPeopleBack => 'Back';

  @override
  String get createFindPeoplePublishFindPeopleRequest =>
      'Publish Find People request';

  @override
  String get createFindPeopleValidationSummary => 'Validation summary';

  @override
  String get createFindPeopleMeetPubliclyDoNotSendMoney =>
      'Meet publicly, do not send money to strangers, and use Report/Block when needed.';

  @override
  String get createFindPeopleIAcceptFindPeopleSafetyRules =>
      'I accept the Find People Safety Rules *';

  @override
  String get createFindPeopleRequestOnlyAdults18 =>
      'This request is only for adults 18+ *';

  @override
  String get createFindPeopleSchedulePublicationUtcOptional =>
      'Schedule publication UTC (optional)';

  @override
  String get createFindPeopleCoverImageUrlOptional =>
      'Cover image URL (optional)';

  @override
  String get createFindPeopleMediaPublication => 'Media and publication';

  @override
  String get createFindPeopleTheseFieldsAreNeverIncludedPublic =>
      'These fields are never included in public data, analytics, or push payloads.';

  @override
  String get createFindPeoplePrivateHostPreview => 'Private host preview';

  @override
  String get createFindPeopleApproximatePublicArea => 'Approximate public area';

  @override
  String get createFindPeopleAddShortDescription => 'Add a short description.';

  @override
  String get createFindPeopleUntitledFindPeopleRequest =>
      'Untitled Find People request';

  @override
  String get createFindPeopleMirrorsSafePublicDetailsContract =>
      'This mirrors the safe public Details contract.';

  @override
  String get createFindPeoplePublicPreview => 'Public preview';

  @override
  String get createFindPeopleQuietHoursEnd01439 => 'Quiet hours end (0–1439)';

  @override
  String get createFindPeopleQuietHoursStart01439 =>
      'Quiet hours start (0–1439)';

  @override
  String get createFindPeopleAllowAcceptedParticipantsInvite =>
      'Allow accepted participants to invite';

  @override
  String get createFindPeopleConversationPolicy => 'Conversation policy *';

  @override
  String get createFindPeopleInviteCoHost => 'Invite co-host';

  @override
  String get createFindPeopleUserId => 'User ID';

  @override
  String createFindPeopleResponsibleHostsDataResponsiblehostuseridsJoin(
    int count,
  ) {
    return 'Responsible hosts: $count';
  }

  @override
  String get createFindPeoplePublisherUserId => 'Publisher user ID *';

  @override
  String get createFindPeopleManagedPageId => 'Managed Page ID *';

  @override
  String get createFindPeoplePublishAs => 'Publish as *';

  @override
  String get createFindPeopleAddExpense => 'Add expense';

  @override
  String get createFindPeopleExpenseItem => 'Expense item';

  @override
  String get createFindPeopleExpenseSplitMode => 'Expense split mode *';

  @override
  String get createFindPeopleCostNote => 'Cost note';

  @override
  String createFindPeopleExpectedSpendPerPerson(String value) {
    return 'Expected spend per person ($value) *';
  }

  @override
  String get createFindPeopleExpectedCost => 'Expected cost *';

  @override
  String get createFindPeopleAddQuestion => 'Add question';

  @override
  String get createFindPeopleSafeQuestion => 'Safe question';

  @override
  String get createFindPeopleApplicationQuestions => 'Application questions';

  @override
  String get createFindPeopleRequireAttendanceReconfirmation =>
      'Require attendance reconfirmation';

  @override
  String get createFindPeopleWaitlistPolicy => 'Waitlist policy';

  @override
  String get createFindPeopleEnableWaitlist => 'Enable waitlist';

  @override
  String get createFindPeopleVerificationRequirement =>
      'Verification requirement *';

  @override
  String get createFindPeopleMaximumSeatsPerApplication =>
      'Maximum seats per application';

  @override
  String get createFindPeopleAllowPartyApplications =>
      'Allow party applications';

  @override
  String get createFindPeopleApprovalMode => 'Approval mode *';

  @override
  String get createFindPeopleHostSeats => 'Host seats';

  @override
  String get createFindPeopleTargetGroupSize => 'Target group size';

  @override
  String get createFindPeopleGroupSizeIncludesHostsExpectedSpend =>
      'Group size includes hosts. Expected spend is information, never a payment to the host.';

  @override
  String get createFindPeopleGroupParticipation => 'Group and participation';

  @override
  String get createFindPeopleBackupMeetingPlan => 'Backup meeting plan';

  @override
  String get createFindPeoplePrivateAccessSecretReference =>
      'Private access secret reference *';

  @override
  String get createFindPeopleGoogleMeetZoomDiscord =>
      'Google Meet, Zoom, Discord…';

  @override
  String get createFindPeopleOnlineProvider => 'Online provider *';

  @override
  String get createFindPeoplePrivateHomesResidentialAccessDetailsAre =>
      'Private homes and residential access details are not allowed.';

  @override
  String get createFindPeoplePublicMeetingPlace =>
      'This is a public meeting place *';

  @override
  String get createFindPeopleMeetingInstructionsPrivate =>
      'Meeting instructions (private)';

  @override
  String get createFindPeopleExactAddressPrivate => 'Exact address (private) *';

  @override
  String createFindPeoplePublicMapPoint(String value) {
    return 'Public map point: $value';
  }

  @override
  String get createFindPeopleSetExactPointGenerateSafePublic =>
      'Set exact point and generate safe public point';

  @override
  String get createFindPeopleExactLongitude => 'Exact longitude *';

  @override
  String get createFindPeopleExactLatitude => 'Exact latitude *';

  @override
  String get createFindPeopleOldTownNearCentralPark =>
      'Old Town, near Central Park';

  @override
  String get createFindPeoplePublicAreaLabel => 'Public area label *';

  @override
  String get createFindPeopleMeetingPlaceName => 'Meeting place name *';

  @override
  String get createFindPeopleMeetingMode => 'Meeting mode *';

  @override
  String get createFindPeopleOnlyApproximatePublicAreaAppearsDiscover =>
      'Only the approximate public area appears in Discover. Exact details stay private.';

  @override
  String get createFindPeopleMeetingLocation => 'Meeting location';

  @override
  String get createFindPeopleMaximumOccurrences252 =>
      'Maximum occurrences (2–52)';

  @override
  String get createFindPeopleSeriesEndUtc => 'Series end UTC';

  @override
  String get createFindPeopleRecurrenceRule => 'Recurrence rule *';

  @override
  String get createFindPeopleApplicationDeadlineUtc =>
      'Application deadline UTC *';

  @override
  String get createFindPeoplePollResponseDeadlineUtc =>
      'Poll response deadline UTC *';

  @override
  String get createFindPeopleRemoveSlot => 'Remove slot';

  @override
  String get createFindPeopleAddTimeOption => 'Add time option';

  @override
  String get createFindPeopleSetMeetingTime => 'Set meeting time';

  @override
  String get createFindPeopleEndUtc => 'End UTC *';

  @override
  String get createFindPeopleStartUtc => 'Start UTC *';

  @override
  String get createFindPeopleScheduleMode => 'Schedule mode *';

  @override
  String createFindPeopleAllTimesAreStoredUtcDisplayed(String value) {
    return 'All times are stored in UTC and displayed using $value.';
  }

  @override
  String get createFindPeopleSchedule => 'Schedule';

  @override
  String get createFindPeopleHouseRulesNote => 'House rules note';

  @override
  String get createFindPeopleHouseRules => 'House rules';

  @override
  String get createFindPeopleAccessibilityNotes => 'Accessibility notes';

  @override
  String get createFindPeopleEquipmentNotes => 'Equipment notes';

  @override
  String get createFindPeopleExperienceRequirementsOnePerLine =>
      'Experience requirements (one per line)';

  @override
  String get createFindPeopleCommunicationLanguages =>
      'Communication languages *';

  @override
  String get createFindPeopleParticipationGoal => 'Participation goal *';

  @override
  String get createFindPeopleSkillLevel => 'Skill level *';

  @override
  String get createFindPeopleFullDescription => 'Full description *';

  @override
  String get createFindPeopleShortDescription => 'Short description *';

  @override
  String get createFindPeoplePublicContentMustDescribeConcreteActivity =>
      'Public content must describe a concrete activity without contacts or payment links.';

  @override
  String get createFindPeopleActivityDescription => 'Activity and description';

  @override
  String get createFindPeopleFindPeopleDraftDataBeingPrepared =>
      'Find People draft data is being prepared…';

  @override
  String get createSessionOnlyWhatMarkedRequiredBlocksPublishing =>
      'Only what is marked “required” blocks publishing. Everything else is optional and can be added now or later.';

  @override
  String get createSessionPublish => 'Publish';

  @override
  String get createSessionSaveDraft => 'Save draft';

  @override
  String get createSessionNeverRequiredPublishSesD14 =>
      'Never required to publish.';

  @override
  String get createSessionRecommendedDetailsCategory =>
      'Recommended details for this category';

  @override
  String get createSessionAmenities => 'Amenities';

  @override
  String get createSessionBlock => 'Block';

  @override
  String get createSessionBlockedDates => 'Blocked dates';

  @override
  String get createSessionMaxPartySize => 'Max party size';

  @override
  String get createSessionTermsUrlOptionalHttps =>
      'Terms URL (optional, https://…)';

  @override
  String get createSessionExternalBookingUrlHttps =>
      'External booking URL (https://…)';

  @override
  String get createSessionPricePerSlotEur => 'Price per slot, EUR';

  @override
  String get createSessionFree => 'Free';

  @override
  String get createSessionPriceBooking => 'Price and booking';

  @override
  String get createSessionNextOffers => 'Next offers';

  @override
  String get createSessionSlotDuration => 'Slot duration';

  @override
  String get createSessionNoWeeklyRuleYetPickPreset =>
      'No weekly rule yet — pick a preset above.';

  @override
  String get createSessionWhen => 'When';

  @override
  String get createSessionConfirmLocation => 'Confirm this location';

  @override
  String get createSessionLongitude => 'Longitude';

  @override
  String get createSessionLatitude => 'Latitude';

  @override
  String get createSessionCity => 'City';

  @override
  String get createSessionAddress => 'Address';

  @override
  String get createSessionResourceNameEGSauna1 =>
      'Resource name (e.g. “Sauna 1”)';

  @override
  String get createSessionGalleryImageDescription =>
      'Gallery image description';

  @override
  String get createSessionCoverImageDescription => 'Cover image description';

  @override
  String get createSessionContentLanguage => 'Content language';

  @override
  String get createSessionCoverImageUrl => 'Cover image URL';

  @override
  String get createSessionFullDescription => 'Full description';

  @override
  String get createSessionShortDescription => 'Short description';

  @override
  String get createSessionSubcategory => 'Subcategory';

  @override
  String get createSessionCategory => 'Category';

  @override
  String get createSessionTitle => 'Title';

  @override
  String get createSessionWhatWhere => 'What and where';

  @override
  String get createSessionLoadingBookableSessionDraft =>
      'Loading Bookable session draft…';

  @override
  String get createClassPublish => 'Publish';

  @override
  String get createClassSaveDraft => 'Save draft';

  @override
  String get createClassEnrollmentState => 'Enrollment state';

  @override
  String get createClassEnrollmentLinkHttps => 'Enrollment link (https)';

  @override
  String get createClassEnrollmentOrganiserSite =>
      'Enrollment on the organiser site';

  @override
  String get createClassPriceCovers => 'The price covers';

  @override
  String createClassAmountCents(String value) {
    return 'Amount in cents ($value)';
  }

  @override
  String get createClassPrice => 'Price';

  @override
  String get createClassDeclaredGroupSizeOptional =>
      'Declared group size (optional)';

  @override
  String get createClassWhatBringKnowOnePerLine =>
      'What to bring or know (one per line)';

  @override
  String get createClassIncludedMaterialsOnePerLine =>
      'Included materials (one per line)';

  @override
  String get createClassAddDate => 'Add date';

  @override
  String get createClassRemoveDate => 'Remove date';

  @override
  String get createClassLocalTimeDoesNotExistAmbiguous =>
      'This local time does not exist or is ambiguous';

  @override
  String get createClassPublicArea => 'Public area';

  @override
  String get createClassShowOnlyAreaPublicly => 'Show only the area publicly';

  @override
  String get createClassConfirmLocation => 'Confirm this location';

  @override
  String get createClassLocationConfirmed => 'Location confirmed';

  @override
  String get createClassOnlineProvider => 'Online provider';

  @override
  String get createClassDelivery => 'Delivery';

  @override
  String createClassTimesAre(String value) {
    return 'Times are in $value';
  }

  @override
  String get createClassFixedSeries => 'Fixed series';

  @override
  String get createClassSingleClass => 'Single class';

  @override
  String get createClassClear => 'Clear';

  @override
  String get createClassNotPublishedClearExplicitly =>
      'It is not published; clear it explicitly.';

  @override
  String get createClassDraftHasOldSchedule => 'This draft has an old schedule';

  @override
  String get createClassInstructorBio => 'Instructor bio';

  @override
  String get createClassInstructorName => 'Instructor name';

  @override
  String get createClassWhatParticipantsTakeHome =>
      'What participants take home';

  @override
  String get createClassNoPrerequisites => 'No prerequisites';

  @override
  String get createClassProgrammeStepsOnePerLine =>
      'Programme steps (one per line)';

  @override
  String get createClassGalleryImageDescription => 'Gallery image description';

  @override
  String get createClassCoverImageDescription => 'Cover image description';

  @override
  String get createClassContentLanguage => 'Content language';

  @override
  String get createClassCoverImage => 'Cover image';

  @override
  String get createClassFullDescription => 'Full description';

  @override
  String get createClassShortDescription => 'Short description';

  @override
  String get createClassOfferingKind => 'Offering kind';

  @override
  String get createClassClassDraftWasSavedByNewer =>
      'This Class draft was saved by a newer app version and is read-only.';

  @override
  String get createRouteGpxOperationCouldNotCompleted =>
      'The GPX operation could not be completed.';

  @override
  String get createRouteChooseOneContinuousTrackRouteDraft =>
      'Choose one continuous track for this Route draft.';

  @override
  String get createRouteSavingGpxFilesNotAvailableDevice =>
      'Saving GPX files is not available on this device yet.';

  @override
  String get createRouteOnlyOneContinuousRouteTrackCan =>
      'Only one continuous Route track can be exported.';

  @override
  String get createRouteGpxTrackContainsTooManyPoints =>
      'The GPX track contains too many points.';

  @override
  String get createRouteGpxFileDamagedHasUnsupportedStructure =>
      'The GPX file is damaged or has an unsupported structure.';

  @override
  String get createRouteChooseValidGpxFile => 'Choose a valid GPX file.';

  @override
  String get createRouteGpxFileTooLarge => 'The GPX file is too large.';

  @override
  String get createRouteDismiss => 'Dismiss';

  @override
  String get createRouteImportTrack => 'Import track';

  @override
  String get createRouteCancel => 'Cancel';

  @override
  String get createRouteTheyRemainOffTrackUntilReviewed =>
      'They remain off-track until reviewed and positioned.';

  @override
  String get createRouteReviewTheseConnectorsMapBeforePublishing =>
      'Review these connectors on the map before publishing.';

  @override
  String get createRouteChooseOneTrack => 'Choose one track';

  @override
  String get createRoutePrivateMetadataTimestampsWillRemovedDuring =>
      'Private metadata and timestamps will be removed during import.';

  @override
  String get createRouteRouteBuilder => 'Route builder';

  @override
  String get createRouteReplace => 'Replace';

  @override
  String get createRouteCurrentGeometryWillRemainAvailableThrough =>
      'The current geometry will remain available through Undo.';

  @override
  String get createRouteReplaceExistingTrack => 'Replace existing track?';

  @override
  String get createRouteContinue => 'Continue';

  @override
  String get createRouteBack => 'Back';

  @override
  String get createRouteMarkedTrail => 'Marked trail';

  @override
  String get createRouteHard => 'Hard';

  @override
  String get createRouteModerate => 'Moderate';

  @override
  String get createRouteEasy => 'Easy';

  @override
  String get createRouteDifficulty => 'Difficulty';

  @override
  String get createRouteConditions => 'Conditions';

  @override
  String get createRouteSubcategory => 'Subcategory';

  @override
  String get createRouteCategory => 'Category';

  @override
  String get createRouteTaxonomy => 'Category';

  @override
  String get createRouteCoverImageUrl => 'Cover image URL';

  @override
  String get createRouteFullDescription => 'Full description';

  @override
  String get createRouteShortDescription => 'Short description *';

  @override
  String get createRouteRouteDetails => 'Route details';

  @override
  String get createRoutePreferUnpavedTrails => 'Prefer unpaved trails';

  @override
  String get createRouteAvoidStairs => 'Avoid stairs';

  @override
  String get createRouteRoutingPreferences => 'Routing preferences';

  @override
  String get createRouteLoop => 'Loop';

  @override
  String get createRouteOneWay => 'One way';

  @override
  String get createRouteRouteShape => 'Route shape';

  @override
  String get createRouteProfile => 'Profile';

  @override
  String get createRouteBundledMeAparksGraphCurrentlyValidates =>
      'The bundled Mežaparks graph currently validates walking routes locally.';

  @override
  String get createRouteMovementProfile => 'Movement profile';

  @override
  String get createRouteSaveFile => 'Save file';

  @override
  String get createRoutePrivateMetadataNotesTimestampsAreNever =>
      'Private metadata, notes and timestamps are never exported.';

  @override
  String get createRouteIncludeRoutePoi => 'Include route POI';

  @override
  String get createRouteUnavailableTrack => 'Unavailable for this track';

  @override
  String get createRouteIncludeElevation => 'Include elevation';

  @override
  String get createRouteExportGpx => 'Export GPX';

  @override
  String get createRouteExportOnlyTrackOptionalRoutePoi =>
      'Export only the track and optional route POI. Draft IDs, notes, safety data and timestamps are excluded.';

  @override
  String get createRouteInspectGpxFileLocallyChooseOne =>
      'Inspect a GPX file locally, choose one track and remove private metadata.';

  @override
  String get createRouteImportGpx => 'Import GPX';

  @override
  String get createRouteRecordMovementDeviceThenReviewAccuracy =>
      'Record movement on this device, then review accuracy, gaps and privacy trimming.';

  @override
  String get createRouteRecordWithGps => 'Record with GPS';

  @override
  String get createRouteDrawOneContinuousLineKeepIts =>
      'Draw one continuous line and keep its exact geometry.';

  @override
  String get createRouteFreehand => 'Freehand';

  @override
  String get createRoutePlaceAnchorsConnectThemAlongOffline =>
      'Place anchors and connect them along the offline trail graph.';

  @override
  String get createRoutePoints => 'Points';

  @override
  String get createRouteAllMethodsUseOneCanonicalRoute =>
      'All methods use one canonical Route model. This demo enables points and freehand without paid services.';

  @override
  String get createRouteHowWillYouCreateTrack =>
      'How will you create the track?';

  @override
  String get createRouteEditorWillReadyMoment =>
      'The editor will be ready in a moment.';

  @override
  String get createRoutePreparingRouteDraft => 'Preparing Route draft…';

  @override
  String get createRouteRestoringLatestPersistedRevision =>
      'Restoring the latest saved revision.';

  @override
  String get createRouteRetry => 'Retry';

  @override
  String get createRouteOfflineMapCouldNotLoaded =>
      'Offline map could not be loaded';

  @override
  String get createRouteNoNetworkPaidRoutingCallRequired =>
      'No network or paid routing call is required.';

  @override
  String get createRouteLoadingOfflineTrailEditor =>
      'Loading offline trail editor…';

  @override
  String get createRouteGapNeedsTrailRoutingBeforeCan =>
      'This gap needs trail routing before it can be applied.';

  @override
  String get createRouteReviewEveryTrackGapBeforeContinuing =>
      'Review every track gap before continuing.';

  @override
  String get createRouteProtectedRecordingCouldNotSavedRecording =>
      'The protected recording could not be saved. Recording was stopped safely.';

  @override
  String get createRouteNotEnoughReliableMovementWasRecorded =>
      'Not enough reliable movement was recorded. Delete this recording and try again.';

  @override
  String get createRouteSafetyPointLimitWasReachedFinish =>
      'The safety point limit was reached. Finish and review this recording.';

  @override
  String get createRouteDeviceLocationServicesAreSwitchedOff =>
      'Device location services are switched off.';

  @override
  String get createRouteBackgroundAccessWasNotGrantedTurn =>
      'Background access was not granted. Turn off screen-lock recording or allow it in settings.';

  @override
  String get createRouteLocationAccessDisabledAppSettings =>
      'Location access is disabled in app settings.';

  @override
  String get createRouteLocationPermissionWasNotGranted =>
      'Location permission was not granted.';

  @override
  String get createRouteYourSavedRecordingPreservedWhenRecovery =>
      'Your saved recording is preserved when recovery is possible.';

  @override
  String get createRouteInspectGapsAccuracyPrivacyTrimmingBefore =>
      'Inspect gaps, accuracy and privacy trimming before using the track.';

  @override
  String get createRouteFilteringUnsafeNoisyGpsPoints =>
      'Filtering unsafe and noisy GPS points.';

  @override
  String get createRouteReadingProtectedLocalJournal =>
      'Reading the protected local journal.';

  @override
  String get createRoutePauseStaysAsExplicitGapWill =>
      'The pause stays as an explicit gap and will never be connected silently.';

  @override
  String get createRouteKeepRechargeOpenWhileMovingAlong =>
      'Keep Recharge open while moving along the Route.';

  @override
  String get createRouteRecordingContinuesWithVisibleSystemIndicator =>
      'Recording continues with a visible system indicator.';

  @override
  String get createRouteRechargeRequestsLocationOnlyRouteRecording =>
      'Recharge requests location only for Route recording.';

  @override
  String get createRouteWalkRunRideRoutePointsStay =>
      'Walk, run or ride the Route. Points stay encrypted on this device until you apply the track.';

  @override
  String get createRouteRecordingReady => 'Recording ready';

  @override
  String get createRouteProcessingTrack => 'Processing track…';

  @override
  String get createRouteRecoveringRecording => 'Recovering recording…';

  @override
  String get createRouteRecordingPaused => 'Recording paused';

  @override
  String get createRouteRecordingRoute => 'Recording Route';

  @override
  String get createRouteCheckingGpsAccess => 'Checking GPS access…';

  @override
  String get createRouteOpenAppSettings => 'Open app settings';

  @override
  String get createRouteRecordingActive => 'Recording is active';

  @override
  String get createRouteConnectDirectly => 'Connect directly';

  @override
  String createRouteRecordedRoutePreviewTrackSectionsGaps(
    int count,
    int total,
  ) {
    return 'Recorded Route preview: track sections $count, gaps $total';
  }

  @override
  String get createRouteDelete => 'Delete';

  @override
  String get createRouteRecoveryJournalAllRecordedPointsWill =>
      'The recovery journal and all recorded points will be removed.';

  @override
  String get createRouteDeleteGpsRecording => 'Delete GPS recording?';

  @override
  String get createRouteUseTrack => 'Use this track';

  @override
  String get createRouteRouteMustStayContinuousConfirmEach =>
      'A Route must stay continuous. Confirm each straight connection or record the missing section again.';

  @override
  String get createRouteTrackGaps => 'Track gaps';

  @override
  String get createRouteHideRouteEnd => 'Hide route end';

  @override
  String get createRouteHideRouteStart => 'Hide route start';

  @override
  String get createRoutePrivacyTrim => 'Privacy trim';

  @override
  String get createRouteReviewRecordedTrack => 'Review recorded track';

  @override
  String get createRouteDeleteRecording => 'Delete recording';

  @override
  String get createRouteFinishReview => 'Finish and review';

  @override
  String get createRouteResumeRecording => 'Resume recording';

  @override
  String get createRouteFinish => 'Finish';

  @override
  String get createRoutePause => 'Pause';

  @override
  String get createRouteStartRecording => 'Start recording';

  @override
  String get createRouteRequiresBackgroundLocationPermissionShowsSystem =>
      'Requires background location permission and shows a system indicator.';

  @override
  String get createRouteContinueWhileScreenLocked =>
      'Continue while the screen is locked';

  @override
  String get createRouteRecoveredSafelyAfterPreviousSessionReview =>
      'Recovered safely after the previous session. Review before resuming.';

  @override
  String get createRouteRemoveWaypoint => 'Remove waypoint';

  @override
  String get createRouteAttachAnchor => 'Attach to anchor';

  @override
  String get createRouteAddViewpointFromAnchorMenu =>
      'Add a viewpoint from an anchor menu.';

  @override
  String get createRouteSplitAtMidpoint => 'Split at midpoint';

  @override
  String get createRouteUseIntentionalDirectLine =>
      'Use intentional direct line';

  @override
  String get createRouteRetryRouting => 'Retry routing';

  @override
  String get createRouteSegmentActions => 'Segment actions';

  @override
  String get createRouteRemoveAnchor => 'Remove anchor';

  @override
  String get createRouteAddViewpoint => 'Add viewpoint';

  @override
  String get createRouteAnchorActions => 'Anchor actions';

  @override
  String get createRouteMoveAnchorEast => 'Move anchor east';

  @override
  String get createRouteMoveAnchorWest => 'Move anchor west';

  @override
  String get createRouteMoveAnchorSouth => 'Move anchor south';

  @override
  String get createRouteMoveAnchorNorth => 'Move anchor north';

  @override
  String get createRouteNoAnchorsYet => 'No anchors yet.';

  @override
  String get createRouteEveryActionAvailableAsLabelledControl =>
      'Every action is available as a labelled control.';

  @override
  String get createRouteAddAnchor => 'Add anchor';

  @override
  String get createRouteLongitude => 'Longitude';

  @override
  String get createRouteLatitude => 'Latitude';

  @override
  String get createRouteCoordinatesProvideKeyboardScreenReaderAlternative =>
      'Coordinates provide a keyboard and screen-reader alternative.';

  @override
  String get createRouteAddAnchorWithoutMapGestures =>
      'Add anchor without map gestures';

  @override
  String get createRouteLastSaved => 'Last saved';

  @override
  String get createRouteRedo => 'Redo';

  @override
  String get createRouteUndo => 'Undo';

  @override
  String get createRouteTapMapAddAnchorsLocalGraph =>
      'Tap the map to add anchors. The local graph connects them along available trails.';

  @override
  String get createRouteDrawOneContinuousLineExistingGeometry =>
      'Draw one continuous line. Existing geometry is replaced only after confirmation.';

  @override
  String get createRouteOfflineTrailEditor => 'Offline trail editor';

  @override
  String get createRouteSelectedDifficultyDiffersFromCalculatedRecommendation =>
      'The selected difficulty differs from the calculated recommendation and requires review.';

  @override
  String get createRouteRouteQuality => 'Route quality';

  @override
  String get createRouteYourProfileDoesNotHavePermission =>
      'Your profile does not have permission to submit this Route.';

  @override
  String get createRouteSubmitRouteReview => 'Submit Route for review';

  @override
  String get createRoutePublishRoute => 'Publish Route';

  @override
  String get createRouteRestoreLastSavedRevision =>
      'Restore last saved revision';

  @override
  String get createRouteSaveDraft => 'Save draft';

  @override
  String get createRouteRoutingProgress => 'Routing in progress…';

  @override
  String get createRouteInvestorDemoVersionUsesBundledOffline =>
      'Demo: this version uses the bundled offline trail graph and is marked demo-only. No paid routing call is made.';

  @override
  String get createRouteRouteDraftStructurallyReady =>
      'Route draft is structurally ready';

  @override
  String get createRouteOfflineTrailMapTapAddRoute =>
      'Offline trail map. Tap to add a route anchor.';

  @override
  String get createRouteOfflineTrailMapDrawContinuousRoute =>
      'Offline trail map. Draw a continuous route with one finger.';

  @override
  String get createRouteNoRouteVersionsAreWaitingReview =>
      'No Route versions are waiting for review.';

  @override
  String get createRouteModerateRouteCapabilityRequired =>
      'You need permission to moderate routes.';

  @override
  String get createRouteReject => 'Reject';

  @override
  String get createRouteReasonCodeConciseReason =>
      'Reason code or concise reason';

  @override
  String get createRouteRejectRouteVersion => 'Reject Route version';

  @override
  String get createRouteApprove => 'Approve';

  @override
  String get createRouteAccept => 'Accept';

  @override
  String get createRouteDefer => 'Defer';

  @override
  String get createRouteConfirm => 'Confirm';

  @override
  String get createRouteReasonCode => 'Reason code';

  @override
  String get createRouteSafetyDecisionReason => 'Safety decision reason';

  @override
  String get createRouteCandidateDecisionReason => 'Candidate decision reason';

  @override
  String get createRouteNewRouteRevisionDraftWasCreated =>
      'A new Route revision draft was created. Published geometry was not changed.';

  @override
  String get createRouteSafetyReports => 'Safety reports';

  @override
  String get createRouteMapUpdateCandidates => 'Map update candidates';

  @override
  String get createRoutePublicationReview => 'Publication review';

  @override
  String get createRouteRefresh => 'Refresh';

  @override
  String get createRouteRouteModeration => 'Route moderation';

  @override
  String get createScenarioPlannedScheduleNotLive =>
      'Planned schedule, not live.';

  @override
  String get createScenarioPlannedServiceSelectedPreviewNotApplied =>
      'Planned service selected for preview. Not applied to Scenario.';

  @override
  String get createScenarioNoDirectPlannedServicesFound =>
      'No direct planned services found.';

  @override
  String get createScenarioSearchingDirectPlannedServices =>
      'Searching direct planned services.';

  @override
  String get createScenarioScheduleSearchFailedTryAgain =>
      'Schedule search failed. Try again.';

  @override
  String get createScenarioStopSearchFailedTryAgain =>
      'Stop search failed. Try again.';

  @override
  String get createScenarioCompleteProviderStopsDateTimeSelection =>
      'Complete the provider, stops, date and time selection.';

  @override
  String get createScenarioNewScheduleCouldNotSavedExisting =>
      'The new schedule could not be saved. Existing cache was kept.';

  @override
  String get createScenarioCachedScheduleCouldNotRead2 =>
      'The cached schedule could not be read.';

  @override
  String get createScenarioDownloadedScheduleInvalidWasNotSaved =>
      'The downloaded schedule is invalid and was not saved.';

  @override
  String get createScenarioScheduleCouldNotDownloaded =>
      'The schedule could not be downloaded.';

  @override
  String get createScenarioYouAppearOfflineCachedDataRemains =>
      'You appear to be offline. Cached data remains available.';

  @override
  String get createScenarioScheduleDownloadsAreDisabledCachedData =>
      'Schedule downloads are disabled. Cached data remains available.';

  @override
  String get createScenarioDownloadSelectUsableCachedScheduleFirst =>
      'Download or select a usable cached schedule first.';

  @override
  String get createScenarioChooseValidScheduleProvider =>
      'Choose a valid schedule provider.';

  @override
  String get createScenarioNoOfficialScheduleProvidersAreConfigured =>
      'No official schedule providers are configured.';

  @override
  String get createScenarioOfficialScheduleTemporarilyUnavailable =>
      'Official schedule is temporarily unavailable.';

  @override
  String get createScenarioCachedScheduleCouldNotRead =>
      'Cached schedule could not be read.';

  @override
  String get createScenarioCachedScheduleDamagedCannotUsed =>
      'Cached schedule is damaged and cannot be used.';

  @override
  String get createScenarioNoScheduleDownloadedProvider =>
      'No schedule is downloaded for this provider.';

  @override
  String get createScenarioCachedScheduleFreshnessUnknownRecheckBefore =>
      'Cached schedule freshness is unknown. Recheck before travel.';

  @override
  String get createScenarioCheckingCachedSchedule =>
      'Checking cached schedule…';

  @override
  String get createScenarioPlannedScheduleNotLiveSelectionNot =>
      'Planned schedule · not live. This selection is not yet applied to the Scenario.';

  @override
  String get createScenarioSelectionPreview => 'Selection preview';

  @override
  String get createScenarioScheduleSearchFailed => 'Schedule search failed.';

  @override
  String get createScenarioNoDirectServicesFoundAfterSelected =>
      'No direct services found after the selected time.';

  @override
  String get createScenarioChooseDate => 'Choose date';

  @override
  String get createScenarioScenarioDateMissing => 'Scenario date is missing';

  @override
  String get createScenarioRetry => 'Retry';

  @override
  String get createScenarioUseCached => 'Use cached';

  @override
  String get createScenarioUpdateSchedule => 'Update schedule';

  @override
  String get createScenarioDownloadSchedule => 'Download schedule';

  @override
  String get createScenarioScheduleProvider => 'Schedule provider';

  @override
  String get createScenarioOfficialScheduleProvidersAreUnavailable =>
      'Official schedule providers are unavailable.';

  @override
  String get createScenarioPlannedScheduleNotLiveDelaysTickets =>
      'Planned schedule · not live. Delays, tickets, fares, seats and transfers are not confirmed. Recheck before travel.';

  @override
  String get createScenarioEnterScheduleManually => 'Enter schedule manually';

  @override
  String get createScenarioApplyCreatesOneUndoableScenarioChange =>
      'Apply creates one undoable Scenario change.';

  @override
  String get createScenarioServiceHasNoValidStopCoordinates =>
      'This service has no valid stop coordinates and cannot be applied safely.';

  @override
  String get createScenarioApplyScenario => 'Apply to Scenario';

  @override
  String get createScenarioChooseDateCheckOfficialSchedule =>
      'Choose a date to check the official schedule.';

  @override
  String get createScenarioFindDirectServices => 'Find direct services';

  @override
  String get createScenarioDownloadScheduleBeforeSearchingStops =>
      'Download a schedule before searching for stops.';

  @override
  String get createScenarioDestination => 'Destination';

  @override
  String get createScenarioOrigin => 'Origin';

  @override
  String get createScenarioCloseOfficialSchedule => 'Close official schedule';

  @override
  String get createScenarioOfficialSchedule => 'Official schedule';

  @override
  String get createScenarioStaticTimetableSnapshotNotLive =>
      'Static timetable snapshot · not live.';

  @override
  String get createScenarioFindOfficialSchedule => 'Find in official schedule';

  @override
  String get createScenarioWorksOfflineStaysEditable =>
      'Works offline and stays editable.';

  @override
  String get createScenarioEnterManually => 'Enter manually';

  @override
  String get createScenarioAddPlannedTransport => 'Add planned transport';

  @override
  String get createScenarioPublicTransport => 'Public transport';

  @override
  String get createScenarioOwnCar => 'Own car';

  @override
  String get createScenarioProviderValue => 'Provider value';

  @override
  String get createScenarioEstimatedTime => 'Estimated time';

  @override
  String get createScenarioEnteredManually => 'Entered manually';

  @override
  String get createScenarioPlannedScheduleNotLive2 =>
      'Planned schedule · not live';

  @override
  String get createScenarioCustomLocation => 'Custom location';

  @override
  String get createScenarioPlannedTransport => 'Planned transport';

  @override
  String get createScenarioAddAtLeastTwoIndependentStops =>
      'Add at least two independent stops. Use catalog objects or custom time blocks.';

  @override
  String get createScenarioLocationDataRequiredManualLeg =>
      'Location data required for a manual leg';

  @override
  String get createScenarioScenarioChangedRecheckBeforeReplacing =>
      'Scenario changed. Recheck before replacing.';

  @override
  String get createScenarioSavedScheduleReplaced => 'Saved schedule replaced.';

  @override
  String get createScenarioRecheckSchedule => 'Recheck schedule';

  @override
  String get createScenarioScenarioChangedReviewServiceTryAgain =>
      'Scenario changed. Review the service and try again.';

  @override
  String get createScenarioOfficialScheduleAddedScenario =>
      'Official schedule added to Scenario.';

  @override
  String get createScenarioReview => 'Review';

  @override
  String get createScenarioUseYourPrimaryTransportEnterHonest =>
      'Use your primary transport or enter honest manual values.';

  @override
  String get createScenarioTravelBetweenStops => 'Travel between stops';

  @override
  String get createScenarioTimeLock => 'Time lock';

  @override
  String get createScenarioOrderLock => 'Order lock';

  @override
  String get createScenarioOptional => 'Optional';

  @override
  String get createScenarioMandatory => 'Mandatory';

  @override
  String get createScenarioRemove => 'Remove';

  @override
  String get createScenarioMoveDown => 'Move down';

  @override
  String get createScenarioMoveUp => 'Move up';

  @override
  String get createScenarioAddCustomTimeBlock => 'Add custom time block';

  @override
  String get createScenarioBusTrainTimesAreStoredAs =>
      'Bus and train times are stored as planned schedule · not live.';

  @override
  String get createScenarioAddCustomStop => 'Add custom stop';

  @override
  String get createScenarioAdd => 'Add';

  @override
  String get createScenarioFindCatalogPlaceEventActivityRoute =>
      'Find a catalog place, event, activity or Route';

  @override
  String get createScenarioRedo => 'Redo';

  @override
  String get createScenarioUndo => 'Undo';

  @override
  String get createScenarioFeedRetrievedAt => 'Feed retrieved at';

  @override
  String get createScenarioFeedVersion => 'Feed version';

  @override
  String get createScenarioServiceLabel => 'Service label';

  @override
  String get createScenarioArrivalTime => 'Arrival time';

  @override
  String get createScenarioDepartureTime => 'Departure time';

  @override
  String get createScenarioDestinationStop => 'Destination stop';

  @override
  String get createScenarioOriginStop => 'Origin stop';

  @override
  String get createScenarioServiceCalendar => 'Service calendar';

  @override
  String get createScenarioSavedItemWasKeptUnchangedCannot =>
      'The saved item was kept unchanged and cannot be rechecked automatically.';

  @override
  String get createScenarioSavedItemWasKeptUnchangedBecause =>
      'The saved item was kept unchanged because cached schedule data is unavailable.';

  @override
  String get createScenarioSavedItemWasKeptUnchangedRecheck =>
      'The saved item was kept unchanged. Recheck later or enter transport manually.';

  @override
  String get createScenarioReviewEveryDifferenceBeforeReplacingSaved =>
      'Review every difference before replacing the saved snapshot.';

  @override
  String get createScenarioCachedOfficialScheduleMatchesSavedSnapshot =>
      'The cached official schedule matches the saved snapshot. It is still not live.';

  @override
  String get createScenarioSavedDataIncomplete => 'Saved data is incomplete';

  @override
  String get createScenarioRecheckUnavailable => 'Recheck unavailable';

  @override
  String get createScenarioServiceNotFound => 'Service not found';

  @override
  String get createScenarioNoScheduleChangesFound =>
      'No schedule changes found';

  @override
  String get createScenarioClose => 'Close';

  @override
  String get createScenarioReplaceSavedSchedule => 'Replace saved schedule';

  @override
  String get createScenarioPlannedScheduleNotLiveReplaceChanges =>
      'Planned schedule · not live. Replace changes only the saved snapshot after explicit confirmation.';

  @override
  String get createScenarioChangesCachedOfficialSchedule =>
      'Changes in the cached official schedule';

  @override
  String get createScenarioCloseScheduleRecheck => 'Close schedule recheck';

  @override
  String get createScenarioScheduleRecheck => 'Schedule recheck';

  @override
  String get createScenarioDiscard => 'Discard';

  @override
  String get createScenarioEditPrompt => 'Edit prompt';

  @override
  String get createScenarioStillUnverified => 'Still unverified';

  @override
  String get createScenarioPreviewReadinessNeedsYourReview =>
      'Preview readiness: needs your review';

  @override
  String get createScenarioPreviewReadinessReadyReview =>
      'Preview readiness: ready to review';

  @override
  String get createScenarioCatalogSnapshot => 'Catalog snapshot';

  @override
  String get createScenarioProposedStops => 'Proposed stops';

  @override
  String get createScenarioGeneratePreview => 'Generate preview';

  @override
  String get createScenarioBuildingPreview => 'Building preview…';

  @override
  String get createScenarioUseExample => 'Use an example';

  @override
  String get createScenarioRelaxedAfternoonRigaWithCultureDinner =>
      'A relaxed afternoon in Riga with culture and dinner';

  @override
  String get createScenarioWhatWouldYouLikeDo => 'What would you like to do?';

  @override
  String get createScenarioDescribeMoodPrioritiesDemoUsesOnly =>
      'Describe the mood and priorities. This demo uses only the local Recharge catalog; it does not call an external AI.';

  @override
  String get createScenarioLocalDemo => 'Local demo';

  @override
  String get createScenarioBuildWithAi => 'Build with AI';

  @override
  String get createScenarioSaveTravel => 'Save travel';

  @override
  String get createScenarioTravelMode => 'Travel mode';

  @override
  String get createScenarioManualValuesStayLockedUntilYou =>
      'Manual values stay locked until you edit them.';

  @override
  String get createScenarioAddScenario => 'Add to Scenario';

  @override
  String get createScenarioServiceRoute => 'Service or route *';

  @override
  String get createScenarioTransport => 'Transport';

  @override
  String get createScenarioPlannedScheduleNotLiveRecheckService =>
      'Planned schedule · not live. Recheck the service before travel.';

  @override
  String get createScenarioPrimaryTransport => 'Primary transport';

  @override
  String get createScenarioOwnCarFullySupportedPublicTransport =>
      'Own car is fully supported. Public transport uses planned schedules, not live data.';

  @override
  String get createScenarioHowWillYouTravel => 'How will you travel?';

  @override
  String get createScenarioBudgetBasis => 'Budget basis';

  @override
  String get createScenarioPace => 'Pace';

  @override
  String get createScenarioPeople => 'People';

  @override
  String get createScenarioParty => 'Party';

  @override
  String get createScenarioDatedTrip => 'Dated trip';

  @override
  String get createScenarioFlexibleTemplate => 'Flexible template';

  @override
  String get createScenarioFormat => 'Format';

  @override
  String get createScenarioScenarioTitle => 'Scenario title *';

  @override
  String get createScenarioPublicUnlistedScenarioPublishingRemainsDisabled =>
      'Public and unlisted Scenario publishing remains disabled until publisher capabilities and moderation are implemented.';

  @override
  String get createScenarioPlannedScheduleNotLiveRecheckDepartures =>
      'Planned schedule · not live. Recheck departures, delays and cancellations before travel.';

  @override
  String get createScenarioActionSavesPersonalScenarioDoesNot =>
      'This action saves a personal Scenario. It does not publish it to the catalog.';

  @override
  String get createScenarioReadyMyScenarios => 'Ready for My Scenarios';

  @override
  String get createScenarioWarnings => 'Warnings';

  @override
  String get createScenarioUnknownTravel => 'Unknown travel';

  @override
  String get createScenarioTimeBlocks => 'Time blocks';

  @override
  String get createScenarioActivity => 'Activity';

  @override
  String get createScenarioActiveStops => 'Active stops';

  @override
  String get createScenarioScenarioDataUnavailable =>
      'Scenario data is unavailable.';

  @override
  String get createScenarioSaveMyScenarios => 'Save to My Scenarios';

  @override
  String get createScenarioBack => 'Back';

  @override
  String get createScenarioExpandedFromQuickPlanAsIndependent =>
      'Expanded from a Quick Plan as an independent copy. Legacy stops are private custom locations until you review them.';

  @override
  String get createScenarioBuildCityDayWeekendTripPlan =>
      'Build a city, day, weekend or trip plan from independent stops. A Scenario is not a Route and does not change a Quick Plan.';

  @override
  String get createScenarioScenarioPlan => 'Scenario plan';

  @override
  String get createScenarioTitle => 'Title';

  @override
  String get createScenarioUseCoordinatesAnyLocationLatviaStop =>
      'Use coordinates for any location in Latvia. The stop stays private by default.';

  @override
  String get createScenarioAddTimeBlock => 'Add time block';

  @override
  String get createScenarioFeedSha256 => 'Feed SHA-256';

  @override
  String get createScenarioFeedRetrieved2 => 'Feed retrieved';

  @override
  String get createScenarioLicence => 'Licence';

  @override
  String get createScenarioStops => 'Stops';

  @override
  String get createScenarioPlannedTime => 'Planned time';

  @override
  String get createScenarioServiceDate => 'Service date';

  @override
  String get createScenarioProvider => 'Provider';

  @override
  String get createFindPeopleExactAddressLabel => 'Exact address';

  @override
  String get createFindPeopleExactGeoLabel => 'Exact point';

  @override
  String get createFindPeopleOnlineAccessLabel => 'Online access reference';

  @override
  String get createFindPeopleNotSet => 'Not set';

  @override
  String get createFindPeopleConfigured => 'Configured';

  @override
  String get createScenarioSelectionPreviewUnchanged =>
      'Selection preview only. Scenario is unchanged.';

  @override
  String createScenarioActivityTime(String value) {
    return 'Activity time: $value';
  }

  @override
  String createScenarioDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String createScenarioDurationHours(int count) {
    return '$count h';
  }

  @override
  String createScenarioDurationHoursMinutes(int start, int end) {
    return '$start h $end min';
  }

  @override
  String createScenarioMinutesNotLive(int count) {
    return '$count min · Planned schedule · not live';
  }

  @override
  String createScenarioFeedRetrievedLine(String value) {
    return 'Feed retrieved $value';
  }

  @override
  String get createScenarioCacheCurrent => 'Cached schedule is current.';

  @override
  String createScenarioCacheCurrentAt(String value) {
    return 'Cached schedule is current · $value.';
  }

  @override
  String get createScenarioCacheStale =>
      'Cached schedule is stale. You may use it with a warning or update it.';

  @override
  String createScenarioCacheStaleAt(String value) {
    return 'Cached schedule is stale · $value. You may use it with a warning or update it.';
  }

  @override
  String get createStepFindPeopleActivityTitle => 'Activity';

  @override
  String get createStepFindPeopleActivityDescription =>
      'Describe what you want to do and who it suits.';

  @override
  String get createStepFindPeopleScheduleTitle => 'When';

  @override
  String get createStepFindPeopleScheduleDescription =>
      'Choose one time, a poll, or a finite recurring series.';

  @override
  String get createStepFindPeopleMeetingTitle => 'Where';

  @override
  String get createStepFindPeopleMeetingDescription =>
      'Keep the public area separate from private meeting details.';

  @override
  String get createStepFindPeopleGroupTitle => 'Group';

  @override
  String get createStepFindPeopleGroupDescription =>
      'Set capacity, applications, verification, waitlist, and costs.';

  @override
  String get createStepFindPeopleHostsTitle => 'Hosts & access';

  @override
  String get createStepFindPeopleHostsDescription =>
      'Configure publisher, visibility, communication, and sharing.';

  @override
  String get createStepFindPeoplePublishTitle => 'Preview & publish';

  @override
  String get createStepFindPeoplePublishDescription =>
      'Review public/private data and complete safety confirmations.';

  @override
  String get createStepRouteMethodTitle => 'Method';

  @override
  String get createStepRouteMethodDescription =>
      'Choose how the continuous track is created';

  @override
  String get createStepRouteProfileTitle => 'Profile';

  @override
  String get createStepRouteProfileDescription =>
      'Set movement profile and routing preferences';

  @override
  String get createStepRouteEditorTitle => 'Track';

  @override
  String get createStepRouteEditorDescription =>
      'Edit anchors and continuous route segments';

  @override
  String get createStepRouteDetailsTitle => 'Details';

  @override
  String get createStepRouteDetailsDescription =>
      'Add route conditions and practical information';

  @override
  String get createStepRouteReviewTitle => 'Review';

  @override
  String get createStepRouteReviewDescription =>
      'Review geometry, warnings and readiness';

  @override
  String get createStepSessionWhatWhereTitle => 'What and where';

  @override
  String get createStepSessionWhatWhereDescription =>
      'Resource, category, media, location, timezone';

  @override
  String get createStepSessionWhenTitle => 'When';

  @override
  String get createStepSessionWhenDescription =>
      'Weekly schedule, duration, buffer, notice';

  @override
  String get createStepSessionPriceAndBookingTitle => 'Price and booking';

  @override
  String get createStepSessionPriceAndBookingDescription =>
      'Price, max party size, external booking URL';

  @override
  String get createStepClassWorkshopBasicsTitle => 'Offering';

  @override
  String get createStepClassWorkshopBasicsDescription =>
      'Kind, title, descriptions, category, criteria and media';

  @override
  String get createStepClassWorkshopLearningTitle => 'Programme and instructor';

  @override
  String get createStepClassWorkshopLearningDescription =>
      'Outcomes, programme, prerequisites and instructor';

  @override
  String get createStepClassWorkshopScheduleTitle => 'Dates and place';

  @override
  String get createStepClassWorkshopScheduleDescription =>
      'Single class or fixed series, timezone, delivery, place';

  @override
  String get createStepClassWorkshopParticipationTitle => 'Participation';

  @override
  String get createStepClassWorkshopParticipationDescription =>
      'Materials, requirements, group size, price, enrollment';

  @override
  String get createStepScenarioContextTitle => 'Context';

  @override
  String get createStepScenarioContextDescription =>
      'Format, date mode, party, pace and budget';

  @override
  String get createStepScenarioComposerTitle => 'Plan';

  @override
  String get createStepScenarioComposerDescription =>
      'Independent stops, time blocks and their order';

  @override
  String get createStepScenarioReviewTitle => 'Review';

  @override
  String get createStepScenarioReviewDescription =>
      'Totals, warnings and personal save readiness';

  @override
  String get createSessionPresetEveryday => 'Every day 9:00–21:00';

  @override
  String get createSessionPresetWeekdays => 'Weekdays 9:00–18:00';

  @override
  String createFindPeopleHouseRule(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'be_on_time': 'Be on time',
      'respect_boundaries': 'Respect boundaries',
      'no_harassment': 'No harassment',
      'no_sales': 'No sales',
      'no_substances': 'No alcohol or drugs',
      'bring_required_gear': 'Bring required gear',
      'follow_venue_rules': 'Follow venue rules',
      'leave_no_trace': 'Leave no trace',
      'other': 'Rule',
    });
    return '$_temp0';
  }

  @override
  String createFindPeopleCohostRight(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'review_applications': 'Review applications',
      'manage_schedule': 'Manage schedule',
      'manage_participants': 'Manage participants',
      'moderate_conversation': 'Moderate conversation',
      'other': 'Right',
    });
    return '$_temp0';
  }

  @override
  String get createFindPeopleCohostAccepted => 'Accepted';

  @override
  String get createFindPeopleCohostPending => 'Invitation pending';

  @override
  String get createFindPeopleSeatFitPolicy => 'Seat-fit policy';

  @override
  String get createFindPeopleVisibilityRequired => 'Visibility *';

  @override
  String get createFormDateIso => 'Date (YYYY-MM-DD)';

  @override
  String get createClassFirstSummerTime => 'First (summer time)';

  @override
  String get createRouteOutAndBack => 'Out & back';

  @override
  String get createScenarioEdit => 'Edit';

  @override
  String get createScenarioTimeBlockHint => 'Coffee, rest, free time…';

  @override
  String get createScenarioPrivateLocalTravel => 'Private / local travel';

  @override
  String get createScenarioRouteLabel => 'Route';

  @override
  String get createScenarioCarrierLabel => 'Carrier';

  @override
  String createScenarioSelectedStop(String value) {
    return 'Selected: $value';
  }

  @override
  String get createScenarioDepartureHhMm => 'Departure (HH:mm)';

  @override
  String get createScenarioArrivalHhMm => 'Arrival (HH:mm)';

  @override
  String get createRouteResolveRestore => 'Resolve & restore';

  @override
  String get createRouteResolve => 'Resolve';

  @override
  String scenarioIntakeNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'targetsUnavailable': 'Scenarios are unavailable. Retry from Details.',
      'chooseTarget': 'Choose a Scenario or create a new one.',
      'targetNotEditable': 'This Scenario is no longer editable.',
      'titleRequired': 'Enter a Scenario title.',
      'openFailed': 'Could not open this Scenario.',
      'signInAgain': 'Sign in again before adding items to Scenario.',
      'confirmDuplicate': 'Confirm adding another occurrence.',
      'confirmUnavailable': 'Confirm use of the unavailable saved snapshot.',
      'confirmScheduleAdjustment':
          'Confirm conversion to a flexible template stop.',
      'revisionConflict':
          'Scenario changed. Go back, reopen it and review again.',
      'intentExpired':
          'This selection expired. Return to Details and try again.',
      'targetGone': 'This Scenario is no longer available. Choose another one.',
      'lockedLegBoundary':
          'A locked logistics leg protects this insertion point.',
      'persistenceUnavailable':
          'Could not save. Your selection is retained; retry Apply.',
      'other': 'Could not add this object. Review the selection and retry.',
    });
    return '$_temp0';
  }

  @override
  String scenarioIntakeObjectType(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'event': 'Event',
      'place': 'Place',
      'activity': 'Activity',
      'route': 'Route',
      'bookableSession': 'Session',
      'other': 'Object',
    });
    return '$_temp0';
  }

  @override
  String scenarioIntakeSourceStatus(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'ready': 'Ready',
      'stale': 'Needs refresh',
      'unresolved': 'Not resolved',
      'unavailable': 'Unavailable',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String get scenarioIntakeUnavailable => 'Add to Scenario is unavailable.';

  @override
  String get scenarioIntakeTitle => 'Add to Scenario';

  @override
  String get scenarioIntakeClose => 'Close Add to Scenario';

  @override
  String get scenarioIntakeChooseTarget => 'Choose a personal Scenario';

  @override
  String get scenarioIntakeOnlyPrivateDrafts =>
      'Only your editable private drafts are shown.';

  @override
  String get scenarioIntakeNoTargets =>
      'No saved Scenario yet. Create one below.';

  @override
  String get scenarioIntakeUntitled => 'Untitled';

  @override
  String get scenarioIntakeCreateNew => 'Create new Scenario';

  @override
  String get scenarioIntakeCreateNewHint =>
      'Private · one day · saved only with the stop';

  @override
  String get scenarioIntakeTitleField => 'Scenario title';

  @override
  String get scenarioIntakeContinue => 'Continue to placement';

  @override
  String get scenarioIntakeScenarioFallback => 'Scenario';

  @override
  String get scenarioIntakeDay => 'Day';

  @override
  String get scenarioIntakeUnscheduled => 'Unscheduled';

  @override
  String get scenarioIntakeInsert => 'Insert';

  @override
  String get scenarioIntakeAtEnd => 'At end';

  @override
  String get scenarioIntakeRole => 'Role';

  @override
  String get scenarioIntakeMandatory => 'Mandatory';

  @override
  String get scenarioIntakeOptional => 'Optional';

  @override
  String get scenarioIntakeBack => 'Back';

  @override
  String get scenarioIntakeReview => 'Review';

  @override
  String get scenarioIntakeAddAnother => 'Add another occurrence';

  @override
  String get scenarioIntakeAddAnotherHint =>
      'This exact catalog object already exists in the Scenario.';

  @override
  String get scenarioIntakeUseUnavailable => 'Use saved unavailable snapshot';

  @override
  String get scenarioIntakeUseTemplateStop => 'Use as a flexible template stop';

  @override
  String get scenarioIntakeUseTemplateStopHint =>
      'The source has a fixed date, but this Scenario is a template.';

  @override
  String get scenarioIntakeLogisticsNotice =>
      'Logistics are not recalculated live. Existing unlocked boundary estimates will be invalidated safely.';

  @override
  String scenarioIntakeAddCount(int count) {
    return 'Add $count';
  }

  @override
  String get scenarioIntakeDurationUnknown => 'Duration unknown';

  @override
  String scenarioIntakeFixedStart(String time) {
    return 'Fixed $time';
  }

  @override
  String get scenarioIntakeMoveUp => 'Move up';

  @override
  String get scenarioIntakeMoveDown => 'Move down';

  @override
  String get scenarioIntakeApplyingSemantics =>
      'Adding selected stops to Scenario';

  @override
  String get scenarioIntakeLoadingSemantics => 'Loading your Scenarios';

  @override
  String get scenarioIntakeApplying => 'Adding to Scenario…';

  @override
  String get scenarioIntakeLoading => 'Loading your Scenarios…';

  @override
  String get scenarioIntakeReplayed =>
      'Already saved · no duplicate was created.';

  @override
  String get scenarioIntakeStay => 'Stay here';

  @override
  String get scenarioIntakeOpenScenario => 'Open Scenario';

  @override
  String get scenarioIntakePrepareFailed =>
      'Could not prepare Add to Scenario.';

  @override
  String get scenarioIntakeRetry => 'Retry';

  @override
  String get scenarioIntakeTemplate => 'Template';

  @override
  String get scenarioIntakeDated => 'Dated';

  @override
  String get discoverSchedule => 'Schedule';

  @override
  String get discoverShowOnMap => 'Show on map';

  @override
  String get discoverReadMore => 'Read more';

  @override
  String get discoverShowLess => 'Show less';

  @override
  String get discoverExactAddressNotPublished => 'Exact address not published';

  @override
  String get discoverLocationNotPublished => 'Location not published';

  @override
  String get discoverLinkFromBookingService =>
      'The link comes from the booking service';

  @override
  String get discoverOnline => 'Online';

  @override
  String get discoverPartnerConfirmsTime =>
      'The actual time and terms are confirmed on the partner’s website.';

  @override
  String get discoverTimesToBook => 'Times to book';

  @override
  String get discoverScheduleNeedsRefresh =>
      'The schedule needs a refresh — check the time on the website.';

  @override
  String get discoverNoTimeInWindow =>
      'No time is listed in the current window.';

  @override
  String get discoverCoordinatesNotPublic => 'Coordinates are not public';

  @override
  String get discoverAccessDetailsNotPublished =>
      'Access details are not published';

  @override
  String get discoverApproximateMeetingArea =>
      'Approximate public meeting area';

  @override
  String get discoverFree => 'Free';

  @override
  String get discoverHybrid => 'Hybrid';

  @override
  String get discoverInPerson => 'In person';

  @override
  String get discoverCheckEnrollmentOnSite => 'Check enrollment on the website';

  @override
  String get discoverInAppEnrollmentUnavailable =>
      'In-app enrollment is not connected yet';

  @override
  String get discoverEnrollmentMethodUnknown =>
      'Enrollment method not specified yet';

  @override
  String get discoverTermsOnSite =>
      'Terms of participation are confirmed on site';

  @override
  String get discoverEnrollmentClosed => 'Enrollment closed';

  @override
  String get discoverAvailabilityOnOrganizerSite =>
      'Availability, final price and terms are on the organizer’s website';

  @override
  String get discoverLocationTbc => 'Location to be confirmed';

  @override
  String get discoverOrganizerSendsInstructions =>
      'The organizer will send instructions';

  @override
  String get discoverOnlineClass => 'Online class';

  @override
  String get discoverOrganizerVerified => 'Organizer verified';

  @override
  String get discoverProfileVerified => 'Profile verified';

  @override
  String get discoverTeacher => 'Teacher';

  @override
  String get discoverSessionDuration => 'Session duration';

  @override
  String get discoverCourseDuration => 'Course duration';

  @override
  String get discoverPrice => 'Price';

  @override
  String get discoverPricePerPersonCourse => 'Price per person / course';

  @override
  String get discoverPricePerPersonSession => 'Price per person / session';

  @override
  String get discoverDatesTbc => 'Dates to be confirmed';

  @override
  String get discoverKindHandsOn => 'Hands-on experience';

  @override
  String get discoverKindCourse => 'Course';

  @override
  String get discoverKindMasterclass => 'Masterclass';

  @override
  String get discoverKindWorkshop => 'Workshop';

  @override
  String get discoverKindClass => 'Class';

  @override
  String get discoverRecruitmentClosed => 'Closed to new people';

  @override
  String get discoverMeetupCancelled => 'Meetup cancelled';

  @override
  String get discoverMeetupEnded => 'Meetup ended';

  @override
  String get discoverGroupFull => 'Group is full';

  @override
  String get discoverWaitlistOnly => 'Waitlist only';

  @override
  String get discoverRecruitmentOpen => 'Open to join';

  @override
  String get discoverCollectingTimeOptions => 'Collecting time options';

  @override
  String get discoverDeliveryAvailable => 'Delivery available';

  @override
  String get discoverDepositRequired => 'Deposit required';

  @override
  String get discoverNoDepositRequired => 'No deposit required';

  @override
  String get discoverPriceOnRequest => 'Price on request';

  @override
  String get discoverSignUp => 'Sign up';

  @override
  String get discoverAddToCalendar => 'Add to calendar';

  @override
  String get discoverAboutEvent => 'About the event';

  @override
  String get discoverProfile => 'Profile';

  @override
  String get discoverClubProfile => 'Club profile';

  @override
  String get discoverOrganizer => 'Organizer';

  @override
  String get discoverDuration => 'Duration';

  @override
  String get discoverParticipantCountUnknown =>
      'Number of participants unknown';

  @override
  String get discoverParticipants => 'Participants';

  @override
  String get discoverAddToScenario => 'Add to Scenario';

  @override
  String get discoverShare => 'Share';

  @override
  String get discoverBadgeEvent => 'EVENT';

  @override
  String get discoverCurrentlyUnavailable => 'Currently unavailable';

  @override
  String get discoverConfirmOnProviderSite => 'Confirm on provider site';

  @override
  String get discoverRatePlan => 'Rate plan';

  @override
  String get discoverWhatIsRented => 'What is rented';

  @override
  String get discoverBadgeRental => 'RENTAL';

  @override
  String get discoverFlexible => 'Flexible';

  @override
  String get discoverAboutClass => 'About the class';

  @override
  String get discoverClosed => 'Closed';

  @override
  String get discoverOpeningHours => 'Opening hours';

  @override
  String get discoverAboutPlace => 'About the place';

  @override
  String get discoverTime => 'Time';

  @override
  String get discoverFromYou => 'From you';

  @override
  String get discoverAboutService => 'About the service';

  @override
  String get discoverSpecialist => 'Specialist';

  @override
  String get discoverOrganization => 'Organisation';

  @override
  String get discoverGroupSize => 'Group size';

  @override
  String get discoverRequirements => 'Requirements';

  @override
  String get discoverMaterialsIncluded => 'Materials and what is included';

  @override
  String get discoverCostsNotSpecified => 'Costs not specified';

  @override
  String get discoverNoRequiredCosts => 'No required costs';

  @override
  String get discoverDesiredSize => 'Desired size';

  @override
  String get discoverInGroupNow => 'In the group now';

  @override
  String get discoverExpectedCosts => 'Expected costs';

  @override
  String get discoverParticipantRequirements => 'Participant requirements';

  @override
  String get discoverMeetupFormat => 'Meetup format';

  @override
  String get discoverMeetupTime => 'Meetup time';

  @override
  String get discoverTimeOptions => 'Time options';

  @override
  String get discoverAboutMeetup => 'About the meetup';

  @override
  String get discoverPublisher => 'Publisher';

  @override
  String get discoverShareAndMore => 'Share and more actions';

  @override
  String get discoverMarkVisited => 'Mark as visited';

  @override
  String get discoverCreateRoute => 'Create route';

  @override
  String get discoverViewRoute => 'View route';

  @override
  String get discoverCreateSimilar => 'Create similar';

  @override
  String get discoverFindSimilar => 'Find similar';

  @override
  String get discoverCheckTimeOnSite => 'Check the time on the website';

  @override
  String get discoverReviewAndBook => 'Review and book';

  @override
  String get discoverRequestSent => 'Request sent';

  @override
  String get discoverDateSet => 'Date set';

  @override
  String get discoverAnyDate => 'Any date';

  @override
  String get discoverDone => 'Done';

  @override
  String get discoverWindowAsEntered => 'Used as entered for time matching.';

  @override
  String get discoverEffectiveWindow => 'Effective window';

  @override
  String get discoverBufferEachSide => 'Buffer on each side';

  @override
  String get discoverEnd => 'End';

  @override
  String get discoverStart => 'Start';

  @override
  String get discoverChangeDate => 'Change date';

  @override
  String get discoverFlexibleTime => 'Flexible';

  @override
  String get discoverExact => 'Exact';

  @override
  String get discoverBackToFilters => 'Back to filters';

  @override
  String get discoverReset => 'Reset';

  @override
  String get discoverExactTime => 'Exact time';

  @override
  String get discoverApplyFilters => 'Apply filters';

  @override
  String get discoverIncludeReturnTrip => 'Include return trip';

  @override
  String get discoverTransit => 'Public transport';

  @override
  String get discoverDriving => 'Driving';

  @override
  String get discoverWalking => 'Walking';

  @override
  String get discoverMapPoint => 'Map point';

  @override
  String get discoverTravel => 'Travel';

  @override
  String get discoverNoBuffer => 'No buffer';

  @override
  String get discoverChangeFlexibility => 'Change flexibility';

  @override
  String get discoverWindowEdgeBuffer => 'Window edge buffer';

  @override
  String get discoverToday => 'Today';

  @override
  String get discoverWhen => 'When';

  @override
  String get discoverSave => 'Save';

  @override
  String get discoverCancel => 'Cancel';

  @override
  String get discoverEnterBudget => 'Enter an amount from €0 to €10,000';

  @override
  String get discoverAmountInEur => 'Amount in EUR';

  @override
  String get discoverBudgetPerPerson => 'Budget per person';

  @override
  String get discoverEnterPeople => 'Enter a number from 1 to 99';

  @override
  String get discoverExampleSix => 'For example, 6';

  @override
  String get discoverNumberOfPeople => 'Number of people';

  @override
  String get discoverAnyArea => 'Any area';

  @override
  String get discoverAnyDuration => 'Any duration';

  @override
  String get discoverAnyDistance => 'Any distance';

  @override
  String get discoverOnlyAvailable => 'Only available';

  @override
  String get discoverOpenNow => 'Open now';

  @override
  String get discoverTimeAvailable => 'Time available';

  @override
  String get discoverSearchFilters => 'Search filters';

  @override
  String get discoverSocialEvening => 'Social evening';

  @override
  String get discoverActiveMorning => 'Active morning';

  @override
  String get discoverSunsetBreak => 'Sunset break';

  @override
  String get discoverAfterWork => 'After work';

  @override
  String get discoverRegularSearchesHint =>
      'Your regular searches will appear here automatically.';

  @override
  String get discoverCalmEvening => 'Calm evening';

  @override
  String get discoverLowBudget => 'Low budget';

  @override
  String get discoverForTwo => 'For two';

  @override
  String get discoverNearMeNow => 'Near me now';

  @override
  String get discoverApplyRadius => 'Apply radius';

  @override
  String get discoverCustomRadius => 'Custom radius';

  @override
  String get discoverSearchRadius => 'Search radius';

  @override
  String get discoverAnyBudget => 'Any budget';

  @override
  String get discoverExampleEight => 'For example, 8';

  @override
  String get discoverJustMe => 'Just me';

  @override
  String get discoverAnyGroup => 'Any group';

  @override
  String get discoverChooseSearchDates => 'Choose search dates';

  @override
  String get discoverChooseDates => 'Choose dates';

  @override
  String get discoverThisWeekend => 'This weekend';

  @override
  String get discoverTomorrow => 'Tomorrow';

  @override
  String get discoverChooseDate => 'Choose date';

  @override
  String get discoverUntilEndOfDay => 'Until end of day';

  @override
  String get discoverRecentSearches => 'Recent searches';

  @override
  String get discoverQuickPlans => 'Quick plans';

  @override
  String get discoverSeeAll => 'See all';

  @override
  String get discoverSearchHint => 'Search activity, place or plan';

  @override
  String get discoverSearchRecharge => 'Search Recharge';

  @override
  String get discoverJoinActivity => 'Join activity';

  @override
  String get discoverParticipantsUnknown => 'Participants unknown';

  @override
  String get discoverCapacityUnknown => 'Capacity unknown';

  @override
  String get discoverOpeningHoursUnknown => 'Opening hours unknown';

  @override
  String get discoverTimeNotConfirmed => 'Time not confirmed';

  @override
  String get discoverDoesNotFit => 'Does not fit';

  @override
  String get discoverPartialAttendance => 'Partial attendance possible';

  @override
  String get discoverFitsYourTime => 'Fits your time';

  @override
  String get discoverOptionalContribution => 'Optional contribution';

  @override
  String get discoverNoContribution => 'No contribution specified';

  @override
  String get discoverDifficultyNotSet => 'Difficulty not set';

  @override
  String get discoverAnyTime => 'Any time';

  @override
  String get discoverWhatAwaitsYou => 'What awaits you';

  @override
  String get discoverPerkSaveForLater => 'Save the activity for later';

  @override
  String get discoverPerkOrganizerDetails =>
      'Organizer details available before joining';

  @override
  String get discoverPerkMeetingPoint => 'Clear meeting point and timing';

  @override
  String get discoverDistance => 'Distance';

  @override
  String get discoverLocation => 'Location';

  @override
  String get discoverRouteGeometry => 'Route geometry';

  @override
  String get discoverDateAndTime => 'Date and time';

  @override
  String get discoverRouteMap => 'Route map';

  @override
  String get discoverRouteFromThis => 'Route from this';

  @override
  String get discoverAddToPrivateHistory => 'Add to private history';

  @override
  String get discoverOpenCreateHub => 'Open Create Hub';

  @override
  String get discoverSearchThisCategory => 'Search with this category';

  @override
  String get discoverAddStopToPlan => 'Add this stop to a personal plan';

  @override
  String get discoverOpenNearbyContext => 'Open nearby context';

  @override
  String get discoverMap => 'Map';

  @override
  String get discoverPlanHint =>
      'Turn this activity into a route, compare similar options, or save it for later.';

  @override
  String get discoverNotSaved => 'Not saved';

  @override
  String get discoverPlanThisRecharge => 'Plan this recharge';

  @override
  String get discoverSend => 'Send';

  @override
  String get discoverCriticalOnlyImmediateRisk =>
      'Choose critical danger only when people are at immediate risk.';

  @override
  String get discoverDescribeWithoutPersonalData =>
      'Describe the problem without personal data';

  @override
  String get discoverCommentOptional => 'Comment (optional)';

  @override
  String get discoverSeverityCritical => 'Critical danger';

  @override
  String get discoverSeverityDanger => 'Dangerous';

  @override
  String get discoverSeverityWarning => 'Needs attention';

  @override
  String get discoverSeverityInfo => 'Information';

  @override
  String get discoverSeverity => 'Severity';

  @override
  String get discoverIssueOther => 'Other';

  @override
  String get discoverIssueWrongLine => 'Wrong route line';

  @override
  String get discoverIssueObstacle => 'Obstacle';

  @override
  String get discoverIssueHazardousSurface => 'Hazardous surface';

  @override
  String get discoverIssueTrailClosed => 'Trail closed';

  @override
  String get discoverWhatHappened => 'What happened';

  @override
  String get discoverRouteIssue => 'Problem on the route';

  @override
  String get discoverReportRouteIssue => 'Report a problem on the route';

  @override
  String get discoverElevationUnavailable =>
      'Elevation data is unavailable and is not shown as zero.';

  @override
  String get discoverElevationPartial =>
      'Elevation data is partial; ascent and descent are not presented as complete.';

  @override
  String get discoverDemoData => 'Demo data';

  @override
  String get discoverFieldVerified => 'Field verified';

  @override
  String get discoverPublishedRoute => 'Published Route';

  @override
  String get discoverOpenDetails => 'Open details';

  @override
  String get discoverSelectForScenario => 'Select for Scenario';

  @override
  String get discoverAny => 'Any';

  @override
  String get discoverSearchThisArea => 'Search this area';

  @override
  String get discoverResetRouteProgress => 'Reset route progress';

  @override
  String get discoverStartRoute => 'Start route';

  @override
  String get discoverNextStop => 'Next stop';

  @override
  String get discoverReadyToStart => 'Ready to start';

  @override
  String get discoverRouteComplete => 'Route complete';

  @override
  String get discoverCopy => 'Copy';

  @override
  String get discoverCreateRouteListing => 'Create route listing';

  @override
  String get discoverSearchSimilarRoute => 'Search similar route';

  @override
  String get discoverEditRoute => 'Edit route';

  @override
  String get discoverScenarioRoute => 'Scenario route';

  @override
  String get discoverNoActivitiesInArea => 'No activities in this area';

  @override
  String get discoverRetry => 'Retry';

  @override
  String get discoverMapSearchFailed => 'Map search failed';

  @override
  String get discoverMapResults => 'Map results';

  @override
  String get discoverApply => 'Apply';

  @override
  String get discoverSavedOnMap => 'Saved on map';

  @override
  String get discoverRouteFromSmart => 'Build route from smart search';

  @override
  String get discoverCreateFromSmart => 'Create listing from smart search';

  @override
  String get discoverApplySmartToMap => 'Apply smart search to map';

  @override
  String get discoverSmart => 'Smart';

  @override
  String get discoverRouteFromSaved => 'Build route from saved conditions';

  @override
  String get discoverCreateFromSaved => 'Create listing from saved conditions';

  @override
  String get discoverApplySavedToMap => 'Apply saved conditions to map';

  @override
  String get discoverSaved => 'Saved';

  @override
  String get discoverCreateHere => 'Create here';

  @override
  String get discoverSearch => 'Search';

  @override
  String get discoverClear => 'Clear';

  @override
  String get discoverSearchOnMap => 'Search on map';

  @override
  String get discoverMapArea => 'Map area';

  @override
  String get discoverRechargeIdea => 'Recharge idea';

  @override
  String get discoverMapAreaIdea => 'Map area idea';

  @override
  String get discoverScenarioCopied => 'Scenario copied';

  @override
  String get discoverScenarioSaved => 'Scenario saved';

  @override
  String get discoverRecenter => 'Recenter';

  @override
  String get discoverUseCurrentLocation => 'Use current location';

  @override
  String get discoverCancelScenarioSelection => 'Cancel Scenario selection';

  @override
  String get discoverAll => 'All';

  @override
  String get discoverSearchFailed => 'Search failed';

  @override
  String get discoverResetConditions => 'Reset conditions';

  @override
  String get discoverNoMatches => 'No activities match these conditions';

  @override
  String get discoverShowingNearby => 'Showing nearby activities';

  @override
  String get discoverRadius => 'Radius';

  @override
  String get discoverTonight => 'Tonight';

  @override
  String get discoverDate => 'Date';

  @override
  String get discoverBudget => 'Budget';

  @override
  String get discoverShowNoTicket => 'Show no-ticket activities';

  @override
  String get discoverFreeOnly => 'Free only';

  @override
  String get discoverOutdoor => 'Outdoor';

  @override
  String get discoverFreeToday => 'Free today';

  @override
  String get discoverSearchConditions => 'Search conditions';

  @override
  String get discoverOpenSavedOnMap => 'Open saved conditions on map';

  @override
  String get discoverDeleteSaved => 'Delete saved conditions';

  @override
  String get discoverNoRecentSearches => 'No recent searches yet';

  @override
  String get discoverCreateListingFromSearch =>
      'Create listing from current search';

  @override
  String get discoverConditions => 'Conditions';

  @override
  String get discoverViewMap => 'View map';

  @override
  String get discoverCategories => 'Categories';

  @override
  String get discoverQuickScenarios => 'Quick scenarios';

  @override
  String get discoverCreateFromCurrentSearch => 'Create from current search';

  @override
  String get discoverUnderstoodParameters => 'Understood parameters';

  @override
  String get discoverTextQuery => 'Text query';

  @override
  String get discoverGotIt => 'Got it';

  @override
  String get discoverSmartSearchHow => 'How Smart Search works';

  @override
  String get discoverSayWhatToFind => 'Say what you want to find';

  @override
  String get discoverSmartSearchPrompt => 'Write or say what to find';

  @override
  String get discoverStartSearch => 'Start search';

  @override
  String get discoverDeleteQuery => 'Delete query';

  @override
  String get discoverRecentSmartSearches => 'Recent smart searches';

  @override
  String get discoverPopularQueries => 'Popular queries';

  @override
  String get discoverChipUpTo20 => 'Up to €20';

  @override
  String get discoverChipOneTwoHours => '1–2 hours';

  @override
  String get discoverChipCalmEvening => 'Calm evening';

  @override
  String get discoverChipForTwo => 'For two';

  @override
  String get discoverChipNearNow => 'Near me now';

  @override
  String get discoverVoiceQuery => 'Voice query';

  @override
  String get discoverSmartSearchPromptTwoLines =>
      'Write or say\\nwhat you want to find';

  @override
  String get discoverSmartSearch => 'Smart Search';

  @override
  String get discoverHoursUnknown => 'Hours unknown';

  @override
  String get discoverTimeUnknown => 'Time unknown';

  @override
  String get discoverPartialFit => 'Partial fit';

  @override
  String get discoverMatchesYourTime => 'Matches your time';

  @override
  String get discoverOpenSettings => 'Open settings';

  @override
  String get discoverNoLocationAccess => 'No access to location';

  @override
  String get discoverFeedFailed => 'Could not load the feed';

  @override
  String get discoverRemoveTime => 'Remove the time';

  @override
  String get discoverNoReturnTrip => 'Without the return trip';

  @override
  String get discoverWidenTime => 'Widen the time';

  @override
  String get discoverRefresh => 'Refresh';

  @override
  String get discoverFeedEmpty => 'Nothing in the feed yet';

  @override
  String get discoverFeedLoading => 'Loading the feed…';

  @override
  String get discoverWaypoints => 'Points on the route';

  @override
  String get discoverElevation => 'Elevation';

  @override
  String get discoverDescent => 'Descent';

  @override
  String get discoverAscent => 'Ascent';

  @override
  String get discoverRouteMapFailed => 'Could not load the route map';

  @override
  String get discoverOpenOnMap => 'Open on map';

  @override
  String get discoverShapeOneWay => 'One way';

  @override
  String get discoverShapeOutAndBack => 'Out and back';

  @override
  String get discoverShapeLoop => 'Loop';

  @override
  String get discoverPublisherPage => 'Page';

  @override
  String get discoverPublisherAuthor => 'Author';

  @override
  String get discoverRouteDetails => 'Route details';

  @override
  String discoverDistanceKm(String value) {
    return '$value km';
  }

  @override
  String discoverDistanceFromYou(String value) {
    return '$value km from you';
  }

  @override
  String discoverStartPointAway(String value) {
    return 'Start point · $value km away';
  }

  @override
  String discoverFromStartKm(String value) {
    return '$value km from the start';
  }

  @override
  String discoverMeters(String value) {
    return '$value m';
  }

  @override
  String discoverAscentShort(String value) {
    return '↑ $value m';
  }

  @override
  String discoverElevationRange(String min, String max) {
    return '$min–$max m';
  }

  @override
  String discoverTrackGaps(int count) {
    return 'Track gaps: $count';
  }

  @override
  String discoverDirectSegments(int count) {
    return 'Direct segments: $count';
  }

  @override
  String discoverDirectSegmentsInline(int count) {
    return 'direct segments: $count';
  }

  @override
  String discoverMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String discoverMinutesRange(int min, int max) {
    return '$min–$max min';
  }

  @override
  String discoverHours(String value) {
    return '$value h';
  }

  @override
  String discoverHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String discoverDays(int days) {
    return '$days d';
  }

  @override
  String discoverUpTo(int count) {
    return 'up to $count';
  }

  @override
  String discoverUpToPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'up to $count people',
      one: 'up to $count person',
    );
    return '$_temp0';
  }

  @override
  String discoverAboutPerPerson(String price) {
    return 'About $price per person';
  }

  @override
  String discoverCancelledSuffix(String date) {
    return '$date · Cancelled';
  }

  @override
  String get discoverRentalQuantitiesDisclaimer =>
      'Listed quantities are Creator-declared, not a live booking guarantee or confirmed-fresh count. Confirm on the provider site before relying on them.';

  @override
  String discoverDeliveryWithin(String value) {
    return 'Delivery available within $value km';
  }

  @override
  String discoverRentalPeriod(String min, String max) {
    return 'Rental period: $min – $max';
  }

  @override
  String discoverMinAge(int age) {
    return 'Min age $age';
  }

  @override
  String get discoverIdRequired => 'ID required at handover';

  @override
  String discoverDeposit(String price) {
    return 'Deposit: $price';
  }

  @override
  String discoverTimeOptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count time options',
      one: '$count time option',
    );
    return '$_temp0';
  }

  @override
  String discoverFirstAndMore(String time, int count) {
    return '$time · $count more';
  }

  @override
  String discoverTimeOptionCandidate(String time) {
    return 'Option · $time';
  }

  @override
  String discoverDateTimeRange(String date, String start, String end) {
    return '$date · $start–$end';
  }

  @override
  String discoverUpToBudget(String price) {
    return 'Up to $price';
  }

  @override
  String discoverFlexibilityMinutes(int minutes) {
    return '±$minutes min';
  }

  @override
  String discoverUsedInsteadOf(String start, String end) {
    return 'Used for matching instead of $start–$end.';
  }

  @override
  String discoverTypicalDuration(String value) {
    return 'Typical duration: $value';
  }

  @override
  String discoverSuggestedGroup(int min, int max) {
    return 'Suggested group: $min–$max';
  }

  @override
  String discoverBestTime(String value) {
    return 'Best time: $value';
  }

  @override
  String discoverAmountHint(String price) {
    return 'Amount hint: $price';
  }

  @override
  String discoverBookFor(String price) {
    return 'Book for $price';
  }

  @override
  String discoverResultsInArea(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places and activities in this area',
      one: '$count place or activity in this area',
    );
    return '$_temp0';
  }

  @override
  String discoverStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '$count stop',
    );
    return '$_temp0';
  }

  @override
  String discoverStopOf(int current, int total) {
    return 'Stop $current of $total';
  }

  @override
  String discoverRadiusKm(String value) {
    return 'Radius: $value km';
  }

  @override
  String discoverRemoveFromSelection(int order) {
    return 'Remove #$order from selection';
  }

  @override
  String discoverMood(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm',
      'social': 'Social',
      'active': 'Active',
      'other': 'Custom',
    });
    return '$_temp0';
  }

  @override
  String get discoverRouteLabel => 'Route';

  @override
  String get discoverSmartSearchHowBody =>
      'Type a query or use voice input. Recharge reads the time, place, budget and mood and shows suitable options.';

  @override
  String get discoverSmartPromptCalmEveningNearby => 'Calm evening nearby';

  @override
  String get discoverSmartPromptSomethingForTwoHours =>
      'Find something interesting for 2 hours';

  @override
  String get discoverSmartPromptForTwoNearby => 'Where to go for two nearby';

  @override
  String get discoverSmartPromptExample =>
      'Something calm nearby tonight, up to 20 EUR';

  @override
  String get discoverSmartPromptExampleHint =>
      'For example: “Something calm nearby tonight, up to €20”';

  @override
  String get discoverSmartPromptNearNow => 'Something interesting nearby now';

  @override
  String get discoverSmartPromptForTwo => 'Where to go for two';

  @override
  String get discoverSmartPromptCalmEvening => 'Calm evening';

  @override
  String get discoverSmartPromptTwoHours => 'Find a plan for 2 hours';

  @override
  String get discoverSmartPromptUpTo20 => 'Find something up to 20 EUR';

  @override
  String discoverRentalBaseRate(String type, String price) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'hour': '$price / hour',
      'week': '$price / week',
      'other': '$price / day',
    });
    return '$_temp0';
  }

  @override
  String discoverRentalRateStep(String type, String price, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '$count week',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    String _temp3 = intl.Intl.selectLogic(type, {
      'hour': 'From $_temp0: $price / hour',
      'week': 'From $_temp1: $price / week',
      'other': 'From $_temp2: $price / day',
    });
    return '$_temp3';
  }

  @override
  String discoverRentalUnitsListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units listed',
      one: '$count unit listed',
    );
    return '$_temp0';
  }

  @override
  String discoverSeason(String value) {
    return 'Season: $value';
  }

  @override
  String get discoverLength => 'Length';

  @override
  String get discoverPeople => 'People';

  @override
  String get discoverCycling => 'Cycling';

  @override
  String get discoverDifficultyEasy => 'Easy';

  @override
  String get discoverDifficultyModerate => 'Moderate';

  @override
  String get discoverDifficultyHard => 'Hard';

  @override
  String get discoverOpen => 'Open';

  @override
  String discoverAddedToScenario(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count stops to Scenario',
      one: 'Added $count stop to Scenario',
    );
    return '$_temp0';
  }

  @override
  String discoverCompletedDuration(int minutes) {
    return 'Completed · $minutes min';
  }

  @override
  String get discoverRestart => 'Restart';

  @override
  String get discoverFinish => 'Finish';

  @override
  String get discoverRadiusAnyArea => 'Radius: any area';

  @override
  String get discoverWaypoint => 'Point on the route';

  @override
  String discoverFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count found',
      one: '$count found',
    );
    return '$_temp0';
  }

  @override
  String discoverPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String discoverUnder(String value) {
    return 'Under $value';
  }

  @override
  String discoverFlexibleWindow(int minutes) {
    return 'Flexible ±$minutes min';
  }

  @override
  String get discoverCustom => 'Custom';

  @override
  String discoverCustomValue(String value) {
    return 'Custom · $value';
  }

  @override
  String discoverHoursLong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String get discoverAboutOneHour => '~ 1 hour';

  @override
  String discoverHoursRange(int min, int max) {
    return '$min–$max hours';
  }

  @override
  String get discoverAvailability => 'Availability';

  @override
  String get discoverMoodTitle => 'Mood';

  @override
  String discoverTravelMinutes(int minutes) {
    return '$minutes min travel';
  }

  @override
  String discoverTravelMinutesEstimated(int minutes) {
    return '$minutes min travel · est.';
  }

  @override
  String get discoverSlotChosen => 'Time slot chosen';

  @override
  String get discoverFits => 'Fits';

  @override
  String get discoverUnsave => 'Unsave';

  @override
  String discoverRecommendedDifficulty(String value) {
    return 'Recommended $value';
  }

  @override
  String discoverPoiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points of interest',
      one: '$count point of interest',
    );
    return '$_temp0';
  }

  @override
  String get discoverSurfaceTitle => 'Surface';

  @override
  String discoverSurface(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'asphalt': 'Asphalt',
      'paved': 'Paved',
      'concrete': 'Concrete',
      'paving_stones': 'Paving stones',
      'sett': 'Cobblestones',
      'compacted': 'Compacted',
      'fine_gravel': 'Fine gravel',
      'gravel': 'Gravel',
      'dirt': 'Dirt',
      'earth': 'Earth',
      'ground': 'Ground',
      'grass': 'Grass',
      'sand': 'Sand',
      'unpaved': 'Unpaved',
      'wood': 'Wood',
      'mixed': 'Mixed',
      'other': 'Other surface',
    });
    return '$_temp0';
  }

  @override
  String discoverUnknownSurface(String meters) {
    return 'Surface data is unknown for $meters.';
  }

  @override
  String get discoverIntakeFindPeopleNotSupported =>
      'A Find People request cannot be added to a Scenario.';

  @override
  String get discoverIntakeMissingIdentity =>
      'This result cannot be added: it has no stable catalog identity.';

  @override
  String get discoverIntakeNoLocation =>
      'This result has no usable catalog location.';

  @override
  String discoverIntakeLimitReached(int count) {
    return 'A Scenario intake can contain up to $count items.';
  }

  @override
  String discoverStopsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops selected for Scenario.',
      one: '$count stop selected for Scenario.',
    );
    return '$_temp0';
  }

  @override
  String discoverSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String discoverTimeWindowIssue(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'unknownTimezone': 'The time zone of this area is unknown.',
      'dayEnded': 'This day has already ended here.',
      'boundsRequired': 'Choose a start and an end.',
      'nonexistentLocalTime':
          'This local time does not exist because of the clock change.',
      'endBeforeStart': 'The end must be after the start.',
      'invalidTravelContext': 'The travel settings are not valid.',
      'serviceUnavailable': 'Time matching is unavailable right now.',
      'other': 'The time window could not be applied.',
    });
    return '$_temp0';
  }

  @override
  String discoverFeedNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'emptyArea':
          'Nothing found in this area. Try a larger radius or fewer filters.',
      'loadFailed': 'Could not load the data. Try again.',
      'dataUnavailable': 'The data is unavailable.',
      'offline': 'No internet connection.',
      'other': 'Could not load the feed. Try again.',
    });
    return '$_temp0';
  }

  @override
  String scenarioIntakeStep(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'target': '1 of 3 · Scenario',
      'placement': '2 of 3 · Placement',
      'review': '3 of 3 · Review',
      'success': 'Complete',
      'applying': 'Saving',
      'other': 'Preparing',
    });
    return '$_temp0';
  }

  @override
  String scenarioIntakePlacement(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'unscheduled': 'Unscheduled',
      'atEnd': 'At end',
      'other': 'After selected stop',
    });
    return '$_temp0';
  }

  @override
  String get scenarioIntakeAfterLabel => 'After:';

  @override
  String scenarioIntakeCandidateLabel(int count) {
    return 'Selected stop $count:';
  }

  @override
  String scenarioIntakeSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count stops to the Scenario',
      one: 'Added $count stop to the Scenario',
    );
    return '$_temp0';
  }

  @override
  String scenarioIntakeTargetCounts(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total active items',
      one: '$total active item',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String discoverHomeIdeaTitle(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'freeToday': 'Free today',
      'nearMe': 'Near me',
      'eveningPlans': 'Evening plans',
      'coffeeReset': 'Coffee reset',
      'freeCityReset': 'Free city reset',
      'socialEvening': 'Social evening',
      'activeBoost': 'Active boost',
      'other': 'Idea',
    });
    return '$_temp0';
  }

  @override
  String discoverHomeIdeaSubtitle(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'freeToday': 'Activities nearby without tickets',
      'nearMe': 'Use the map radius and quick list',
      'eveningPlans': 'Find something after work',
      'coffeeReset': 'A calm cafe start with an easy city walk.',
      'freeCityReset': 'A free low-pressure route for a quick recharge.',
      'socialEvening': 'Start social, then keep the night nearby.',
      'activeBoost': 'Move first, then cool down on a walk.',
      'other': 'A quick plan nearby.',
    });
    return '$_temp0';
  }

  @override
  String get discoverHomeNew => 'New';

  @override
  String get discoverHomeForYou => 'For you';

  @override
  String get discoverHomeQuickEvents => 'Quick events';

  @override
  String get discoverHomeNearby => 'Nearby';

  @override
  String get discoverHomePopular => 'Popular';

  @override
  String get discoverRouteIdeas => 'Route ideas';

  @override
  String get discoverBuilder => 'Builder';

  @override
  String get discoverBuild => 'Build';

  @override
  String get discoverCreate => 'Create';

  @override
  String get discoverResume => 'Resume';

  @override
  String get discoverWalkable => 'Walkable';

  @override
  String get discoverMixedPrice => 'Mixed';

  @override
  String discoverMapTemplateRoute(String message) {
    return 'Map $message route';
  }

  @override
  String discoverCreateTemplateRoute(String message) {
    return 'Create $message route';
  }

  @override
  String get discoverForYouHint =>
      'Personal picks, saved ideas and creator tools stay one tap away.';

  @override
  String get discoverSmartSearchIdea => 'Smart search idea';

  @override
  String get discoverLanguagesLabel => 'Languages:';

  @override
  String get discoverEquipmentLabel => 'Equipment:';

  @override
  String get discoverAccessibilityLabel => 'Accessibility:';

  @override
  String get discoverListedByPageLabel => 'Listed by page';

  @override
  String get discoverListedByLabel => 'Listed by';

  @override
  String get discoverLearningOutcomesLabel => 'What you will learn:';

  @override
  String get discoverOrganizerLabel => 'Organizer:';

  @override
  String get discoverLinkedPlaceLabel => 'Linked Place:';

  @override
  String get discoverInformalAccessLabel => 'Informal access:';

  @override
  String discoverCompletedAtStopLabel(int index) {
    return 'Completed at stop $index:';
  }

  @override
  String discoverFocusedStopLabel(int index) {
    return 'Focused stop $index:';
  }

  @override
  String discoverNowAtStopLabel(int index) {
    return 'Now: stop $index ·';
  }

  @override
  String discoverSelectedStopLabel(int index) {
    return 'Selected stop $index:';
  }

  @override
  String discoverMoodRoute(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm route',
      'social': 'Social route',
      'active': 'Active route',
      'other': 'Custom route',
    });
    return '$_temp0';
  }

  @override
  String discoverMoodRechargeRoute(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm recharge route',
      'social': 'Social recharge route',
      'active': 'Active recharge route',
      'other': 'Custom recharge route',
    });
    return '$_temp0';
  }

  @override
  String discoverMoodRechargeScenario(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm recharge scenario',
      'social': 'Social recharge scenario',
      'active': 'Active recharge scenario',
      'other': 'Custom recharge scenario',
    });
    return '$_temp0';
  }

  @override
  String discoverOptionalContributionLabel(String value) {
    return 'Optional $value:';
  }

  @override
  String discoverIdeaForCategory(String type) {
    return '$type idea';
  }

  @override
  String get discoverIntentLabel => 'Intent:';

  @override
  String get discoverAppliedLabel => 'Applied:';

  @override
  String get discoverVersionLabel => 'Version';

  @override
  String get discoverRemove => 'Remove';

  @override
  String get discoverCouldNotOpenLink => 'Could not open';

  @override
  String discoverCollectionMapSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Map of $count places in this Collection. Use the list below to browse them without the map.',
      one:
          'Map of $count place in this Collection. Use the list below to browse it without the map.',
    );
    return '$_temp0';
  }

  @override
  String discoverRoutePreview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Route preview: $count segments',
      one: 'Route preview: $count segment',
    );
    return '$_temp0';
  }

  @override
  String get discoverSearchCategories => 'Search categories';

  @override
  String get discoverClearSearch => 'Clear search';

  @override
  String get discoverNoCategories => 'No categories found';

  @override
  String get discoverCategoryNotFound => 'Category not found';

  @override
  String get discoverOpenRoute => 'Open Route';

  @override
  String discoverTodayDate(String date) {
    return 'Today, $date';
  }

  @override
  String get discoverByLabel => 'By';

  @override
  String get discoverBadgePlace => 'PLACE';

  @override
  String get discoverBadgeActivity => 'ACTIVITY';

  @override
  String get discoverBadgeFindPeople => 'FIND PEOPLE';

  @override
  String get discoverBadgeSession => 'SESSION';

  @override
  String get discoverBadgeClassWorkshop => 'CLASS / WORKSHOP';

  @override
  String get identityProfessionalPage => 'Professional Page';

  @override
  String get identityVerificationRevoked => 'Verification revoked';

  @override
  String get identityVerificationRejected => 'Verification rejected';

  @override
  String get identityVerificationPending => 'Verification pending';

  @override
  String get identityKindPrivateProfessional => 'Private professional';

  @override
  String get identityKindVenueOperator => 'Venue operator';

  @override
  String get identityKindRepresentativeOffice => 'Representative office';

  @override
  String get identityRetry => 'Retry';

  @override
  String get identityCreate => 'Create';

  @override
  String get identityMinTwoChars => 'Enter at least 2 characters';

  @override
  String get identityCancel => 'Cancel';

  @override
  String get identityPageStartsPending =>
      'The page starts in Pending review. Market, locale, timezone and currency come from the active market configuration.';

  @override
  String get identityPageType => 'Page type';

  @override
  String get identityPageName => 'Page name';

  @override
  String get identityCreatePage => 'Create Professional Page';

  @override
  String get identityPreviewOnlyRoles =>
      'Presentation preview only. Roles and permissions do not change.';

  @override
  String get identityViewAs => 'View as';

  @override
  String get identityNoPageYet =>
      'You have not created a Professional Page yet.';

  @override
  String get identityCreateContent => 'Create content';

  @override
  String get identityManagePage => 'Manage page';

  @override
  String get identityPersonalRevoked =>
      'Personal profile · Verification revoked';

  @override
  String get identityPersonalExpired =>
      'Personal profile · Verification expired';

  @override
  String get identityPersonalRejected =>
      'Personal profile · Verification rejected';

  @override
  String get identityVerifiedTools =>
      'Verified · Tools follow your permissions';

  @override
  String get identityPersonalPending =>
      'Personal profile · Verification pending';

  @override
  String get identityPersonalNotStarted =>
      'Personal profile · Verification not started';

  @override
  String get identityAdminSeparate =>
      'Admin access active · separate from publishing';

  @override
  String get identityAdminTools => 'Admin tools';

  @override
  String get identityRequestAdditionalPage => 'Request additional page';

  @override
  String get identityModeratorsWillReview =>
      'Moderators will review your request.';

  @override
  String get identityLimitRequestPending => 'Additional page request pending';

  @override
  String get identityCreator => 'Creator';

  @override
  String get identityOk => 'OK';

  @override
  String get identityAdminMockNotice =>
      'This mock account has explicit Admin capabilities. Operational Admin tools are connected in IDP-05A.';

  @override
  String get identityAdminAccessActive => 'Admin access active';

  @override
  String get identityPageNotFound => 'Page not found';

  @override
  String get identityContentViaProjection =>
      'Content appears here only through an approved publisher projection.';

  @override
  String get identityNoPublishedContent => 'No published content yet';

  @override
  String get identityPublishedContent => 'Published content';

  @override
  String get identityEditPage => 'Edit page';

  @override
  String get identityShare => 'Share';

  @override
  String get identityVerifiedPage => 'Verified Professional Page';

  @override
  String get identityPreviewDoesNotPublish =>
      'This preview does not publish or verify the page.';

  @override
  String get identityPublicPagePreview => 'Public page preview';

  @override
  String get identityPreviewNotPublic =>
      'Preview. This page is not publicly visible.';

  @override
  String get identityPageAccountSettings =>
      'Page account, memberships and international settings.';

  @override
  String get identityContentScoped =>
      'Content is scoped to this exact Professional Page.';

  @override
  String get identityOverviewModeration =>
      'Professional Page overview and moderation status.';

  @override
  String get identityPreviewUntilVerified =>
      'Preview only. The page is not public until verification is approved.';

  @override
  String get identityPreviewPublicPage => 'Preview public page';

  @override
  String get identityNoPageInvented =>
      'No page is invented for this preview. Create a page to activate its workspace and publisher context.';

  @override
  String get identityContentAfterRealPage =>
      'Content appears only after the user creates or joins a real Professional Page.';

  @override
  String get identityPagePreview => 'Professional Page preview';

  @override
  String get identitySwitchPage => 'Switch Professional Page';

  @override
  String get identityCreateOrSelectPage => 'Create or select Professional Page';

  @override
  String get identityUserId => 'User ID';

  @override
  String get identitySendInvitation => 'Send invitation';

  @override
  String get identityCapabilities => 'Capabilities';

  @override
  String get identityRole => 'Role';

  @override
  String get identityInviteBy => 'Invite by';

  @override
  String get identityInviteMember => 'Invite a team member';

  @override
  String get identityRevoke => 'Revoke';

  @override
  String get identityNoInvitations => 'No invitations sent from this page yet.';

  @override
  String get identityNoTeamPermission =>
      'You do not have permission to manage the team.';

  @override
  String get identitySave => 'Save';

  @override
  String get identityNotSet => 'Not set.';

  @override
  String get identityCustomActivityLabel => 'Custom activity label';

  @override
  String get identityDescription => 'Description';

  @override
  String get identityShortDescription => 'Short description';

  @override
  String get identitySwitchWorkspaceHint =>
      'Personal profile, Professional Pages and Admin access';

  @override
  String get identitySwitchWorkspace => 'Switch workspace';

  @override
  String get profileDateTbd => 'Date to be set';

  @override
  String get profileDraftListing => 'Draft listing';

  @override
  String get profileSmartSearchIdea => 'Smart search idea';

  @override
  String get profilePublishedRoute => 'Published route';

  @override
  String get profileReadyToPublish => 'Ready to publish';

  @override
  String get profileNoCity => 'No city';

  @override
  String get profileUntitledListing => 'Untitled listing';

  @override
  String get profileRouteMap => 'Route map';

  @override
  String get profileEditRoute => 'Edit route';

  @override
  String get profileWalking => 'Walking';

  @override
  String get profileFree => 'Free';

  @override
  String get profileOpenQuickPlanNext =>
      'Open Quick Plan for the next generated idea';

  @override
  String get profileBuildNextRoute => 'Build next route';

  @override
  String get profileMapPublishedListing => 'Map published listing';

  @override
  String get profileOpenRouteMap => 'Open route map';

  @override
  String get profileFindDraftAudience => 'Find draft audience';

  @override
  String get profileFinishDraft => 'Finish draft';

  @override
  String get profileCreatorNextSteps => 'Creator next steps';

  @override
  String get profileMapListingArea => 'Map listing area';

  @override
  String get profileSearchSimilarListing => 'Search similar listing';

  @override
  String get profileContinueDraft => 'Continue draft';

  @override
  String get profileOpenCreate => 'Open Create';

  @override
  String get profileCreatorListing => 'Creator listing';

  @override
  String get profileBuildRoute => 'Build route';

  @override
  String get profileNewListing => 'New listing';

  @override
  String get profileManageDrafts =>
      'Manage drafts and published listings from the same workspace.';

  @override
  String get profileCreatorPublications => 'Creator publications';

  @override
  String get profileListingFromLatestSmart =>
      'Create listing from latest smart search';

  @override
  String get profileRouteFromLatestSmart =>
      'Build route from latest smart search';

  @override
  String get profileMapSmart => 'Map smart';

  @override
  String get profileResumeSmart => 'Resume smart';

  @override
  String get profileAnyArea => 'Any area';

  @override
  String get profileSmartRoute => 'Smart route';

  @override
  String get profileSmart => 'Smart';

  @override
  String get profileLatestSmartSearch => 'Latest smart search';

  @override
  String get profileListingFromLatestSearch =>
      'Create listing from latest search';

  @override
  String get profileRouteFromLatestSearch => 'Build route from latest search';

  @override
  String get profileMapSearch => 'Map search';

  @override
  String get profileResumeSearch => 'Resume search';

  @override
  String get profileConditions => 'Conditions';

  @override
  String get profileLatestSearch => 'Latest search';

  @override
  String get profileMapRoute => 'Map route';

  @override
  String get profileScenario => 'Scenario';

  @override
  String get profileLatestRoute => 'Latest route';

  @override
  String get profilePersonalScenario => 'Create a personal recharge scenario';

  @override
  String get profileBuildARoute => 'Build a route';

  @override
  String get profileUseSearchMap => 'Use Search and Map conditions';

  @override
  String get profileFindNextActivity => 'Find next activity';

  @override
  String get profileSavedPlan => 'Saved plan';

  @override
  String get profileReviewSavedPlan => 'Review saved plan';

  @override
  String get profileUseSavedInspiration =>
      'Use saved searches and scenarios as inspiration';

  @override
  String get profileBuildRouteIdea => 'Build route idea';

  @override
  String get profileDraftFromTaxonomy => 'Draft event or place from taxonomy';

  @override
  String get profileCreateHub => 'Create Hub';

  @override
  String get profileIdeaToHub => 'Move from route idea to Create Hub';

  @override
  String get profilePublishIdea => 'Publish idea';

  @override
  String get profileSmartPrompt => 'Smart prompt';

  @override
  String get profileOpenBuilderControls => 'Open Builder with route controls';

  @override
  String get profileGenerateScenario => 'Generate scenario';

  @override
  String get profileSearches => 'Searches';

  @override
  String get profileRoutes => 'Routes';

  @override
  String get profileSaved => 'Saved';

  @override
  String get profileUntitledActivity => 'Untitled activity';

  @override
  String get profileContinueInSearch => 'Continue in Search conditions';

  @override
  String get profileFindPeople => 'Find people';

  @override
  String get profileOpenScenarioBlock =>
      'Open the Scenario block in Create Hub';

  @override
  String get profileCreateScenario => 'Create Scenario';

  @override
  String get profileOpenRouteBlock => 'Open the Route block in Create Hub';

  @override
  String get profileCreateRoute => 'Create route';

  @override
  String get profileOpenTaxonomyFlow => 'Open taxonomy-based creator flow';

  @override
  String get profileViewAllEvents => 'View all events';

  @override
  String get profileStartFromHub => 'Start from Recharge Create Hub';

  @override
  String get profileNoCreatedEvents => 'No created events yet';

  @override
  String get profileCreateFirstEvent => 'Create first event';

  @override
  String get profileEventInsights => 'Event insights';

  @override
  String get profileCreatedEvents => 'Created events';

  @override
  String get profileManagePage => 'Manage page';

  @override
  String get profilePhotos => 'Photos';

  @override
  String get profileVisited => 'Visited';

  @override
  String get profileCreated => 'Created';

  @override
  String get profileWorkspace => 'Profile workspace';

  @override
  String get profileSignInRequired => 'Sign-in required';

  @override
  String get profileCheckVerification =>
      'Check verification and available tools in Settings';

  @override
  String get profileCreatorTools => 'Creator tools';

  @override
  String get profileSavedList => 'Saved list';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileObjectUpdatesOff => 'Object updates off';

  @override
  String get profileObjectUpdatesOn => 'Object updates on';

  @override
  String get profileCompleted => 'Completed';

  @override
  String get profileActiveUpcoming => 'Active and upcoming';

  @override
  String get quickPlanAnyArea => 'Any area';

  @override
  String get quickPlanAnyPrice => 'Any price';

  @override
  String get quickPlanAllCategories => 'All categories';

  @override
  String get quickPlanSmartRoute => 'Smart route';

  @override
  String get quickPlanRechargeIdea => 'Recharge idea';

  @override
  String get quickPlanTplActiveHint =>
      'Move first, cool down outside, then keep energy steady.';

  @override
  String get quickPlanTplActive => 'Active boost';

  @override
  String get quickPlanTplSocialHint =>
      'Meet people first, then keep the evening moving nearby.';

  @override
  String get quickPlanTplSocial => 'Social evening';

  @override
  String get quickPlanTplFreeCity => 'Free city reset';

  @override
  String get quickPlanTplCoffeeHint =>
      'Start gently, then take a low-pressure city walk.';

  @override
  String get quickPlanTplCoffee => 'Coffee reset';

  @override
  String get quickPlanResetBuilder => 'Reset builder';

  @override
  String get quickPlanNoStopsMatch => 'No stops match these conditions';

  @override
  String get quickPlanAdd => 'Add';

  @override
  String get quickPlanSuggestedStops => 'Suggested stops';

  @override
  String get quickPlanRemoveStop => 'Remove stop';

  @override
  String get quickPlanMoveDown => 'Move down';

  @override
  String get quickPlanMoveUp => 'Move up';

  @override
  String get quickPlanPublishOptimized => 'Publish optimized route';

  @override
  String get quickPlanMapRoute => 'Map route';

  @override
  String get quickPlanOptimize => 'Optimize';

  @override
  String get quickPlanFreeOnly => 'Free only';

  @override
  String get quickPlanRouteFit => 'Route fit';

  @override
  String get quickPlanWalkingRoute => 'Walking route';

  @override
  String get quickPlanMoodActive => 'Active';

  @override
  String get quickPlanMoodSocial => 'Social';

  @override
  String get quickPlanMoodCalm => 'Calm';

  @override
  String get quickPlanListingFromSmart => 'Create listing from smart search';

  @override
  String get quickPlanOpenSmartOnMap => 'Open smart search on map';

  @override
  String get quickPlanApplySmartToBuilder => 'Apply smart search to builder';

  @override
  String get quickPlanSmartSearch => 'Smart search';

  @override
  String get quickPlanListingFromSaved =>
      'Create listing from saved conditions';

  @override
  String get quickPlanOpenSavedOnMap => 'Open saved conditions on map';

  @override
  String get quickPlanApplySavedToBuilder =>
      'Apply saved conditions to builder';

  @override
  String get quickPlanSavedConditions => 'Saved conditions';

  @override
  String get quickPlanBuildFromSaved => 'Build from saved intent';

  @override
  String get quickPlanReadyIdeas => 'Ready route ideas';

  @override
  String get quickPlanPublishRoute => 'Publish route';

  @override
  String get quickPlanSearch => 'Search';

  @override
  String get quickPlanMap => 'Map';

  @override
  String get quickPlanCopy => 'Copy';

  @override
  String get quickPlanSave => 'Save';

  @override
  String get quickPlanBuildRechargeRoute => 'Build a recharge route';

  @override
  String get quickPlanRoutePreview => 'Route preview';

  @override
  String get quickPlanContinueSnapshot => 'Continue with snapshot';

  @override
  String get quickPlanRefresh => 'Refresh';

  @override
  String get quickPlanRefreshOrContinue =>
      'Refresh the preview or continue with the latest available snapshot.';

  @override
  String get quickPlanChanged => 'Quick Plan changed';

  @override
  String get quickPlanCreateIndependent => 'Create independent Scenario';

  @override
  String get quickPlanCancel => 'Cancel';

  @override
  String get quickPlanNoNotes =>
      'Only your own notes are eligible; this legacy plan has none.';

  @override
  String get quickPlanCopyNotes => 'Copy my private notes';

  @override
  String get quickPlanLegacyStopsHint =>
      'Legacy stops have no catalog object IDs, so selected stops will enter Scenario as private custom locations.';

  @override
  String get quickPlanIndependentHint =>
      'A new independent Scenario will be created. Later changes will not sync in either direction.';

  @override
  String get quickPlanExpandToScenario => 'Expand to Scenario';

  @override
  String get quickPlanCopyStopsHint =>
      'Copy selected stops into a new independent Scenario. This Quick Plan stays unchanged.';

  @override
  String get quickPlanNeedLargerPlan => 'Need a larger city or trip plan?';

  @override
  String get quickPlanSavePlan => 'Save this plan';

  @override
  String get quickPlanOpenMap => 'Open map';

  @override
  String get quickPlanEditPlan => 'Edit plan';

  @override
  String get quickPlanNoStopsFit =>
      'No stops fit these conditions yet. Edit the plan to add one.';

  @override
  String get quickPlanYourRoute => 'Your route';

  @override
  String get quickPlanExpandFailed => 'Could not expand this Quick Plan';

  @override
  String get quickPlanCopied => 'Quick Plan copied';

  @override
  String get quickPlanSaved => 'Quick Plan saved';

  @override
  String get quickPlanNotSynced =>
      'Not synced. Your local changes are retained; refresh to retry.';

  @override
  String get quickPlanLeave => 'Leave';

  @override
  String get quickPlanOpenReadOnly => 'Open read-only';

  @override
  String get quickPlanDecline => 'Decline';

  @override
  String get quickPlanAccept => 'Accept';

  @override
  String get quickPlanRevoke => 'Revoke';

  @override
  String get quickPlanCancelInvite => 'Cancel invite';

  @override
  String get quickPlanDeletePersonal => 'Delete current personal plan';

  @override
  String get quickPlanImportPersonal => 'Import personal plan';

  @override
  String get quickPlanImportJson => 'Import recharge.quickPlan JSON';

  @override
  String get quickPlanInviteToSaved => 'Invite to current saved plan';

  @override
  String get quickPlanInviteUserId => 'Invite existing user ID';

  @override
  String get quickPlanUseKnownUserId =>
      'Use a known user ID. Pending actions take effect after server confirmation.';

  @override
  String get quickPlanInvitations => 'Quick Plan invitations';

  @override
  String get quickPlanContinue => 'Continue';

  @override
  String get quickPlanLeavePlan => 'Leave plan';

  @override
  String get quickPlanContentHidden =>
      'Content hidden. Refresh to verify access.';

  @override
  String get quickPlanRefreshAccess => 'Refresh access';

  @override
  String get quickPlanCloseInvited => 'Close invited plan';

  @override
  String get quickPlanInvitedPlan => 'Invited Quick Plan';

  @override
  String get quickPlanRouteSteps => 'Route steps';

  @override
  String get quickPlanYourPlan => 'Your recharge plan';

  @override
  String get quickPlanReset => 'Reset';

  @override
  String get quickPlanEdit => 'Edit';

  @override
  String get quickPlanInvitationsAccess => 'Invitations and access';

  @override
  String get quickPlanQuickPlan => 'Quick Plan';

  @override
  String get quickPlanMyQuickPlan => 'My quick plan';

  @override
  String get favoritesFree => 'Free';

  @override
  String get favoritesAnyArea => 'Any area';

  @override
  String get favoritesSmartRoute => 'Smart route';

  @override
  String get favoritesRechargeIdea => 'Recharge idea';

  @override
  String get favoritesAnyTime => 'Any time';

  @override
  String get favoritesBadgeRoute => 'ROUTE';

  @override
  String get favoritesBadgePlace => 'PLACE';

  @override
  String get favoritesBadgeEvent => 'EVENT';

  @override
  String get favoritesShowAll => 'Show all';

  @override
  String get favoritesFilterEmpty => 'Nothing in this filter yet';

  @override
  String get favoritesRemove => 'Remove';

  @override
  String get favoritesMoreActions => 'More actions';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesRoutes => 'Routes';

  @override
  String get favoritesPlaces => 'Places';

  @override
  String get favoritesEvents => 'Events';

  @override
  String get favoritesAll => 'All';

  @override
  String get favoritesMap => 'Map';

  @override
  String get favoritesResume => 'Resume';

  @override
  String get favoritesListingFromSmart => 'Create listing from smart search';

  @override
  String get favoritesDeleteSmart => 'Delete smart search';

  @override
  String get favoritesSmartSearch => 'Smart search';

  @override
  String get favoritesListingFromSaved =>
      'Create listing from saved conditions';

  @override
  String get favoritesDeleteSaved => 'Delete saved conditions';

  @override
  String get favoritesSavedConditions => 'Saved conditions';

  @override
  String get favoritesSavedIntentsHint =>
      'Conditions and prompts ready to continue';

  @override
  String get favoritesSavedIntents => 'Saved intents';

  @override
  String get favoritesOpenDiscover => 'Open Discover';

  @override
  String get favoritesEmpty => 'No saved events yet';

  @override
  String get favoritesRetry => 'Retry';

  @override
  String get favoritesLoadFailed => 'Could not load favorites';

  @override
  String get favoritesRefresh => 'Refresh favorites';

  @override
  String get visitedRemoveFromHistory => 'Remove from history';

  @override
  String get visitedActions => 'Visit actions';

  @override
  String get visitedClearPeriod => 'Clear period';

  @override
  String get visitedEmptyPeriod => 'No visits in this period';

  @override
  String get visitedClear => 'Clear';

  @override
  String get visitedRemoved => 'Visit removed';

  @override
  String get visitedRemove => 'Remove';

  @override
  String get visitedCancel => 'Cancel';

  @override
  String get visitedRemoveVisit => 'Remove visit?';

  @override
  String get visitedSelectDay => 'Select visit day';

  @override
  String get visitedSelectMonth => 'Select month';

  @override
  String get visitedTitle => 'Visit history';

  @override
  String get visitedEmptyHint =>
      'Places you explicitly mark as visited will appear here.';

  @override
  String get visitedEmpty => 'No visits yet';

  @override
  String get visitedRetry => 'Retry';

  @override
  String get visitedTryAgain => 'Try again.';

  @override
  String get visitedLoadFailed => 'Could not load visits';

  @override
  String get visitedRefresh => 'Refresh visit history';

  @override
  String get visitedSignInRequired => 'Sign-in required';

  @override
  String get identityEmail => 'Email';

  @override
  String get identityPhone => 'Phone';

  @override
  String get quickPlanTplFreeCityHint =>
      'A simple free route for a calm recharge window.';

  @override
  String identityWorkspaceNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'workspace_recovered':
          'The unavailable page was reset to your personal profile.',
      'workspace_load_failed': 'Unable to load workspaces.',
      'workspace_switched': 'Workspace switched.',
      'workspace_access_unavailable':
          'Access to the selected page is unavailable.',
      'workspace_switch_failed': 'Unable to switch the workspace.',
      'admin_preview_selected': 'Admin preview selected.',
      'page_created': 'Professional Page created and sent for review.',
      'self_service_page_limit_reached':
          'You have reached the limit of 3 pages. Send a request to the moderators.',
      'page_create_failed': 'Unable to create the Professional Page.',
      'page_limit_request_sent': 'Request for an additional page sent.',
      'page_limit_request_unavailable':
          'The request is available after you create three pages.',
      'page_limit_request_failed':
          'Unable to send the request to the moderators.',
      'other': 'Unable to load workspaces.',
    });
    return '$_temp0';
  }

  @override
  String identityTeamNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'invitation_sent': 'Invitation sent.',
      'invitation_send_failed': 'Unable to send the invitation.',
      'invitation_revoked': 'Invitation revoked.',
      'invitation_revoke_failed': 'Unable to revoke the invitation.',
      'invitations_load_failed': 'Unable to load the team invitations.',
      'invitation_target_invalid':
          'Enter a valid user ID, email or phone number.',
      'owner_relationship_not_invitable':
          'Ownership cannot be granted by invitation.',
      'inviter_not_active_member':
          'Only an active team member can send invitations.',
      'inviter_missing_team_manage_capability':
          'You do not have permission to manage the team.',
      'cannot_delegate_capability_not_held':
          'You cannot grant a capability you do not have yourself.',
      'revoke_actor_not_active_member':
          'Only an active team member can revoke invitations.',
      'invitation_not_found': 'This invitation no longer exists.',
      'other': 'Unable to send the invitation.',
    });
    return '$_temp0';
  }

  @override
  String identityProfileNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'profile_load_failed': 'Unable to load the page profile.',
      'profile_updated': 'Profile updated.',
      'profile_update_failed': 'Unable to update the profile.',
      'default_locale_value_required':
          'Enter a value for the page’s default language.',
      'unsupported_locale': 'That language is not supported by this page.',
      'value_length_out_of_bounds': 'That text is empty or too long.',
      'actor_not_active_member':
          'Only an active team member can edit the profile.',
      'actor_missing_page_manage_capability':
          'You do not have permission to edit the page profile.',
      'stale_overlay_revision':
          'This field changed elsewhere. Reload and try again.',
      'other': 'Unable to update the profile.',
    });
    return '$_temp0';
  }

  @override
  String identityPublicPageNotice(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'page_load_failed': 'Unable to load this page.',
      'page_preview_failed': 'Unable to load the page preview.',
      'other': 'Unable to load this page.',
    });
    return '$_temp0';
  }

  @override
  String identityInboxTitle(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'identity_page_created_user': 'Professional Page created',
      'identity_page_created_moderators': 'New Professional Page',
      'identity_page_limit_request_user': 'Request sent',
      'identity_page_limit_request_moderators': 'Additional page request',
      'other': 'Notification',
    });
    return '$_temp0';
  }

  @override
  String identityInboxBody(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'identity_page_created_user': 'Review status: pending.',
      'identity_page_created_moderators':
          'A new page was created and needs review.',
      'identity_page_limit_request_user':
          'Moderators will review the additional Professional Page.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String identityInboxLimitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '$count page',
    );
    return 'The user requested a limit of $_temp0.';
  }

  @override
  String profileRoleTitle(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'pro_generator': 'Pro generator',
      'creator': 'Creator',
      'user': 'User',
      'other': 'Creator',
    });
    return '$_temp0';
  }

  @override
  String quickPlanFitLevel(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'needsStops': 'Needs stops',
      'ready': 'Ready',
      'goodWithTweaks': 'Good with tweaks',
      'other': 'Needs tuning',
    });
    return '$_temp0';
  }

  @override
  String quickPlanFitSummary(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'needsStops': 'Add at least one stop to make this route useful.',
      'ready': 'This route is ready for map or publishing.',
      'goodWithTweaks':
          'A small optimization can make this route easier to follow.',
      'other': 'Optimize the route before sending it to Map or Create.',
    });
    return '$_temp0';
  }

  @override
  String get quickPlanFitNoStops => 'No stops selected';

  @override
  String quickPlanFitTrim(int minutes) {
    return 'Trim about $minutes min';
  }

  @override
  String quickPlanFitFits(int minutes) {
    return 'Fits $minutes min';
  }

  @override
  String get quickPlanFitRoom => 'Room for one more stop';

  @override
  String get quickPlanFitRemovePaid => 'Remove paid stops for free-only mode';

  @override
  String get quickPlanFitFreeRoute => 'Free route';

  @override
  String quickPlanFitTotalPrice(String price) {
    return '$price total';
  }

  @override
  String get quickPlanFitShortenTransfers =>
      'Shorten transfers for walking mode';

  @override
  String quickPlanFitTotalDistance(String km) {
    return '$km km total';
  }

  @override
  String get profileOpenSearchWith => 'Open Search with';

  @override
  String get quickPlanAccessUnavailable =>
      'Access unavailable. Refresh to retry.';

  @override
  String get quickPlanNotConfirmed => 'Not confirmed yet. Refresh to retry.';

  @override
  String quickPlanTemplateApplied(String message) {
    return '$message applied';
  }

  @override
  String quickPlanApplyTemplate(String message) {
    return 'Apply $message template';
  }

  @override
  String quickPlanExpandStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expand $count stops to Scenario',
      one: 'Expand $count stop to Scenario',
    );
    return '$_temp0';
  }

  @override
  String get identitySectionPage => 'Page';

  @override
  String get identitySectionContent => 'Content';

  @override
  String get identitySectionAccount => 'Account';

  @override
  String identityEditField(String message) {
    return 'Edit $message';
  }

  @override
  String get identityInvitationPending => 'Pending';

  @override
  String get identityInvitationRevoked => 'Revoked';

  @override
  String get identityInvitationExpired => 'Expired';

  @override
  String get identityKindCompany => 'Company';

  @override
  String get identityKindOrganization => 'Organization';

  @override
  String get identityUnverified => 'Unverified';

  @override
  String get identityVerified => 'Verified';

  @override
  String get profilePersonal => 'Personal';

  @override
  String get profileBookingsRequests => 'Bookings & requests';

  @override
  String get profileOneTimeEvent => 'One-time event';

  @override
  String profileMissingFields(String message) {
    return 'Missing: $message';
  }

  @override
  String profileMissingField(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'title': 'title',
      'category': 'category',
      'city': 'city',
      'cover': 'cover image',
      'other': 'start time',
    });
    return '$_temp0';
  }

  @override
  String get profileStagePublished => 'Published';

  @override
  String get profileStageDraft => 'Draft';

  @override
  String get profilePublishedReady => 'Published-ready';

  @override
  String profileMissingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missing',
      one: '$count missing',
    );
    return '$_temp0';
  }

  @override
  String get profileAll => 'All';

  @override
  String get quickPlanRetryPending => 'Refresh / retry pending';

  @override
  String get quickPlanPlanLabel => 'Plan';

  @override
  String quickPlanGrantStatus(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'pending': 'Pending',
      'active': 'Active',
      'accepted': 'Accepted',
      'declined': 'Declined',
      'revoked': 'Revoked',
      'left': 'Left',
      'other': 'Unknown status',
    });
    return '$_temp0';
  }

  @override
  String get quickPlanInvitee => 'Invitee';

  @override
  String get quickPlanOwner => 'Owner';

  @override
  String get quickPlanReinvite => 'Re-invite';

  @override
  String quickPlanMoodReady(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm route, ready to follow or adjust.',
      'social': 'Social route, ready to follow or adjust.',
      'active': 'Active route, ready to follow or adjust.',
      'other': 'Custom route, ready to follow or adjust.',
    });
    return '$_temp0';
  }

  @override
  String quickPlanMoodPlan(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm plan',
      'social': 'Social plan',
      'active': 'Active plan',
      'other': 'Custom plan',
    });
    return '$_temp0';
  }

  @override
  String quickPlanMoodQuickPlan(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'calm': 'Calm quick plan',
      'social': 'Social quick plan',
      'active': 'Active quick plan',
      'other': 'Custom quick plan',
    });
    return '$_temp0';
  }

  @override
  String get quickPlanApplied => 'Applied';

  @override
  String get quickPlanUse => 'Use';

  @override
  String get favoritesEdit => 'Edit';

  @override
  String get favoritesOpen => 'Open';

  @override
  String get favoritesRoute => 'Route';

  @override
  String get visitedMonth => 'Month';

  @override
  String get visitedDay => 'Day';

  @override
  String get routeRecordingNotificationTitle => 'Route recording is active';

  @override
  String get routeRecordingNotificationText =>
      'Recharge is saving your route while the app is in the background.';

  @override
  String get createFormSaveContinue => 'Save & continue';

  @override
  String get createClassLeadMyself => 'I lead this class myself';

  @override
  String get profileControlCenter => 'CONTROL CENTER';

  @override
  String get profileLatestCreatedEvents => 'LATEST CREATED EVENTS';

  @override
  String get profileQuickActions => 'QUICK ACTIONS';

  @override
  String get profileWorkspaceHeading => 'Workspace';

  @override
  String profileSearchContinuations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count searches to continue',
      one: '$count search to continue',
    );
    return '$_temp0';
  }

  @override
  String profileActivitiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activities',
      one: '$count activity',
    );
    return '$_temp0';
  }

  @override
  String profileRoutesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count routes',
      one: '$count route',
    );
    return '$_temp0';
  }

  @override
  String profileSavedIdeasReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved ideas ready',
      one: '$count saved idea ready',
    );
    return '$_temp0';
  }

  @override
  String get profileResume => 'Resume';

  @override
  String get quickPlanReadOnlyOnline => 'Read-only · online access required';

  @override
  String get quickPlanConditions => 'Conditions';

  @override
  String get quickPlanIntentLabel => 'Intent';

  @override
  String get visitedPrivateHint => 'Private, self-reported places you visited.';

  @override
  String get visitedSelfReported => 'Self-reported';

  @override
  String get identityProfile => 'Profile';

  @override
  String get identityTeam => 'Team';

  @override
  String get identityRequired => 'Required.';

  @override
  String get identitySectionPersonal => 'PERSONAL';

  @override
  String get identitySectionProfessionalPages => 'PROFESSIONAL PAGES';

  @override
  String get identitySectionAdministration => 'ADMINISTRATION';

  @override
  String identityPagesUsed(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$count of $max self-service pages used',
      one: '$count of $max self-service page used',
    );
    return '$_temp0';
  }

  @override
  String identityPublishedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count published items',
      one: '$count published item',
    );
    return '$_temp0';
  }

  @override
  String get profileScenarioLibrary => 'Scenarios';

  @override
  String get discoverHomeTagline => 'VACATION APP';

  @override
  String createTaxonomySearchCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search $count categories',
      one: 'Search $count category',
    );
    return '$_temp0';
  }

  @override
  String createFormOpeningRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opening rules',
      one: '$count opening rule',
    );
    return '$_temp0';
  }

  @override
  String get createFormAddHours => 'Add 09:00–21:00';

  @override
  String createFormMinimumVisitChip(int minutes) {
    return 'Minimum $minutes min';
  }

  @override
  String createFormCapacityOf(int current, int max) {
    return 'Capacity $current/$max';
  }

  @override
  String createFormMetersValue(String value) {
    return '$value m';
  }

  @override
  String createFormPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return '$_temp0';
  }

  @override
  String get createRouteVersionLabel => 'version';

  @override
  String get createRouteGeometryLabel => 'Geometry';

  @override
  String get createActivityPurchaseHint =>
      'Purchase (e.g. coffee at the counter)';

  @override
  String get createActivityGroupMin => 'Group, min people';

  @override
  String createFormMinutesRange(int min, int max) {
    return '$min–$max min';
  }

  @override
  String get createFormImagesPermission =>
      'I have permission to use these images';

  @override
  String get createClassOutcomesPerLine => 'Outcomes (one per line)';

  @override
  String get createClassPrerequisitesPerLine => 'Prerequisites (one per line)';

  @override
  String get createClassFoldSecond => 'Second (winter time)';

  @override
  String get createClassStartHhmm => 'Start (HH:MM)';

  @override
  String get createClassEndHhmm => 'End (HH:MM)';

  @override
  String get createCollectionNoTitleYet => '(no title yet)';

  @override
  String get createCollectionPublishedRemove =>
      'Published — remove without review';

  @override
  String createCollectionObjectType(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'place': 'Place',
      'route': 'Route',
      'bookableSession': 'Session',
      'classWorkshop': 'Class / Workshop',
      'rental': 'Rental',
      'other': 'Object',
    });
    return '$_temp0';
  }

  @override
  String get createEventPreviewLabel => 'Preview';

  @override
  String get createEventInterestedOptional => 'Optional “Interested” response';

  @override
  String get createEventAvailabilityLabel => 'State';

  @override
  String createEventAvailabilityState(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'available': 'available',
      'lowAvailability': 'few places left',
      'soldOut': 'sold out',
      'waitlistAvailable': 'waitlist open',
      'registrationClosed': 'registration closed',
      'cancelled': 'cancelled',
      'stale': 'out of date',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String createEventAvailabilityFreshness(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'current': 'current',
      'stale': 'out of date',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String get createEventSuggestedLabel => 'Suggested';

  @override
  String createEventArchetype(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'performance': 'Performance',
      'screening': 'Screening',
      'exhibition': 'Exhibition',
      'open_stage': 'Open stage',
      'meet_greet': 'Meet and greet',
      'talk': 'Talk',
      'discussion': 'Discussion',
      'conference': 'Conference',
      'networking': 'Networking',
      'social_meetup': 'Social meetup',
      'hosted_game': 'Hosted game',
      'open_play': 'Open play',
      'competition': 'Competition',
      'class_session': 'Class',
      'workshop': 'Workshop',
      'retreat_camp': 'Retreat or camp',
      'wellness_session': 'Wellness session',
      'tasting': 'Tasting',
      'shared_meal': 'Shared meal',
      'party': 'Party',
      'celebration': 'Celebration',
      'festival': 'Festival',
      'market_fair': 'Market or fair',
      'auction': 'Auction',
      'launch_promotion': 'Launch or promotion',
      'open_day': 'Open day',
      'tour_excursion': 'Tour or excursion',
      'outdoor_gathering': 'Outdoor gathering',
      'community_action': 'Community action',
      'volunteering': 'Volunteering',
      'fundraiser': 'Fundraiser',
      'family_program': 'Family program',
      'ceremony': 'Ceremony',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String createEventParticipationMode(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'mode_watch': 'Watch',
      'mode_attend': 'Attend',
      'mode_play': 'Play',
      'mode_compete': 'Compete',
      'mode_perform': 'Perform',
      'mode_practice': 'Practice',
      'mode_learn': 'Learn',
      'mode_create': 'Create',
      'mode_meet_people': 'Meet people',
      'mode_date': 'Date',
      'mode_visit': 'Visit',
      'mode_explore': 'Explore',
      'mode_eat_drink': 'Eat and drink',
      'mode_shop': 'Shop',
      'mode_support': 'Support',
      'mode_volunteer': 'Volunteer',
      'mode_travel': 'Travel',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String createEventAdditionalRole(String message) {
    return '$message: additional attendee role';
  }

  @override
  String get createEventMediaRights =>
      'I have the right to publish this media *';

  @override
  String get createEventAllDay => 'All-day event';

  @override
  String get createEventIanaTimezone => 'IANA timezone';

  @override
  String createEventOccurrencesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count occurrences materialized',
      one: '$count occurrence materialized',
    );
    return '$_temp0';
  }

  @override
  String get createEventNextDateLabel => 'Next';

  @override
  String createEventPriceIn(String value) {
    return 'Price ($value)';
  }

  @override
  String get createFormContinue => 'Continue';

  @override
  String get createEventCapacityInventory => 'Capacity & inventory';

  @override
  String get createEventPoolsLabel => 'Pools';

  @override
  String get createEventZoneReference => 'Zone/table reference';

  @override
  String get createFindPeopleTagsField => 'Tags (comma-separated, up to 8)';

  @override
  String get createFindPeoplePaceOptional => 'Pace (optional)';

  @override
  String get createFindPeopleSecretRefHint =>
      'Session-scoped secure reference; never shown publicly';

  @override
  String get createFormAmount => 'Amount';

  @override
  String get createFindPeopleHostsTitle =>
      'Hosts, visibility, and communication';

  @override
  String get createFindPeopleCohostInactive =>
      'Co-host permissions remain inactive until the invited user accepts the role.';

  @override
  String get createFindPeopleAccuracyConfirm =>
      'I confirm that all details are accurate *';

  @override
  String get createFormReadOnlyDraft => 'Read-only draft';

  @override
  String get createFormDescriptionRequired => 'Description *';

  @override
  String get createFormDescriptionRecommended => 'Description (recommended)';

  @override
  String get createPlaceShortDescHint => '20–180 characters.';

  @override
  String get createPlaceDirectionsHint =>
      'Optional: entrance, path or meeting point';

  @override
  String get createPlaceOpen247 => 'Open 24/7';

  @override
  String get createPlaceSeasonalPhase2 => 'Seasonal (Phase 2)';

  @override
  String get createFormDateFormatHint => 'YYYY-MM-DD';

  @override
  String get createPlaceUntilInclusive => 'Until (inclusive)';

  @override
  String get createPlaceShortVisit => 'A shorter visit can still work';

  @override
  String get createPlaceCoverRecommended =>
      'A cover is recommended and can be added later.';

  @override
  String get createPlaceGalleryOptional => 'Optional · maximum 12';

  @override
  String get createPlaceWarningsReviewed => 'I reviewed these warnings';

  @override
  String get createFormReviewing => 'Reviewing…';

  @override
  String createPlaceRecommendedMinutes(int minutes) {
    return '$minutes min recommended';
  }

  @override
  String get createPlaceRoutePrimary => 'Route (primary action)';

  @override
  String createPlaceDuplicateReason(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'title_match': 'similar name',
      'category_match': 'same category',
      'official_domain_match': 'same website',
      'phone_match': 'same phone',
      'other': 'similar details',
    });
    return '$_temp0';
  }

  @override
  String get createRentalBrandModel => 'Brand / model (optional)';

  @override
  String get createRentalConfirmCategory =>
      'I confirm this category is correct';

  @override
  String get createRentalSizeVariant => 'Size / variant';

  @override
  String createFormConfirmedOn(String date) {
    return 'Confirmed $date';
  }

  @override
  String createRentalUnitsBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units blocked',
      one: '$count unit blocked',
    );
    return '$_temp0';
  }

  @override
  String get createRentalDefaultsEditable =>
      'Editable — nothing applies automatically.';

  @override
  String get createRentalIdRequired => 'ID required at handover';

  @override
  String get createRentalCurrencyField => 'Currency (ISO 4217)';

  @override
  String createRentalRateStep(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count units: $price minor',
      one: 'From $count unit: $price minor',
    );
    return '$_temp0';
  }

  @override
  String get createRentalDepositField => 'Deposit (minor units, 0 = none)';

  @override
  String get createRentalPrivateNotice =>
      'Private — not public: exact pickup address, geo and handover instructions are entered separately and never appear here.';

  @override
  String get createRentalRightToOffer =>
      'I have the right to offer this for rent';

  @override
  String createFormStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get createRouteGpxExport => 'GPX export';

  @override
  String get createRouteGpxSaved => 'GPX file saved.';

  @override
  String createFormBytes(String value) {
    return '$value B';
  }

  @override
  String createFormKilobytes(String value) {
    return '$value KB';
  }

  @override
  String createFormMegabytes(String value) {
    return '$value MB';
  }

  @override
  String createRouteGpxKind(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'track': 'Track',
      'other': 'Route',
    });
    return '$_temp0';
  }

  @override
  String createRouteSegmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segments',
      one: '$count segment',
    );
    return '$_temp0';
  }

  @override
  String createRouteConnectGaps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connect $count gaps with straight lines',
      one: 'Connect $count gap with straight lines',
    );
    return '$_temp0';
  }

  @override
  String createRouteImportPoi(int count) {
    return 'Import $count POI';
  }

  @override
  String createRouteAnchorsTitle(int count) {
    return 'Anchors ($count)';
  }

  @override
  String createRouteAnchorSemantics(int index, String start, String end) {
    return 'Anchor $index, latitude $start, longitude $end';
  }

  @override
  String createRouteSegmentsTitle(int count) {
    return 'Segments ($count)';
  }

  @override
  String get createRouteSegmentAppears =>
      'A segment appears after the second anchor.';

  @override
  String createRouteSegmentN(int index) {
    return 'Segment $index';
  }

  @override
  String createRouteWaypointsTitle(int count) {
    return 'Waypoints ($count)';
  }

  @override
  String createRouteAnchorN(int index) {
    return 'Anchor $index';
  }

  @override
  String createRouteAcceptedPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accepted points',
      one: '$count accepted point',
    );
    return '$_temp0';
  }

  @override
  String createRouteAverageAccuracy(String value) {
    return '$value m avg';
  }

  @override
  String createRouteUnsafePoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unsafe points excluded.',
      one: '$count unsafe point excluded.',
    );
    return '$_temp0';
  }

  @override
  String createRouteGapLabel(int index, int meters, int total) {
    return 'Gap $index: $meters m, $total s';
  }

  @override
  String createRouteGpsPointsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count GPS points saved',
      one: '$count GPS point saved',
    );
    return '$_temp0';
  }

  @override
  String get createRouteGpsAttention => 'GPS needs attention';

  @override
  String get createRouteGpsUnsafeStop =>
      'GPS recording could not continue safely.';

  @override
  String createRouteBlockingChecks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocking checks',
      one: '$count blocking check',
    );
    return '$_temp0';
  }

  @override
  String createRouteWarningsToReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings to review',
      one: '$count warning to review',
    );
    return '$_temp0';
  }

  @override
  String createRouteUnknownSurfaceMeters(String value) {
    return '$value m unknown';
  }

  @override
  String get createScenarioDayOne => 'Day 1';

  @override
  String get createScenarioRechecking => 'Rechecking…';

  @override
  String get createScenarioTimeNotEntered => 'time not entered';

  @override
  String get createScenarioDurationMinutesField => 'Duration, minutes';

  @override
  String get createScenarioStopHint => 'Park, viewpoint, private address…';

  @override
  String createScenarioBlockingIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocking issues',
      one: '$count blocking issue',
    );
    return '$_temp0';
  }

  @override
  String get createScenarioServiceChanged => 'A changed service was found';

  @override
  String get createScenarioFreshnessLabel => 'Freshness';

  @override
  String createScenarioFreshness(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'current': 'current',
      'stale': 'stale',
      'unavailable': 'unavailable',
      'other': 'unknown',
    });
    return '$_temp0';
  }

  @override
  String createScenarioAfterTime(String time) {
    return 'After $time';
  }

  @override
  String get createScenarioNoStopsFound => 'No stops found.';

  @override
  String createScenarioDepartureSemantics(
    String start,
    String end,
    int minutes,
  ) {
    return '$start to $end, $minutes minutes, planned schedule not live';
  }

  @override
  String get createScenarioCarrierOptional => 'Carrier (optional)';

  @override
  String get createScenarioServiceHint => 'Train 802 / Bus 7480';

  @override
  String get createScenarioDurationMinRequired => 'Duration, min *';

  @override
  String get createScenarioDurationMin => 'Duration, min';

  @override
  String get createScenarioDistanceKm => 'Distance, km';

  @override
  String get createScenarioOtherCost =>
      'Parking / ticket / other cost (optional)';

  @override
  String get createSessionTimezoneField => 'Timezone (IANA, e.g. Europe/Riga)';

  @override
  String get createFormConfirmed => 'Confirmed';

  @override
  String createSessionBuffer(int minutes) {
    return 'Buffer $minutes min';
  }

  @override
  String createSessionNotice(int minutes) {
    return 'notice $minutes min';
  }

  @override
  String get createSessionPlatformDefaults =>
      'platform defaults, change anytime';

  @override
  String get createSessionPriceFixed => '€ Fixed';

  @override
  String get createSessionOptionalLater =>
      'Optional — add now or after publishing';

  @override
  String discoverResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String get discoverSubcategories => 'Subcategories';

  @override
  String get discoverFilterMode => 'Mode';

  @override
  String get discoverEstimated => 'estimated';

  @override
  String get discoverSlotLabel => 'Slot';

  @override
  String get discoverGuides => 'Guides';

  @override
  String discoverItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String identityVerificationStatus(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'unverified': 'Unverified',
      'pending': 'Verification pending',
      'verified': 'Verified',
      'rejected': 'Verification rejected',
      'revoked': 'Verification revoked',
      'other': 'Unverified',
    });
    return '$_temp0';
  }

  @override
  String identityRelationship(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'owner': 'Owner',
      'manager': 'Manager',
      'other': 'Editor',
    });
    return '$_temp0';
  }

  @override
  String get errorAccountChanged =>
      'The signed-in account changed. Refresh and try again.';

  @override
  String get errorProcessingRestricted =>
      'This action is unavailable while your data processing is restricted.';

  @override
  String get errorPublicationActive =>
      'Withdraw the publication first, then try again.';

  @override
  String get libraryErrorVisitFuture => 'A visit date cannot be in the future.';

  @override
  String get libraryErrorPlaceTimezone =>
      'This place has no valid time zone, so the visit cannot be recorded.';

  @override
  String get quickPlanErrorInviteLimit =>
      'This plan has reached its invitation limit.';

  @override
  String get scenarioErrorLinkExpired => 'This link has expired.';

  @override
  String get routeErrorTooLarge => 'This route is too large to save.';

  @override
  String get routeErrorTooManyPoints => 'This route has too many points.';

  @override
  String get routeErrorGeometry => 'The route track is not valid.';

  @override
  String get routeErrorLicense =>
      'The licence of this route source does not allow this.';

  @override
  String get routeErrorProvenance =>
      'The origin of this track could not be confirmed.';

  @override
  String get routeErrorTrimInvalid =>
      'The hidden start and end of the route are not valid.';

  @override
  String get routeErrorTitleRequired => 'Add a route title first.';

  @override
  String get routeErrorDistributionLimit =>
      'The limit for sharing this route has been reached.';

  @override
  String get identityErrorAccountBlocked => 'This account is blocked.';

  @override
  String get identityErrorAccountRestricted => 'This account is restricted.';

  @override
  String get identityErrorSessionLimit =>
      'Too many active sessions. Sign out on another device and try again.';

  @override
  String get identityErrorRecentAuth => 'Sign in again to continue.';

  @override
  String get localErrorStorageFull =>
      'Too many unsent changes. Connect to the internet and try again.';

  @override
  String get localErrorImportNotReappliable =>
      'This import cannot be repeated. Import the file again.';

  @override
  String get taxCategoryMusicNightlife => 'Music & nightlife';

  @override
  String get taxCategoryComedyTheatrePerformance => 'Comedy & performance';

  @override
  String get taxCategoryCinemaScreenings => 'Cinema & screenings';

  @override
  String get taxCategoryArtCultureMuseums => 'Art, culture & museums';

  @override
  String get taxCategoryEducationTalks => 'Education & talks';

  @override
  String get taxCategoryBusinessNetworking => 'Business & networking';

  @override
  String get taxCategoryWorkshopsMasterclasses => 'Workshops & masterclasses';

  @override
  String get taxCategoryLanguageSocialLearning => 'Languages & social learning';

  @override
  String get taxCategoryFoodDrinks => 'Food & drinks';

  @override
  String get taxCategoryGamesIndoor => 'Games & indoor';

  @override
  String get taxCategorySport => 'Sport';

  @override
  String get taxCategoryDance => 'Dance';

  @override
  String get taxCategoryOutdoorNatureWalking => 'Outdoor, nature & walking';

  @override
  String get taxCategoryWaterActivities => 'Water activities';

  @override
  String get taxCategoryWinterSeasonal => 'Winter & seasonal';

  @override
  String get taxCategoryTravelTours => 'Travel & tours';

  @override
  String get taxCategoryFamilyKids => 'Family & kids';

  @override
  String get taxCategoryPetsAnimals => 'Pets & animals';

  @override
  String get taxCategoryCommunityCharity => 'Community & charity';

  @override
  String get taxCategoryMarketsFairs => 'Markets & fairs';

  @override
  String get taxCategoryHolidaysSeasonal => 'Holidays & seasonal';

  @override
  String get taxCategoryWellnessRecharge => 'Wellness & recharge';

  @override
  String get taxCategoryAdrenalineEntertainment => 'Adrenaline & entertainment';

  @override
  String get taxCategoryAttractions => 'Attractions';

  @override
  String get taxCategoryAutoMoto => 'Auto & moto';

  @override
  String get taxCategoryGeekTech => 'Geek & tech';

  @override
  String get taxCategoryDatingSingles => 'Dating & singles';

  @override
  String get taxCategoryOther => 'Other';

  @override
  String get taxSubcategoryConcert => 'Concert';

  @override
  String get taxSubcategoryLiveMusic => 'Live music';

  @override
  String get taxSubcategoryAcousticEvening => 'Acoustic evening';

  @override
  String get taxSubcategoryJazz => 'Jazz';

  @override
  String get taxSubcategoryClassicalMusic => 'Classical music';

  @override
  String get taxSubcategoryRockMusic => 'Rock music';

  @override
  String get taxSubcategoryPopMusic => 'Pop music';

  @override
  String get taxSubcategoryElectronicMusic => 'Electronic music';

  @override
  String get taxSubcategoryTechno => 'Techno';

  @override
  String get taxSubcategoryHouseMusic => 'House music';

  @override
  String get taxSubcategoryLatinMusic => 'Latin music';

  @override
  String get taxSubcategoryDjParty => 'DJ party';

  @override
  String get taxSubcategoryClubNight => 'Club night';

  @override
  String get taxSubcategoryKaraoke => 'Karaoke';

  @override
  String get taxSubcategoryOpenMicMusic => 'Open mic music';

  @override
  String get taxSubcategoryRooftopParty => 'Rooftop party';

  @override
  String get taxSubcategoryBeachParty => 'Beach party';

  @override
  String get taxSubcategoryThemedParty => 'Themed party';

  @override
  String get taxSubcategoryMusicFestival => 'Music festival';

  @override
  String get taxSubcategoryListeningParty => 'Listening party';

  @override
  String get taxSubcategoryJamSession => 'Jam session';

  @override
  String get taxSubcategoryNightBar => 'Night bar';

  @override
  String get taxSubcategoryAfterworkDrinks => 'Afterwork drinks';

  @override
  String get taxSubcategoryLateNightSocial => 'Late night social';

  @override
  String get taxSubcategoryGroupSinging => 'Group singing';

  @override
  String get taxSubcategoryOrganConcert => 'Organ concert';

  @override
  String get taxSubcategoryStandup => 'Stand-up';

  @override
  String get taxSubcategoryComedyOpenMic => 'Comedy open mic';

  @override
  String get taxSubcategoryTheatre => 'Theatre';

  @override
  String get taxSubcategoryImprovisation => 'Improvisation';

  @override
  String get taxSubcategoryMagicShow => 'Magic show';

  @override
  String get taxSubcategoryCircus => 'Circus';

  @override
  String get taxSubcategoryPoetryNight => 'Poetry night';

  @override
  String get taxSubcategoryStorytelling => 'Storytelling';

  @override
  String get taxSubcategoryPuppetShow => 'Puppet show';

  @override
  String get taxSubcategoryBallet => 'Ballet';

  @override
  String get taxSubcategoryOpera => 'Opera';

  @override
  String get taxSubcategoryCabaret => 'Cabaret';

  @override
  String get taxSubcategoryStreetPerformance => 'Street performance';

  @override
  String get taxSubcategoryPerformanceArt => 'Performance art';

  @override
  String get taxSubcategoryDragShow => 'Drag show';

  @override
  String get taxSubcategoryMusical => 'Musical';

  @override
  String get taxSubcategoryExperimentalTheatre => 'Experimental theatre';

  @override
  String get taxSubcategoryCinema => 'Cinema';

  @override
  String get taxSubcategoryMovieScreening => 'Movie screening';

  @override
  String get taxSubcategoryOpenAirCinema => 'Open-air cinema';

  @override
  String get taxSubcategoryFilmFestival => 'Film festival';

  @override
  String get taxSubcategoryDocumentary => 'Documentary';

  @override
  String get taxSubcategoryShortFilms => 'Short films';

  @override
  String get taxSubcategoryRetroCinema => 'Retro cinema';

  @override
  String get taxSubcategoryAnimation => 'Animation';

  @override
  String get taxSubcategorySportsScreening => 'Sports screening';

  @override
  String get taxSubcategoryMovieDiscussion => 'Movie discussion';

  @override
  String get taxSubcategoryPremiere => 'Premiere';

  @override
  String get taxSubcategoryIndependentFilm => 'Independent film';

  @override
  String get taxSubcategoryCinemaClub => 'Cinema club';

  @override
  String get taxSubcategoryExhibition => 'Exhibition';

  @override
  String get taxSubcategoryGallery => 'Gallery';

  @override
  String get taxSubcategoryMuseum => 'Museum';

  @override
  String get taxSubcategoryMuseumNight => 'Museum night';

  @override
  String get taxSubcategoryGalleryWalk => 'Gallery walk';

  @override
  String get taxSubcategoryArtistTalk => 'Artist talk';

  @override
  String get taxSubcategoryArtWalk => 'Art walk';

  @override
  String get taxSubcategoryPhotographyExhibition => 'Photography exhibition';

  @override
  String get taxSubcategoryStreetArt => 'Street art';

  @override
  String get taxSubcategoryArchitecture => 'Architecture';

  @override
  String get taxSubcategoryCulturalHeritage => 'Cultural heritage';

  @override
  String get taxSubcategoryMonument => 'Monument';

  @override
  String get taxSubcategoryMemorial => 'Memorial';

  @override
  String get taxSubcategorySculpture => 'Sculpture';

  @override
  String get taxSubcategoryHistoricLandmark => 'Historic landmark';

  @override
  String get taxSubcategoryLiteratureEvening => 'Literature evening';

  @override
  String get taxSubcategoryBookReading => 'Book reading';

  @override
  String get taxSubcategoryHistoryWalk => 'History walk';

  @override
  String get taxSubcategoryDesignEvent => 'Design event';

  @override
  String get taxSubcategoryCraftExhibition => 'Craft exhibition';

  @override
  String get taxSubcategoryPublicArt => 'Public art';

  @override
  String get taxSubcategoryCreativeMeetup => 'Creative meetup';

  @override
  String get taxSubcategoryFashionEvent => 'Fashion event';

  @override
  String get taxSubcategoryLecture => 'Lecture';

  @override
  String get taxSubcategoryPublicTalk => 'Public talk';

  @override
  String get taxSubcategoryDiscussion => 'Discussion';

  @override
  String get taxSubcategoryDebate => 'Debate';

  @override
  String get taxSubcategoryPanelDiscussion => 'Panel discussion';

  @override
  String get taxSubcategoryScienceTalk => 'Science talk';

  @override
  String get taxSubcategoryHistoryLecture => 'History lecture';

  @override
  String get taxSubcategoryPsychologyTalk => 'Psychology talk';

  @override
  String get taxSubcategoryFinanceTalk => 'Finance talk';

  @override
  String get taxSubcategoryCareerTalk => 'Career talk';

  @override
  String get taxSubcategoryLegalInfoSession => 'Legal info session';

  @override
  String get taxSubcategoryBookClub => 'Book club';

  @override
  String get taxSubcategoryPracticalSeminar => 'Practical seminar';

  @override
  String get taxSubcategorySelfDevelopment => 'Self development';

  @override
  String get taxSubcategoryHealthTalk => 'Health talk';

  @override
  String get taxSubcategoryTechnologyTalk => 'Technology talk';

  @override
  String get taxSubcategoryStartupTalk => 'Startup talk';

  @override
  String get taxSubcategoryParentingTalk => 'Parenting talk';

  @override
  String get taxSubcategoryCommunityDiscussion => 'Community discussion';

  @override
  String get taxSubcategoryNetworking => 'Networking';

  @override
  String get taxSubcategoryBusinessBreakfast => 'Business breakfast';

  @override
  String get taxSubcategoryBusinessLunch => 'Business lunch';

  @override
  String get taxSubcategoryConference => 'Conference';

  @override
  String get taxSubcategoryProductPresentation => 'Product presentation';

  @override
  String get taxSubcategoryProductLaunch => 'Product launch';

  @override
  String get taxSubcategoryStartupMeetup => 'Startup meetup';

  @override
  String get taxSubcategoryPitchNight => 'Pitch night';

  @override
  String get taxSubcategoryInvestorMeetup => 'Investor meetup';

  @override
  String get taxSubcategoryJobFair => 'Job fair';

  @override
  String get taxSubcategoryPortfolioReview => 'Portfolio review';

  @override
  String get taxSubcategoryFreelancersMeetup => 'Freelancers meetup';

  @override
  String get taxSubcategoryDemoDay => 'Demo day';

  @override
  String get taxSubcategoryExpo => 'Expo';

  @override
  String get taxSubcategoryFounderMeetup => 'Founder meetup';

  @override
  String get taxSubcategoryIndustryMeetup => 'Industry meetup';

  @override
  String get taxSubcategoryCareerNetworking => 'Career networking';

  @override
  String get taxSubcategoryCoworkingEvent => 'Coworking event';

  @override
  String get taxSubcategoryBusinessWorkshop => 'Business workshop';

  @override
  String get taxSubcategoryWorkshop => 'Workshop';

  @override
  String get taxSubcategoryMasterclass => 'Masterclass';

  @override
  String get taxSubcategoryCourse => 'Course';

  @override
  String get taxSubcategoryPottery => 'Pottery';

  @override
  String get taxSubcategoryCeramics => 'Ceramics';

  @override
  String get taxSubcategoryDrawing => 'Drawing';

  @override
  String get taxSubcategoryPainting => 'Painting';

  @override
  String get taxSubcategoryPhotography => 'Photography';

  @override
  String get taxSubcategoryCookingClass => 'Cooking class';

  @override
  String get taxSubcategorySewing => 'Sewing';

  @override
  String get taxSubcategoryFloristics => 'Floristics';

  @override
  String get taxSubcategoryCandleMaking => 'Candle making';

  @override
  String get taxSubcategoryPublicSpeaking => 'Public speaking';

  @override
  String get taxSubcategoryCreativeClass => 'Creative class';

  @override
  String get taxSubcategoryCraftWorkshop => 'Craft workshop';

  @override
  String get taxSubcategoryWritingWorkshop => 'Writing workshop';

  @override
  String get taxSubcategoryMusicLesson => 'Music lesson';

  @override
  String get taxSubcategoryDanceWorkshop => 'Dance workshop';

  @override
  String get taxSubcategoryBeautyWorkshop => 'Beauty workshop';

  @override
  String get taxSubcategoryWellnessWorkshop => 'Wellness workshop';

  @override
  String get taxSubcategoryLanguageExchange => 'Language exchange';

  @override
  String get taxSubcategoryEnglishClub => 'English club';

  @override
  String get taxSubcategoryDutchClub => 'Dutch club';

  @override
  String get taxSubcategoryLatvianClub => 'Latvian club';

  @override
  String get taxSubcategoryConversationClub => 'Conversation club';

  @override
  String get taxSubcategoryInternationalMeetup => 'International meetup';

  @override
  String get taxSubcategoryExpatsMeetup => 'Expats meetup';

  @override
  String get taxSubcategoryTandemMeeting => 'Tandem meeting';

  @override
  String get taxSubcategoryLanguageCafe => 'Language cafe';

  @override
  String get taxSubcategoryLanguageWalk => 'Language walk';

  @override
  String get taxSubcategorySpeedFriending => 'Speed friending';

  @override
  String get taxSubcategorySpeakingClub => 'Speaking club';

  @override
  String get taxSubcategoryCultureExchange => 'Culture exchange';

  @override
  String get taxSubcategoryNewcomersMeetup => 'Newcomers meetup';

  @override
  String get taxSubcategoryStudyGroup => 'Study group';

  @override
  String get taxSubcategoryCoffee => 'Coffee';

  @override
  String get taxSubcategoryBreakfast => 'Breakfast';

  @override
  String get taxSubcategoryBrunch => 'Brunch';

  @override
  String get taxSubcategoryLunch => 'Lunch';

  @override
  String get taxSubcategoryDinner => 'Dinner';

  @override
  String get taxSubcategoryDessert => 'Dessert';

  @override
  String get taxSubcategoryStreetFood => 'Street food';

  @override
  String get taxSubcategoryFoodTasting => 'Food tasting';

  @override
  String get taxSubcategoryDrinkTasting => 'Drink tasting';

  @override
  String get taxSubcategoryWineTasting => 'Wine tasting';

  @override
  String get taxSubcategoryBeerTasting => 'Beer tasting';

  @override
  String get taxSubcategoryCocktailTasting => 'Cocktail tasting';

  @override
  String get taxSubcategoryTeaCeremony => 'Tea ceremony';

  @override
  String get taxSubcategoryBbq => 'BBQ';

  @override
  String get taxSubcategoryPicnic => 'Picnic';

  @override
  String get taxSubcategoryFoodTour => 'Food tour';

  @override
  String get taxSubcategoryBarCrawl => 'Bar crawl';

  @override
  String get taxSubcategoryPubCrawl => 'Pub crawl';

  @override
  String get taxSubcategoryHappyHour => 'Happy hour';

  @override
  String get taxSubcategoryRestaurantVisit => 'Restaurant visit';

  @override
  String get taxSubcategoryCafeVisit => 'Cafe visit';

  @override
  String get taxSubcategoryBakeryVisit => 'Bakery visit';

  @override
  String get taxSubcategoryVeganFood => 'Vegan food';

  @override
  String get taxSubcategoryLocalFood => 'Local food';

  @override
  String get taxSubcategoryFineDining => 'Fine dining';

  @override
  String get taxSubcategoryFamilyMeal => 'Family meal';

  @override
  String get taxSubcategoryQuiz => 'Quiz';

  @override
  String get taxSubcategoryBoardGames => 'Board games';

  @override
  String get taxSubcategoryMafia => 'Mafia';

  @override
  String get taxSubcategoryPokerNoGambling => 'Poker (no gambling)';

  @override
  String get taxSubcategoryChess => 'Chess';

  @override
  String get taxSubcategoryEscapeRoom => 'Escape room';

  @override
  String get taxSubcategoryQuest => 'Quest';

  @override
  String get taxSubcategoryCityGame => 'City game';

  @override
  String get taxSubcategoryTreasureHunt => 'Treasure hunt';

  @override
  String get taxSubcategoryBowling => 'Bowling';

  @override
  String get taxSubcategoryBilliards => 'Billiards';

  @override
  String get taxSubcategoryDarts => 'Darts';

  @override
  String get taxSubcategoryMiniGolf => 'Mini golf';

  @override
  String get taxSubcategoryArcade => 'Arcade';

  @override
  String get taxSubcategoryVrArcade => 'VR arcade';

  @override
  String get taxSubcategoryVideoGames => 'Video games';

  @override
  String get taxSubcategoryTableGames => 'Table games';

  @override
  String get taxSubcategoryCardGames => 'Card games';

  @override
  String get taxSubcategoryRolePlayingGame => 'Role playing game';

  @override
  String get taxSubcategoryIndoorCompetition => 'Indoor competition';

  @override
  String get taxSubcategoryFootball => 'Football';

  @override
  String get taxSubcategoryBasketball => 'Basketball';

  @override
  String get taxSubcategoryVolleyball => 'Volleyball';

  @override
  String get taxSubcategoryBeachVolleyball => 'Beach volleyball';

  @override
  String get taxSubcategoryTennis => 'Tennis';

  @override
  String get taxSubcategoryTableTennis => 'Table tennis';

  @override
  String get taxSubcategoryBadminton => 'Badminton';

  @override
  String get taxSubcategorySquash => 'Squash';

  @override
  String get taxSubcategoryPadel => 'Padel';

  @override
  String get taxSubcategoryRunning => 'Running';

  @override
  String get taxSubcategoryTrailRunning => 'Trail running';

  @override
  String get taxSubcategoryCycling => 'Cycling';

  @override
  String get taxSubcategorySwimming => 'Swimming';

  @override
  String get taxSubcategoryBoxing => 'Boxing';

  @override
  String get taxSubcategoryMartialArts => 'Martial arts';

  @override
  String get taxSubcategoryClimbing => 'Climbing';

  @override
  String get taxSubcategoryBouldering => 'Bouldering';

  @override
  String get taxSubcategoryFitness => 'Fitness';

  @override
  String get taxSubcategoryGym => 'Gym';

  @override
  String get taxSubcategoryCrossfit => 'Crossfit';

  @override
  String get taxSubcategoryCalisthenics => 'Calisthenics';

  @override
  String get taxSubcategoryYoga => 'Yoga';

  @override
  String get taxSubcategoryPilates => 'Pilates';

  @override
  String get taxSubcategoryStretching => 'Stretching';

  @override
  String get taxSubcategoryDanceFitness => 'Dance fitness';

  @override
  String get taxSubcategoryNordicWalking => 'Nordic walking';

  @override
  String get taxSubcategorySkating => 'Skating';

  @override
  String get taxSubcategorySkateboarding => 'Skateboarding';

  @override
  String get taxSubcategoryRollerblading => 'Rollerblading';

  @override
  String get taxSubcategoryGolf => 'Golf';

  @override
  String get taxSubcategoryFrisbee => 'Frisbee';

  @override
  String get taxSubcategoryDiscGolf => 'Disc golf';

  @override
  String get taxSubcategoryRunningRace => 'Running race';

  @override
  String get taxSubcategoryCyclingRace => 'Cycling race';

  @override
  String get taxSubcategoryFitnessChallenge => 'Fitness challenge';

  @override
  String get taxSubcategoryAmateurTournament => 'Amateur tournament';

  @override
  String get taxSubcategorySalsa => 'Salsa';

  @override
  String get taxSubcategoryBachata => 'Bachata';

  @override
  String get taxSubcategoryKizomba => 'Kizomba';

  @override
  String get taxSubcategoryTango => 'Tango';

  @override
  String get taxSubcategoryHipHop => 'Hip-hop';

  @override
  String get taxSubcategoryContemporaryDance => 'Contemporary dance';

  @override
  String get taxSubcategoryBallroomDance => 'Ballroom dance';

  @override
  String get taxSubcategoryFolkDance => 'Folk dance';

  @override
  String get taxSubcategoryDanceSocial => 'Dance social';

  @override
  String get taxSubcategoryDanceBattle => 'Dance battle';

  @override
  String get taxSubcategoryZumba => 'Zumba';

  @override
  String get taxSubcategoryPartnerDance => 'Partner dance';

  @override
  String get taxSubcategoryLatinDance => 'Latin dance';

  @override
  String get taxSubcategoryHeelsDance => 'Heels dance';

  @override
  String get taxSubcategoryStreetDance => 'Street dance';

  @override
  String get taxSubcategoryDanceClass => 'Dance class';

  @override
  String get taxSubcategoryDancePractice => 'Dance practice';

  @override
  String get taxSubcategoryDanceShow => 'Dance show';

  @override
  String get taxSubcategoryHiking => 'Hiking';

  @override
  String get taxSubcategoryNatureWalk => 'Nature walk';

  @override
  String get taxSubcategoryCityWalk => 'City walk';

  @override
  String get taxSubcategoryHistoricalWalk => 'Historical walk';

  @override
  String get taxSubcategorySunsetWalk => 'Sunset walk';

  @override
  String get taxSubcategorySunriseWalk => 'Sunrise walk';

  @override
  String get taxSubcategoryForestWalk => 'Forest walk';

  @override
  String get taxSubcategoryLakeWalk => 'Lake walk';

  @override
  String get taxSubcategoryRiverWalk => 'River walk';

  @override
  String get taxSubcategoryArchitectureWalk => 'Architecture walk';

  @override
  String get taxSubcategoryHiddenGemsWalk => 'Hidden gems walk';

  @override
  String get taxSubcategoryPhotographyWalk => 'Photography walk';

  @override
  String get taxSubcategoryBirdwatching => 'Birdwatching';

  @override
  String get taxSubcategoryMushroomPicking => 'Mushroom picking';

  @override
  String get taxSubcategoryBerryPicking => 'Berry picking';

  @override
  String get taxSubcategoryPicnicWalk => 'Picnic walk';

  @override
  String get taxSubcategoryParkWalk => 'Park walk';

  @override
  String get taxSubcategoryBeachWalk => 'Beach walk';

  @override
  String get taxSubcategoryPromenadeWalk => 'Promenade walk';

  @override
  String get taxSubcategoryPark => 'Park';

  @override
  String get taxSubcategoryBeach => 'Beach';

  @override
  String get taxSubcategoryPromenade => 'Promenade';

  @override
  String get taxSubcategoryViewpoint => 'Viewpoint';

  @override
  String get taxSubcategoryForest => 'Forest';

  @override
  String get taxSubcategoryLake => 'Lake';

  @override
  String get taxSubcategoryWaterfall => 'Waterfall';

  @override
  String get taxSubcategoryCave => 'Cave';

  @override
  String get taxSubcategoryNaturalLandmark => 'Natural landmark';

  @override
  String get taxSubcategoryOutdoorWorkout => 'Outdoor workout';

  @override
  String get taxSubcategoryNatureEscape => 'Nature escape';

  @override
  String get taxSubcategorySlowWalk => 'Slow walk';

  @override
  String get taxSubcategoryStargazing => 'Stargazing';

  @override
  String get taxSubcategoryNorthernLightsWatch => 'Northern lights watch';

  @override
  String get taxSubcategoryMeteorShowerWatch => 'Meteor shower watch';

  @override
  String get taxSubcategorySup => 'SUP';

  @override
  String get taxSubcategoryKayak => 'Kayak';

  @override
  String get taxSubcategoryCanoe => 'Canoe';

  @override
  String get taxSubcategoryBoatTrip => 'Boat trip';

  @override
  String get taxSubcategoryCatamaran => 'Catamaran';

  @override
  String get taxSubcategoryCanalCruise => 'Canal cruise';

  @override
  String get taxSubcategoryRowing => 'Rowing';

  @override
  String get taxSubcategorySailing => 'Sailing';

  @override
  String get taxSubcategoryFishing => 'Fishing';

  @override
  String get taxSubcategoryWakeboarding => 'Wakeboarding';

  @override
  String get taxSubcategoryWaterBike => 'Water bike';

  @override
  String get taxSubcategoryJetSki => 'Jet ski';

  @override
  String get taxSubcategoryBeachActivity => 'Beach activity';

  @override
  String get taxSubcategoryWaterTour => 'Water tour';

  @override
  String get taxSubcategoryDiving => 'Diving';

  @override
  String get taxSubcategorySnorkeling => 'Snorkeling';

  @override
  String get taxSubcategorySurfing => 'Surfing';

  @override
  String get taxSubcategoryWindsurfing => 'Windsurfing';

  @override
  String get taxSubcategoryKitesurfing => 'Kitesurfing';

  @override
  String get taxSubcategoryBeachDay => 'Beach day';

  @override
  String get taxSubcategoryWinterWalk => 'Winter walk';

  @override
  String get taxSubcategoryIceSkating => 'Ice skating';

  @override
  String get taxSubcategorySkiing => 'Skiing';

  @override
  String get taxSubcategorySnowboarding => 'Snowboarding';

  @override
  String get taxSubcategorySledding => 'Sledding';

  @override
  String get taxSubcategoryWinterHiking => 'Winter hiking';

  @override
  String get taxSubcategoryChristmasMarketWalk => 'Christmas market walk';

  @override
  String get taxSubcategoryWinterPhotoRoute => 'Winter photo route';

  @override
  String get taxSubcategorySaunaColdPlunge => 'Sauna and cold plunge';

  @override
  String get taxSubcategoryIceFishing => 'Ice fishing';

  @override
  String get taxSubcategoryWinterFestival => 'Winter festival';

  @override
  String get taxSubcategoryAutumnLeafWalk => 'Autumn leaf walk';

  @override
  String get taxSubcategorySpringBlossomWalk => 'Spring blossom walk';

  @override
  String get taxSubcategorySummerOutdoor => 'Summer outdoor';

  @override
  String get taxSubcategorySeasonalWalk => 'Seasonal walk';

  @override
  String get taxSubcategorySnowActivity => 'Snow activity';

  @override
  String get taxSubcategoryColdPlunge => 'Cold plunge';

  @override
  String get taxSubcategoryHolidayLightsWalk => 'Holiday lights walk';

  @override
  String get taxSubcategoryDayTrip => 'Day trip';

  @override
  String get taxSubcategoryWeekendTrip => 'Weekend trip';

  @override
  String get taxSubcategoryLocalExperience => 'Local experience';

  @override
  String get taxSubcategoryTouristExcursion => 'Tourist excursion';

  @override
  String get taxSubcategoryCityTour => 'City tour';

  @override
  String get taxSubcategoryFoodTastingTour => 'Food tasting tour';

  @override
  String get taxSubcategoryCraftExperience => 'Craft experience';

  @override
  String get taxSubcategoryFarmExperience => 'Farm experience';

  @override
  String get taxSubcategoryCastleTour => 'Castle tour';

  @override
  String get taxSubcategoryNatureReserveTour => 'Nature reserve tour';

  @override
  String get taxSubcategoryCoastalTrip => 'Coastal trip';

  @override
  String get taxSubcategoryTrainDayTrip => 'Train day trip';

  @override
  String get taxSubcategoryLocalGuideExperience => 'Local guide experience';

  @override
  String get taxSubcategoryBikeTour => 'Bike tour';

  @override
  String get taxSubcategoryWalkingTour => 'Walking tour';

  @override
  String get taxSubcategoryHistoricalTour => 'Historical tour';

  @override
  String get taxSubcategoryArchitectureTour => 'Architecture tour';

  @override
  String get taxSubcategoryPhotoTour => 'Photo tour';

  @override
  String get taxSubcategoryHiddenGemsTour => 'Hidden gems tour';

  @override
  String get taxSubcategoryFamilyActivity => 'Family activity';

  @override
  String get taxSubcategoryKidsWorkshop => 'Kids workshop';

  @override
  String get taxSubcategoryPlaygroundEvent => 'Playground event';

  @override
  String get taxSubcategoryFamilyPicnic => 'Family picnic';

  @override
  String get taxSubcategoryKidsTheatre => 'Kids theatre';

  @override
  String get taxSubcategoryKidsMuseumEvent => 'Kids museum event';

  @override
  String get taxSubcategoryFamilySportsDay => 'Family sports day';

  @override
  String get taxSubcategoryParentChildClass => 'Parent-child class';

  @override
  String get taxSubcategoryCreativeKidsClass => 'Creative kids class';

  @override
  String get taxSubcategoryKidsCookingClass => 'Kids cooking class';

  @override
  String get taxSubcategoryKidsOutdoorWalk => 'Kids outdoor walk';

  @override
  String get taxSubcategoryBirthdayActivity => 'Birthday activity';

  @override
  String get taxSubcategoryFamilyFarmVisit => 'Family farm visit';

  @override
  String get taxSubcategoryFamilyRoute => 'Family route';

  @override
  String get taxSubcategoryKidsParty => 'Kids party';

  @override
  String get taxSubcategoryEducationalKidsEvent => 'Educational kids event';

  @override
  String get taxSubcategoryBabyFriendlyActivity => 'Baby-friendly activity';

  @override
  String get taxSubcategoryKidsCamp => 'Kids camp';

  @override
  String get taxSubcategoryDayCamp => 'Day camp';

  @override
  String get taxSubcategoryTeenMeetup => 'Teen meetup';

  @override
  String get taxSubcategoryTeenEvent => 'Teen event';

  @override
  String get taxSubcategoryKidsQuest => 'Kids quest';

  @override
  String get taxSubcategoryKidsScienceEvent => 'Kids science event';

  @override
  String get taxSubcategoryKidsDisco => 'Kids disco';

  @override
  String get taxSubcategoryDogWalk => 'Dog walk';

  @override
  String get taxSubcategoryDogMeetup => 'Dog meetup';

  @override
  String get taxSubcategoryDogParkMeetup => 'Dog park meetup';

  @override
  String get taxSubcategoryPetFriendlyCafe => 'Pet-friendly cafe';

  @override
  String get taxSubcategoryDogTraining => 'Dog training';

  @override
  String get taxSubcategoryPetPhotoSession => 'Pet photo session';

  @override
  String get taxSubcategoryAnimalShelterVisit => 'Animal shelter visit';

  @override
  String get taxSubcategoryFarmAnimalExperience => 'Farm animal experience';

  @override
  String get taxSubcategoryHorseRiding => 'Horse riding';

  @override
  String get taxSubcategoryPonyRiding => 'Pony riding';

  @override
  String get taxSubcategoryCatCafe => 'Cat cafe';

  @override
  String get taxSubcategoryPetAdoption => 'Pet adoption';

  @override
  String get taxSubcategoryPetCharity => 'Pet charity';

  @override
  String get taxSubcategoryPetFriendlyWalk => 'Pet-friendly walk';

  @override
  String get taxSubcategoryDogSport => 'Dog sport';

  @override
  String get taxSubcategoryPetOwnerMeetup => 'Pet owner meetup';

  @override
  String get taxSubcategoryDogShow => 'Dog show';

  @override
  String get taxSubcategoryPetExhibition => 'Pet exhibition';

  @override
  String get taxSubcategoryPetFair => 'Pet fair';

  @override
  String get taxSubcategoryPetCareTalk => 'Pet care talk';

  @override
  String get taxSubcategoryAnimalTherapy => 'Animal therapy';

  @override
  String get taxSubcategoryCharityEvent => 'Charity event';

  @override
  String get taxSubcategoryVolunteerActivity => 'Volunteer activity';

  @override
  String get taxSubcategoryCommunityCleanup => 'Community cleanup';

  @override
  String get taxSubcategoryDonationEvent => 'Donation event';

  @override
  String get taxSubcategoryNeighborhoodEvent => 'Neighborhood event';

  @override
  String get taxSubcategoryFundraisingDinner => 'Fundraising dinner';

  @override
  String get taxSubcategoryCharityRun => 'Charity run';

  @override
  String get taxSubcategoryAnimalShelterVolunteering =>
      'Animal shelter volunteering';

  @override
  String get taxSubcategoryFoodBankVolunteering => 'Food bank volunteering';

  @override
  String get taxSubcategoryTreePlanting => 'Tree planting';

  @override
  String get taxSubcategoryBeachCleanup => 'Beach cleanup';

  @override
  String get taxSubcategoryParkCleanup => 'Park cleanup';

  @override
  String get taxSubcategoryCommunityGarden => 'Community garden';

  @override
  String get taxSubcategoryPublicSquare => 'Public square';

  @override
  String get taxSubcategoryLocalCommunityMeetup => 'Local community meetup';

  @override
  String get taxSubcategoryMutualAid => 'Mutual aid';

  @override
  String get taxSubcategorySocialImpactEvent => 'Social impact event';

  @override
  String get taxSubcategoryEnvironmentalAction => 'Environmental action';

  @override
  String get taxSubcategoryLocalMarket => 'Local market';

  @override
  String get taxSubcategoryFleaMarket => 'Flea market';

  @override
  String get taxSubcategorySeasonalMarket => 'Seasonal market';

  @override
  String get taxSubcategoryChristmasMarket => 'Christmas market';

  @override
  String get taxSubcategoryFarmersMarket => 'Farmers market';

  @override
  String get taxSubcategoryCraftMarket => 'Craft market';

  @override
  String get taxSubcategoryDesignMarket => 'Design market';

  @override
  String get taxSubcategoryVintageMarket => 'Vintage market';

  @override
  String get taxSubcategoryBookMarket => 'Book market';

  @override
  String get taxSubcategoryFoodMarket => 'Food market';

  @override
  String get taxSubcategoryFlowerMarket => 'Flower market';

  @override
  String get taxSubcategoryArtFair => 'Art fair';

  @override
  String get taxSubcategoryPopUpShop => 'Pop-up shop';

  @override
  String get taxSubcategoryStreetMarket => 'Street market';

  @override
  String get taxSubcategoryHandmadeFair => 'Handmade fair';

  @override
  String get taxSubcategoryCharityMarket => 'Charity market';

  @override
  String get taxSubcategoryKidsMarket => 'Kids market';

  @override
  String get taxSubcategoryNightMarket => 'Night market';

  @override
  String get taxSubcategoryLocalBrandsMarket => 'Local brands market';

  @override
  String get taxSubcategoryClothingSwap => 'Clothing swap';

  @override
  String get taxSubcategoryChristmas => 'Christmas';

  @override
  String get taxSubcategoryNewYear => 'New Year';

  @override
  String get taxSubcategoryHalloween => 'Halloween';

  @override
  String get taxSubcategoryEaster => 'Easter';

  @override
  String get taxSubcategoryValentinesDay => 'Valentine\'s Day';

  @override
  String get taxSubcategoryJani => 'Jāņi (Midsummer)';

  @override
  String get taxSubcategoryCityFestival => 'City festival';

  @override
  String get taxSubcategorySummerFestival => 'Summer festival';

  @override
  String get taxSubcategoryAutumnEvent => 'Autumn event';

  @override
  String get taxSubcategorySpringEvent => 'Spring event';

  @override
  String get taxSubcategorySchoolHoliday => 'School holiday';

  @override
  String get taxSubcategoryNationalHoliday => 'National holiday';

  @override
  String get taxSubcategoryLocalTradition => 'Local tradition';

  @override
  String get taxSubcategoryMidsummer => 'Midsummer';

  @override
  String get taxSubcategoryFireworks => 'Fireworks';

  @override
  String get taxSubcategoryPublicCelebration => 'Public celebration';

  @override
  String get taxSubcategoryRechargeWalk => 'Recharge walk';

  @override
  String get taxSubcategoryCalmWalk => 'Calm walk';

  @override
  String get taxSubcategoryMindfulWalk => 'Mindful walk';

  @override
  String get taxSubcategoryCoffeeWalk => 'Coffee walk';

  @override
  String get taxSubcategoryTeaWalk => 'Tea walk';

  @override
  String get taxSubcategorySunsetReset => 'Sunset reset';

  @override
  String get taxSubcategoryNatureReset => 'Nature reset';

  @override
  String get taxSubcategoryDigitalDetox => 'Digital detox';

  @override
  String get taxSubcategorySlowMorning => 'Slow morning';

  @override
  String get taxSubcategoryEveningReset => 'Evening reset';

  @override
  String get taxSubcategorySauna => 'Sauna';

  @override
  String get taxSubcategorySpa => 'Spa';

  @override
  String get taxSubcategoryMassage => 'Massage';

  @override
  String get taxSubcategoryBreathwork => 'Breathwork';

  @override
  String get taxSubcategoryMeditation => 'Meditation';

  @override
  String get taxSubcategorySoundHealing => 'Sound healing';

  @override
  String get taxSubcategoryWellnessClass => 'Wellness class';

  @override
  String get taxSubcategoryRelaxationSession => 'Relaxation session';

  @override
  String get taxSubcategoryMentalHealthMeetup => 'Mental health meetup';

  @override
  String get taxSubcategoryQuietSocial => 'Quiet social';

  @override
  String get taxSubcategoryCoupleRecharge => 'Couple recharge';

  @override
  String get taxSubcategorySoloRecharge => 'Solo recharge';

  @override
  String get taxSubcategoryFriendsRecharge => 'Friends recharge';

  @override
  String get taxSubcategoryPirtsRitual => 'Pirts ritual (Latvian sauna)';

  @override
  String get taxSubcategoryRetreat => 'Retreat';

  @override
  String get taxSubcategoryLaserTag => 'Laser tag';

  @override
  String get taxSubcategoryPaintball => 'Paintball';

  @override
  String get taxSubcategoryAirsoft => 'Airsoft';

  @override
  String get taxSubcategoryKarting => 'Karting';

  @override
  String get taxSubcategoryShootingRange => 'Shooting range';

  @override
  String get taxSubcategoryArchery => 'Archery';

  @override
  String get taxSubcategoryAxeThrowing => 'Axe throwing';

  @override
  String get taxSubcategoryTrampolinePark => 'Trampoline park';

  @override
  String get taxSubcategoryRopePark => 'Rope park';

  @override
  String get taxSubcategoryZipline => 'Zipline';

  @override
  String get taxSubcategoryWindTunnel => 'Wind tunnel';

  @override
  String get taxSubcategoryHotAirBalloon => 'Hot air balloon';

  @override
  String get taxSubcategorySkydiving => 'Skydiving';

  @override
  String get taxSubcategoryBungeeJumping => 'Bungee jumping';

  @override
  String get taxSubcategoryParkour => 'Parkour';

  @override
  String get taxSubcategoryObstacleCourse => 'Obstacle course';

  @override
  String get taxSubcategoryZoo => 'Zoo';

  @override
  String get taxSubcategoryPettingZoo => 'Petting zoo';

  @override
  String get taxSubcategoryAquarium => 'Aquarium';

  @override
  String get taxSubcategoryAmusementPark => 'Amusement park';

  @override
  String get taxSubcategoryWaterPark => 'Water park';

  @override
  String get taxSubcategoryAdventurePark => 'Adventure park';

  @override
  String get taxSubcategoryBotanicalGarden => 'Botanical garden';

  @override
  String get taxSubcategoryPlanetarium => 'Planetarium';

  @override
  String get taxSubcategoryScienceCenter => 'Science center';

  @override
  String get taxSubcategoryObservationDeck => 'Observation deck';

  @override
  String get taxSubcategoryFerrisWheel => 'Ferris wheel';

  @override
  String get taxSubcategorySeasonalAttraction => 'Seasonal attraction';

  @override
  String get taxSubcategoryCarMeetup => 'Car meetup';

  @override
  String get taxSubcategoryRetroCars => 'Retro cars';

  @override
  String get taxSubcategoryCarShow => 'Car show';

  @override
  String get taxSubcategoryAutoExhibition => 'Auto exhibition';

  @override
  String get taxSubcategoryTuningMeetup => 'Tuning meetup';

  @override
  String get taxSubcategoryDriftEvent => 'Drift event';

  @override
  String get taxSubcategoryOffroadTrip => 'Off-road trip';

  @override
  String get taxSubcategoryMotorcycleRide => 'Motorcycle ride';

  @override
  String get taxSubcategoryMotorcycleMeetup => 'Motorcycle meetup';

  @override
  String get taxSubcategoryScooterMeetup => 'Scooter meetup';

  @override
  String get taxSubcategoryCarPhotoMeet => 'Car photo meet';

  @override
  String get taxSubcategoryDriveInCinema => 'Drive-in cinema';

  @override
  String get taxSubcategoryAnimeMeetup => 'Anime meetup';

  @override
  String get taxSubcategoryCosplayEvent => 'Cosplay event';

  @override
  String get taxSubcategoryComicCon => 'Comic Con';

  @override
  String get taxSubcategoryEsportsTournament => 'Esports tournament';

  @override
  String get taxSubcategoryLanParty => 'LAN party';

  @override
  String get taxSubcategoryRetroGaming => 'Retro gaming';

  @override
  String get taxSubcategoryTabletopWargames => 'Tabletop wargames';

  @override
  String get taxSubcategoryTradingCardGames => 'Trading card games';

  @override
  String get taxSubcategoryHackathon => 'Hackathon';

  @override
  String get taxSubcategoryGameDevMeetup => 'Game dev meetup';

  @override
  String get taxSubcategoryTechMeetup => 'Tech meetup';

  @override
  String get taxSubcategoryRoboticsEvent => 'Robotics event';

  @override
  String get taxSubcategoryFandomMeetup => 'Fandom meetup';

  @override
  String get taxSubcategoryCollectorsMeetup => 'Collectors meetup';

  @override
  String get taxSubcategorySpeedDating => 'Speed dating';

  @override
  String get taxSubcategorySinglesParty => 'Singles party';

  @override
  String get taxSubcategorySinglesMixer => 'Singles mixer';

  @override
  String get taxSubcategorySinglesDinner => 'Singles dinner';

  @override
  String get taxSubcategoryBlindDateEvent => 'Blind date event';

  @override
  String get taxSubcategoryDatingGameEvent => 'Dating game event';

  @override
  String get taxSubcategorySinglesActivity => 'Singles activity';

  @override
  String get taxSubcategoryMatchmakingEvent => 'Matchmaking event';

  @override
  String get taxSubcategoryOtherEvent => 'Other event';

  @override
  String get discoverHomeShortSport => 'Sport';

  @override
  String get discoverHomeShortWalks => 'Walks';

  @override
  String get discoverHomeShortGames => 'Games';

  @override
  String get discoverHomeShortDance => 'Dance';

  @override
  String get discoverHomeShortMusic => 'Music';

  @override
  String get discoverHomeShortArt => 'Art';

  @override
  String get discoverHomeShortFood => 'Food';

  @override
  String get discoverHomeShortWellness => 'Wellness';

  @override
  String get contentTranslationAction => 'Translate';

  @override
  String get contentTranslationShowTranslation => 'Show translation';

  @override
  String get contentTranslationLoading => 'Translating…';

  @override
  String get contentTranslationLabel => 'Translated automatically';

  @override
  String get contentTranslationShowOriginal => 'Show original';

  @override
  String get contentTranslationKeptOriginal =>
      'Terms, safety notes and names stay in the original language.';

  @override
  String get contentTranslationErrorSignIn => 'Sign in to translate.';

  @override
  String get contentTranslationErrorDisabled =>
      'Translation is not available right now.';

  @override
  String get contentTranslationErrorSameLanguage =>
      'This text is already in your language.';

  @override
  String get contentTranslationErrorUnsupported =>
      'Translation into this language is not available.';

  @override
  String get contentTranslationErrorSource => 'This text cannot be translated.';

  @override
  String get contentTranslationErrorRevision =>
      'This publication has been updated. Refresh the page.';

  @override
  String get contentTranslationErrorQuota =>
      'Translation limit reached for today. Try again tomorrow.';

  @override
  String get contentTranslationErrorBudget =>
      'Translation is temporarily unavailable.';

  @override
  String get contentTranslationErrorProvider =>
      'Could not translate. The original is shown.';

  @override
  String get createContentLanguageLabel => 'Language of this text';

  @override
  String get createContentLanguageHelp =>
      'Readers can translate the text only if you choose its language.';
}
