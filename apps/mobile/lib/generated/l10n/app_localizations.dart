import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_lv.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('lv'),
    Locale('ru'),
  ];

  /// Product name; not translated.
  ///
  /// In en, this message translates to:
  /// **'Recharge'**
  String get appTitle;

  /// Button: repeat a failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Button: re-check an action whose outcome is unknown.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get commonCheckAgain;

  /// Button: re-read the current server state.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Dialog confirmation button.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Generic loading state.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// Button: save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Button/title: sign in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get commonSignIn;

  /// Legacy button: continue without signing in.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get commonContinueAsGuest;

  /// Settings: label of the UI language selector.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// Settings: follow the device language list.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// Endonym of English; never translated.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// Endonym of Latvian; never translated.
  ///
  /// In en, this message translates to:
  /// **'Latviešu'**
  String get languageNameLv;

  /// Endonym of Russian; never translated.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageNameRu;

  /// Settings: explains what a language change affects.
  ///
  /// In en, this message translates to:
  /// **'Changes only the app language. Market, currency and event times stay the same.'**
  String get languageHint;

  /// Bottom navigation (accessibility label): personal home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation: favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// Bottom navigation: smart search.
  ///
  /// In en, this message translates to:
  /// **'Smart Search'**
  String get navSmartSearch;

  /// Bottom navigation and settings: notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// Bottom navigation: personal profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Bottom navigation: the Professional Page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get navPage;

  /// Bottom navigation: the Page's content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get navContent;

  /// Bottom navigation: create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// Bottom navigation: Page account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// Settings page title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// A signed-in page shown without a signed-in user.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get commonSignInRequired;

  /// Settings load error.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be loaded'**
  String get settingsLoadFailed;

  /// Settings section header (upper case).
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT AND WORKSPACE'**
  String get settingsSectionAccount;

  /// Settings item.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get settingsSwitchWorkspace;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal profile, Professional Pages and Admin access'**
  String get settingsSwitchWorkspaceHint;

  /// Settings section header (upper case).
  ///
  /// In en, this message translates to:
  /// **'CONTENT & ACTIVITY'**
  String get settingsSectionContent;

  /// Settings item.
  ///
  /// In en, this message translates to:
  /// **'Saved plans'**
  String get settingsSavedPlans;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved ideas and personal plans'**
  String get settingsSavedPlansHint;

  /// Settings item.
  ///
  /// In en, this message translates to:
  /// **'Search and conditions'**
  String get settingsSearch;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved searches and discovery filters'**
  String get settingsSearchHint;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox and route updates'**
  String get settingsNotificationsHint;

  /// Settings section header (upper case).
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get settingsSectionPreferences;

  /// Settings switch.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get settingsNotificationPreferences;

  /// Settings link.
  ///
  /// In en, this message translates to:
  /// **'Support / Help'**
  String get settingsSupport;

  /// Settings link title; the policy text itself is mandatory copy outside L4.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// Settings link title; the terms text itself is mandatory copy outside L4.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// Settings button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// Settings section.
  ///
  /// In en, this message translates to:
  /// **'Profile information'**
  String get settingsProfileInformation;

  /// Profile field label.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayName;

  /// Profile field label.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Profile field label.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get settingsCity;

  /// Profile field label.
  ///
  /// In en, this message translates to:
  /// **'Avatar URL/Path'**
  String get settingsAvatar;

  /// Profile save in progress.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get settingsSaving;

  /// Profile save button.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get settingsSaveProfile;

  /// Profile saved confirmation.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get settingsProfileSaved;

  /// Sign-in headline.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save and manage'**
  String get authSignInHeadline;

  /// Auth gate headline.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authSignInToContinue;

  /// Sign-in explanation.
  ///
  /// In en, this message translates to:
  /// **'Without signing in you can browse events and places. Signing in is needed for favorites, your profile and creating activities.'**
  String get authSignInBody;

  /// Auth gate body for Scenario.
  ///
  /// In en, this message translates to:
  /// **'A personal Scenario is available only to a signed-in user.'**
  String get authScenarioRequiresSignIn;

  /// Sign-in field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Sign-in field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEmailHint;

  /// Sign-in field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Sign-in field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// Sign-in in progress.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authSigningIn;

  /// Validation: empty email.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEmailRequired;

  /// Validation: malformed email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authEmailInvalid;

  /// Validation: empty password.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// Validation: password shorter than the minimum.
  ///
  /// In en, this message translates to:
  /// **'The password is too short'**
  String get authPasswordTooShort;

  /// Sign-in error AUTH_INVALID_CREDENTIALS.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password'**
  String get authErrorInvalidCredentials;

  /// Sign-in error AUTH_TOO_MANY_ATTEMPTS.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later'**
  String get authErrorTooManyAttempts;

  /// Sign-in error NETWORK_UNAVAILABLE.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get authErrorNetwork;

  /// Sign-in error, any other code.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Try again'**
  String get authErrorGeneric;

  /// Session restore failed.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again.'**
  String get authSessionExpired;

  /// Splash: session restore in progress.
  ///
  /// In en, this message translates to:
  /// **'Restoring your session…'**
  String get authRestoringSession;

  /// Safe fallback for an unknown or internal error code; the code itself is never shown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// The request could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again when you are back online.'**
  String get errorOffline;

  /// Offline, a journaled command will be retried with the same key.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your request is saved and will not be duplicated.'**
  String get errorOfflineSaved;

  /// The command may have reached the server.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm the result. Checking again will not repeat the action.'**
  String get errorUnknownOutcome;

  /// Session refresh failed.
  ///
  /// In en, this message translates to:
  /// **'Your session could not be confirmed. Try again.'**
  String get errorSessionNotConfirmed;

  /// Server session expired or revoked.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again.'**
  String get errorSessionExpired;

  /// The server needs a signed-in user.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue.'**
  String get errorSignInRequired;

  /// Permission or capability denied.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this action.'**
  String get errorNotAllowed;

  /// Unsupported client, contract or schema version.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Update the app.'**
  String get errorUpdateApp;

  /// Malformed request (invalid contract or argument).
  ///
  /// In en, this message translates to:
  /// **'The request could not be processed. Update the app or try again.'**
  String get errorInvalidRequest;

  /// Rate limited without a retry hint.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again shortly.'**
  String get errorRateLimited;

  /// Rate limited with the server's retry-after in seconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Too many attempts. Try again in {count} second.} other{Too many attempts. Try again in {count} seconds.}}'**
  String errorRateLimitedSeconds(int count);

  /// Server unavailable or contention.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Try again later.'**
  String get errorTemporarilyUnavailable;

  /// Revision conflict or stale revision.
  ///
  /// In en, this message translates to:
  /// **'This was changed meanwhile. Refresh to see the current version.'**
  String get errorConflictRefresh;

  /// The object was not found.
  ///
  /// In en, this message translates to:
  /// **'This is no longer available.'**
  String get errorNotFound;

  /// Server feature flag is off.
  ///
  /// In en, this message translates to:
  /// **'This feature is not available yet.'**
  String get errorFeatureDisabled;

  /// The market is disabled; the market is not named.
  ///
  /// In en, this message translates to:
  /// **'This is not available in this region yet.'**
  String get errorMarketDisabled;

  /// Publisher eligibility: account inactive.
  ///
  /// In en, this message translates to:
  /// **'Your account is restricted.'**
  String get errorAccountRestricted;

  /// Publisher eligibility: access snapshot stale.
  ///
  /// In en, this message translates to:
  /// **'Your access is being updated. Try again.'**
  String get errorAccessUpdating;

  /// Content: publisher not eligible or not accessible.
  ///
  /// In en, this message translates to:
  /// **'You cannot publish on behalf of this profile or page.'**
  String get contentErrorPublisherNotEligible;

  /// Content/identity: creator verification required.
  ///
  /// In en, this message translates to:
  /// **'Taking payment or reservations requires identity verification.'**
  String get contentErrorCreatorVerificationRequired;

  /// Identity: creator verification unavailable.
  ///
  /// In en, this message translates to:
  /// **'Identity verification is temporarily unavailable.'**
  String get contentErrorCreatorVerificationUnavailable;

  /// Page membership inactive.
  ///
  /// In en, this message translates to:
  /// **'Your access to this page has ended.'**
  String get contentErrorMembershipInactive;

  /// Content type disabled or unsupported.
  ///
  /// In en, this message translates to:
  /// **'Publishing this type is not available yet.'**
  String get contentErrorTypeDisabled;

  /// Server validation refused the draft.
  ///
  /// In en, this message translates to:
  /// **'Some fields need attention before publishing.'**
  String get contentErrorValidationFailed;

  /// Attached media not ready.
  ///
  /// In en, this message translates to:
  /// **'Media is still being processed. Try again shortly.'**
  String get contentErrorMediaNotReady;

  /// Moderation required.
  ///
  /// In en, this message translates to:
  /// **'This needs to be reviewed before it can be published.'**
  String get contentErrorModerationRequired;

  /// Publication restricted by Trust & Safety; no reason or reporter is shown.
  ///
  /// In en, this message translates to:
  /// **'Publication is restricted.'**
  String get contentErrorPublicationRestricted;

  /// Storage limit exceeded.
  ///
  /// In en, this message translates to:
  /// **'The storage limit has been reached.'**
  String get contentErrorStorageLimit;

  /// Privacy consent required.
  ///
  /// In en, this message translates to:
  /// **'Your consent is required to continue.'**
  String get contentErrorPrivacyConsentRequired;

  /// Age eligibility required.
  ///
  /// In en, this message translates to:
  /// **'Age confirmation is required for this.'**
  String get contentErrorAgeEligibilityRequired;

  /// Client-side refusal (not_allowed) before any server call.
  ///
  /// In en, this message translates to:
  /// **'This action is not available for this draft.'**
  String get contentErrorNotAllowedLocally;

  /// Import rollback not allowed.
  ///
  /// In en, this message translates to:
  /// **'This import can no longer be undone.'**
  String get importErrorRollbackNotAllowed;

  /// Import generation or cleanup token mismatch.
  ///
  /// In en, this message translates to:
  /// **'The import changed meanwhile. Refresh and try again.'**
  String get importErrorChanged;

  /// Import already rolled back.
  ///
  /// In en, this message translates to:
  /// **'This import was undone.'**
  String get importErrorRolledBack;

  /// The local original was already removed.
  ///
  /// In en, this message translates to:
  /// **'The local original has already been removed.'**
  String get importErrorOriginalRemoved;

  /// Media upload missing, incomplete or mismatched.
  ///
  /// In en, this message translates to:
  /// **'The upload did not complete. Upload the file again.'**
  String get mediaErrorUploadIncomplete;

  /// Media limit exceeded.
  ///
  /// In en, this message translates to:
  /// **'The file is too large or the limit has been reached.'**
  String get mediaErrorLimitExceeded;

  /// Media still referenced.
  ///
  /// In en, this message translates to:
  /// **'This file is still in use and cannot be deleted.'**
  String get mediaErrorAssetReferenced;

  /// Media retry not allowed.
  ///
  /// In en, this message translates to:
  /// **'This upload cannot be retried. Start a new upload.'**
  String get mediaErrorRetryNotAllowed;

  /// Booking: sold out.
  ///
  /// In en, this message translates to:
  /// **'This event is sold out.'**
  String get bookingErrorSoldOut;

  /// Booking: active booking or concurrency limit.
  ///
  /// In en, this message translates to:
  /// **'You have reached the limit of active bookings.'**
  String get bookingErrorBookingLimit;

  /// Booking: registration not open.
  ///
  /// In en, this message translates to:
  /// **'Registration has not opened yet.'**
  String get bookingErrorRegistrationNotOpen;

  /// Booking: registration closed.
  ///
  /// In en, this message translates to:
  /// **'Registration is closed.'**
  String get bookingErrorRegistrationClosed;

  /// Booking: cancellation deadline passed.
  ///
  /// In en, this message translates to:
  /// **'The cancellation deadline has passed.'**
  String get bookingErrorCancellationDeadlinePassed;

  /// Booking: reconfirmation deadline passed.
  ///
  /// In en, this message translates to:
  /// **'The confirmation deadline has passed.'**
  String get bookingErrorReconfirmationDeadlinePassed;

  /// Booking: material revision mismatch.
  ///
  /// In en, this message translates to:
  /// **'The event changed again. Refresh and confirm the new time.'**
  String get bookingErrorMaterialRevisionMismatch;

  /// Booking: reconfirmation not required.
  ///
  /// In en, this message translates to:
  /// **'No confirmation is needed now.'**
  String get bookingErrorReconfirmationNotRequired;

  /// Booking: revision conflict.
  ///
  /// In en, this message translates to:
  /// **'Your booking changed meanwhile. Refresh to see the current state.'**
  String get bookingErrorRevisionConflict;

  /// Booking: already active.
  ///
  /// In en, this message translates to:
  /// **'You already have a booking for this event.'**
  String get bookingErrorAlreadyActive;

  /// Booking: invalid guest count.
  ///
  /// In en, this message translates to:
  /// **'This number of seats is not allowed.'**
  String get bookingErrorInvalidGuestCount;

  /// Booking: event or occurrence unavailable or cancelled.
  ///
  /// In en, this message translates to:
  /// **'This event is not available for booking.'**
  String get bookingErrorEventUnavailable;

  /// Booking: eligibility not satisfied; no private condition is named.
  ///
  /// In en, this message translates to:
  /// **'You do not meet the conditions to book this event.'**
  String get bookingErrorEligibility;

  /// Booking: hold expired.
  ///
  /// In en, this message translates to:
  /// **'The seat hold expired. Try booking again.'**
  String get bookingErrorHoldExpired;

  /// Booking: any other refusal.
  ///
  /// In en, this message translates to:
  /// **'The booking was not accepted.'**
  String get bookingErrorGeneric;

  /// Booking: reading the active booking was refused.
  ///
  /// In en, this message translates to:
  /// **'Booking could not be loaded.'**
  String get bookingErrorLoadFailed;

  /// Booking ended: missed reconfirmation.
  ///
  /// In en, this message translates to:
  /// **'Your booking was released because attendance was not confirmed in time.'**
  String get bookingEndedMissedReconfirmation;

  /// Booking ended: event or occurrence cancelled.
  ///
  /// In en, this message translates to:
  /// **'The organizer cancelled this event; your booking was cancelled.'**
  String get bookingEndedEventCancelled;

  /// Booking ended: organizer cancelled.
  ///
  /// In en, this message translates to:
  /// **'The organizer cancelled your booking.'**
  String get bookingEndedOrganizerCancelled;

  /// Inbox item title when no text could be rendered.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationFallbackTitle;

  /// Inbox item: contentStatus unsupported_locale.
  ///
  /// In en, this message translates to:
  /// **'This notification is not available in your language.'**
  String get notificationUnsupportedLocale;

  /// Inbox item: contentStatus template_unavailable.
  ///
  /// In en, this message translates to:
  /// **'This notification can no longer be shown.'**
  String get notificationTemplateUnavailable;

  /// Client refusal save_required.
  ///
  /// In en, this message translates to:
  /// **'Save the draft to the server first.'**
  String get localErrorSaveRequired;

  /// Client refusal media_missing.
  ///
  /// In en, this message translates to:
  /// **'Upload the required media first.'**
  String get localErrorMediaMissing;

  /// Create media: button that opens the system photo picker.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get createMediaChoosePhoto;

  /// Create media: button that opens the system camera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get createMediaTakePhoto;

  /// Create media: shown while a picked photo is compressed.
  ///
  /// In en, this message translates to:
  /// **'Preparing photo…'**
  String get createMediaPreparing;

  /// Create media: the cover is a photo picked on this device.
  ///
  /// In en, this message translates to:
  /// **'Cover photo selected'**
  String get createMediaCoverSelected;

  /// Client refusal media_unsupported.
  ///
  /// In en, this message translates to:
  /// **'This image can\'t be used. Choose a photo.'**
  String get localErrorMediaUnsupported;

  /// Client refusal media_decode_failed.
  ///
  /// In en, this message translates to:
  /// **'This image couldn\'t be opened. Try another one.'**
  String get localErrorMediaDecodeFailed;

  /// Client refusal media_too_large.
  ///
  /// In en, this message translates to:
  /// **'This image is too large even after compression.'**
  String get localErrorMediaTooLarge;

  /// Client refusal media_storage_full.
  ///
  /// In en, this message translates to:
  /// **'Not enough space for draft photos. Remove some photos.'**
  String get localErrorMediaStorageFull;

  /// Client refusal media_permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings to take a photo.'**
  String get localErrorMediaPermissionDenied;

  /// Client refusal cover_required.
  ///
  /// In en, this message translates to:
  /// **'Add a cover image first.'**
  String get localErrorCoverRequired;

  /// Client refusal submission_required.
  ///
  /// In en, this message translates to:
  /// **'Submit the draft for review first.'**
  String get localErrorSubmissionRequired;

  /// Client refusal publication_required.
  ///
  /// In en, this message translates to:
  /// **'Publish it first.'**
  String get localErrorPublicationRequired;

  /// Client refusal publisher_required.
  ///
  /// In en, this message translates to:
  /// **'Choose who publishes this first.'**
  String get localErrorPublisherRequired;

  /// Client refusal no_conflict.
  ///
  /// In en, this message translates to:
  /// **'There is no newer server version to resolve.'**
  String get localErrorNoConflict;

  /// Client refusal foreign_record; the other account is not named.
  ///
  /// In en, this message translates to:
  /// **'This draft belongs to another account.'**
  String get localErrorForeignRecord;

  /// Client refusal editing_after_publication_not_supported.
  ///
  /// In en, this message translates to:
  /// **'Editing after publication is not available yet.'**
  String get localErrorEditingAfterPublication;

  /// Client refusal media_rights_required.
  ///
  /// In en, this message translates to:
  /// **'Confirm that you have the rights to this media.'**
  String get localErrorMediaRightsRequired;

  /// Client refusal <type>_draft_required.
  ///
  /// In en, this message translates to:
  /// **'Create a draft in Create first.'**
  String get localErrorDraftRequired;

  /// Client refusal activity_draft_changed.
  ///
  /// In en, this message translates to:
  /// **'The draft changed. Save it again.'**
  String get localErrorDraftChanged;

  /// Client refusal consent_missing.
  ///
  /// In en, this message translates to:
  /// **'Consent is missing. Give consent to continue.'**
  String get localErrorConsentMissing;

  /// Client refusal share_token_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available right now.'**
  String get localErrorShareUnavailable;

  /// Client refusal media_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Media upload is not available right now.'**
  String get localErrorMediaUnavailable;

  /// Import: session_open.
  ///
  /// In en, this message translates to:
  /// **'An import is already in progress.'**
  String get importErrorSessionOpen;

  /// Import: no_open_session.
  ///
  /// In en, this message translates to:
  /// **'There is no import in progress.'**
  String get importErrorNoOpenSession;

  /// Import: nothing_to_import.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to import.'**
  String get importErrorNothingToImport;

  /// Import: not_imported.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been imported yet.'**
  String get importErrorNotImported;

  /// Import: not_verified.
  ///
  /// In en, this message translates to:
  /// **'The import has not been checked on the server yet.'**
  String get importErrorNotVerified;

  /// Import: verification_mismatch.
  ///
  /// In en, this message translates to:
  /// **'The server copy does not match the local original. The original is kept.'**
  String get importErrorVerificationMismatch;

  /// Import: server_check_failed.
  ///
  /// In en, this message translates to:
  /// **'The server check did not pass. The original is kept.'**
  String get importErrorServerCheckFailed;

  /// Import: original_missing.
  ///
  /// In en, this message translates to:
  /// **'The local original is missing.'**
  String get importErrorOriginalMissing;

  /// Import: local_changed_since_import.
  ///
  /// In en, this message translates to:
  /// **'The local copy changed after import. Import it again.'**
  String get importErrorLocalChanged;

  /// Profile load error.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be loaded'**
  String get profileLoadFailed;

  /// Booking section title.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get bookingTitle;

  /// Booking: loading.
  ///
  /// In en, this message translates to:
  /// **'Loading your booking…'**
  String get bookingLoading;

  /// Booking: command in flight.
  ///
  /// In en, this message translates to:
  /// **'Sending your request…'**
  String get bookingSending;

  /// Booking state label; status is the stable Booking state id, which is never translated itself.
  ///
  /// In en, this message translates to:
  /// **'{status, select, pending{Pending} confirmed{Confirmed} waitlisted{On the waitlist} other{Inactive}}'**
  String bookingStatus(String status);

  /// Number of booked seats.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} seat} other{{count} seats}}'**
  String bookingSeatsCount(int count);

  /// The user's active booking; status from bookingStatus, seats from bookingSeatsCount.
  ///
  /// In en, this message translates to:
  /// **'Your booking: {status} · {seats}'**
  String bookingMine(String status, String seats);

  /// Booking: none active.
  ///
  /// In en, this message translates to:
  /// **'You have no booking for this event.'**
  String get bookingNone;

  /// Reconfirmation needed, no deadline known.
  ///
  /// In en, this message translates to:
  /// **'The event changed. Please confirm your attendance.'**
  String get bookingReconfirmRequired;

  /// Reconfirmation deadline, already formatted in the event's own time zone.
  ///
  /// In en, this message translates to:
  /// **'The event changed. Confirm your attendance by {deadline}.'**
  String bookingReconfirmBy(String deadline);

  /// Seat selector: chosen of allowed.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {max, plural, one{{max} seat} other{{max} seats}}'**
  String bookingSeatsSelector(int selected, int max);

  /// Book button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Book {count} seat} other{Book {count} seats}}'**
  String bookingBookSeats(int count);

  /// Reconfirm button.
  ///
  /// In en, this message translates to:
  /// **'Confirm attendance'**
  String get bookingConfirmAttendance;

  /// Cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get bookingCancel;

  /// Accessibility label of the minus button.
  ///
  /// In en, this message translates to:
  /// **'Fewer seats'**
  String get bookingFewerSeats;

  /// Accessibility label of the plus button.
  ///
  /// In en, this message translates to:
  /// **'More seats'**
  String get bookingMoreSeats;

  /// Header of a default-off publication test page.
  ///
  /// In en, this message translates to:
  /// **'Test publication path (local Emulator)'**
  String get publicationTestPath;

  /// Header of the publication test page when it talks to the dev cloud (N3a.2), not the local Emulator.
  ///
  /// In en, this message translates to:
  /// **'Test publication path (dev cloud)'**
  String get publicationTestPathDevCloud;

  /// No local draft of the type; type is the stable Create type id.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{No Event draft in Create} place{No Place draft in Create} rental{No Rental draft in Create} session{No Session draft in Create} activity{No Activity draft in Create} collection{No Collection draft in Create} findPeople{No Find People draft in Create} route{No Route draft in Create} scenario{No Scenario draft in Create} classWorkshop{No Class / Workshop draft in Create} other{No draft in Create}}'**
  String publicationNoDraft(String type);

  /// List header of the user's server objects of a type.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{My events} place{My places} rental{My rentals} session{My sessions} activity{My activities} collection{My collections} findPeople{My Find People requests} route{My routes} scenario{My scenarios} classWorkshop{My classes and workshops} other{My objects}}'**
  String publicationMyObjects(String type);

  /// Count of attached media.
  ///
  /// In en, this message translates to:
  /// **'Media uploaded: {count}'**
  String publicationMediaUploaded(int count);

  /// Published revision id; the id itself is not translated.
  ///
  /// In en, this message translates to:
  /// **'Revision {revision}'**
  String publicationRevision(String revision);

  /// Published revision id.
  ///
  /// In en, this message translates to:
  /// **'Published version: {revision}'**
  String publicationPublishedVersion(String revision);

  /// Draft revision number.
  ///
  /// In en, this message translates to:
  /// **'Draft revision: {revision}'**
  String publicationDraftRevision(String revision);

  /// Draft revision with unpublished edits.
  ///
  /// In en, this message translates to:
  /// **'Draft revision: {revision} — unpublished changes; review required'**
  String publicationDraftRevisionPending(String revision);

  /// Revision conflict notice.
  ///
  /// In en, this message translates to:
  /// **'The server has a newer version (revision {revision}). Your edit is kept here; nothing was overwritten.'**
  String publicationConflict(String revision);

  /// Status: no server draft.
  ///
  /// In en, this message translates to:
  /// **'Not saved to the server'**
  String get publicationNotSaved;

  /// Status: no server record yet.
  ///
  /// In en, this message translates to:
  /// **'Not saved to the server yet'**
  String get publicationNotSavedYet;

  /// Status: server draft without publication status.
  ///
  /// In en, this message translates to:
  /// **'Saved as a server draft'**
  String get publicationServerDraft;

  /// Server revision number.
  ///
  /// In en, this message translates to:
  /// **'Server revision {revision}'**
  String publicationServerRevision(String revision);

  /// Status: publication not prepared.
  ///
  /// In en, this message translates to:
  /// **'Not prepared'**
  String get publicationNotPrepared;

  /// Content review state (publication_submission.schema.json state, or draft before any submission); state is the stable server value.
  ///
  /// In en, this message translates to:
  /// **'{state, select, draft{draft} submitted{submitted} under_review{under review} revision_requested{changes requested} rejected{rejected} approved_for_publication{approved} published{published} superseded{superseded} other{unknown}}'**
  String publicationReviewState(String state);

  /// Content visibility (publication_pointer.schema.json visibility, or unpublished); state is the stable server value.
  ///
  /// In en, this message translates to:
  /// **'{state, select, unpublished{not published} visible{visible} withdrawn{hidden} restricted{restricted} archived{archived} other{unknown}}'**
  String publicationVisibilityState(String state);

  /// Status line; both values come from the select messages above.
  ///
  /// In en, this message translates to:
  /// **'Review: {review}; visibility: {visibility}'**
  String publicationStatusLine(String review, String visibility);

  /// A server object could not be read; reason is a localized message.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {reason}'**
  String publicationObjectUnavailable(String reason);

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get publicationSave;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Save to server'**
  String get publicationSaveToServer;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Upload media'**
  String get publicationUploadMedia;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Upload cover'**
  String get publicationUploadCover;

  /// Publication button: submit for review.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get publicationSubmit;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publicationPublish;

  /// Publication button: withdraw from public view.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get publicationHide;

  /// Publication button after a conflict.
  ///
  /// In en, this message translates to:
  /// **'Save my version'**
  String get publicationSaveMyVersion;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Activate published version'**
  String get publicationActivatePublished;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Edit in Create'**
  String get publicationEditInCreate;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get publicationPrepare;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get publicationShareLink;

  /// Publication button.
  ///
  /// In en, this message translates to:
  /// **'Revoke link'**
  String get publicationRevokeLink;

  /// Checkbox: media rights.
  ///
  /// In en, this message translates to:
  /// **'I have permission to use the cover image'**
  String get publicationCoverPermission;

  /// Activity validation refusal hint.
  ///
  /// In en, this message translates to:
  /// **'Check the Activity fields in Create and submit again.'**
  String get publicationActivityCheckFields;

  /// Collection members header.
  ///
  /// In en, this message translates to:
  /// **'Items (server status)'**
  String get publicationCollectionItems;

  /// Find People privacy notice.
  ///
  /// In en, this message translates to:
  /// **'Others see only an approximate area (about 1 km). The exact meeting point stays private to you.'**
  String get findPeopleApproxArea;

  /// Find People consent button.
  ///
  /// In en, this message translates to:
  /// **'Consent to publish'**
  String get findPeopleConsentToPublish;

  /// Find People consent button.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent'**
  String get findPeopleWithdrawConsent;

  /// Find People consent status.
  ///
  /// In en, this message translates to:
  /// **'Consent: not given'**
  String get findPeopleConsentNone;

  /// Inactive consent; state is the stable server value (revoked, expired).
  ///
  /// In en, this message translates to:
  /// **'{state, select, revoked{Consent: withdrawn} expired{Consent: expired} other{Consent: inactive}}'**
  String findPeopleConsentState(String state);

  /// Active consent end, formatted.
  ///
  /// In en, this message translates to:
  /// **'Consent: active until {date}'**
  String findPeopleConsentActiveUntil(String date);

  /// Route privacy trim button.
  ///
  /// In en, this message translates to:
  /// **'Hide {meters} m at both ends'**
  String routeHideEnds(int meters);

  /// Route privacy trim status.
  ///
  /// In en, this message translates to:
  /// **'Hidden ends: unknown'**
  String get routeHiddenEndsUnknown;

  /// Route privacy trim lengths; values are formatted numbers.
  ///
  /// In en, this message translates to:
  /// **'Hidden ends: start {start} m, end {end} m'**
  String routeHiddenEnds(String start, String end);

  /// Route refusal privacy_trim_required.
  ///
  /// In en, this message translates to:
  /// **'Recorded GPS: hide at least 200 m at both ends before publishing'**
  String get routeTrimRequired;

  /// Route refusal privacy_trim_empty.
  ///
  /// In en, this message translates to:
  /// **'Too short to publish: nothing is left after hiding the ends'**
  String get routeTrimEmpty;

  /// Scenario share outcome unknown.
  ///
  /// In en, this message translates to:
  /// **'Link issued, answer lost: issue a new link'**
  String get scenarioShareLost;

  /// Scenario unlisted share; token is shown only to its owner and never translated.
  ///
  /// In en, this message translates to:
  /// **'Unlisted link until {date}: {token}'**
  String scenarioShareUntil(String date, String token);

  /// Server status of a Collection member; status is the stable server value.
  ///
  /// In en, this message translates to:
  /// **'{status, select, eligible{Available} unavailable{Unavailable} withheld{Withheld} unknown{Unknown} forbidden{Not accessible} other{Unknown}}'**
  String collectionMemberStatus(String status);

  /// Title of a default-off publication test page; type is the stable Create type id.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Event publication (test)} place{Place publication (test)} rental{Rental publication (test)} session{Session publication (test)} activity{Activity publication (test)} collection{Collection publication (test)} findPeople{Find People publication (test)} route{Route publication (test)} scenario{Scenario publication (test)} classWorkshop{Class / Workshop publication (test)} other{Publication (test)}}'**
  String publicationPageTitle(String type);

  /// Signed-out state of a publication test page.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Sign in to publish your Event draft} place{Sign in to publish your Place draft} rental{Sign in to publish your Rental draft} session{Sign in to publish your Session draft} activity{Sign in to publish your Activity draft} collection{Sign in to publish your Collection draft} findPeople{Sign in to publish your Find People draft} route{Sign in to publish your Route} scenario{Sign in to publish your Scenario} classWorkshop{Sign in to publish your Class draft} other{Sign in to publish your draft}}'**
  String publicationSignIn(String type);

  /// Activity publication edit precondition.
  ///
  /// In en, this message translates to:
  /// **'Save your Create draft before editing this publication.'**
  String get publicationSaveCreateDraftFirst;

  /// Title of the default-off import test page.
  ///
  /// In en, this message translates to:
  /// **'Import local data (test)'**
  String get importPageTitle;

  /// Dialog cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Name of a Create type; type is the stable type id.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Event} place{Place} rental{Rental} session{Session} activity{Activity} collection{Collection} findPeople{Find People} route{Route} scenario{Scenario} classWorkshop{Class / Workshop} other{Object}}'**
  String createTypeName(String type);

  /// Import test section header.
  ///
  /// In en, this message translates to:
  /// **'Import local data (local Emulator)'**
  String get importSectionTitle;

  /// Import: no session.
  ///
  /// In en, this message translates to:
  /// **'No import session'**
  String get importNoSession;

  /// Import session status; status is the stable value.
  ///
  /// In en, this message translates to:
  /// **'{status, select, approved{Approved} running{Running} paused{Paused} completed{Completed} failed{Failed} other{Unknown}}'**
  String importSessionStatus(String status);

  /// Import session progress.
  ///
  /// In en, this message translates to:
  /// **'Session: {status}, {done} of {total}'**
  String importSessionProgress(String status, int done, int total);

  /// Deleted local copies not yet recorded on the server.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} deleted local copy still to record on the server} other{{count} deleted local copies still to record on the server}}'**
  String importPendingCleanups(int count);

  /// Import button.
  ///
  /// In en, this message translates to:
  /// **'Finish cleanup'**
  String get importFinishCleanup;

  /// Import button: classify without importing.
  ///
  /// In en, this message translates to:
  /// **'Dry run'**
  String get importDryRun;

  /// Import button.
  ///
  /// In en, this message translates to:
  /// **'Approve import'**
  String get importApprove;

  /// Import button.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get importRun;

  /// Import button.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get importResume;

  /// Import plan class of one local draft; value is the stable class.
  ///
  /// In en, this message translates to:
  /// **'{value, select, create{will be created} alreadyMapped{already imported} conflict{changed since import} unsupported{not supported} blocked{blocked} other{unknown}}'**
  String importClassification(String value);

  /// Why a local draft has its import class; reason is the stable code prefix.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, type_not_importable{this type cannot be imported yet} owner_mismatch{belongs to another account} publisher_missing{no publisher chosen} publisher_not_eligible{you cannot publish for this publisher} local_id{has local-only links} unsupported_capability{uses features not supported yet} rolled_back{import was rolled back} rollback_pending{rollback is waiting for the server} cleanup_reserved{local copy is being deleted} cleanup_pending{deletion still to record} resume{import can be resumed} local_changed_since_import{changed locally after import} published_by_test_path{already published from this device} other{other reason}}'**
  String importReason(String reason);

  /// Import plan line; both values are localized labels.
  ///
  /// In en, this message translates to:
  /// **'{type}: {classification}'**
  String importCandidateLine(String type, String classification);

  /// Import plan line with a localized reason.
  ///
  /// In en, this message translates to:
  /// **'{type}: {classification} ({reason})'**
  String importCandidateLineReason(
    String type,
    String classification,
    String reason,
  );

  /// Server state of an imported item; state is the stable value.
  ///
  /// In en, this message translates to:
  /// **'{state, select, created{created} mediaUploaded{media uploaded} bodySaved{content saved} verified{verified} failed{failed} rollbackPending{rollback pending} rolledBack{rolled back} cleanupReserved{local copy being deleted} other{unknown}}'**
  String importItemState(String state);

  /// Server item; contentId is a stable id, never translated.
  ///
  /// In en, this message translates to:
  /// **'Server {contentId}: {state}'**
  String importServerLine(String contentId, String state);

  /// Server item with a localized failure.
  ///
  /// In en, this message translates to:
  /// **'Server {contentId}: {state} ({reason})'**
  String importServerLineReason(String contentId, String state, String reason);

  /// Import refusal with a localized reason.
  ///
  /// In en, this message translates to:
  /// **'Refused: {reason}'**
  String importRefused(String reason);

  /// Local original status.
  ///
  /// In en, this message translates to:
  /// **'Local copy: {state}'**
  String importLocalCopy(String state);

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'kept (not imported)'**
  String get importCleanupNotImported;

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'kept (server copy not verified)'**
  String get importCleanupAwaitingVerification;

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'kept (confirm the server copy)'**
  String get importCleanupAwaitingConfirmation;

  /// Local copy stage: recovery period end, formatted in the device zone.
  ///
  /// In en, this message translates to:
  /// **'kept until {date}'**
  String importCleanupRecovery(String date);

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'may be deleted'**
  String get importCleanupEligible;

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'being deleted (reserved on the server)'**
  String get importCleanupReserved;

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get importCleanupDeleted;

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'kept (rollback waiting for the server)'**
  String get importCleanupRollbackPending;

  /// Local copy stage.
  ///
  /// In en, this message translates to:
  /// **'kept (import rolled back)'**
  String get importCleanupRolledBack;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Import again'**
  String get importAgain;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Keep the server copy'**
  String get importKeepServerCopy;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Finish deleting local copy'**
  String get importFinishDeleting;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Delete local copy'**
  String get importDeleteLocal;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Keep local copy'**
  String get importKeepLocal;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Retry rollback'**
  String get importRetryRollback;

  /// Import item button.
  ///
  /// In en, this message translates to:
  /// **'Roll back import'**
  String get importRollBack;

  /// Rollback confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Roll back this import?'**
  String get importRollbackDialogTitle;

  /// Rollback confirmation body.
  ///
  /// In en, this message translates to:
  /// **'The imported server draft is closed for good. Your local copy stays and can be imported again later.'**
  String get importRollbackDialogBody;

  /// Rollback confirmation button.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get importRollbackConfirm;

  /// Notifications: tooltip of the read-all button.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsReadAll;

  /// Notifications: load error.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be loaded'**
  String get notificationsLoadFailed;

  /// Notifications: empty inbox.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// Notifications: search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search notifications'**
  String get notificationsSearchHint;

  /// Notifications: tooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get notificationsClearSearch;

  /// Notifications filter chip.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// Notifications filter chip.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get notificationsFilterNew;

  /// Notifications filter chip.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationsFilterReminders;

  /// Notifications filter chip.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get notificationsFilterUpdates;

  /// Notifications filter chip.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get notificationsFilterScenarios;

  /// Notifications: tooltip of the item menu.
  ///
  /// In en, this message translates to:
  /// **'Notification actions'**
  String get notificationsActions;

  /// Notifications: search without results.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search'**
  String get notificationsNoSearchResults;

  /// Notifications: empty filter.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this filter yet'**
  String get notificationsFilterEmpty;

  /// Notifications: reset the filter.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get notificationsShowAll;

  /// Where a notification leads; kind is a stable id.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, legacy{Legacy notification} routeMap{Route map} map{Map} details{Details} saved{Saved plan} search{Search} publishStatus{Publish status} create{Create} creatorProfile{Creator profile} discover{Discover} other{Update}}'**
  String notificationDestination(String kind);

  /// Action that opens a notification's destination; kind is a stable id.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, legacy{Open} routeMap{Open route} map{Open map} details{Open details} saved{Open saved} search{Search} publishStatus{Open listing} create{Open create} creatorProfile{Open profile} discover{Open feed} other{Open}}'**
  String notificationDestinationAction(String kind);

  /// Signed-out state of the import test page.
  ///
  /// In en, this message translates to:
  /// **'Sign in to import your local data'**
  String get importSignIn;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'A place in the guide is no longer public. Remove or replace it.'**
  String get validationAPlaceInTheGuideIsNo;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'A place in the guide was not found. Remove or replace it.'**
  String get validationAPlaceInTheGuideWasNot;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add a cover image.'**
  String get validationAddACoverImage;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add a cover photo.'**
  String get validationAddACoverPhoto;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add a pricing note.'**
  String get validationAddAPricingNote;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add a safety notice for this category.'**
  String get validationAddASafetyNoticeForThisCategory;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add a short description.'**
  String get validationAddAShortDescription;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add a title.'**
  String get validationAddATitle;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add an address or a location label.'**
  String get validationAddAnAddressOrALocationLabel;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add at least three places.'**
  String get validationAddAtLeastThreePlaces;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add places to the guide.'**
  String get validationAddPlacesToTheGuide;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add the delivery fee (zero if free).'**
  String get validationAddTheDeliveryFeeZeroIfFree;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add the entry price.'**
  String get validationAddTheEntryPrice;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add the prices.'**
  String get validationAddThePrices;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add the public business address.'**
  String get validationAddThePublicBusinessAddress;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add the rental terms.'**
  String get validationAddTheRentalTerms;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add the weekly opening hours.'**
  String get validationAddTheWeeklyOpeningHours;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Add what you rent out.'**
  String get validationAddWhatYouRentOut;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Category data is unavailable. Try again later.'**
  String get validationCategoryDataIsUnavailableTryAgainLater;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Category requirements are unavailable. Try again later.'**
  String get validationCategoryRequirementsAreUnavailableTryAgainLater;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the access caution.'**
  String get validationCheckTheAccessCaution;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the amount.'**
  String get validationCheckTheAmount;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the best time.'**
  String get validationCheckTheBestTime;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the category criteria.'**
  String get validationCheckTheCategoryCriteria;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the contribution.'**
  String get validationCheckTheContribution;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the description length.'**
  String get validationCheckTheDescriptionLength;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the device clock and confirm the availability again.'**
  String get validationCheckTheDeviceClockAndConfirmThe;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the duration range.'**
  String get validationCheckTheDurationRange;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the email address.'**
  String get validationCheckTheEmailAddress;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the gallery images.'**
  String get validationCheckTheGalleryImages;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the group size.'**
  String get validationCheckTheGroupSize;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the linked Place.'**
  String get validationCheckTheLinkedPlace;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the opening times.'**
  String get validationCheckTheOpeningTimes;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the short description length.'**
  String get validationCheckTheShortDescriptionLength;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Check the title length.'**
  String get validationCheckTheTitleLength;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a cancellation policy.'**
  String get validationChooseACancellationPolicy;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a category.'**
  String get validationChooseACategory;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a contribution kind.'**
  String get validationChooseAContributionKind;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a kind for this contribution.'**
  String get validationChooseAKindForThisContribution;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a season.'**
  String get validationChooseASeason;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a subcategory available for Activity.'**
  String get validationChooseASubcategoryAvailableForActivity;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a subcategory available for places.'**
  String get validationChooseASubcategoryAvailableForPlaces;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a subcategory from the category list.'**
  String get validationChooseASubcategoryFromTheCategoryList;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a subcategory.'**
  String get validationChooseASubcategory;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose a time of day.'**
  String get validationChooseATimeOfDay;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose an opening-hours mode.'**
  String get validationChooseAnOpeningHoursMode;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose how the opening hours work.'**
  String get validationChooseHowTheOpeningHoursWork;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose the text language.'**
  String get validationChooseTheTextLanguage;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose what kind of place it is.'**
  String get validationChooseWhatKindOfPlaceItIs;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose whether entry is free or paid.'**
  String get validationChooseWhetherEntryIsFreeOrPaid;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Choose your relationship to this place.'**
  String get validationChooseYourRelationshipToThisPlace;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Complete this category criterion.'**
  String get validationCompleteThisCategoryCriterion;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Confirm the availability again; it is older than a week.'**
  String get validationConfirmTheAvailabilityAgainItIsOlder;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Confirm the category.'**
  String get validationConfirmTheCategory;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Confirm the map pin.'**
  String get validationConfirmTheMapPin;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Confirm the rental statements.'**
  String get validationConfirmTheRentalStatements;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Confirm when the items are available.'**
  String get validationConfirmWhenTheItemsAreAvailable;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Describe how to get there.'**
  String get validationDescribeHowToGetThere;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Describe the damage policy.'**
  String get validationDescribeTheDamagePolicy;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Describe the handover.'**
  String get validationDescribeTheHandover;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Describe the informal access.'**
  String get validationDescribeTheInformalAccess;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Describe the optional contribution.'**
  String get validationDescribeTheOptionalContribution;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Do not write the title in capitals.'**
  String get validationDoNotWriteTheTitleInCapitals;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Keep contacts out of the title.'**
  String get validationKeepContactsOutOfTheTitle;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Linked Place is unavailable for publication.'**
  String get validationLinkedPlaceIsUnavailableForPublication;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Make at least one item available.'**
  String get validationMakeAtLeastOneItemAvailable;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Minimum must not exceed maximum.'**
  String get validationMinimumMustNotExceedMaximum;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Name the area.'**
  String get validationNameTheArea;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Name what you rent out.'**
  String get validationNameWhatYouRentOut;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Only saved, published places can be added.'**
  String get validationOnlySavedPublishedPlacesCanBeAdded;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Opening times overlap.'**
  String get validationOpeningTimesOverlap;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Places could not be checked. Try again later.'**
  String get validationPlacesCouldNotBeCheckedTryAgain;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicate images.'**
  String get validationRemoveDuplicateImages;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Remove some gallery images.'**
  String get validationRemoveSomeGalleryImages;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Remove some places.'**
  String get validationRemoveSomePlaces;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Remove the # part from the booking link.'**
  String get validationRemoveThePartFromTheBookingLink;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Review the guide again: it changed after the review.'**
  String get validationReviewTheGuideAgainItChangedAfter;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Review the guide before submitting.'**
  String get validationReviewTheGuideBeforeSubmitting;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Save the draft again before submitting.'**
  String get validationSaveTheDraftAgainBeforeSubmitting;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Save the places in the guide before submitting.'**
  String get validationSaveThePlacesInTheGuideBefore;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Seasonal hours are not supported yet.'**
  String get validationSeasonalHoursAreNotSupportedYet;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Set the location.'**
  String get validationSetTheLocation;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Set the map pin.'**
  String get validationSetTheMapPin;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Set the minimum renter age.'**
  String get validationSetTheMinimumRenterAge;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Set the typical duration.'**
  String get validationSetTheTypicalDuration;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Set valid coordinates.'**
  String get validationSetValidCoordinates;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Shorten a curator note to 300 characters.'**
  String get validationShortenACuratorNoteTo300Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Shorten the description.'**
  String get validationShortenTheDescription;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Show the approximate area at 500 m or coarser.'**
  String get validationShowTheApproximateAreaAt500M;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Some places changed status. Review the guide again.'**
  String get validationSomePlacesChangedStatusReviewTheGuide;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'The linked Place is no longer public. Remove or replace it.'**
  String get validationTheLinkedPlaceIsNoLongerPublic;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'The linked Place was not found. Remove or replace it.'**
  String get validationTheLinkedPlaceWasNotFoundRemove;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'The pin is outside the service area.'**
  String get validationThePinIsOutsideTheServiceArea;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'The rental rules changed. Confirm the statements again.'**
  String get validationTheRentalRulesChangedConfirmTheStatements;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'This category cannot be rented out here yet.'**
  String get validationThisCategoryCannotBeRentedOutHere;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'This category requires an ID at handover.'**
  String get validationThisCategoryRequiresAnIDAtHandover;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'This language is not supported here.'**
  String get validationThisLanguageIsNotSupportedHere;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use 10–140 characters.'**
  String get validationUse10140Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use 10–300 characters.'**
  String get validationUse10300Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use 20–180 characters.'**
  String get validationUse20180Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use 3–120 characters.'**
  String get validationUse3120Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use 5–80 characters.'**
  String get validationUse580Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use 7–15 digits; only + ( ) . - and spaces besides digits.'**
  String get validationUse715DigitsOnlyAndSpaces;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use a delivery radius up to 50 km.'**
  String get validationUseADeliveryRadiusUpTo50;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use a positive amount.'**
  String get validationUseAPositiveAmount;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use a secure https booking link.'**
  String get validationUseASecureHttpsBookingLink;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use a secure https link.'**
  String get validationUseASecureHttpsLink;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use at most 1000 characters.'**
  String get validationUseAtMost1000Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use at most 12 gallery images.'**
  String get validationUseAtMost12GalleryImages;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use at most 200 characters.'**
  String get validationUseAtMost200Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use at most 300 characters.'**
  String get validationUseAtMost300Characters;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use positive whole minutes.'**
  String get validationUsePositiveWholeMinutes;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use positive whole numbers.'**
  String get validationUsePositiveWholeNumbers;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Use the market currency.'**
  String get validationUseTheMarketCurrency;

  /// Create: server validation detail shown next to the field.
  ///
  /// In en, this message translates to:
  /// **'Your relationship to the place does not match how it was added.'**
  String get validationYourRelationshipToThePlaceDoesNot;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldLabelAddress;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get fieldLabelArea;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get fieldLabelAvailability;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Booking link'**
  String get fieldLabelBookingLink;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Cancellation policy'**
  String get fieldLabelCancellationPolicy;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldLabelCategory;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Category criteria'**
  String get fieldLabelCategoryCriteria;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get fieldLabelCoverImage;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldLabelCurrency;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Damage policy'**
  String get fieldLabelDamagePolicy;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get fieldLabelDeliveryFee;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Delivery radius'**
  String get fieldLabelDeliveryRadius;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldLabelDescription;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get fieldLabelDraft;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldLabelEmail;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get fieldLabelEntry;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Entry price'**
  String get fieldLabelEntryPrice;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get fieldLabelGallery;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Guide review'**
  String get fieldLabelGuideReview;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Handover'**
  String get fieldLabelHandover;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Handover address'**
  String get fieldLabelHandoverAddress;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Handover area'**
  String get fieldLabelHandoverArea;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'ID at handover'**
  String get fieldLabelIDAtHandover;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get fieldLabelItems;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Kind of place'**
  String get fieldLabelKindOfPlace;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get fieldLabelLocation;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Map pin'**
  String get fieldLabelMapPin;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Minimum age'**
  String get fieldLabelMinimumAge;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get fieldLabelOpeningHours;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldLabelPhone;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get fieldLabelPhotos;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Places in the guide'**
  String get fieldLabelPlacesInTheGuide;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Prices'**
  String get fieldLabelPrices;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Pricing note'**
  String get fieldLabelPricingNote;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Safety notice'**
  String get fieldLabelSafetyNotice;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get fieldLabelShortDescription;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Statements'**
  String get fieldLabelStatements;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get fieldLabelSubcategory;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get fieldLabelTerms;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Text language'**
  String get fieldLabelTextLanguage;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldLabelTitle;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get fieldLabelWebsite;

  /// Create: name of a form field in server requirements.
  ///
  /// In en, this message translates to:
  /// **'Your relationship'**
  String get fieldLabelYourRelationship;

  /// Create: header of the server requirements card.
  ///
  /// In en, this message translates to:
  /// **'Needed for server publication'**
  String get validationNeededForServer;

  /// Create: server refusal without a known field.
  ///
  /// In en, this message translates to:
  /// **'The server refused this draft. Check the draft and try again.'**
  String get validationGeneralRefusal;

  /// Create: one server requirement; both values are localized.
  ///
  /// In en, this message translates to:
  /// **'{field}: {message}'**
  String validationRequirementLine(String field, String message);

  /// Details: share link copied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get detailsLinkCopied;

  /// Details/Home: favorite saved.
  ///
  /// In en, this message translates to:
  /// **'Saved to favorites'**
  String get detailsSavedToFavorites;

  /// Event Details: calendar export failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the calendar export'**
  String get detailsCalendarExportFailed;

  /// Event Details: interest noted.
  ///
  /// In en, this message translates to:
  /// **'Interest in the event noted'**
  String get detailsInterestMarked;

  /// Details: an external link could not be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get detailsCouldNotOpenLink;

  /// Session Details: external booking site failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the booking site'**
  String get detailsBookingSiteFailed;

  /// Class/Workshop Details: external enrollment site failed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the enrollment site'**
  String get detailsEnrollmentSiteFailed;

  /// Details: report submitted; the reporter is not named anywhere.
  ///
  /// In en, this message translates to:
  /// **'Thank you. The report was sent for review.'**
  String get detailsReportSent;

  /// Details: report failed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Try again.'**
  String get detailsReportFailed;

  /// Details: legacy CTA request confirmation.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get detailsRequestSent;

  /// Details: Visit history needs the Place zone.
  ///
  /// In en, this message translates to:
  /// **'The place time zone is unavailable'**
  String get detailsPlaceTimezoneUnavailable;

  /// Details: Visit history date picker title.
  ///
  /// In en, this message translates to:
  /// **'When did you visit?'**
  String get detailsVisitWhen;

  /// Details: visit recorded; date is the chosen local calendar date, formatted.
  ///
  /// In en, this message translates to:
  /// **'Added to Visit history · {date}'**
  String detailsVisitAdded(String date);

  /// Details: visit not recorded.
  ///
  /// In en, this message translates to:
  /// **'Could not update Visit history'**
  String get detailsVisitFailed;

  /// Details: temporary load failure.
  ///
  /// In en, this message translates to:
  /// **'Details could not be loaded'**
  String get detailsLoadFailed;

  /// Details: object unavailable or not found; no reason is given.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get detailsUnavailable;

  /// Details: a newer Route revision exists.
  ///
  /// In en, this message translates to:
  /// **'The route was updated'**
  String get detailsRouteUpdated;

  /// Details: Route not available.
  ///
  /// In en, this message translates to:
  /// **'Route unavailable'**
  String get detailsRouteUnavailable;

  /// Details: Catalog transport unavailable.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get detailsNoConnection;

  /// Home card: free entry.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get homeFree;

  /// Home card: no fixed time.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get homeAnyTime;

  /// Home: saved search without a radius.
  ///
  /// In en, this message translates to:
  /// **'Any area'**
  String get homeAnyArea;

  /// Home: saved search radius, formatted number.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String homeRadiusKm(String km);

  /// Home card meta line; venue is the object's own name, shown verbatim.
  ///
  /// In en, this message translates to:
  /// **'{price} · {time} · {venue}'**
  String homeCardMeta(String price, String time, String venue);

  /// Home: saved route panel title.
  ///
  /// In en, this message translates to:
  /// **'Continue your route'**
  String get homeContinueRoute;

  /// Home: saved route chip.
  ///
  /// In en, this message translates to:
  /// **'Saved route'**
  String get homeSavedRoute;

  /// Home: saved search panel title.
  ///
  /// In en, this message translates to:
  /// **'Continue saved search'**
  String get homeContinueSavedSearch;

  /// Home: smart search panel title.
  ///
  /// In en, this message translates to:
  /// **'Continue smart search'**
  String get homeContinueSmartSearch;

  /// Home: smart route chip.
  ///
  /// In en, this message translates to:
  /// **'Smart route'**
  String get homeSmartRoute;

  /// Home: tooltip.
  ///
  /// In en, this message translates to:
  /// **'Create listing from saved search'**
  String get homeCreateFromSavedSearch;

  /// Home: tooltip.
  ///
  /// In en, this message translates to:
  /// **'Create listing from smart search'**
  String get homeCreateFromSmartSearch;

  /// Home: empty rail.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get homeNoActivities;

  /// Home: section action.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// Place Create final check; code is the stable local validation code (ValidatePlaceDraftUseCase).
  ///
  /// In en, this message translates to:
  /// **'{code, select, address_or_label_required{Add an address or a location label.} busy_time_notes_too_long{Shorten the busy-time notes.} category_required{Choose a category.} closure_end_invalid{The closure end must not be before its start.} closure_note_too_long{Shorten the closure note.} closure_start_required{Set when the closure starts.} contact_url_invalid{Use a valid https link.} contacts_missing{Add at least one contact.} country_required{Choose the country.} cover_required{Add a cover photo.} details_missing{The place details are missing.} email_invalid{Check the email address.} entrance_hint_too_long{Shorten the entrance hint.} entry_price_range_invalid{The minimum price must not exceed the maximum.} entry_price_required{Add the entry price.} entry_type_unknown{Choose whether entry is free or paid.} full_description_length{Shorten the description.} gallery_limit{Remove some gallery photos.} hours_exception_date_invalid{Check the special-day date.} hours_exception_overlap{Special-day hours overlap.} hours_exception_period_invalid{Check the special-day hours.} hours_exception_period_required{Add hours for the special day.} hours_exception_periods_not_allowed{A closed special day has no hours.} hours_exceptions_not_allowed{Special days are not used in this hours mode.} hours_mode_required{Choose how the opening hours work.} hours_overlap{Opening times overlap.} hours_period_invalid{Check the opening times.} hours_period_required{Add the weekly opening hours.} hours_periods_not_allowed{This hours mode has no weekly times.} hours_unknown{The opening hours are not known yet.} kind_required{Choose what kind of place it is.} locale_unsupported{This language is not supported here.} market_required{The place has no market yet.} minimum_visit_invalid{Check the minimum visit time.} minimum_visit_required{Set the minimum visit time.} mixed_pricing_note_required{Add a pricing note for mixed entry.} outside_market{The pin is outside the service area.} permission_denied{You cannot publish this place.} phone_invalid{Check the phone number.} pin_approximate{The map pin is approximate.} pin_invalid{Set valid coordinates.} pin_unconfirmed{Confirm the map pin.} price_negative{A price cannot be negative.} pricing_note_too_long{Shorten the pricing note.} pricing_url_invalid{Use a valid https price link.} publisher_invalid{Choose who publishes this place.} seasonal_not_supported{Seasonal hours are not supported yet.} short_description_length{Use 20–180 characters in the short description.} spend_range_invalid{The minimum spend must not exceed the maximum.} subcategory_required{Choose a subcategory.} timezone_required{The place has no time zone.} title_all_caps{Do not write the title in capitals.} title_contact{Keep contacts out of the title.} title_length{Use 3–120 characters in the title.} visit_buffer_invalid{Check the visit buffer.} visit_duration_invalid{Check the typical visit duration.} other{Check this part of the place.}}'**
  String placeValidationIssue(String code);

  /// Place Create section of a final check; section is the stable section id.
  ///
  /// In en, this message translates to:
  /// **'{section, select, identity{Basics} category{Category} location{Location} contacts{Contacts} hours{Opening hours} pricing{Prices} planning{Visit planning} media{Photos} other{Place}}'**
  String placeValidationSection(String section);

  /// Place Create: final checks header.
  ///
  /// In en, this message translates to:
  /// **'Final checks'**
  String get placeFinalChecks;

  /// Session Create check; code is the stable SessionBlockingCode/SessionWarningCode value.
  ///
  /// In en, this message translates to:
  /// **'{code, select, session_category_not_allowed{This category is not available for sessions.} session_resource_missing{Name what is booked and set its time zone.} session_timezone_invalid{Confirm the time zone.} session_schedule_empty{Add at least one time slot.} session_weekday_invalid{Check the weekdays.} session_range_invalid{Check the start and end times.} session_range_overlap{Time slots overlap.} session_duration_out_of_range{Check the session length.} session_buffer_out_of_range{Check the break between sessions.} session_notice_out_of_range{Check the booking notice.} session_projection_overflow{The schedule creates too many sessions. Shorten it.} session_exception_invalid{Check the exceptions.} session_party_size_out_of_range{Check the group size.} session_price_invalid{Check the price.} session_booking_url_invalid{Use a secure https booking link.} session_media_incomplete{Add the required photos.} session_publisher_ineligible{You cannot publish on behalf of this profile or page.} session_legacy_review_required{Review this older draft before publishing.} session_no_offers_in_window{No sessions fall into the coming weeks.} session_candidates_dropped_for_buffer{Some times were skipped to keep the breaks.} session_dst_slots_skipped{Some times were skipped at the clock change.} session_external_state_unknown{The booking site state could not be checked.} session_material_revision{This change will ask booked guests to confirm again.} session_category_criteria_incomplete{Complete the category criteria.} other{Check this part of the session.}}'**
  String sessionValidationIssue(String code);

  /// Session Create: blocking checks header.
  ///
  /// In en, this message translates to:
  /// **'Fix before publishing'**
  String get sessionFixBeforePublishing;

  /// Route Create check; code is a specific stable code or a code family chosen by the client.
  ///
  /// In en, this message translates to:
  /// **'{code, select, route_too_short{The route is too short.} route_too_long{The route is too long.} route_duration_too_long{The route takes too long.} loop_must_close{A loop must end where it starts.} one_way_must_not_close{A one-way route must not end where it starts.} out_and_back_must_return{An out-and-back route must return to the start.} anchors_too_few{Add more points to the route.} segments_missing{Build the route between the points.} manual_duration_reason_required{Explain why you changed the duration.} provider_license_disallows_publish{This map data cannot be published.} temporary_id_not_publishable{Save the route before publishing.} family_segment{A route segment needs attention.} family_waypoint{A point on the route needs attention.} family_anchor{Check the route points.} family_condition{Check the route conditions.} family_duration{Check the route duration.} family_data{The route data is out of date. Rebuild the route.} other{Check this part of the route.}}'**
  String routeValidationIssue(String code);

  /// Route Create check section; section is the stable section id.
  ///
  /// In en, this message translates to:
  /// **'{section, select, route{Route} geometry{Track} metrics{Distance and time} operations{Edits} profile{Profile} quality{Quality} relations{Points} sources{Sources} waypoints{Points of interest} conditions{Conditions} other{Route}}'**
  String routeValidationSection(String section);

  /// Route Create check line; both values are localized.
  ///
  /// In en, this message translates to:
  /// **'• {message} — {section}'**
  String routeIssueLine(String message, String section);

  /// Class/Workshop enrollment state; reason is the stable wire value.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, closed{Enrollment closed} on_site{Enroll on site} not_provided{No enrollment details} other{Enrollment information}}'**
  String classWorkshopEnrollmentReason(String reason);

  /// Scenario Create check; code is the stable ScenarioValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, schema_version_unsupported{Scenario schema version is unsupported}revision_negative{Revision cannot be negative}default_timezone_invalid{Choose a valid IANA timezone}display_currency_invalid{Display currency must use a three-letter ISO code}days_minimum{A Scenario must contain at least one calendar day}days_limit{A Scenario can contain at most 30 days}items_limit{A Scenario can contain at most 250 items}unscheduled_items_limit{Keep at most 50 unscheduled items}day_index_not_contiguous{Day indices must form a continuous 0-based sequence}day_item_duplicate{An item can appear only once in a day}item_scheduled_multiple_days{An item can belong to only one day}day_item_dangling{Day references a missing item}item_day_mismatch{Item dayId must match its day membership}unscheduled_item_duplicate{Unscheduled item ids must be unique}unscheduled_item_dangling{Unscheduled list references a missing item}unscheduled_item_has_day{An unscheduled item cannot belong to a day}item_missing_from_day{Scheduled item must appear in its day itemIds}item_orphaned{Item must be scheduled or explicitly unscheduled}active_items_limit{A Scenario can contain at most 200 active items}active_items_minimum{Add at least two active scheduled items}temporary_id_not_materialized{Temporary local ids must be replaced before saving}temporary_catalog_reference{Catalog references require permanent object ids}private_location_in_distribution{Private locations cannot enter a distributed payload}mandatory_item_unscheduled{Mandatory items must be scheduled}mandatory_source_unavailable{Replace or remove the unavailable mandatory item}start_requires_dated_mode{Starting a Scenario requires real dates}party_size_invalid{Party size must be between 1 and 100}children_count_invalid{Children count must fit the party size}budget_invalid{Budget must be non-negative and use an ISO currency}travel_modes_empty{Choose at least one allowed travel mode}primary_travel_mode_not_allowed{Primary travel mode must be allowed}vehicle_profile_invalid{Vehicle passenger seats must be valid}travel_limit_negative{Travel limits cannot be negative}day_id_missing{Day id is required}dated_day_date_missing{Dated Scenario days require a valid local date}dated_day_timezone_missing{Dated Scenario days require an IANA timezone}template_day_has_date{Template days must not store real dates}day_location_dangling{Day references a missing location}location_invalid{Location requires an id and valid coordinates}location_source_incomplete{Location source type and id must be set together}item_id_missing{Item id is required}item_day_dangling{Item references a missing day}item_location_dangling{Item references a missing location}item_duration_missing{Item requires a positive duration}mandatory_item_not_selected{Mandatory items are always selected}alternative_group_missing{Alternative items require a group id}alternative_group_unexpected{Only alternative items can belong to an alternative group}source_stale{Source snapshot is stale and should be refreshed}source_unresolved{Resolve the item source before distribution or start}planned_schedule_stale{Planned schedule is stale and must be rechecked}item_source_incompatible{Item kind and source are incompatible}schedule_date_mode_mismatch{Schedule representation must match Scenario date mode}template_day_range_invalid{Template day range is invalid}fixed_start_missing{Fixed dated items require a start instant}fixed_interval_invalid{Fixed end must be after fixed start}window_bounds_missing{Window schedule requires valid start and end times}window_order_invalid{Same-day window end must be after its start}window_day_offset_invalid{Window day offset can only be 0 or 1}cost_component_invalid{Cost component knowledge and amount are inconsistent}cost_confidence_invalid{Estimated price confidence must be between 0 and 1}cost_confidence_unexpected{Only estimated prices can have confidence}cost_basis_duplicate{Price basis cannot be duplicated in one component}cost_unknown{Item price is unknown}cost_basis_overlap{Per-person price overlaps adult or child pricing}alternative_limit{Use at most 20 alternative groups with 5 items each}alternative_multiple_selected{Only one alternative can be selected in a group}leg_reference_invalid{Leg contains a dangling or incomplete reference}leg_value_negative{Leg distance and duration cannot be negative}manual_logistics{Travel time was entered manually}schedule_snapshot_missing{Scheduled travel requires a plan snapshot}schedule_stale{Planned schedule is stale and must be rechecked}multi_day_format_disabled{Weekend and trip formats require the multi-day capability}multi_day_disabled{Multi-day data is present while the capability is disabled}item_capability_disabled{Active item uses a disabled Scenario capability}multi_currency_disabled{Foreign-currency costs require the multi-currency capability}day_id_duplicate{Identifiers must be unique}location_id_duplicate{Identifiers must be unique}item_id_duplicate{Identifiers must be unique}leg_id_duplicate{Identifiers must be unique}title_required{Give the Scenario a title}data_missing{Scenario data is missing} other{Check this part of the Scenario.}}'**
  String scenarioValidationIssue(String code);

  /// Find People Create check; code is the stable FindPeopleValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, details_missing{Find People details are missing}category_required{Choose a category}subcategory_required{Choose a subcategory}tags_limit{Use no more than 8 tags}languages_count{Choose 1–3 communication languages}language_invalid{Language codes must use BCP-47 format}house_rules_limit{Use no more than 10 house rules}public_contact_forbidden{Public text cannot contain contacts, payment links, or messenger handles}single_slot_count{Single schedule requires exactly one slot}poll_slot_count{Time poll requires at least two options}recurring_slots{Recurring schedule needs at least one materialized slot}recurrence_rule{Add a recurrence rule}recurrence_horizon{Recurring schedule must have a finite horizon}occurrence_limit{Occurrence count must be between 2 and 52}slot_duration{Each slot must last from 30 minutes to 24 hours}slot_overlap{Schedule options cannot overlap}poll_deadline{Poll deadline must be before the first option}application_deadline{Application deadline must be before the first meeting}scheduled_publish{Scheduled publish must be before the first meeting}meeting_name{Add a public meeting place}public_area{Add a safe public area label}public_geo{Add a valid approximate public map point}exact_geo{Add a valid exact meeting point}exact_address{Add the private exact address}public_place{Confirm that the meeting point is a public place}unsafe_location{Private homes and residential access details are not allowed}online_geo_forbidden{Online requests cannot publish fake map coordinates or an address}online_provider{Choose an online provider}online_secret{Add a private session-scoped access reference}offline_secret_forbidden{In-person requests cannot contain online access data}group_size{Group size must be between 2 and 20}host_seats{Host seats must be lower than total group size}party_disabled{Single-person applications must reserve exactly one seat}party_seats{Party applications can request 1–4 available seats}questions_limit{Use no more than 8 application questions}question_invalid{Every application question needs an ID and prompt}invite_visibility{Invite-only approval requires invite-only visibility}visibility_approval{Invite-only visibility requires invite-only approval}estimated_cost{Estimated cost requires a positive amount and currency}cost_amount_forbidden{Only estimated cost can contain an amount}expense_items{Itemized split requires planned expense items}expense_invalid{Every expense item needs an ID, category, and positive amount}publisher{Publisher is required}responsible_host{At least one responsible host is required}page_host{A page request needs a responsible host}cohost_grants{Co-host grants must use supported capabilities}quiet_hours{Quiet-hour minutes must be between 0 and 1439}safety_rules{Accept the Find People safety rules}accuracy{Confirm that the request details are accurate}adult_only{Confirm that this request is for adults 18+}publisher_host_mismatch{A personal request must include its owner as responsible host}title_length{Check the title length}shortDescription_length{Check the short description length}fullDescription_length{Check the full description length}equipmentNotes_length{Shorten the equipment notes}accessibilityNotes_length{Shorten the accessibility notes}houseRulesNote_length{Shorten the house rules note}meetingInstructions_length{Shorten the meeting instructions}costNote_length{Shorten the cost note} other{Check this part of the request.}}'**
  String findPeopleValidationIssue(String code);

  /// Find People: text length out of range; field is the stable field id.
  ///
  /// In en, this message translates to:
  /// **'{field, select, title{Title must contain {min}–{max, plural, one{{max} character} other{{max} characters}}}shortDescription{Short description must contain {min}–{max, plural, one{{max} character} other{{max} characters}}}fullDescription{Full description must contain {min}–{max, plural, one{{max} character} other{{max} characters}}} other{Use {min}–{max, plural, one{{max} character} other{{max} characters}}}}'**
  String findPeopleLengthIssue(String field, int min, int max);

  /// Find People: text longer than allowed; field is the stable field id.
  ///
  /// In en, this message translates to:
  /// **'{field, select, equipmentNotes{Equipment notes cannot exceed {max, plural, one{{max} character} other{{max} characters}}}accessibilityNotes{Accessibility notes cannot exceed {max, plural, one{{max} character} other{{max} characters}}}houseRulesNote{House rules note cannot exceed {max, plural, one{{max} character} other{{max} characters}}}meetingInstructions{Meeting instructions cannot exceed {max, plural, one{{max} character} other{{max} characters}}}costNote{Cost note cannot exceed {max, plural, one{{max} character} other{{max} characters}}} other{Use at most {max, plural, one{{max} character} other{{max} characters}}}}'**
  String findPeopleMaxLengthIssue(String field, int max);

  /// Event Create check; code is the stable EventValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, event_data_missing{Event details are unavailable. Reopen the draft.}event_schema_unsupported{This Event draft was created by a newer app version.}event_publisher_unsupported{This Event uses an unsupported publisher contract.}event_publisher_required{Choose who publishes this Event.}event_classification_unsupported{This Event uses a classification from a newer app version.}title_required{Add a title of at least 3 characters.}taxonomy_required{Choose a category and subcategory.}short_description_required{Add a short description of at least 10 characters.}cover_required{Add a cover image.}cover_alt_required{Describe the cover image for accessibility.}media_rights_required{Confirm that you may publish this media.}gallery_alt_required{Describe every gallery image for accessibility.}city_required{Choose the event city.}location_required{Add an address or a clear meeting point.}location_coordinates_required{Place a valid map pin for the physical location.}location_pin_unconfirmed{Confirm the physical location pin.}online_access_required{Choose how attendees receive online access.}public_online_url_invalid{Use a valid HTTPS online event URL.}online_access_registration_conflict{External online access requires external registration.}timezone_required{Choose an IANA timezone.}duration_invalid{Duration must be positive.}local_start_date_invalid{Use a valid local date in YYYY-MM-DD format.}start_minute_invalid{Choose a valid local start time.}all_day_duration_invalid{All-day duration must be a whole number of days.}multi_dates_required{Add at least one date.}multi_date_invalid{Every date must use the YYYY-MM-DD format.}recurrence_invalid{Configure a valid recurrence rule.}recurrence_weekday_invalid{Weekdays must be between 1 and 7.}recurrence_exception_invalid{Every excluded date must use the YYYY-MM-DD format.}recurrence_until_required{Choose the final local date.}recurrence_until_invalid{Use a valid final date in YYYY-MM-DD format.}recurrence_count_required{Occurrence count must be positive.}occurrences_required{The schedule must produce at least one occurrence.}future_occurrence_required{Add at least one future occurrence.}age_min_invalid{Minimum age cannot be negative.}age_max_invalid{Maximum age cannot be negative.}age_range_invalid{Maximum age must not be below minimum age.}free_price_conflict{Free events cannot collect a mandatory payment.}fixed_price_required{Enter a positive fixed price.}payment_mode_unavailable{Choose onsite or external payment for this slice.}pricing_capability_unavailable{Ticket types and donations require a later capability slice.}event_admission_unsupported{This Event uses a newer or unsupported admission contract.}event_inventory_unsupported{This Event uses a newer or unsupported inventory contract.}event_admission_required{Confirm the Event admission configuration.}event_inventory_authority_required{Confirm who, if anyone, owns Event inventory.}internal_registration_v1_unsupported{This configuration is outside local internal registration v1.}external_booking_url_invalid{Use a valid HTTPS registration URL.}internal_booking_unavailable{Internal Booking is not enabled in this slice.}private_access_unavailable{Private access requires a later protected-access slice.}event_access_contract_unsupported{This Event uses a newer access contract and cannot be changed here.}capacity_required{Enter a positive capacity.}capacity_mode_conflict{Unknown or unlimited capacity cannot store a numeric limit.}admission_axes_incomplete{Choose admission, registration and confirmation modes.}open_entry_axes_conflict{Open entry requires no registration and no confirmation.}interest_policy_not_non_reserving{Optional interest cannot create a booking or reserve inventory.}guest_capacity_bypass_unsupported{Guests must count against visitor capacity.}guest_limit_required{Plus-N guest policy requires a positive guest limit.}guest_limit_mode_conflict{Only Plus-N guest policy stores a custom guest limit.}eligibility_rule_id_invalid{Eligibility rules require unique stable IDs.}eligibility_policy_ref_invalid{Eligibility policy references cannot contain secret values.}eligibility_policy_not_ready{Eligibility policy reference is not available in this runtime.}external_registration_handoff_required{External registration requires a safe HTTPS handoff.}cancellation_deadline_required{Choose when cancellation closes before the start.}cancellation_deadline_invalid{Cancellation can close 0 to 10080 minutes before the start.}guest_policy_required{Choose a guest policy, including \"none\".}internal_registration_not_ready{Internal registration is configuration-only until ECL-03.}provider_confirmation_not_ready{Provider-managed confirmation requires a verified provider.}lottery_not_ready{Lottery requires an application window and auditable selector.}waitlist_not_ready{Active waitlist requires finite authoritative inventory lifecycle.}waitlist_offer_ttl_required{Automatic waitlist requires a positive offer TTL.}access_window_must_be_relative{Multi-date and recurring access windows must be occurrence-relative.}absolute_access_window_invalid{Absolute access must open before it closes and close before start.}access_window_kind_conflict{The access window type does not match its values.}relative_access_window_invalid{Relative opening offset must be greater than closing offset.}inventory_authority_none_conflict{No inventory authority cannot own shapes or pools.}inventory_primary_shape_required{Choose a primary inventory shape.}inventory_pools_required{Configured inventory authority requires at least one pool.}inventory_shape_duplicate{Primary shape cannot be repeated as an additional shape.}inventory_pool_id_invalid{Inventory pools require unique stable IDs.}inventory_pool_label_required{Every inventory pool needs a public label.}inventory_pool_shape_unconfigured{Every pool shape must be selected in the inventory configuration.}inventory_pool_capacity_required{Known inventory pool capacity must be positive.}inventory_pool_capacity_conflict{Unknown or unlimited pool cannot store numeric capacity.}inventory_pool_roles_required{Role-based pools require neutral role IDs.}inventory_pool_roles_invalid{Role IDs must be unique neutral identifiers.}inventory_pool_zone_required{Zone and table pools require a stable public reference.}inventory_provider_pool_ref_invalid{Provider pool references must be opaque identifiers.}inventory_pool_total_exceeds_event_capacity{Pool capacity exceeds Event capacity.}hybrid_onsite_pool_required{Finite physical capacity requires a bounded onsite pool.}assigned_seating_not_ready{Assigned seating requires an authoritative hold API.}recharge_inventory_not_ready{Recharge inventory is configuration-only until ECL-03.}external_inventory_not_ready{External inventory requires verified provider references and freshness.}event_archetype_required{Choose how this event is organized.}primary_participation_required{Choose the attendee\'s primary role.}additional_participation_limit{Choose no more than three additional attendee roles.}participation_mode_duplicate{The primary role cannot also be an additional role.}event_archetype_other_reason_required{Explain the event mechanics when choosing Other.}event_archetype_other_moderation_review{Other mechanics will be reviewed after submission.} other{Check this part of the Event.}}'**
  String eventValidationIssue(String code);

  /// Event admission preset needs a choice; field is the stable field id.
  ///
  /// In en, this message translates to:
  /// **'{field, select, admissionMode{Choose RSVP or booking before applying this preset.}confirmationMode{Choose how registration is confirmed before applying this preset.}registrationMode{Choose internal or external team registration.} other{Choose the admission settings before applying this preset.}}'**
  String eventAdmissionPresetIssue(String field);

  /// Collection Create check; code is the stable CollectionValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, details_missing{Collection details are missing}title_required{Add a title}area_required{Add an area or city}min_items{Add more items}duplicate_item{An item is added more than once}orphan_section{An item points to a section that does not exist}curator_note_length{Shorten the curator note}composition_review_missing{Review the live composition before publishing}composition_review_stale{Some unavailable items were not part of the last review}curator_note_empty{Say why this item is in the Collection}item_count_high{This Collection has many items — consider grouping them into sections or splitting it}self_publisher_share_high{Most items in this Collection are your own — consider adding independent picks too} other{Check this part of the Collection.}}'**
  String collectionValidationIssue(String code);

  /// Collection: too few items to publish.
  ///
  /// In en, this message translates to:
  /// **'Add at least {count, plural, one{{count} item} other{{count} items}}'**
  String collectionMinItemsIssue(int count);

  /// Collection: curator note longer than allowed.
  ///
  /// In en, this message translates to:
  /// **'Curator note cannot exceed {max, plural, one{{max} character} other{{max} characters}}'**
  String collectionCuratorNoteLengthIssue(int max);

  /// Collection warning: many items.
  ///
  /// In en, this message translates to:
  /// **'This Collection has {count, plural, one{{count} item} other{{count} items}} — consider grouping them into sections or splitting it'**
  String collectionItemCountHighIssue(int count);

  /// Class/Workshop Create check; code is the stable ClassWorkshopValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, offering_kind{Choose the offering kind}title{Add a title}short_description{Add a short description}full_description{Add a full description}media{Add a cover and confirm image rights}outcomes{Add an outcome}modules{Add a programme step}prerequisites{Choose prerequisites or \"No prerequisites\"}take_home_result{Describe the result participants take home}instructor{Add the instructor name and bio}instructor_bio{A masterclass needs the instructor bio}occurrences{Check the dates}timezone{Confirm the timezone}legacy_schedule{Clear the old schedule before publishing}location{Confirm the location}safe_area_label{Add the public area label}online_provider_label{Name the online provider}price{Add the amount and what it covers}enrollment{Add the external enrollment link} other{Check this part of the class.}}'**
  String classWorkshopValidationIssue(String code);

  /// Class/Workshop: wrong number of dates; kind is single or series.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, single{A single class has exactly one date}series{A series has at least two dates} other{Check the dates}}'**
  String classWorkshopOccurrencesIssue(String kind);

  /// Create availability check; code is the stable availability issue code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, buffers_negative{Buffers cannot be negative}minimum_visit_required{Minimum visit duration is required for partial attendance}slots_required{Add at least one schedule slot}slots_hours_conflict{Slots and opening hours cannot be combined}opening_hours_required{Add at least one opening-hours rule}availability_not_empty{Availability data must be empty when kind is none}slot_order_invalid{Slot end must be after start}opening_rule_target_invalid{Each rule needs either weekday or exception date}opening_weekday_invalid{Weekday must be from 1 to 7}opening_times_required{Open and close times are required} other{Check this field}}'**
  String createAvailabilityIssue(String code);

  /// Quick Plan → Scenario expansion note; code is the stable QuickPlanConversionIssueCode name.
  ///
  /// In en, this message translates to:
  /// **'{code, select, sourceNotFoundOrForbidden{Quick Plan is unavailable or cannot be copied}sourceRevisionMismatch{Quick Plan changed. Review it and try again}selectionEmpty{Select at least one stop to expand}stopUnavailable{A stop is unavailable and must be resolved in Scenario}privateNoteNotCopied{A private note was not copied}legacySourceIdentityMissing{A stop was copied as a private custom location because the old plan has no catalog object}stopNotFound{Selected stop no longer exists} other{Check this stop.}}'**
  String quickPlanConversionIssue(String code);

  /// Recharge Activity Create check; code is the stable ActivityValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, access_caution_note_length{Use at most 200 characters.}access_caution_note_required{Describe the informal access.}access_notes_length{Use 10–300 characters.}access_notes_required{Describe how to get there.}category_required{Choose a category.}contribution_amount_not_positive{Use a positive amount.}contribution_currency_unsupported{Use the market currency.}contribution_note_length{Use 10–140 characters.}contribution_note_required{Describe the optional contribution.}cover_image_required{Add a cover image.}duration_not_positive{Use positive whole minutes.}duration_range_invalid{Minimum must not exceed maximum.}full_description_length{Use at most 1000 characters.}group_size_not_positive{Use positive whole numbers.}group_size_range_invalid{Minimum must not exceed maximum.}location_coordinates_required{Set valid coordinates.}pin_confirmation_required{Confirm the map pin.}short_description_length{Use 20–180 characters.}subcategory_not_applicable{Choose a subcategory available for Activity.}title_length{Use 5–80 characters.}contribution_amount_needs_kind{Choose a kind for this contribution}criterion_required{Complete this category criterion}details_missing{Activity details are missing}duration_out_of_recommended_range{The duration is outside the usual range for this category}group_size_out_of_recommended_range{The group size is outside the usual range for this category}informal_access_notice{This place has informal access. Describe it carefully} other{Check this part of the activity.}}'**
  String activityValidationIssue(String code);

  /// Rental Create check; code is the stable RentalValidationIssue.code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, title_length{Use 3–80 characters for the title}short_description_length{Use 20–240 characters for the short description}full_description_length{Use 50–4000 characters for the full description}category_not_whitelisted{This category is not available for rentals}category_not_confirmed{Confirm the category}inventory_group_count{Add 1–50 groups of items}no_available_group{Mark at least one group as available}group_quantity_range{Quantity must be from 1 to 999}group_size_required{Add the size for this group}availability_timezone_missing{Choose the time zone}availability_coverage_missing{Say how availability is kept up to date}block_unknown_group{A blocked period refers to a group that does not exist}block_interval_invalid{A blocked period must end after it starts}pickup_place_name_missing{Add the pickup place name}public_geo_missing{Set the public map point}approximate_area_has_address{An approximate area must not contain an exact address}business_address_missing{Add the public business address}opening_hours_missing{Add the opening hours}delivery_radius_missing{Add the delivery radius}delivery_fee_missing{Add the delivery fee (zero if free)}duration_bounds_invalid{Check the minimum and maximum rental time}billing_unit_exceeds_min_duration{The billing unit cannot be longer than the minimum rental time}min_renter_age_required{Set the minimum renter age for this category}id_required_at_handover{This category requires an ID check at handover}safety_notice_required{Add a safety notice for this category}currency_invalid{Use a three-letter currency code}rate_steps_missing{Add the prices}rate_first_step_not_one{The first price step must start from one unit}rate_steps_not_increasing{Price steps must go up in units}rate_price_increases{A longer rental cannot cost more per unit}rate_step_currency_or_sign{Use one currency and positive prices}deposit_currency_mismatch{The deposit must use the price currency}deposit_zero_requires_none{A zero deposit cannot have a collection method}deposit_nonzero_requires_method{Choose how the deposit is collected}deposit_terms_missing{Add the deposit terms}damage_policy_missing{Add the damage policy}cancellation_policy_missing{Choose a cancellation policy}external_url_missing{Add the booking link}external_url_not_https{Use a secure https booking link}attestation_incomplete{Confirm all statements before publishing} other{Check this part of the rental.}}'**
  String rentalValidationIssue(String code);

  /// Create form notice; code is the stable CreateNotice code kept in CreateState.message.
  ///
  /// In en, this message translates to:
  /// **'{code, select, template_store_unavailable{Template storage is unavailable.}template_saved{Template saved.}template_renamed{Template renamed.}template_updated{Template updated.}template_deleted{Template deleted.}template_applied{Template applied.}template_invalid{This template is invalid.}template_action_failed{The template action could not be completed.}route_create_not_allowed{This account cannot create routes.}collection_create_not_allowed{This account cannot create collections.}scenario_preview_stale{Scenario changed. Generate a fresh preview.}scenario_preview_failed{Could not build this local demo preview. Try again.}scenario_title_required{Add a title before saving}scenario_blocking_issues{Resolve the blocking Scenario issues}scenario_unavailable{Scenario is no longer available.}scenario_open_failed{Could not open this Scenario.}scenario_public_publish_disabled{Public Scenario publishing is not enabled yet. Save it to My Scenarios.}classification_role_limit{You can choose up to three additional roles}classification_changed{Classification changed. Review the current draft.}admission_preview_stale{Admission configuration changed. Preview the preset again.}admission_legacy_review{An older admission suggestion must be reviewed again.}step_required_fields{Check the required fields of this step}required_fields{Check the required fields}place_helper_failed{The local helper could not review this draft. Manual creation still works.}place_suggestions_applied{Local suggestions applied. Review them before publishing.}place_helper_stale{The draft changed. Run the local review again.}route_editor_loading{The Route editor is still loading.}route_draft_saved{Route draft saved}route_segments_busy{Wait until the segment operations finish.}route_save_failed{Could not save the Route. The draft stays in the form.}draft_saved{Draft saved}draft_save_failed{Could not save. Your data stays in the form.}publisher_page_unavailable{Publishing as this page is unavailable: access was revoked or restricted. The draft is saved.}publisher_unavailable{Publishing is unavailable for this owner. The draft is saved.}place_duplicates_review{Review similar places before publishing}warnings_confirm{Confirm the warnings before publishing}submit_failed{Could not send. The draft is saved, try again.}published{Published}submitted_for_review{Sent for review}route_publication_unavailable{The Route publication service is unavailable.}route_not_published{The Route was not published. The draft is saved.}route_published{Route published.}route_submitted{Route sent for review.}route_action_forbidden{This Route action is not allowed.}route_not_ready{The Route is not ready yet. Check the highlighted parts.}route_submit_failed{Could not send the Route. The draft is saved.}route_queue_unavailable{The Route review queue is unavailable.}route_version_approved{Route version approved and active.}route_version_rejected{Route version rejected.}route_decision_forbidden{This decision is not allowed.}route_new_version_created{A new version was created. The published Route has not changed yet.}route_new_version_unavailable{A new version is unavailable.}route_not_found{Route not found.}route_withdrawn{Route withdrawn from publication. Version history is kept.}route_archive_forbidden{Archiving is not allowed.}route_command_refused{The Route action was refused.}transit_scenario_changed{Scenario changed. Review the selected service and try again.}transit_service_unsafe{The selected service cannot be applied safely.}transit_item_missing{The planned transport item no longer exists.}transit_only_official{Only an official schedule item can be replaced here.}transit_not_applied{The selected service was not applied.}rental_new_draft_from_listing{A new draft was created from this listing.}collection_publication_disabled{Collection publishing is temporarily turned off.}collection_publish_not_allowed{This account cannot publish collections.}collection_submitted{Collection sent for review.}collection_published{Collection published.}collection_published_sync_pending{Collection published, but Discover has not finished updating yet.}collection_not_published{The Collection was not published. The draft is saved.}collection_items_removed_sync_pending{Items removed, but Discover has not finished updating yet.}collection_archived_sync_pending{Collection archived, but Discover has not finished updating yet.}collection_rejection_reason_required{Rejecting a Collection requires a reason.}collection_accepted_sync_pending{Collection accepted, but Discover has not finished updating yet.}scenario_ai_proposal_added{AI proposal added to your Scenario.}scenario_generation_empty_prompt{Describe the plan you want to build.}scenario_generation_prompt_too_long{Keep the request under 500 characters.}scenario_generation_invalid_proposal{The local generator returned an invalid proposal.}event_access_contract_unsupported{This Event uses a newer access contract and cannot be changed here.}place_gallery_limit{The Place gallery is full.} other{Something went wrong. Please try again.}}'**
  String createNotice(String code);

  /// Create Place: gallery photo limit reached.
  ///
  /// In en, this message translates to:
  /// **'You can keep up to {count, plural, one{{count} photo} other{{count} photos}} in the Place gallery'**
  String createPlaceGalleryLimit(int count);

  /// Generic Create form field check; code is the stable field issue code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, title_required{Enter a title}category_required{Choose a category}city_required{Enter a city}cover_required{Add a cover image}start_required{Choose the start date and time} other{Check this field}}'**
  String createFieldIssue(String code);

  /// Event admission/inventory capability note; note is the stable EventAccessDisclosureNote name.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, localConfiguration{Local configuration only. No booking or inventory is reserved.}internalNotActive{Internal registration is not active until ECL-03.}internalLocalStand{Internal registration v1 is available only in the local testBackend stand: free, offline, instant confirmation. No booking is created by configuring this draft.}providerConfirmationNotConnected{Provider-managed confirmation is not connected.}waitlistConfigurationOnly{Waitlist is configuration-only; no queue is running.}capacityIsConfiguration{Capacity is configuration, not a live remaining balance.}externalInventoryUnverified{External inventory has no verified provider source.}assignedSeatingUnavailable{Assigned seating requires an authoritative hold API.} other{This option is configuration only.}}'**
  String eventAccessDisclosure(String kind);

  /// Scenario planned transport status; freshness is the stable ScenarioTransitDisclosureFreshness name. Planned/not-live wording follows Scenario spec v1.7.
  ///
  /// In en, this message translates to:
  /// **'{state, select, current{Feed snapshot was current when saved · not live}stale{Stale feed snapshot · recheck required}unknown{Feed freshness unknown · recheck required}unavailable{Provenance or feed unavailable · saved data retained}notApplicable{Entered manually · not verified} other{Provenance or feed unavailable · saved data retained}}'**
  String scenarioTransitStatus(String state);

  /// Scenario planned transport caution; warning is the stable ScenarioTransitWarning name. Never promise live data.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, manualNotVerified{Planned schedule · not live. Manual values are not verified against an operator timetable.}plannedNotLive{Planned schedule · not live.}freshnessCurrent{Current describes feed freshness when saved. It confirms neither service operation, delays nor punctuality.}freshnessStale{The saved feed snapshot is stale. Recheck the service before travel.}freshnessUnknown{Feed freshness is unknown. Do not treat the saved times as confirmed.}freshnessUnavailable{The saved item remains available, but its official provenance or feed cannot be verified.}manualNoFreshness{Manual values have no official feed freshness.}limitations{Fare, tickets, seats, availability, delays and cancellations are unknown. Recheck with the operator before travel.} other{Fare, tickets, seats, availability, delays and cancellations are unknown. Recheck with the operator before travel.}}'**
  String scenarioTransitWarning(String kind);

  /// Scenario: fallback title of a planned transport item without a service label.
  ///
  /// In en, this message translates to:
  /// **'Planned transport'**
  String get scenarioTransitPlannedTransport;

  /// Create form: "Hours not selected".
  ///
  /// In en, this message translates to:
  /// **'Hours not selected'**
  String get createFormHoursNotSelected;

  /// Create form: "Opening hours unknown".
  ///
  /// In en, this message translates to:
  /// **'Opening hours unknown'**
  String get createFormOpeningHoursUnknown;

  /// Create form: "Seasonal hours".
  ///
  /// In en, this message translates to:
  /// **'Seasonal hours'**
  String get createFormSeasonalHours;

  /// Create form: "Regular opening hours".
  ///
  /// In en, this message translates to:
  /// **'Regular opening hours'**
  String get createFormRegularOpeningHours;

  /// Create form: "Not selected".
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get createFormNotSelected;

  /// Create form: "No entry ticket concept".
  ///
  /// In en, this message translates to:
  /// **'No entry ticket concept'**
  String get createFormNoEntryTicketConcept;

  /// Create form: "Free and paid areas".
  ///
  /// In en, this message translates to:
  /// **'Free and paid areas'**
  String get createFormFreePaidAreas;

  /// Create form: "Paid entry".
  ///
  /// In en, this message translates to:
  /// **'Paid entry'**
  String get createFormPaidEntry;

  /// Create form: "Free entry".
  ///
  /// In en, this message translates to:
  /// **'Free entry'**
  String get createFormFreeEntry;

  /// Create form: "Local curator".
  ///
  /// In en, this message translates to:
  /// **'Local curator'**
  String get createFormLocalCurator;

  /// Create form: "Staff member".
  ///
  /// In en, this message translates to:
  /// **'Staff member'**
  String get createFormStaffMember;

  /// Create form: "Untitled place".
  ///
  /// In en, this message translates to:
  /// **'Untitled place'**
  String get createFormUntitledPlace;

  /// Create form: "Preview".
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get createFormPreview;

  /// Create form: "Review this Place".
  ///
  /// In en, this message translates to:
  /// **'Review this Place'**
  String get createFormReviewPlace;

  /// Create form: "Apply suggestions".
  ///
  /// In en, this message translates to:
  /// **'Apply suggestions'**
  String get createFormApplySuggestions;

  /// Create form: "Discard".
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get createFormDiscard;

  /// Place AI helper: number of recommended details still missing.
  ///
  /// In en, this message translates to:
  /// **'Could improve later: {count, plural, one{{count} detail} other{{count} details}}'**
  String createFormCouldImproveLaterProposalMissingrecommendedfieldidsJoin(
    int count,
  );

  /// Place AI helper: estimated visit length in minutes.
  ///
  /// In en, this message translates to:
  /// **'Estimated visit: {count} min'**
  String createFormEstimatedVisitMin(int count);

  /// Create form: "Editable description draft".
  ///
  /// In en, this message translates to:
  /// **'Editable description draft'**
  String get createFormEditableDescriptionDraft;

  /// Create form: "Suggested category".
  ///
  /// In en, this message translates to:
  /// **'Suggested category'**
  String get createFormSuggestedCategory;

  /// Create form: "Review this draft, suggest a taxonomy match and identify use".
  ///
  /// In en, this message translates to:
  /// **'Review this draft, suggest a taxonomy match and identify useful missing details. Nothing is published automatically.'**
  String get createFormReviewDraftSuggestTaxonomyMatchIdentify;

  /// Create form: "Local demo".
  ///
  /// In en, this message translates to:
  /// **'Local demo'**
  String get createFormLocalDemo;

  /// Create form: "Finish with AI".
  ///
  /// In en, this message translates to:
  /// **'Finish with AI'**
  String get createFormFinishWithAi;

  /// Create form: "Create a place".
  ///
  /// In en, this message translates to:
  /// **'Create a place'**
  String get createFormCreatePlace;

  /// Create form: "Save failed • retry available".
  ///
  /// In en, this message translates to:
  /// **'Save failed • retry available'**
  String get createFormSaveFailedRetryAvailable;

  /// Create form: "Unsaved changes".
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get createFormUnsavedChanges;

  /// Create form: "Send for review".
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get createFormSendReview;

  /// Create form: "Back".
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get createFormBack;

  /// Create form: "This is a different place".
  ///
  /// In en, this message translates to:
  /// **'This is a different place'**
  String get createFormDifferentPlace;

  /// Create form: "Could this place already exist?".
  ///
  /// In en, this message translates to:
  /// **'Could this place already exist?'**
  String get createFormCouldPlaceAlreadyExist;

  /// Create form: "Add".
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get createFormAdd;

  /// Create form: "Gallery image URL/path".
  ///
  /// In en, this message translates to:
  /// **'Gallery image URL/path'**
  String get createFormGalleryImageUrlPath;

  /// Create form: "Add gallery images".
  ///
  /// In en, this message translates to:
  /// **'Add gallery images'**
  String get createFormAddGalleryImages;

  /// Create form: "Cover image URL/path (recommended)".
  ///
  /// In en, this message translates to:
  /// **'Cover image URL/path (recommended)'**
  String get createFormCoverImageUrlPathRecommended;

  /// Create form: "Cover image URL/path *".
  ///
  /// In en, this message translates to:
  /// **'Cover image URL/path *'**
  String get createFormCoverImageUrlPath;

  /// Create form: "A cover is required. Gallery is optional.".
  ///
  /// In en, this message translates to:
  /// **'A cover is required. Gallery is optional.'**
  String get createFormCoverRequiredGalleryOptional;

  /// Create form: "Photos".
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get createFormPhotos;

  /// Create form: "Official booking landing page".
  ///
  /// In en, this message translates to:
  /// **'Official booking landing page'**
  String get createFormOfficialBookingLandingPage;

  /// Create form: "Public email".
  ///
  /// In en, this message translates to:
  /// **'Public email'**
  String get createFormPublicEmail;

  /// Create form: "Public phone".
  ///
  /// In en, this message translates to:
  /// **'Public phone'**
  String get createFormPublicPhone;

  /// Create form: "Official website".
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get createFormOfficialWebsite;

  /// Create form: "Add only official public details. HTTPS links are required.".
  ///
  /// In en, this message translates to:
  /// **'Add only official public details. HTTPS links are required.'**
  String get createFormAddOnlyOfficialPublicDetailsHttps;

  /// Create form: "Optional public contacts".
  ///
  /// In en, this message translates to:
  /// **'Optional public contacts'**
  String get createFormOptionalPublicContacts;

  /// Create form: "Official pricing URL (https)".
  ///
  /// In en, this message translates to:
  /// **'Official pricing URL (https)'**
  String get createFormOfficialPricingUrlHttps;

  /// Create form: "Pricing note".
  ///
  /// In en, this message translates to:
  /// **'Pricing note'**
  String get createFormPricingNote;

  /// Create form: "Pricing explanation *".
  ///
  /// In en, this message translates to:
  /// **'Pricing explanation *'**
  String get createFormPricingExplanation;

  /// Create form: "Typical spend to".
  ///
  /// In en, this message translates to:
  /// **'Typical spend to'**
  String get createFormTypicalSpend;

  /// Create form: "Typical spend from".
  ///
  /// In en, this message translates to:
  /// **'Typical spend from'**
  String get createFormTypicalSpendFrom;

  /// Place price: entry to, in the currency code value.
  ///
  /// In en, this message translates to:
  /// **'Entry to, {value}'**
  String createFormEntry(String value);

  /// Place price: entry from, in the currency code value.
  ///
  /// In en, this message translates to:
  /// **'Entry from, {value} *'**
  String createFormEntryFrom(String value);

  /// Create form: "Entry price and typical spend are separate concepts.".
  ///
  /// In en, this message translates to:
  /// **'Entry price and typical spend are separate concepts.'**
  String get createFormEntryPriceTypicalSpendAreSeparate;

  /// Create form: "Price".
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get createFormPrice;

  /// Create form: "Unset".
  ///
  /// In en, this message translates to:
  /// **'Unset'**
  String get createFormUnset;

  /// Create form: "Yes".
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get createFormYes;

  /// Create form: "Choose Yes or Unknown. Unset is never treated as No.".
  ///
  /// In en, this message translates to:
  /// **'Choose Yes or Unknown. Unset is never treated as No.'**
  String get createFormChooseYesUnknownUnsetNeverTreated;

  /// Create form: "Amenities".
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get createFormAmenities;

  /// Create form: "Exit buffer".
  ///
  /// In en, this message translates to:
  /// **'Exit buffer'**
  String get createFormExitBuffer;

  /// Create form: "Arrival buffer".
  ///
  /// In en, this message translates to:
  /// **'Arrival buffer'**
  String get createFormArrivalBuffer;

  /// Create form: "Weather dependent".
  ///
  /// In en, this message translates to:
  /// **'Weather dependent'**
  String get createFormWeatherDependent;

  /// Create form: "Minimum minutes".
  ///
  /// In en, this message translates to:
  /// **'Minimum minutes'**
  String get createFormMinimumMinutes;

  /// Create form: "Recommended minutes".
  ///
  /// In en, this message translates to:
  /// **'Recommended minutes'**
  String get createFormRecommendedMinutes;

  /// Create form: "These values improve time-fit without changing opening hours".
  ///
  /// In en, this message translates to:
  /// **'These values improve time-fit without changing opening hours.'**
  String get createFormTheseValuesImproveTimeFitWithout;

  /// Create form: "Help people plan the visit".
  ///
  /// In en, this message translates to:
  /// **'Help people plan the visit'**
  String get createFormHelpPeoplePlanVisit;

  /// Create form: "Add interval".
  ///
  /// In en, this message translates to:
  /// **'Add interval'**
  String get createFormAddInterval;

  /// Create form: "Closes next day".
  ///
  /// In en, this message translates to:
  /// **'Closes next day'**
  String get createFormClosesNextDay;

  /// Create form: "Close HH:mm".
  ///
  /// In en, this message translates to:
  /// **'Close HH:mm'**
  String get createFormCloseHhMm;

  /// Create form: "Open HH:mm".
  ///
  /// In en, this message translates to:
  /// **'Open HH:mm'**
  String get createFormOpenHhMm;

  /// Create form: "Day".
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get createFormDay;

  /// Create form: "Closed from *".
  ///
  /// In en, this message translates to:
  /// **'Closed from *'**
  String get createFormClosedFrom;

  /// Create form: "Current operational status".
  ///
  /// In en, this message translates to:
  /// **'Current operational status'**
  String get createFormCurrentOperationalStatus;

  /// Create form: "Add closed day".
  ///
  /// In en, this message translates to:
  /// **'Add closed day'**
  String get createFormAddClosedDay;

  /// Create form: "Custom hours".
  ///
  /// In en, this message translates to:
  /// **'Custom hours'**
  String get createFormCustomHours;

  /// Create form: "Closed all day".
  ///
  /// In en, this message translates to:
  /// **'Closed all day'**
  String get createFormClosedAllDay;

  /// Create form: "Date exceptions".
  ///
  /// In en, this message translates to:
  /// **'Date exceptions'**
  String get createFormDateExceptions;

  /// Create form: "Remove period".
  ///
  /// In en, this message translates to:
  /// **'Remove period'**
  String get createFormRemovePeriod;

  /// Create form: "Hours unknown".
  ///
  /// In en, this message translates to:
  /// **'Hours unknown'**
  String get createFormHoursUnknown;

  /// Create form: "Regular schedule".
  ///
  /// In en, this message translates to:
  /// **'Regular schedule'**
  String get createFormRegularSchedule;

  /// Create form: "Hours mode".
  ///
  /// In en, this message translates to:
  /// **'Hours mode'**
  String get createFormHoursMode2;

  /// Create form: "Hours mode *".
  ///
  /// In en, this message translates to:
  /// **'Hours mode *'**
  String get createFormHoursMode;

  /// Create form: "Unknown is better than invented hours.".
  ///
  /// In en, this message translates to:
  /// **'Unknown is better than invented hours.'**
  String get createFormUnknownBetterThanInventedHours;

  /// Create form: "When can people visit?".
  ///
  /// In en, this message translates to:
  /// **'When can people visit?'**
  String get createFormWhenCanPeopleVisit;

  /// Create form: "Add more visit information".
  ///
  /// In en, this message translates to:
  /// **'Add more visit information'**
  String get createFormAddMoreVisitInformation;

  /// Create form: "Add only information that is useful for this place.".
  ///
  /// In en, this message translates to:
  /// **'Add only information that is useful for this place.'**
  String get createFormAddOnlyInformationThatUsefulPlace;

  /// Create form: "Optional visit details".
  ///
  /// In en, this message translates to:
  /// **'Optional visit details'**
  String get createFormOptionalVisitDetails;

  /// Create form: "Add opening or access hours".
  ///
  /// In en, this message translates to:
  /// **'Add opening or access hours'**
  String get createFormAddOpeningAccessHours;

  /// Create form: "Add hours only when this place really has them.".
  ///
  /// In en, this message translates to:
  /// **'Add hours only when this place really has them.'**
  String get createFormAddHoursOnlyWhenPlaceReally;

  /// Create form: "Access restrictions".
  ///
  /// In en, this message translates to:
  /// **'Access restrictions'**
  String get createFormAccessRestrictions;

  /// Create form: "How to find this place".
  ///
  /// In en, this message translates to:
  /// **'How to find this place'**
  String get createFormHowFindPlace;

  /// Create form: "Add directions".
  ///
  /// In en, this message translates to:
  /// **'Add directions'**
  String get createFormAddDirections;

  /// Create form: "Required when there is no postal address.".
  ///
  /// In en, this message translates to:
  /// **'Required when there is no postal address.'**
  String get createFormRequiredWhenThereNoPostalAddress;

  /// Create form: "Location label".
  ///
  /// In en, this message translates to:
  /// **'Location label'**
  String get createFormLocationLabel;

  /// Create form: "Formatted address".
  ///
  /// In en, this message translates to:
  /// **'Formatted address'**
  String get createFormFormattedAddress;

  /// Create form: "Confirm this pin".
  ///
  /// In en, this message translates to:
  /// **'Confirm this pin'**
  String get createFormConfirmPin;

  /// Create form: "Pin confirmed".
  ///
  /// In en, this message translates to:
  /// **'Pin confirmed'**
  String get createFormPinConfirmed;

  /// Create form: "Tap the map and confirm the representative point.".
  ///
  /// In en, this message translates to:
  /// **'Tap the map and confirm the representative point.'**
  String get createFormTapMapConfirmRepresentativePoint;

  /// Create form: "Where is it?".
  ///
  /// In en, this message translates to:
  /// **'Where is it?'**
  String get createFormWhere;

  /// Create form: "Change".
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get createFormChange;

  /// Create form: "Cancel".
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createFormCancel;

  /// Create form: "Compatible category details will be kept. Fields that do not".
  ///
  /// In en, this message translates to:
  /// **'Compatible category details will be kept. Fields that do not belong to the new profile will be removed from publication.'**
  String get createFormCompatibleCategoryDetailsWillKeptFields;

  /// Create form: "Change category?".
  ///
  /// In en, this message translates to:
  /// **'Change category?'**
  String get createFormChangeCategory;

  /// Create form: "Category details".
  ///
  /// In en, this message translates to:
  /// **'Category details'**
  String get createFormCategoryDetails;

  /// Create form: "Content language".
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get createFormContentLanguage;

  /// Create form: "Public landmarks do not require an ownership claim.".
  ///
  /// In en, this message translates to:
  /// **'Public landmarks do not require an ownership claim.'**
  String get createFormPublicLandmarksDoNotRequireOwnership;

  /// Create form: "Community contribution".
  ///
  /// In en, this message translates to:
  /// **'Community contribution'**
  String get createFormCommunityContribution;

  /// Create form: "Your relationship".
  ///
  /// In en, this message translates to:
  /// **'Your relationship'**
  String get createFormYourRelationship;

  /// Create form: "Detailed description".
  ///
  /// In en, this message translates to:
  /// **'Detailed description'**
  String get createFormDetailedDescription;

  /// Create form: "Optional description, language and attribution".
  ///
  /// In en, this message translates to:
  /// **'Optional description, language and attribution'**
  String get createFormOptionalDescriptionLanguageAttribution;

  /// Create form: "More about this place".
  ///
  /// In en, this message translates to:
  /// **'More about this place'**
  String get createFormMoreAboutPlace;

  /// Create form: "You can add or improve this later.".
  ///
  /// In en, this message translates to:
  /// **'You can add or improve this later.'**
  String get createFormYouCanAddImproveLater;

  /// Create form: "Place name *".
  ///
  /// In en, this message translates to:
  /// **'Place name *'**
  String get createFormPlaceName;

  /// Create form: "Choose a category and the form keeps only relevant fields.".
  ///
  /// In en, this message translates to:
  /// **'Choose a category and the form keeps only relevant fields.'**
  String get createFormChooseCategoryFormKeepsOnlyRelevant;

  /// Create form: "What is this place?".
  ///
  /// In en, this message translates to:
  /// **'What is this place?'**
  String get createFormWhatPlace;

  /// Create form: "The create.place capability is required to edit or publish.".
  ///
  /// In en, this message translates to:
  /// **'You need permission to create places to edit or publish.'**
  String get createFormCreatePlaceCapabilityRequiredEditPublish;

  /// Create form: "Place data is being prepared…".
  ///
  /// In en, this message translates to:
  /// **'Place data is being prepared…'**
  String get createFormPlaceDataBeingPrepared;

  /// Create form: "Scenario route".
  ///
  /// In en, this message translates to:
  /// **'Scenario route'**
  String get createFormScenarioRoute;

  /// Create seed chip: number of stops.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} stop} other{{count} stops}}'**
  String createFormStops(int count);

  /// Create form: "Recharge idea".
  ///
  /// In en, this message translates to:
  /// **'Recharge idea'**
  String get createFormRechargeIdea;

  /// Create form: "Map route".
  ///
  /// In en, this message translates to:
  /// **'Map route'**
  String get createFormMapRoute;

  /// Create form: "Edit route".
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get createFormEditRoute;

  /// Create form: "Scenario route seed".
  ///
  /// In en, this message translates to:
  /// **'Scenario route seed'**
  String get createFormScenarioRouteSeed;

  /// Create seed card: where the draft was started; type is the stable seed source code.
  ///
  /// In en, this message translates to:
  /// **'{type, select, details{Seeded from details} saved_search{Seeded from saved search} search{Seeded from search conditions} smart_search{Seeded from smart search} profile{Seeded from profile workspace} scenario{Seeded from scenario route} map{Seeded from map area} other{Seeded from Recharge}}'**
  String createFormSeededFrom(String type);

  /// Create form: "No limit".
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get createFormNoLimit;

  /// Create form: "Capacity unknown".
  ///
  /// In en, this message translates to:
  /// **'Capacity unknown'**
  String get createFormCapacityUnknown;

  /// Create availability: buffer minutes before (start) and after (end) the visit.
  ///
  /// In en, this message translates to:
  /// **'Onsite buffers: {start} / {end} min'**
  String createFormOnsiteBuffersMin(int start, int end);

  /// Create form: "Allow partial attendance".
  ///
  /// In en, this message translates to:
  /// **'Allow partial attendance'**
  String get createFormAllowPartialAttendance;

  /// Create form: "Duration".
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get createFormDuration;

  /// Create form: "No opening hours yet".
  ///
  /// In en, this message translates to:
  /// **'No opening hours yet'**
  String get createFormNoOpeningHoursYet;

  /// Create form: "Add slot".
  ///
  /// In en, this message translates to:
  /// **'Add slot'**
  String get createFormAddSlot;

  /// Create form: "Schedule slots".
  ///
  /// In en, this message translates to:
  /// **'Schedule slots'**
  String get createFormScheduleSlots;

  /// Create form: "None".
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get createFormNone;

  /// Create form: "Hours".
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get createFormHours;

  /// Create form: "Schedule".
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get createFormSchedule;

  /// Create form: "No categories match this search.".
  ///
  /// In en, this message translates to:
  /// **'No categories match this search.'**
  String get createFormNoCategoriesMatchSearch;

  /// Create form: "Activity criteria".
  ///
  /// In en, this message translates to:
  /// **'Activity criteria'**
  String get createFormActivityCriteria;

  /// Create form: "Scenario taxonomy".
  ///
  /// In en, this message translates to:
  /// **'Scenario taxonomy'**
  String get createFormScenarioTaxonomy;

  /// Create form: "Convert to rental".
  ///
  /// In en, this message translates to:
  /// **'Convert to rental'**
  String get createFormConvertRental;

  /// Create form: "Keep session".
  ///
  /// In en, this message translates to:
  /// **'Keep session'**
  String get createFormKeepSession;

  /// Create form: "This legacy offer was migrated safely as a Bookable session.".
  ///
  /// In en, this message translates to:
  /// **'This legacy offer was migrated safely as a Bookable session. Choose Rental only if equipment or transport is being rented.'**
  String get createFormLegacyOfferWasMigratedSafelyAs;

  /// Create form: "Could this be a rental?".
  ///
  /// In en, this message translates to:
  /// **'Could this be a rental?'**
  String get createFormCouldRental;

  /// Create form: "Recharge Create".
  ///
  /// In en, this message translates to:
  /// **'Recharge Create'**
  String get createFormRechargeCreate;

  /// Create form: "Save draft".
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get createFormSaveDraft;

  /// Create form: "Cover image *".
  ///
  /// In en, this message translates to:
  /// **'Cover image *'**
  String get createFormCoverImage;

  /// Create form: "Full description".
  ///
  /// In en, this message translates to:
  /// **'Full description'**
  String get createFormFullDescription;

  /// Create form: "Short description".
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get createFormShortDescription;

  /// Create form: "Address".
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get createFormAddress;

  /// Create form: "Subcategory".
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get createFormSubcategory;

  /// Create form: "Main category *".
  ///
  /// In en, this message translates to:
  /// **'Main category *'**
  String get createFormMainCategory;

  /// Create form: "Not saved".
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get createFormNotSaved;

  /// Create form: "Требуется авторизация".
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get createFormText;

  /// Create form: "Submit for review".
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get createFormSubmitReview;

  /// Create form: "This is not a prohibited/unsafe item".
  ///
  /// In en, this message translates to:
  /// **'This is not a prohibited/unsafe item'**
  String get createFormNotProhibitedUnsafeItem;

  /// Create form: "This listing is accurate".
  ///
  /// In en, this message translates to:
  /// **'This listing is accurate'**
  String get createFormListingAccurate;

  /// Create form: "Public preview".
  ///
  /// In en, this message translates to:
  /// **'Public preview'**
  String get createFormPublicPreview;

  /// Create form: "You will leave Recharge and go to $host to check availabilit".
  ///
  /// In en, this message translates to:
  /// **'You will leave Recharge and go to an external site to check availability.'**
  String get createFormYouWillLeaveRechargeGoCheck;

  /// Create form: "External booking URL (https)".
  ///
  /// In en, this message translates to:
  /// **'External booking URL (https)'**
  String get createFormExternalBookingUrlHttps;

  /// Create form: "Late return policy".
  ///
  /// In en, this message translates to:
  /// **'Late return policy'**
  String get createFormLateReturnPolicy;

  /// Create form: "Damage policy".
  ///
  /// In en, this message translates to:
  /// **'Damage policy'**
  String get createFormDamagePolicy;

  /// Create form: "Deposit terms".
  ///
  /// In en, this message translates to:
  /// **'Deposit terms'**
  String get createFormDepositTerms;

  /// Create form: "Collection method".
  ///
  /// In en, this message translates to:
  /// **'Collection method'**
  String get createFormCollectionMethod;

  /// Create form: "Add rate step".
  ///
  /// In en, this message translates to:
  /// **'Add rate step'**
  String get createFormAddRateStep;

  /// Create form: "Billing unit".
  ///
  /// In en, this message translates to:
  /// **'Billing unit'**
  String get createFormBillingUnit;

  /// Create form: "Usage restrictions".
  ///
  /// In en, this message translates to:
  /// **'Usage restrictions'**
  String get createFormUsageRestrictions;

  /// Create form: "Safety notice".
  ///
  /// In en, this message translates to:
  /// **'Safety notice'**
  String get createFormSafetyNotice;

  /// Create form: "Minimum renter age".
  ///
  /// In en, this message translates to:
  /// **'Minimum renter age'**
  String get createFormMinimumRenterAge;

  /// Create form: "Max duration (min)".
  ///
  /// In en, this message translates to:
  /// **'Max duration (min)'**
  String get createFormMaxDurationMin;

  /// Create form: "Min duration (min)".
  ///
  /// In en, this message translates to:
  /// **'Min duration (min)'**
  String get createFormMinDurationMin;

  /// Create form: "Apply".
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get createFormApply;

  /// Create form: "Suggested defaults for this category".
  ///
  /// In en, this message translates to:
  /// **'Suggested defaults for this category'**
  String get createFormSuggestedDefaultsCategory;

  /// Create form: "Delivery fee (minor units)".
  ///
  /// In en, this message translates to:
  /// **'Delivery fee (minor units)'**
  String get createFormDeliveryFeeMinorUnits;

  /// Create form: "Delivery radius (km)".
  ///
  /// In en, this message translates to:
  /// **'Delivery radius (km)'**
  String get createFormDeliveryRadiusKm;

  /// Create form: "Offer delivery".
  ///
  /// In en, this message translates to:
  /// **'Offer delivery'**
  String get createFormOfferDelivery;

  /// Create form: "By arrangement".
  ///
  /// In en, this message translates to:
  /// **'By arrangement'**
  String get createFormByArrangement;

  /// Create form: "Opening hours".
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get createFormOpeningHours;

  /// Create form: "Pickup schedule".
  ///
  /// In en, this message translates to:
  /// **'Pickup schedule'**
  String get createFormPickupSchedule;

  /// Create form: "Public business address".
  ///
  /// In en, this message translates to:
  /// **'Public business address'**
  String get createFormPublicBusinessAddress;

  /// Create form: "Approximate area (default)".
  ///
  /// In en, this message translates to:
  /// **'Approximate area (default)'**
  String get createFormApproximateAreaDefault;

  /// Create form: "Location disclosure".
  ///
  /// In en, this message translates to:
  /// **'Location disclosure'**
  String get createFormLocationDisclosure;

  /// Create form: "Longitude".
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get createFormLongitude;

  /// Create form: "Latitude".
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get createFormLatitude;

  /// Create form: "Public area label".
  ///
  /// In en, this message translates to:
  /// **'Public area label'**
  String get createFormPublicAreaLabel;

  /// Create form: "Pickup place name".
  ///
  /// In en, this message translates to:
  /// **'Pickup place name'**
  String get createFormPickupPlaceName;

  /// Create form: "That would exceed the group capacity.".
  ///
  /// In en, this message translates to:
  /// **'That would exceed the group capacity.'**
  String get createFormThatWouldExceedGroupCapacity;

  /// Create form: "Block a date range".
  ///
  /// In en, this message translates to:
  /// **'Block a date range'**
  String get createFormBlockDateRange;

  /// Create form: "Confirm calendar".
  ///
  /// In en, this message translates to:
  /// **'Confirm calendar'**
  String get createFormConfirmCalendar;

  /// Create form: "Recharge cannot see external bookings — confirm this is up t".
  ///
  /// In en, this message translates to:
  /// **'Recharge cannot see external bookings — confirm this is up to date.'**
  String get createFormRechargeCannotSeeExternalBookingsConfirm;

  /// Create form: "Calendar not confirmed yet".
  ///
  /// In en, this message translates to:
  /// **'Calendar not confirmed yet'**
  String get createFormCalendarNotConfirmedYet;

  /// Create form: "Add another item type".
  ///
  /// In en, this message translates to:
  /// **'Add another item type'**
  String get createFormAddAnotherItemType;

  /// Create form: "Remove".
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get createFormRemove;

  /// Create form: "Duplicate".
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get createFormDuplicate;

  /// Create form: "Condition".
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get createFormCondition;

  /// Create form: "Quantity".
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get createFormQuantity;

  /// Create form: "Label".
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get createFormLabel;

  /// Create form: "Category".
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get createFormCategory;

  /// Create form: "Title".
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get createFormTitle;

  /// Create form: "Next".
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get createFormNext;

  /// Create form: "The create.rental capability is required to edit or publish.".
  ///
  /// In en, this message translates to:
  /// **'You need permission to create rentals to edit or publish.'**
  String get createFormCreateRentalCapabilityRequiredEditPublish;

  /// Create form: "Rental data is being prepared…".
  ///
  /// In en, this message translates to:
  /// **'Rental data is being prepared…'**
  String get createFormRentalDataBeingPrepared;

  /// Event gallery: remove image number count.
  ///
  /// In en, this message translates to:
  /// **'Remove gallery image {count}'**
  String createFormRemoveGalleryImage(int count);

  /// Event gallery: alt-text field label for image number count.
  ///
  /// In en, this message translates to:
  /// **'Gallery image {count} description *'**
  String createFormGalleryImageDescription(int count);

  /// Create form: "Add gallery image".
  ///
  /// In en, this message translates to:
  /// **'Add gallery image'**
  String get createFormAddGalleryImage;

  /// Create form: "Publishable on local/mock moderation pipeline".
  ///
  /// In en, this message translates to:
  /// **'Publishable on local/mock moderation pipeline'**
  String get createFormPublishableLocalMockModerationPipeline;

  /// Create form: "Untitled event".
  ///
  /// In en, this message translates to:
  /// **'Untitled event'**
  String get createFormUntitledEvent;

  /// Create form: "Visibility".
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get createFormVisibility;

  /// Create form: "External HTTPS registration URL".
  ///
  /// In en, this message translates to:
  /// **'External HTTPS registration URL'**
  String get createFormExternalHttpsRegistrationUrl;

  /// Create form: "Registration".
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get createFormRegistration;

  /// Create form: "Maximum participants".
  ///
  /// In en, this message translates to:
  /// **'Maximum participants'**
  String get createFormMaximumParticipants;

  /// Create form: "Capacity".
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get createFormCapacity;

  /// Create form: "Payment collection".
  ///
  /// In en, this message translates to:
  /// **'Payment collection'**
  String get createFormPaymentCollection;

  /// Create form: "Pricing".
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get createFormPricing;

  /// Create form: "Partial attendance allowed".
  ///
  /// In en, this message translates to:
  /// **'Partial attendance allowed'**
  String get createFormPartialAttendanceAllowed;

  /// Create form: "Pets allowed".
  ///
  /// In en, this message translates to:
  /// **'Pets allowed'**
  String get createFormPetsAllowed;

  /// Create form: "Kids allowed".
  ///
  /// In en, this message translates to:
  /// **'Kids allowed'**
  String get createFormKidsAllowed;

  /// Create form: "Family friendly".
  ///
  /// In en, this message translates to:
  /// **'Family friendly'**
  String get createFormFamilyFriendly;

  /// Create form: "Maximum age".
  ///
  /// In en, this message translates to:
  /// **'Maximum age'**
  String get createFormMaximumAge;

  /// Create form: "Minimum age".
  ///
  /// In en, this message translates to:
  /// **'Minimum age'**
  String get createFormMinimumAge;

  /// Create form: "What attendees should know or bring".
  ///
  /// In en, this message translates to:
  /// **'What attendees should know or bring'**
  String get createFormWhatAttendeesShouldKnowBring;

  /// Create form: "Excluded dates, comma-separated".
  ///
  /// In en, this message translates to:
  /// **'Excluded dates, comma-separated'**
  String get createFormExcludedDatesCommaSeparated;

  /// Create form: "Occurrence count".
  ///
  /// In en, this message translates to:
  /// **'Occurrence count'**
  String get createFormOccurrenceCount;

  /// Create form: "Until local date".
  ///
  /// In en, this message translates to:
  /// **'Until local date'**
  String get createFormUntilLocalDate;

  /// Create form: "Ends".
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get createFormEnds;

  /// Create form: "Every N periods".
  ///
  /// In en, this message translates to:
  /// **'Every N periods'**
  String get createFormEveryNPeriods;

  /// Create form: "Repeat".
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get createFormRepeat;

  /// Create form: "Dates separated by commas".
  ///
  /// In en, this message translates to:
  /// **'Dates separated by commas'**
  String get createFormDatesSeparatedByCommas;

  /// Create form: "Duration in minutes".
  ///
  /// In en, this message translates to:
  /// **'Duration in minutes'**
  String get createFormDurationMinutes;

  /// Create form: "Duration in minutes (1440 = 1 day)".
  ///
  /// In en, this message translates to:
  /// **'Duration in minutes (1440 = 1 day)'**
  String get createFormDurationMinutes14401Day;

  /// Create form: "Local start time (HH:mm)".
  ///
  /// In en, this message translates to:
  /// **'Local start time (HH:mm)'**
  String get createFormLocalStartTimeHhMm;

  /// Create form: "First local date (YYYY-MM-DD)".
  ///
  /// In en, this message translates to:
  /// **'First local date (YYYY-MM-DD)'**
  String get createFormFirstLocalDateYyyyMmDd;

  /// Create form: "Schedule mode".
  ///
  /// In en, this message translates to:
  /// **'Schedule mode'**
  String get createFormScheduleMode;

  /// Create form: "Public HTTPS event URL *".
  ///
  /// In en, this message translates to:
  /// **'Public HTTPS event URL *'**
  String get createFormPublicHttpsEventUrl;

  /// Create form: "Online access".
  ///
  /// In en, this message translates to:
  /// **'Online access'**
  String get createFormOnlineAccess;

  /// Create form: "Confirm this physical location pin *".
  ///
  /// In en, this message translates to:
  /// **'Confirm this physical location pin *'**
  String get createFormConfirmPhysicalLocationPin;

  /// Create form: "Meeting point instructions".
  ///
  /// In en, this message translates to:
  /// **'Meeting point instructions'**
  String get createFormMeetingPointInstructions;

  /// Create form: "Venue".
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get createFormVenue;

  /// Create form: "Format".
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get createFormFormat;

  /// Create form: "Cover description for screen readers *".
  ///
  /// In en, this message translates to:
  /// **'Cover description for screen readers *'**
  String get createFormCoverDescriptionScreenReaders;

  /// Create form: "Short description *".
  ///
  /// In en, this message translates to:
  /// **'Short description *'**
  String get createFormShortDescription2;

  /// Create form: "Event title *".
  ///
  /// In en, this message translates to:
  /// **'Event title *'**
  String get createFormEventTitle;

  /// Create form: "Event draft is unavailable. Reopen Create Hub.".
  ///
  /// In en, this message translates to:
  /// **'Event draft is unavailable. Reopen Create Hub.'**
  String get createFormEventDraftUnavailableReopenCreateHub;

  /// Create form: "Closes at UTC (ISO 8601)".
  ///
  /// In en, this message translates to:
  /// **'Closes at UTC (ISO 8601)'**
  String get createFormClosesAtUtcIso8601;

  /// Create form: "Opens at UTC (ISO 8601)".
  ///
  /// In en, this message translates to:
  /// **'Opens at UTC (ISO 8601)'**
  String get createFormOpensAtUtcIso8601;

  /// Create form: "Close minutes before occurrence".
  ///
  /// In en, this message translates to:
  /// **'Close minutes before occurrence'**
  String get createFormCloseMinutesBeforeOccurrence;

  /// Create form: "Open minutes before occurrence".
  ///
  /// In en, this message translates to:
  /// **'Open minutes before occurrence'**
  String get createFormOpenMinutesBeforeOccurrence;

  /// Create form: "Window type".
  ///
  /// In en, this message translates to:
  /// **'Window type'**
  String get createFormWindowType;

  /// Create form: "Enable window".
  ///
  /// In en, this message translates to:
  /// **'Enable window'**
  String get createFormEnableWindow;

  /// Create form: "Not configured".
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get createFormNotConfigured;

  /// Create form: "Remove eligibility rule".
  ///
  /// In en, this message translates to:
  /// **'Remove eligibility rule'**
  String get createFormRemoveEligibilityRule;

  /// Create form: "Public explanation (no secrets)".
  ///
  /// In en, this message translates to:
  /// **'Public explanation (no secrets)'**
  String get createFormPublicExplanationNoSecrets;

  /// Create form: "Add eligibility rule".
  ///
  /// In en, this message translates to:
  /// **'Add eligibility rule'**
  String get createFormAddEligibilityRule;

  /// Create form: "Rule kind".
  ///
  /// In en, this message translates to:
  /// **'Rule kind'**
  String get createFormRuleKind;

  /// Create form: "Never enter access codes, identities or private documents.".
  ///
  /// In en, this message translates to:
  /// **'Never enter access codes, identities or private documents.'**
  String get createFormNeverEnterAccessCodesIdentitiesPrivate;

  /// Create form: "Eligibility".
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get createFormEligibility;

  /// Create form: "Sales at the door".
  ///
  /// In en, this message translates to:
  /// **'Sales at the door'**
  String get createFormSalesAtDoor;

  /// Create form: "Registration at the door".
  ///
  /// In en, this message translates to:
  /// **'Registration at the door'**
  String get createFormRegistrationAtDoor;

  /// Create form: "Onsite admission allowed".
  ///
  /// In en, this message translates to:
  /// **'Onsite admission allowed'**
  String get createFormOnsiteAdmissionAllowed;

  /// Create form: "Does not book or reserve inventory".
  ///
  /// In en, this message translates to:
  /// **'Does not book or reserve inventory'**
  String get createFormDoesNotBookReserveInventory;

  /// Create form: "Maximum guests per registration *".
  ///
  /// In en, this message translates to:
  /// **'Maximum guests per registration *'**
  String get createFormMaximumGuestsPerRegistration;

  /// Create form: "Guest policy".
  ///
  /// In en, this message translates to:
  /// **'Guest policy'**
  String get createFormGuestPolicy;

  /// Create form: "Future promotion policy".
  ///
  /// In en, this message translates to:
  /// **'Future promotion policy'**
  String get createFormFuturePromotionPolicy;

  /// Create form: "Preview only — no queue or promotion runs".
  ///
  /// In en, this message translates to:
  /// **'Preview only — no queue or promotion runs'**
  String get createFormPreviewOnlyNoQueuePromotionRuns;

  /// Create form: "Configure waitlist".
  ///
  /// In en, this message translates to:
  /// **'Configure waitlist'**
  String get createFormConfigureWaitlist;

  /// Create form: "Application window".
  ///
  /// In en, this message translates to:
  /// **'Application window'**
  String get createFormApplicationWindow;

  /// Create form: "Cancellation closes N minutes before the start *".
  ///
  /// In en, this message translates to:
  /// **'Cancellation closes N minutes before the start *'**
  String get createFormCancellationClosesNMinutesBeforeStart;

  /// Create form: "Registration window".
  ///
  /// In en, this message translates to:
  /// **'Registration window'**
  String get createFormRegistrationWindow;

  /// Create form: "External HTTPS registration URL *".
  ///
  /// In en, this message translates to:
  /// **'External HTTPS registration URL *'**
  String get createFormExternalHttpsRegistrationUrl2;

  /// Create form: "Confirmation mode *".
  ///
  /// In en, this message translates to:
  /// **'Confirmation mode *'**
  String get createFormConfirmationMode;

  /// Create form: "Registration mode *".
  ///
  /// In en, this message translates to:
  /// **'Registration mode *'**
  String get createFormRegistrationMode;

  /// Create form: "Admission mode *".
  ///
  /// In en, this message translates to:
  /// **'Admission mode *'**
  String get createFormAdmissionMode;

  /// Create form: "Apply normalized fields".
  ///
  /// In en, this message translates to:
  /// **'Apply normalized fields'**
  String get createFormApplyNormalizedFields;

  /// Create form: "Configuration preset".
  ///
  /// In en, this message translates to:
  /// **'Configuration preset'**
  String get createFormConfigurationPreset;

  /// Create form: "Confirm suggestion".
  ///
  /// In en, this message translates to:
  /// **'Confirm suggestion'**
  String get createFormConfirmSuggestion;

  /// Create form: "Legacy registration is preserved, but admission and confirma".
  ///
  /// In en, this message translates to:
  /// **'Legacy registration is preserved, but admission and confirmation still require explicit choices.'**
  String get createFormLegacyRegistrationPreservedButAdmissionConfirmation;

  /// Create form: "Open entry with no registration or confirmation.".
  ///
  /// In en, this message translates to:
  /// **'Open entry with no registration or confirmation.'**
  String get createFormOpenEntryWithNoRegistrationConfirmation;

  /// Create form: "Legacy draft suggestion — not applied".
  ///
  /// In en, this message translates to:
  /// **'Legacy draft suggestion — not applied'**
  String get createFormLegacyDraftSuggestionNotApplied;

  /// Create form: "Admission, registration and confirmation are independent. Th".
  ///
  /// In en, this message translates to:
  /// **'Admission, registration and confirmation are independent. This local configuration does not create a booking.'**
  String get createFormAdmissionRegistrationConfirmationAreIndependentLocal;

  /// Create form: "Admission".
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get createFormAdmission;

  /// Create form: "Event admission configuration".
  ///
  /// In en, this message translates to:
  /// **'Event admission configuration'**
  String get createFormEventAdmissionConfiguration;

  /// Create form: "Save draft & return".
  ///
  /// In en, this message translates to:
  /// **'Save draft & return'**
  String get createFormSaveDraftReturn;

  /// Create form: "Preview and publish".
  ///
  /// In en, this message translates to:
  /// **'Preview and publish'**
  String get createFormPreviewPublish;

  /// Create form: "Suggest a group size".
  ///
  /// In en, this message translates to:
  /// **'Suggest a group size'**
  String get createFormSuggestGroupSize;

  /// Create form: "Typical duration, max (minutes)".
  ///
  /// In en, this message translates to:
  /// **'Typical duration, max (minutes)'**
  String get createFormTypicalDurationMaxMinutes;

  /// Create form: "Typical duration, min (minutes)".
  ///
  /// In en, this message translates to:
  /// **'Typical duration, min (minutes)'**
  String get createFormTypicalDurationMinMinutes;

  /// Create form: "Best season (optional)".
  ///
  /// In en, this message translates to:
  /// **'Best season (optional)'**
  String get createFormBestSeasonOptional;

  /// Create form: "Best time of day (optional)".
  ///
  /// In en, this message translates to:
  /// **'Best time of day (optional)'**
  String get createFormBestTimeDayOptional;

  /// Create form: "When is it best, and how long does it take?".
  ///
  /// In en, this message translates to:
  /// **'When is it best, and how long does it take?'**
  String get createFormWhenBestHowLongDoesTake;

  /// Create form: "Approximate amount (optional)".
  ///
  /// In en, this message translates to:
  /// **'Approximate amount (optional)'**
  String get createFormApproximateAmountOptional;

  /// Create form: "e.g. 'Coffee on the counter, optional'".
  ///
  /// In en, this message translates to:
  /// **'e.g. “Coffee on the counter, optional”'**
  String get createFormEGCoffeeCounterOptional;

  /// Create form: "Other".
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get createFormOther;

  /// Create form: "Donation".
  ///
  /// In en, this message translates to:
  /// **'Donation'**
  String get createFormDonation;

  /// Create form: "Contribution kind".
  ///
  /// In en, this message translates to:
  /// **'Contribution kind'**
  String get createFormContributionKind;

  /// Create form: "It is customary to leave something here".
  ///
  /// In en, this message translates to:
  /// **'It is customary to leave something here'**
  String get createFormCustomaryLeaveSomethingHere;

  /// Create form: "What to know before you go".
  ///
  /// In en, this message translates to:
  /// **'What to know before you go'**
  String get createFormWhatKnowBeforeYouGo;

  /// Create form: "This is not an official spot".
  ///
  /// In en, this message translates to:
  /// **'This is not an official spot'**
  String get createFormNotOfficialSpot;

  /// Create form: "Access notes".
  ///
  /// In en, this message translates to:
  /// **'Access notes'**
  String get createFormAccessNotes;

  /// Create form: "Address line (optional)".
  ///
  /// In en, this message translates to:
  /// **'Address line (optional)'**
  String get createFormAddressLineOptional;

  /// Create form: "Where is it, and how do I get there?".
  ///
  /// In en, this message translates to:
  /// **'Where is it, and how do I get there?'**
  String get createFormWhereHowDoIGetThere;

  /// Create form: "More Places".
  ///
  /// In en, this message translates to:
  /// **'More Places'**
  String get createFormMorePlaces;

  /// Create form: "No matching Places on this page.".
  ///
  /// In en, this message translates to:
  /// **'No matching Places on this page.'**
  String get createFormNoMatchingPlacesPage;

  /// Create form: "Search Places".
  ///
  /// In en, this message translates to:
  /// **'Search Places'**
  String get createFormSearchPlaces;

  /// Create form: "Search published Places".
  ///
  /// In en, this message translates to:
  /// **'Search published Places'**
  String get createFormSearchPublishedPlaces;

  /// Create form: "Linked Place is unavailable. Remove or replace the link.".
  ///
  /// In en, this message translates to:
  /// **'Linked Place is unavailable. Remove or replace the link.'**
  String get createFormLinkedPlaceUnavailableRemoveReplaceLink;

  /// Create form: "Remove linked Place".
  ///
  /// In en, this message translates to:
  /// **'Remove linked Place'**
  String get createFormRemoveLinkedPlace;

  /// Create form: "Selected Place: ${activity.location.linkedPlaceId}".
  ///
  /// In en, this message translates to:
  /// **'A Place is linked'**
  String get createFormSelectedPlace;

  /// Create form: "Linked Place (optional)".
  ///
  /// In en, this message translates to:
  /// **'Linked Place (optional)'**
  String get createFormLinkedPlaceOptional;

  /// Create form: "Cover image URL".
  ///
  /// In en, this message translates to:
  /// **'Cover image URL'**
  String get createFormCoverImageUrl;

  /// Create form: "Full description (optional)".
  ///
  /// In en, this message translates to:
  /// **'Full description (optional)'**
  String get createFormFullDescriptionOptional;

  /// Create form: "About this activity".
  ///
  /// In en, this message translates to:
  /// **'About this activity'**
  String get createFormAboutActivity;

  /// Create form: "Check the Activity fields and submit again.".
  ///
  /// In en, this message translates to:
  /// **'Check the Activity fields and submit again.'**
  String get createFormCheckActivityFieldsSubmitAgain;

  /// Create form: "Editing draft only. The published version stays unchanged un".
  ///
  /// In en, this message translates to:
  /// **'Editing draft only. The published version stays unchanged until review and publication.'**
  String get createFormEditingDraftOnlyPublishedVersionStays;

  /// Create form: "Loading Recharge Activity draft…".
  ///
  /// In en, this message translates to:
  /// **'Loading Recharge Activity draft…'**
  String get createFormLoadingRechargeActivityDraft;

  /// Create form: "Published route".
  ///
  /// In en, this message translates to:
  /// **'Published route'**
  String get createFormPublishedRoute;

  /// Create form: "Draft summary is unavailable in this session.".
  ///
  /// In en, this message translates to:
  /// **'Draft summary is unavailable in this session.'**
  String get createFormDraftSummaryUnavailableSession;

  /// Create form: "Map area".
  ///
  /// In en, this message translates to:
  /// **'Map area'**
  String get createFormMapArea;

  /// Create form: "Search similar".
  ///
  /// In en, this message translates to:
  /// **'Search similar'**
  String get createFormSearchSimilar;

  /// Create form: "Profile".
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get createFormProfile;

  /// Create form: "Home".
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get createFormHome;

  /// Create form: "Next steps".
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get createFormNextSteps;

  /// Create form: "Route map".
  ///
  /// In en, this message translates to:
  /// **'Route map'**
  String get createFormRouteMap;

  /// Create form: "Walking".
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get createFormWalking;

  /// Create form: "Free".
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get createFormFree;

  /// Create form: "Archive".
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get createFormArchive;

  /// Create form: "Create new version".
  ///
  /// In en, this message translates to:
  /// **'Create new version'**
  String get createFormCreateNewVersion;

  /// Create form: "Review request".
  ///
  /// In en, this message translates to:
  /// **'Review request'**
  String get createFormReviewRequest;

  /// Create form: "Geometry hash".
  ///
  /// In en, this message translates to:
  /// **'Geometry hash'**
  String get createFormGeometryHash;

  /// Create form: "Version ID".
  ///
  /// In en, this message translates to:
  /// **'Version ID'**
  String get createFormVersionId;

  /// Create form: "Route ID".
  ///
  /// In en, this message translates to:
  /// **'Route ID'**
  String get createFormRouteId;

  /// Create form: "Immutable version awaiting approval".
  ///
  /// In en, this message translates to:
  /// **'Immutable version awaiting approval'**
  String get createFormImmutableVersionAwaitingApproval;

  /// Create form: "Active immutable Route version".
  ///
  /// In en, this message translates to:
  /// **'Active immutable Route version'**
  String get createFormActiveImmutableRouteVersion;

  /// Create form: "Your publish action was handled. Create another listing or r".
  ///
  /// In en, this message translates to:
  /// **'Your publish action was handled. Create another listing or return to Home.'**
  String get createFormYourPublishActionWasHandledCreate;

  /// Create form: "Sent to moderation".
  ///
  /// In en, this message translates to:
  /// **'Sent to moderation'**
  String get createFormSentModeration;

  /// Create form: "Publish processed".
  ///
  /// In en, this message translates to:
  /// **'Publish processed'**
  String get createFormPublishProcessed;

  /// Create form: "Route published".
  ///
  /// In en, this message translates to:
  /// **'Route published'**
  String get createFormRoutePublished;

  /// Create form: "Create another".
  ///
  /// In en, this message translates to:
  /// **'Create another'**
  String get createFormCreateAnother;

  /// Create form: "Create another Event".
  ///
  /// In en, this message translates to:
  /// **'Create another Event'**
  String get createFormCreateAnotherEvent;

  /// Create form: "Create another from ${controller.lastEventTemplate!.name}".
  ///
  /// In en, this message translates to:
  /// **'Create another from the last template'**
  String get createFormCreateAnotherFrom;

  /// Create form: "Open Route moderation queue".
  ///
  /// In en, this message translates to:
  /// **'Open Route moderation queue'**
  String get createFormOpenRouteModerationQueue;

  /// Create form: "Publish status".
  ///
  /// In en, this message translates to:
  /// **'Publish status'**
  String get createFormPublishStatus;

  /// Create form: "Could not remove: $error".
  ///
  /// In en, this message translates to:
  /// **'Could not remove the item. Try again.'**
  String get createFormCouldNotRemove;

  /// Create form: "Remove without review".
  ///
  /// In en, this message translates to:
  /// **'Remove without review'**
  String get createFormRemoveWithoutReview;

  /// Create form: "Removing an item here applies instantly, no moderation round".
  ///
  /// In en, this message translates to:
  /// **'Removing an item here applies instantly, with no moderation round trip. Adding or editing text still needs a new reviewed version — use Publish above for that.'**
  String get createFormRemovingItemHereAppliesInstantlyNo;

  /// Create form: "Publish".
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createFormPublish;

  /// Create form: "Acknowledge composition".
  ///
  /// In en, this message translates to:
  /// **'Acknowledge composition'**
  String get createFormAcknowledgeComposition;

  /// Create form: "Composition reviewed".
  ///
  /// In en, this message translates to:
  /// **'Composition reviewed'**
  String get createFormCompositionReviewed;

  /// Create form: "Refresh live preview".
  ///
  /// In en, this message translates to:
  /// **'Refresh live preview'**
  String get createFormRefreshLivePreview;

  /// Create form: "Some items are no longer available — review before publishin".
  ///
  /// In en, this message translates to:
  /// **'Some items are no longer available — review before publishing.'**
  String get createFormSomeItemsAreNoLongerAvailable;

  /// Create form: "Not enough priced items yet to suggest a budget.".
  ///
  /// In en, this message translates to:
  /// **'Not enough priced items yet to suggest a budget.'**
  String get createFormNotEnoughPricedItemsYetSuggest;

  /// Create form: "Suggest from item prices".
  ///
  /// In en, this message translates to:
  /// **'Suggest from item prices'**
  String get createFormSuggestFromItemPrices;

  /// Create form: "Not set".
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get createFormNotSet;

  /// Create form: "Budget indicator".
  ///
  /// In en, this message translates to:
  /// **'Budget indicator'**
  String get createFormBudgetIndicator;

  /// Create form: "Curator notes".
  ///
  /// In en, this message translates to:
  /// **'Curator notes'**
  String get createFormCuratorNotes;

  /// Create form: "Items".
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get createFormItems;

  /// Create form: "One reference point for the whole guide — not an item locati".
  ///
  /// In en, this message translates to:
  /// **'One reference point for the whole guide — not an item location.'**
  String get createFormOneReferencePointWholeGuideNot;

  /// Create form: "Area anchor".
  ///
  /// In en, this message translates to:
  /// **'Area anchor'**
  String get createFormAreaAnchor;

  /// Create form: "Type to search, or tap the map below (§7 Шаг 1)".
  ///
  /// In en, this message translates to:
  /// **'Type to search, or tap the map below'**
  String get createFormTypeSearchTapMapBelow7;

  /// Create form: "Area or city".
  ///
  /// In en, this message translates to:
  /// **'Area or city'**
  String get createFormAreaCity;

  /// Create form: "Short pitch".
  ///
  /// In en, this message translates to:
  /// **'Short pitch'**
  String get createFormShortPitch;

  /// Create form: "Collection draft data is being prepared…".
  ///
  /// In en, this message translates to:
  /// **'Collection draft data is being prepared…'**
  String get createFormCollectionDraftDataBeingPrepared;

  /// Create form: "Collection draft is being prepared…".
  ///
  /// In en, this message translates to:
  /// **'Collection draft is being prepared…'**
  String get createFormCollectionDraftBeingPrepared;

  /// Create form: "Preparing Collection draft…".
  ///
  /// In en, this message translates to:
  /// **'Preparing Collection draft…'**
  String get createFormPreparingCollectionDraft;

  /// Create form: "Remove pool".
  ///
  /// In en, this message translates to:
  /// **'Remove pool'**
  String get createFormRemovePool;

  /// Create form: "Move pool down".
  ///
  /// In en, this message translates to:
  /// **'Move pool down'**
  String get createFormMovePoolDown;

  /// Create form: "Move pool up".
  ///
  /// In en, this message translates to:
  /// **'Move pool up'**
  String get createFormMovePoolUp;

  /// Create form: "Neutral role IDs, comma-separated".
  ///
  /// In en, this message translates to:
  /// **'Neutral role IDs, comma-separated'**
  String get createFormNeutralRoleIdsCommaSeparated;

  /// Create form: "Capacity mode".
  ///
  /// In en, this message translates to:
  /// **'Capacity mode'**
  String get createFormCapacityMode;

  /// Create form: "Channel".
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get createFormChannel;

  /// Create form: "Shape".
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get createFormShape;

  /// Create form: "Public pool label".
  ///
  /// In en, this message translates to:
  /// **'Public pool label'**
  String get createFormPublicPoolLabel;

  /// Create form: "Unnamed pool".
  ///
  /// In en, this message translates to:
  /// **'Unnamed pool'**
  String get createFormUnnamedPool;

  /// Create form: "Add pool".
  ///
  /// In en, this message translates to:
  /// **'Add pool'**
  String get createFormAddPool;

  /// Create form: "Pool capacity".
  ///
  /// In en, this message translates to:
  /// **'Pool capacity'**
  String get createFormPoolCapacity;

  /// Create form: "Additional views of the same inventory".
  ///
  /// In en, this message translates to:
  /// **'Additional views of the same inventory'**
  String get createFormAdditionalViewsSameInventory;

  /// Create form: "Primary inventory shape *".
  ///
  /// In en, this message translates to:
  /// **'Primary inventory shape *'**
  String get createFormPrimaryInventoryShape;

  /// Create form: "Inventory authority".
  ///
  /// In en, this message translates to:
  /// **'Inventory authority'**
  String get createFormInventoryAuthority;

  /// Create form: "Maximum participants *".
  ///
  /// In en, this message translates to:
  /// **'Maximum participants *'**
  String get createFormMaximumParticipants2;

  /// Create form: "Event capacity".
  ///
  /// In en, this message translates to:
  /// **'Event capacity'**
  String get createFormEventCapacity;

  /// Create form: "Capacity is a declared limit. It is not a live participant c".
  ///
  /// In en, this message translates to:
  /// **'Capacity is a declared limit. It is not a live participant count or transactional inventory balance.'**
  String get createFormCapacityDeclaredLimitNotLiveParticipant;

  /// Create form: "Event inventory configuration".
  ///
  /// In en, this message translates to:
  /// **'Event inventory configuration'**
  String get createFormEventInventoryConfiguration;

  /// Create form: "Confirm".
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get createFormConfirm;

  /// Create form: "Save".
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get createFormSave;

  /// Create form: "Template name".
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get createFormTemplateName;

  /// Create form: "Active drafts and published Events will not be affected.".
  ///
  /// In en, this message translates to:
  /// **'Active drafts and published Events will not be affected.'**
  String get createFormActiveDraftsPublishedEventsWillNot;

  /// Create form: "Delete template?".
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get createFormDeleteTemplate;

  /// Create form: "The reusable content will be replaced with the current Event".
  ///
  /// In en, this message translates to:
  /// **'The reusable content will be replaced with the current Event.'**
  String get createFormReusableContentWillReplacedWithCurrent;

  /// Create form: "Replace template?".
  ///
  /// In en, this message translates to:
  /// **'Replace template?'**
  String get createFormReplaceTemplate;

  /// Create form: "Rename template".
  ///
  /// In en, this message translates to:
  /// **'Rename template'**
  String get createFormRenameTemplate;

  /// Create form: "Delete".
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get createFormDelete;

  /// Create form: "Replace with current".
  ///
  /// In en, this message translates to:
  /// **'Replace with current'**
  String get createFormReplaceWithCurrent;

  /// Create form: "Rename".
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get createFormRename;

  /// Create form: "Template actions".
  ///
  /// In en, this message translates to:
  /// **'Template actions'**
  String get createFormTemplateActions;

  /// Create form: "Last template".
  ///
  /// In en, this message translates to:
  /// **'Last template'**
  String get createFormLastTemplate;

  /// Create form: "Untitled Event".
  ///
  /// In en, this message translates to:
  /// **'Untitled Event'**
  String get createFormUntitledEvent2;

  /// Create form: "No templates yet. Save the current Event to reuse it.".
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Save the current Event to reuse it.'**
  String get createFormNoTemplatesYetSaveCurrentEvent;

  /// Create form: "Your Event templates".
  ///
  /// In en, this message translates to:
  /// **'Your Event templates'**
  String get createFormYourEventTemplates;

  /// Create form: "Save Event template".
  ///
  /// In en, this message translates to:
  /// **'Save Event template'**
  String get createFormSaveEventTemplate;

  /// Create form: "Next “Create another Event” will use: ${template.name}".
  ///
  /// In en, this message translates to:
  /// **'Next “Create another Event” will use the selected template.'**
  String get createFormNextCreateAnotherEventWillUse;

  /// Create form: "Save current".
  ///
  /// In en, this message translates to:
  /// **'Save current'**
  String get createFormSaveCurrent;

  /// Create form: "Choose or manage".
  ///
  /// In en, this message translates to:
  /// **'Choose or manage'**
  String get createFormChooseManage;

  /// Create form: "Event templates".
  ///
  /// In en, this message translates to:
  /// **'Event templates'**
  String get createFormEventTemplates;

  /// Create form: "Clear classification".
  ///
  /// In en, this message translates to:
  /// **'Clear classification'**
  String get createFormClearClassification;

  /// Create form: "Additional roles (up to 3)".
  ///
  /// In en, this message translates to:
  /// **'Additional roles (up to 3)'**
  String get createFormAdditionalRolesUp3;

  /// Create form: "Primary attendee role *".
  ///
  /// In en, this message translates to:
  /// **'Primary attendee role *'**
  String get createFormPrimaryAttendeeRole;

  /// Create form: "Explain the event mechanics *".
  ///
  /// In en, this message translates to:
  /// **'Explain the event mechanics *'**
  String get createFormExplainEventMechanics;

  /// Create form: "Event mechanics *".
  ///
  /// In en, this message translates to:
  /// **'Event mechanics *'**
  String get createFormEventMechanics;

  /// Create form: "Use suggestion".
  ///
  /// In en, this message translates to:
  /// **'Use suggestion'**
  String get createFormUseSuggestion;

  /// Create form: "This is only a suggestion. Confirm it or choose another.".
  ///
  /// In en, this message translates to:
  /// **'This is only a suggestion. Confirm it or choose another.'**
  String get createFormOnlySuggestionConfirmChooseAnother;

  /// Create form: "Mechanics and attendee roles are independent from the catego".
  ///
  /// In en, this message translates to:
  /// **'Mechanics and attendee roles are independent from the category, format, access and price.'**
  String get createFormMechanicsAttendeeRolesAreIndependentFrom;

  /// Create form: "How does this event work?".
  ///
  /// In en, this message translates to:
  /// **'How does this event work?'**
  String get createFormHowDoesEventWork;

  /// Create form: "Event classification".
  ///
  /// In en, this message translates to:
  /// **'Event classification'**
  String get createFormEventClassification;

  /// Create form: "Section title".
  ///
  /// In en, this message translates to:
  /// **'Section title'**
  String get createFormSectionTitle;

  /// Create form: "New section".
  ///
  /// In en, this message translates to:
  /// **'New section'**
  String get createFormNewSection;

  /// Create form: "No longer available".
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get createFormNoLongerAvailable;

  /// Create form: "No items yet.".
  ///
  /// In en, this message translates to:
  /// **'No items yet.'**
  String get createFormNoItemsYet;

  /// Create form: "Remove section".
  ///
  /// In en, this message translates to:
  /// **'Remove section'**
  String get createFormRemoveSection;

  /// Collection items picker: header with the number of items.
  ///
  /// In en, this message translates to:
  /// **'In this Collection ({count})'**
  String createFormCollection(int count);

  /// Create form: "Results".
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get createFormResults;

  /// Create form: "Search".
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get createFormSearch;

  /// Create form: "Search Place, Route, Bookable Session, Class/Workshop, Renta".
  ///
  /// In en, this message translates to:
  /// **'Search Place, Route, Bookable Session, Class/Workshop, Rental'**
  String get createFormSearchPlaceRouteBookableSessionClass;

  /// Create form: "Choose a type to open its creation page.".
  ///
  /// In en, this message translates to:
  /// **'Choose a type to open its creation page.'**
  String get createFormChooseTypeOpenItsCreationPage;

  /// Create form: "What do you want to create?".
  ///
  /// In en, this message translates to:
  /// **'What do you want to create?'**
  String get createFormWhatDoYouWantCreate;

  /// Create form: "Create Hub".
  ///
  /// In en, this message translates to:
  /// **'Create Hub'**
  String get createFormCreateHub;

  /// Create form: "Refresh preview".
  ///
  /// In en, this message translates to:
  /// **'Refresh preview'**
  String get createFormRefreshPreview;

  /// Create form: "Checking local fixture…".
  ///
  /// In en, this message translates to:
  /// **'Checking local fixture…'**
  String get createFormCheckingLocalFixture;

  /// Create form: "Local mock preview — not live availability".
  ///
  /// In en, this message translates to:
  /// **'Local mock preview — not live availability'**
  String get createFormLocalMockPreviewNotLiveAvailability;

  /// Create form: "Local mock availability preview".
  ///
  /// In en, this message translates to:
  /// **'Local mock availability preview'**
  String get createFormLocalMockAvailabilityPreview;

  /// Create form: "Duplicate this listing".
  ///
  /// In en, this message translates to:
  /// **'Duplicate this listing'**
  String get createFormDuplicateListing;

  /// Create form: "Save current as template".
  ///
  /// In en, this message translates to:
  /// **'Save current as template'**
  String get createFormSaveCurrentAsTemplate;

  /// Create form: "Use".
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get createFormUse;

  /// Create form: "No saved templates yet.".
  ///
  /// In en, this message translates to:
  /// **'No saved templates yet.'**
  String get createFormNoSavedTemplatesYet;

  /// Create form: "Templates".
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get createFormTemplates;

  /// Create form: "Why is it here?".
  ///
  /// In en, this message translates to:
  /// **'Why is it here?'**
  String get createFormWhyHere;

  /// Create form: "Featured".
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get createFormFeatured;

  /// Create form: "Add items in the previous step first.".
  ///
  /// In en, this message translates to:
  /// **'Add items in the previous step first.'**
  String get createFormAddItemsPreviousStepFirst;

  /// Create seed chip: budget limit; price is the seed value as given.
  ///
  /// In en, this message translates to:
  /// **'up to {price}'**
  String createFormUpToPrice(String price);

  /// Create seed chip: search radius in kilometres.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String createFormDistanceKm(String km);

  /// Create seed chip: duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String createFormMinutes(int count);

  /// Place relationship: owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get createFormOwner;

  /// Place relationship: visitor.
  ///
  /// In en, this message translates to:
  /// **'Visitor'**
  String get createFormVisitor;

  /// Place entry type: unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get createFormUnknown;

  /// Place hours mode: always open.
  ///
  /// In en, this message translates to:
  /// **'Open 24/7'**
  String get createFormOpen247;

  /// Create place step "identity" title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get createStepPlaceIdentityTitle;

  /// Create place step "identity" description.
  ///
  /// In en, this message translates to:
  /// **'Name, category and only the details this place needs'**
  String get createStepPlaceIdentityDescription;

  /// Create place step "visit" title.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get createStepPlaceVisitTitle;

  /// Create place step "visit" description.
  ///
  /// In en, this message translates to:
  /// **'Confirmed map point and relevant visit information'**
  String get createStepPlaceVisitDescription;

  /// Create place step "publish" title.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createStepPlacePublishTitle;

  /// Create place step "publish" description.
  ///
  /// In en, this message translates to:
  /// **'Readiness, optional improvements and final checks'**
  String get createStepPlacePublishDescription;

  /// Create event step "basics_media" title.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get createStepEventBasicsMediaTitle;

  /// Create event step "basics_media" description.
  ///
  /// In en, this message translates to:
  /// **'Identity, category, description and media'**
  String get createStepEventBasicsMediaDescription;

  /// Create event step "location_schedule" title.
  ///
  /// In en, this message translates to:
  /// **'When & where'**
  String get createStepEventLocationScheduleTitle;

  /// Create event step "location_schedule" description.
  ///
  /// In en, this message translates to:
  /// **'Format, location, timezone and occurrences'**
  String get createStepEventLocationScheduleDescription;

  /// Create event step "requirements" title.
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get createStepEventRequirementsTitle;

  /// Create event step "requirements" description.
  ///
  /// In en, this message translates to:
  /// **'Audience, amenities and participation rules'**
  String get createStepEventRequirementsDescription;

  /// Create event step "price_participants" title.
  ///
  /// In en, this message translates to:
  /// **'Price & people'**
  String get createStepEventPriceParticipantsTitle;

  /// Create event step "price_participants" description.
  ///
  /// In en, this message translates to:
  /// **'Money, admission, capacity and inventory'**
  String get createStepEventPriceParticipantsDescription;

  /// Create event step "preview_publish" title.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createStepEventPreviewPublishTitle;

  /// Create event step "preview_publish" description.
  ///
  /// In en, this message translates to:
  /// **'Preview, readiness and moderation submission'**
  String get createStepEventPreviewPublishDescription;

  /// Create activity step "basics" title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get createStepActivityBasicsTitle;

  /// Create activity step "basics" description.
  ///
  /// In en, this message translates to:
  /// **'Title, category and media'**
  String get createStepActivityBasicsDescription;

  /// Create activity step "location" title.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get createStepActivityLocationTitle;

  /// Create activity step "location" description.
  ///
  /// In en, this message translates to:
  /// **'Where to go and how to get there'**
  String get createStepActivityLocationDescription;

  /// Create activity step "whenFor" title.
  ///
  /// In en, this message translates to:
  /// **'When & for whom'**
  String get createStepActivityWhenForTitle;

  /// Create activity step "whenFor" description.
  ///
  /// In en, this message translates to:
  /// **'Best time, duration and group size'**
  String get createStepActivityWhenForDescription;

  /// Create activity step "publish" title.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createStepActivityPublishTitle;

  /// Create activity step "publish" description.
  ///
  /// In en, this message translates to:
  /// **'Preview and send'**
  String get createStepActivityPublishDescription;

  /// Create collection step "basics" title.
  ///
  /// In en, this message translates to:
  /// **'Basics & media'**
  String get createStepCollectionBasicsTitle;

  /// Create collection step "basics" description.
  ///
  /// In en, this message translates to:
  /// **'Title, pitch, cover and area'**
  String get createStepCollectionBasicsDescription;

  /// Create collection step "items" title.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get createStepCollectionItemsTitle;

  /// Create collection step "items" description.
  ///
  /// In en, this message translates to:
  /// **'Search and add existing places, routes and more'**
  String get createStepCollectionItemsDescription;

  /// Create collection step "curatorNotes" title.
  ///
  /// In en, this message translates to:
  /// **'Curator notes'**
  String get createStepCollectionCuratorNotesTitle;

  /// Create collection step "curatorNotes" description.
  ///
  /// In en, this message translates to:
  /// **'Say why each item is here and pick your highlights'**
  String get createStepCollectionCuratorNotesDescription;

  /// Create collection step "budget" title.
  ///
  /// In en, this message translates to:
  /// **'Budget & publisher'**
  String get createStepCollectionBudgetTitle;

  /// Create collection step "budget" description.
  ///
  /// In en, this message translates to:
  /// **'Set a budget hint, publisher, market and visibility'**
  String get createStepCollectionBudgetDescription;

  /// Create collection step "publish" title.
  ///
  /// In en, this message translates to:
  /// **'Preview & publish'**
  String get createStepCollectionPublishTitle;

  /// Create collection step "publish" description.
  ///
  /// In en, this message translates to:
  /// **'Review the composition and send'**
  String get createStepCollectionPublishDescription;

  /// Create rental step "listing" title.
  ///
  /// In en, this message translates to:
  /// **'Listing and media'**
  String get createStepRentalListingTitle;

  /// Create rental step "listing" description.
  ///
  /// In en, this message translates to:
  /// **'Title, category and cover for the item or fleet'**
  String get createStepRentalListingDescription;

  /// Create rental step "inventory" title.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get createStepRentalInventoryTitle;

  /// Create rental step "inventory" description.
  ///
  /// In en, this message translates to:
  /// **'Groups of interchangeable units, condition and quantity'**
  String get createStepRentalInventoryDescription;

  /// Create rental step "availability" title.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get createStepRentalAvailabilityTitle;

  /// Create rental step "availability" description.
  ///
  /// In en, this message translates to:
  /// **'Confirmed coverage window and manual occupancy blocks'**
  String get createStepRentalAvailabilityDescription;

  /// Create rental step "handover" title.
  ///
  /// In en, this message translates to:
  /// **'Handover and location'**
  String get createStepRentalHandoverTitle;

  /// Create rental step "handover" description.
  ///
  /// In en, this message translates to:
  /// **'Pickup area, schedule and optional delivery'**
  String get createStepRentalHandoverDescription;

  /// Create rental step "terms" title.
  ///
  /// In en, this message translates to:
  /// **'Duration and safety'**
  String get createStepRentalTermsTitle;

  /// Create rental step "terms" description.
  ///
  /// In en, this message translates to:
  /// **'Offered duration range, age, ID and safety requirements'**
  String get createStepRentalTermsDescription;

  /// Create rental step "pricing" title.
  ///
  /// In en, this message translates to:
  /// **'Pricing and deposit'**
  String get createStepRentalPricingTitle;

  /// Create rental step "pricing" description.
  ///
  /// In en, this message translates to:
  /// **'Rate plan, deposit policy and damage/cancellation terms'**
  String get createStepRentalPricingDescription;

  /// Create rental step "fulfillment" title.
  ///
  /// In en, this message translates to:
  /// **'External fulfillment and policies'**
  String get createStepRentalFulfillmentTitle;

  /// Create rental step "fulfillment" description.
  ///
  /// In en, this message translates to:
  /// **'External booking link and destination warning preview'**
  String get createStepRentalFulfillmentDescription;

  /// Create rental step "review" title.
  ///
  /// In en, this message translates to:
  /// **'Review and submit'**
  String get createStepRentalReviewTitle;

  /// Create rental step "review" description.
  ///
  /// In en, this message translates to:
  /// **'Public/private preview, attestation and submission'**
  String get createStepRentalReviewDescription;

  /// Place creation profile name; type is the stable PlaceCreationProfileId name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, simplePoi{Simple point of interest}publicSpace{Public space}naturalDestination{Natural destination}culturalVenue{Cultural venue}hospitality{Food or hospitality venue}activityVenue{Activity or service venue}paidAttraction{Managed attraction}balanced{General place} other{General place}}'**
  String createPlacePolicyLabel(String type);

  /// Place creation profile explanation; type is the stable PlaceCreationProfileId name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, simplePoi{A landmark people can identify and visit without managed access.}publicSpace{An open public area with optional access restrictions.}naturalDestination{A natural point or area where access facts may be unknown.}culturalVenue{A managed museum, gallery, cinema or cultural venue.}hospitality{A managed venue where spend matters but admission does not.}activityVenue{A managed venue with optional booking, spend and facilities.}paidAttraction{A managed attraction that may have admission and facilities.}balanced{A safe fallback with no invented opening or pricing facts.} other{A safe fallback with no invented opening or pricing facts.}}'**
  String createPlacePolicyDescription(String type);

  /// Amenity name; value is the stable amenity id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, wheelchair_accessible{Wheelchair accessible}accessible_toilet{Accessible toilet}parking{Parking}bike_parking{Bike parking}public_transport_nearby{Public transport nearby}public_transport{Public transport nearby}family_friendly{Family friendly}baby_changing{Baby changing}pets_allowed{Pets allowed}toilet{Toilet}wifi{Wi-Fi}drinking_water{Drinking water}food_available{Food available}outdoor_seating{Outdoor seating}shelter{Weather shelter}weather_shelter{Weather shelter}first_aid{First aid}shower{Shower}towels{Towels provided}changing_room{Changing room}equipment_provided{Equipment provided} other{Amenity}}'**
  String createAmenityLabel(String value);

  /// Amenity group name; value is the stable group id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, accessibility{Accessibility}audience{Audience}facilities{Facilities}family{Family}food{Food}outdoor{Outdoor}pets{Pets}safety{Safety}transport{Transport}wellness{Wellness} other{Other}}'**
  String createAmenityGroup(String value);

  /// Create: the draft is saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get createFormSaved;

  /// Create: the draft is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get createFormSaving;

  /// Create form option label; option is "<EnumType>_<stable value>".
  ///
  /// In en, this message translates to:
  /// **'{value, select, EventCapacityMode_known{Known limit}EventCapacityMode_unknown{Unknown}EventCapacityMode_unlimited{Unlimited}EventFormat_offline{In person}EventFormat_online{Online}EventFormat_hybrid{Hybrid}EventOnlineAccessMode_publicLink{Public link}EventOnlineAccessMode_externalRegistration{External registration}EventOnlineAccessMode_internalBooking{Internal booking}EventPaymentCollectionMode_none{No payment}EventPaymentCollectionMode_onsite{On site}EventPaymentCollectionMode_external{External}EventPaymentCollectionMode_internal{In Recharge}EventPricingMode_free{Free}EventPricingMode_fixed{Fixed price}EventPricingMode_ticketTypes{Ticket types}EventPricingMode_donation{Donation}EventRecurrenceEndMode_never{Never}EventRecurrenceEndMode_untilDate{On a date}EventRecurrenceEndMode_occurrenceCount{After a number of times}EventRecurrenceFrequency_daily{Daily}EventRecurrenceFrequency_weekly{Weekly}EventRecurrenceFrequency_monthly{Monthly}EventRecurrenceFrequency_yearly{Yearly}EventRegistrationMode_none{No registration}EventRegistrationMode_external{External}EventRegistrationMode_internal{In Recharge}EventScheduleMode_oneTime{One time}EventScheduleMode_multiDate{Several dates}EventScheduleMode_recurring{Recurring}EventVisibility_public{Public}EventVisibility_unlisted{By link}EventVisibility_private{Private}EventAdmissionPreset_noRegistration{No registration}EventAdmissionPreset_freeRsvp{Free RSVP}EventAdmissionPreset_organizerApplication{Application to the organizer}EventAdmissionPreset_externalRegistration{External registration}EventAdmissionPreset_externalTickets{External tickets}EventAdmissionPreset_rechargeTickets{Recharge tickets}EventAdmissionPreset_teamRegistration{Team registration}AdmissionMode_openEntry{Open entry}AdmissionMode_rsvp{RSVP}AdmissionMode_booking{Booking}AdmissionMode_application{Application}AdmissionMode_ticket{Ticket}AdmissionMode_teamRegistration{Team registration}ConfirmationMode_none{No confirmation}ConfirmationMode_instant{Instant}ConfirmationMode_manualApproval{Manual approval}ConfirmationMode_lottery{Lottery}ConfirmationMode_providerManaged{By the provider}WaitlistPromotionMode_organizerManaged{By the organizer}WaitlistPromotionMode_fifoAutomatic{Automatic, first come}GuestPolicyMode_none{No guests}GuestPolicyMode_plusOne{Plus one}GuestPolicyMode_plusN{Plus N}GuestPolicyMode_namedGuestsOnly{Named guests only}EligibilityRuleKind_invitation{Invitation}EligibilityRuleKind_accessCode{Access code}EligibilityRuleKind_membership{Membership}EligibilityRuleKind_allowlist{Guest list}EligibilityRuleKind_qualification{Qualification}EligibilityRuleKind_accreditation{Accreditation}EligibilityRuleKind_ageRequirement{Age requirement}EligibilityRuleKind_waiver{Waiver}EventAccessWindowKind_absolute{Fixed dates}EventAccessWindowKind_occurrenceRelative{Relative to each date}InventoryShape_generalCapacity{General capacity}InventoryShape_sharedTicketPool{Shared ticket pool}InventoryShape_separateTicketPools{Separate ticket pools}InventoryShape_zones{Zones}InventoryShape_assignedSeating{Assigned seats}InventoryShape_teamSlots{Team slots}InventoryShape_participantRoles{Participant roles}InventoryShape_roleBalancedSlots{Role-balanced slots}InventoryShape_tableInventory{Tables}InventoryShape_timeSlotInventory{Time slots}InventoryChannel_onsite{On site}InventoryChannel_online{Online}InventoryChannel_any{Any}InventoryAuthority_none{Nobody}InventoryAuthority_recharge{Recharge}InventoryAuthority_externalProvider{External provider}ActivityContributionKind_purchase{Purchase}ActivityContributionKind_donation{Donation}ActivityContributionKind_other{Other}ActivitySeason_winter{Winter}ActivitySeason_spring{Spring}ActivitySeason_summer{Summer}ActivitySeason_autumn{Autumn}ActivitySeason_any{Any season}ActivityTimeOfDay_morning{Morning}ActivityTimeOfDay_afternoon{Afternoon}ActivityTimeOfDay_evening{Evening}ActivityTimeOfDay_night{Night}ActivityTimeOfDay_any{Any time}PlaceOperationalStatus_operating{Operating}PlaceOperationalStatus_temporarilyClosed{Temporarily closed}PlaceOperationalStatus_permanentlyClosed{Permanently closed}RentalLocationDisclosure_approximateArea{Approximate area (default)}RentalLocationDisclosure_publicBusinessAddress{Public business address}RentalScheduleMode_openingHours{Opening hours}RentalScheduleMode_byArrangement{By arrangement}RentalBillingUnit_hour{Per hour}RentalBillingUnit_day{Per day}RentalBillingUnit_week{Per week}RentalCondition_rentalNew{New}RentalCondition_likeNew{Like new}RentalCondition_good{Good}RentalCondition_worn{Worn}RentalDepositCollectionMethod_none{No deposit}RentalDepositCollectionMethod_atHandover{At handover}RentalDepositCollectionMethod_externalProvider{External provider}RentalDepositCollectionMethod_other{Other}VisibilityType_public{Public}VisibilityType_unlisted{By link}VisibilityType_private{Private}PublishStatus_draft{Draft}PublishStatus_pendingReview{Pending review}PublishStatus_published{Published}PublishStatus_archived{Archived}PublishStatus_hidden{Hidden}PublishStatus_deleted{Deleted}FindPeopleApprovalMode_manual{Host approves}FindPeopleApprovalMode_automatic{Automatic}FindPeopleApprovalMode_inviteOnly{Invite only}FindPeopleConversationPolicy_acceptedOnly{Accepted participants only}FindPeopleConversationPolicy_applicantsAndAccepted{Applicants and accepted}FindPeopleCostType_free{Free}FindPeopleCostType_estimated{Estimated cost}FindPeopleCostType_unknown{Unknown}FindPeopleExpenseSplitMode_none{No split}FindPeopleExpenseSplitMode_equal{Split equally}FindPeopleExpenseSplitMode_itemized{By item}FindPeopleExpenseSplitMode_settleLater{Settle later}FindPeopleMeetingMode_inPerson{In person}FindPeopleMeetingMode_online{Online}FindPeopleMeetingMode_hybrid{Hybrid}FindPeopleParticipationGoal_social{Socialising}FindPeopleParticipationGoal_practice{Practice}FindPeopleParticipationGoal_teamUp{Team up}FindPeopleParticipationGoal_sharedTrip{Shared trip}FindPeopleParticipationGoal_accountability{Keep each other going}FindPeopleParticipationGoal_other{Other}FindPeoplePublisherType_user{Personal profile}FindPeoplePublisherType_page{Professional page}FindPeopleScheduleMode_single{One time}FindPeopleScheduleMode_timePoll{Time poll}FindPeopleScheduleMode_recurring{Recurring}FindPeopleSeatFitPolicy_strictOrder{Strict order}FindPeopleSeatFitPolicy_firstFitting{First that fits}FindPeopleSkillLevel_any{Any level}FindPeopleSkillLevel_beginner{Beginner}FindPeopleSkillLevel_intermediate{Intermediate}FindPeopleSkillLevel_advanced{Advanced}FindPeopleVerificationLevel_none{No verification}FindPeopleVerificationLevel_phone{Phone}FindPeopleVerificationLevel_identityDocument{Identity document}FindPeopleVerificationLevel_organization{Organisation}FindPeopleVisibility_public{Public}FindPeopleVisibility_unlisted{By link}FindPeopleVisibility_inviteOnly{Invite only}FindPeopleWaitlistPolicy_firstCome{First come}FindPeopleWaitlistPolicy_hostReview{Host review}ScenarioBudgetBasis_wholeGroup{Whole group}ScenarioBudgetBasis_perPerson{Per person}ScenarioFormat_city{City}ScenarioFormat_day{Day}ScenarioFormat_weekend{Weekend}ScenarioFormat_trip{Trip}ScenarioPace_relaxed{Relaxed}ScenarioPace_balanced{Balanced}ScenarioPace_intensive{Intensive}ScenarioPartyKind_solo{Solo}ScenarioPartyKind_couple{Couple}ScenarioPartyKind_friends{Friends}ScenarioPartyKind_family{Family}ScenarioPartyKind_group{Group}ScenarioPartyKind_mixed{Mixed}ScenarioPlannedTransportKind_bus{Bus}ScenarioPlannedTransportKind_train{Train}ScenarioPlannedTransportKind_tram{Tram}ScenarioPlannedTransportKind_trolleybus{Trolleybus}ScenarioPlannedTransportKind_ferry{Ferry}ScenarioPlannedTransportKind_flight{Flight}ScenarioPlannedTransportKind_other{Other}ScenarioTravelMode_walking{Walking}ScenarioTravelMode_bicycle{Bicycle}ScenarioTravelMode_car{Own car}ScenarioTravelMode_taxi{Taxi}ScenarioTravelMode_transit{Public transport}ScenarioTravelMode_other{Other}ScenarioDateMode_template{Flexible template}ScenarioDateMode_dated{Dated trip}ScenarioItemKind_visit{Visit}ScenarioItemKind_event{Event}ScenarioItemKind_activity{Activity}ScenarioItemKind_route{Route}ScenarioItemKind_bookableSession{Session}ScenarioItemKind_stay{Stay}ScenarioItemKind_plannedTransport{Planned transport}ScenarioItemKind_timeBlock{Time block}RouteSegmentSource_routed{Routed}RouteSegmentSource_generated{Generated}RouteSegmentSource_freehand{Freehand}RouteSegmentSource_recordedGps{Recorded GPS}RouteSegmentSource_importedGpx{Imported GPX}RouteSegmentSource_intentionalDirect{Intentional direct line}RouteSegmentSource_fallbackDirect{Direct line (fallback)}RouteSegmentOperationState_ready{Ready}RouteSegmentOperationState_routing{Routing}RouteSegmentOperationState_failed{Failed}RouteSegmentOperationState_stale{Needs update}ScenarioScheduleFreshness_current{Current when saved}ScenarioScheduleFreshness_stale{Stale}ScenarioScheduleFreshness_unknown{Unknown}ScenarioScheduleFreshness_notApplicable{Not applicable} other{Other}}'**
  String createOption(String value);

  /// Create field: city (required).
  ///
  /// In en, this message translates to:
  /// **'City *'**
  String get createFormCityRequired;

  /// Create field: latitude (required).
  ///
  /// In en, this message translates to:
  /// **'Latitude *'**
  String get createFormLatitudeRequired;

  /// Create field: longitude (required).
  ///
  /// In en, this message translates to:
  /// **'Longitude *'**
  String get createFormLongitudeRequired;

  /// Create field: category (required).
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get createFormCategoryRequired;

  /// Create field: subcategory (required).
  ///
  /// In en, this message translates to:
  /// **'Subcategory *'**
  String get createFormSubcategoryRequired;

  /// Create field: title (required).
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get createFormTitleRequired;

  /// Event preview: number of dates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} date} other{{count} dates}}'**
  String createFormOccurrences(int count);

  /// Event preview: admission summary; value is a list of localized option labels.
  ///
  /// In en, this message translates to:
  /// **'Admission: {value}'**
  String createFormAdmissionLine(String value);

  /// Preview: visibility; value is a localized option label.
  ///
  /// In en, this message translates to:
  /// **'Visibility: {value}'**
  String createFormVisibilityLine(String value);

  /// Event preview: number of blocking problems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} problem blocks publishing} other{{count} problems block publishing}}'**
  String createFormBlockingIssues(int count);

  /// Create: the draft is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get createFormSending;

  /// Create: the draft is being published.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get createFormPublishing;

  /// Rental: fallback name of an unnamed item group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get createFormGroup;

  /// Preview: no title yet.
  ///
  /// In en, this message translates to:
  /// **'(no title yet)'**
  String get createFormNoTitleYet;

  /// Rental preview: number of units.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unit} other{{count} units}}'**
  String createFormUnits(int count);

  /// Rental preview: deposit amount, formatted with its currency.
  ///
  /// In en, this message translates to:
  /// **'Deposit: {price}'**
  String createFormDepositLine(String price);

  /// Activity field: group size, maximum people.
  ///
  /// In en, this message translates to:
  /// **'Group, max people'**
  String get createFormGroupMaxPeople;

  /// Collection preview: who publishes; type is the stable publisher type.
  ///
  /// In en, this message translates to:
  /// **'{type, select, user{Publisher: your profile} page{Publisher: a professional page} other{Publisher: not set}}'**
  String createFormPublisherLine(String type);

  /// Create: the draft has unsaved state.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get createFormDraft;

  /// Create form section: details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get createFormDetails;

  /// Create form section: availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get createFormAvailability;

  /// Opening hours rule: closed all day.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get createFormClosed;

  /// Create object type name. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Event}activity{Recharge activity}route{Route}place{Place}session{Bookable session}scenario{Scenario}quickPlan{Legacy Quick Plan}findPeople{Find people}classWorkshop{Class / workshop}rental{Rental / equipment}collection{Collection / guide} other{Object}}'**
  String createObjectTypeName(String type);

  /// Create object type explanation. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Public activity with time, place, and attendees}activity{Lightweight activity such as a walk or reset}route{Continuous track with anchors, segments and route details}place{A permanent physical place, venue, public space or landmark}session{Time-based service, class, table, court, or session}scenario{City, day, weekend or trip plan made of independent stops}quickPlan{Personal lightweight plan kept for read compatibility}findPeople{Find company for a specific activity}classWorkshop{A guided class, workshop, or hands-on experience}rental{Equipment or transport available for rent}collection{A curated collection of places and ideas} other{Create an object}}'**
  String createObjectTypeDescription(String type);

  /// Create form location field label. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Venue}activity{Where to go}route{Start point}place{Place name}session{Bookable venue}scenario{Area or city}quickPlan{Meeting place}findPeople{Meeting place}classWorkshop{Class venue}rental{Pickup place}collection{Area} other{Location}}'**
  String createObjectTypeLocationLabel(String type);

  /// Create form price field label. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Ticket or entry price}activity{}route{Route budget}place{Typical spend}session{Booking price}scenario{Scenario budget}quickPlan{Expected spend}findPeople{Expected spend}classWorkshop{Participation price}rental{Rental price}collection{Collection budget} other{Price}}'**
  String createObjectTypePriceLabel(String type);

  /// Create app bar title for a new object. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{New event}activity{New recharge activity}route{New route}place{New place}session{New bookable session}scenario{New scenario}quickPlan{New legacy quick plan}findPeople{New find people}classWorkshop{New class / workshop}rental{New rental / equipment}collection{New collection / guide} other{New object}}'**
  String createObjectTypeNewTitle(String type);

  /// Create page title. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Create Event}activity{Create Recharge activity}route{Create Route}place{Create Place}session{Create Bookable session}scenario{Create Scenario}quickPlan{Create Legacy Quick Plan}findPeople{Create Find people}classWorkshop{Create Class / workshop}rental{Create Rental / equipment}collection{Create Collection / guide} other{Create}}'**
  String createObjectTypeCreateTitle(String type);

  /// Create form: the object is free. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Free event}activity{Free recharge activity}route{Free route}place{Free place}session{Free bookable session}scenario{Free scenario}quickPlan{Free legacy quick plan}findPeople{Free find people}classWorkshop{Free class / workshop}rental{Free rental / equipment}collection{Free collection / guide} other{Free}}'**
  String createObjectTypeFreeToggle(String type);

  /// Create form: start instant in UTC. type is the stable CreateObjectType name.
  ///
  /// In en, this message translates to:
  /// **'{type, select, event{Event start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}activity{Recharge activity start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}route{Route start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}place{Place start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}session{Bookable session start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}scenario{Scenario start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}quickPlan{Legacy Quick Plan start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}findPeople{Find people start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}classWorkshop{Class / workshop start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}rental{Rental / equipment start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *}collection{Collection / guide start date and time, UTC (YYYY-MM-DDTHH:mm:ssZ) *} other{Start date and time, UTC *}}'**
  String createObjectTypeStartUtc(String type);

  /// Create success: the draft is now in a status; value is a localized status label.
  ///
  /// In en, this message translates to:
  /// **'Now: {value}.'**
  String createFormNowStatus(String value);

  /// Find People: step done of total.
  ///
  /// In en, this message translates to:
  /// **'Find People · {done}/{total}'**
  String createFindPeopleFindPeople(int done, int total);

  /// Create form: "Save error".
  ///
  /// In en, this message translates to:
  /// **'Save error'**
  String get createFindPeopleSaveError;

  /// Create form: "Unsaved changes".
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get createFindPeopleUnsavedChanges;

  /// Create form: "Continue".
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createFindPeopleContinue;

  /// Create form: "Save draft".
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get createFindPeopleSaveDraft;

  /// Create form: "Back".
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get createFindPeopleBack;

  /// Create form: "Publish Find People request".
  ///
  /// In en, this message translates to:
  /// **'Publish Find People request'**
  String get createFindPeoplePublishFindPeopleRequest;

  /// Create form: "Validation summary".
  ///
  /// In en, this message translates to:
  /// **'Validation summary'**
  String get createFindPeopleValidationSummary;

  /// Create form: "Meet publicly, do not send money to strangers, and use Repor".
  ///
  /// In en, this message translates to:
  /// **'Meet publicly, do not send money to strangers, and use Report/Block when needed.'**
  String get createFindPeopleMeetPubliclyDoNotSendMoney;

  /// Create form: "I accept the Find People Safety Rules *".
  ///
  /// In en, this message translates to:
  /// **'I accept the Find People Safety Rules *'**
  String get createFindPeopleIAcceptFindPeopleSafetyRules;

  /// Create form: "This request is only for adults 18+ *".
  ///
  /// In en, this message translates to:
  /// **'This request is only for adults 18+ *'**
  String get createFindPeopleRequestOnlyAdults18;

  /// Create form: "Schedule publication UTC (optional)".
  ///
  /// In en, this message translates to:
  /// **'Schedule publication UTC (optional)'**
  String get createFindPeopleSchedulePublicationUtcOptional;

  /// Create form: "Cover image URL (optional)".
  ///
  /// In en, this message translates to:
  /// **'Cover image URL (optional)'**
  String get createFindPeopleCoverImageUrlOptional;

  /// Create form: "Media and publication".
  ///
  /// In en, this message translates to:
  /// **'Media and publication'**
  String get createFindPeopleMediaPublication;

  /// Create form: "These fields are never included in public DTO, analytics, or".
  ///
  /// In en, this message translates to:
  /// **'These fields are never included in public data, analytics, or push payloads.'**
  String get createFindPeopleTheseFieldsAreNeverIncludedPublic;

  /// Create form: "Private host preview".
  ///
  /// In en, this message translates to:
  /// **'Private host preview'**
  String get createFindPeoplePrivateHostPreview;

  /// Create form: "Approximate public area".
  ///
  /// In en, this message translates to:
  /// **'Approximate public area'**
  String get createFindPeopleApproximatePublicArea;

  /// Create form: "Add a short description.".
  ///
  /// In en, this message translates to:
  /// **'Add a short description.'**
  String get createFindPeopleAddShortDescription;

  /// Create form: "Untitled Find People request".
  ///
  /// In en, this message translates to:
  /// **'Untitled Find People request'**
  String get createFindPeopleUntitledFindPeopleRequest;

  /// Create form: "This mirrors the safe public Details contract.".
  ///
  /// In en, this message translates to:
  /// **'This mirrors the safe public Details contract.'**
  String get createFindPeopleMirrorsSafePublicDetailsContract;

  /// Create form: "Public preview".
  ///
  /// In en, this message translates to:
  /// **'Public preview'**
  String get createFindPeoplePublicPreview;

  /// Create form: "Quiet hours end (0–1439)".
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end (0–1439)'**
  String get createFindPeopleQuietHoursEnd01439;

  /// Create form: "Quiet hours start (0–1439)".
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start (0–1439)'**
  String get createFindPeopleQuietHoursStart01439;

  /// Create form: "Allow accepted participants to invite".
  ///
  /// In en, this message translates to:
  /// **'Allow accepted participants to invite'**
  String get createFindPeopleAllowAcceptedParticipantsInvite;

  /// Create form: "Conversation policy *".
  ///
  /// In en, this message translates to:
  /// **'Conversation policy *'**
  String get createFindPeopleConversationPolicy;

  /// Create form: "Invite co-host".
  ///
  /// In en, this message translates to:
  /// **'Invite co-host'**
  String get createFindPeopleInviteCoHost;

  /// Create form: "User ID".
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get createFindPeopleUserId;

  /// Find People: number of responsible hosts (ids are not shown).
  ///
  /// In en, this message translates to:
  /// **'Responsible hosts: {count}'**
  String createFindPeopleResponsibleHostsDataResponsiblehostuseridsJoin(
    int count,
  );

  /// Create form: "Publisher user ID *".
  ///
  /// In en, this message translates to:
  /// **'Publisher user ID *'**
  String get createFindPeoplePublisherUserId;

  /// Create form: "Managed Page ID *".
  ///
  /// In en, this message translates to:
  /// **'Managed Page ID *'**
  String get createFindPeopleManagedPageId;

  /// Create form: "Publish as *".
  ///
  /// In en, this message translates to:
  /// **'Publish as *'**
  String get createFindPeoplePublishAs;

  /// Create form: "Add expense".
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get createFindPeopleAddExpense;

  /// Create form: "Expense item".
  ///
  /// In en, this message translates to:
  /// **'Expense item'**
  String get createFindPeopleExpenseItem;

  /// Create form: "Expense split mode *".
  ///
  /// In en, this message translates to:
  /// **'Expense split mode *'**
  String get createFindPeopleExpenseSplitMode;

  /// Create form: "Cost note".
  ///
  /// In en, this message translates to:
  /// **'Cost note'**
  String get createFindPeopleCostNote;

  /// Find People: expected spend per person in the currency code value.
  ///
  /// In en, this message translates to:
  /// **'Expected spend per person ({value}) *'**
  String createFindPeopleExpectedSpendPerPerson(String value);

  /// Create form: "Expected cost *".
  ///
  /// In en, this message translates to:
  /// **'Expected cost *'**
  String get createFindPeopleExpectedCost;

  /// Create form: "Add question".
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get createFindPeopleAddQuestion;

  /// Create form: "Safe question".
  ///
  /// In en, this message translates to:
  /// **'Safe question'**
  String get createFindPeopleSafeQuestion;

  /// Create form: "Application questions".
  ///
  /// In en, this message translates to:
  /// **'Application questions'**
  String get createFindPeopleApplicationQuestions;

  /// Create form: "Require attendance reconfirmation".
  ///
  /// In en, this message translates to:
  /// **'Require attendance reconfirmation'**
  String get createFindPeopleRequireAttendanceReconfirmation;

  /// Create form: "Waitlist policy".
  ///
  /// In en, this message translates to:
  /// **'Waitlist policy'**
  String get createFindPeopleWaitlistPolicy;

  /// Create form: "Enable waitlist".
  ///
  /// In en, this message translates to:
  /// **'Enable waitlist'**
  String get createFindPeopleEnableWaitlist;

  /// Create form: "Verification requirement *".
  ///
  /// In en, this message translates to:
  /// **'Verification requirement *'**
  String get createFindPeopleVerificationRequirement;

  /// Create form: "Maximum seats per application".
  ///
  /// In en, this message translates to:
  /// **'Maximum seats per application'**
  String get createFindPeopleMaximumSeatsPerApplication;

  /// Create form: "Allow party applications".
  ///
  /// In en, this message translates to:
  /// **'Allow party applications'**
  String get createFindPeopleAllowPartyApplications;

  /// Create form: "Approval mode *".
  ///
  /// In en, this message translates to:
  /// **'Approval mode *'**
  String get createFindPeopleApprovalMode;

  /// Create form: "Host seats".
  ///
  /// In en, this message translates to:
  /// **'Host seats'**
  String get createFindPeopleHostSeats;

  /// Create form: "Target group size".
  ///
  /// In en, this message translates to:
  /// **'Target group size'**
  String get createFindPeopleTargetGroupSize;

  /// Create form: "Group size includes hosts. Expected spend is information, ne".
  ///
  /// In en, this message translates to:
  /// **'Group size includes hosts. Expected spend is information, never a payment to the host.'**
  String get createFindPeopleGroupSizeIncludesHostsExpectedSpend;

  /// Create form: "Group and participation".
  ///
  /// In en, this message translates to:
  /// **'Group and participation'**
  String get createFindPeopleGroupParticipation;

  /// Create form: "Backup meeting plan".
  ///
  /// In en, this message translates to:
  /// **'Backup meeting plan'**
  String get createFindPeopleBackupMeetingPlan;

  /// Create form: "Private access secret reference *".
  ///
  /// In en, this message translates to:
  /// **'Private access secret reference *'**
  String get createFindPeoplePrivateAccessSecretReference;

  /// Create form: "Google Meet, Zoom, Discord…".
  ///
  /// In en, this message translates to:
  /// **'Google Meet, Zoom, Discord…'**
  String get createFindPeopleGoogleMeetZoomDiscord;

  /// Create form: "Online provider *".
  ///
  /// In en, this message translates to:
  /// **'Online provider *'**
  String get createFindPeopleOnlineProvider;

  /// Create form: "Private homes and residential access details are not allowed".
  ///
  /// In en, this message translates to:
  /// **'Private homes and residential access details are not allowed.'**
  String get createFindPeoplePrivateHomesResidentialAccessDetailsAre;

  /// Create form: "This is a public meeting place *".
  ///
  /// In en, this message translates to:
  /// **'This is a public meeting place *'**
  String get createFindPeoplePublicMeetingPlace;

  /// Create form: "Meeting instructions (private)".
  ///
  /// In en, this message translates to:
  /// **'Meeting instructions (private)'**
  String get createFindPeopleMeetingInstructionsPrivate;

  /// Create form: "Exact address (private) *".
  ///
  /// In en, this message translates to:
  /// **'Exact address (private) *'**
  String get createFindPeopleExactAddressPrivate;

  /// Find People: the generated public map point; value is "lat, lng".
  ///
  /// In en, this message translates to:
  /// **'Public map point: {value}'**
  String createFindPeoplePublicMapPoint(String value);

  /// Create form: "Set exact point and generate safe public point".
  ///
  /// In en, this message translates to:
  /// **'Set exact point and generate safe public point'**
  String get createFindPeopleSetExactPointGenerateSafePublic;

  /// Create form: "Exact longitude *".
  ///
  /// In en, this message translates to:
  /// **'Exact longitude *'**
  String get createFindPeopleExactLongitude;

  /// Create form: "Exact latitude *".
  ///
  /// In en, this message translates to:
  /// **'Exact latitude *'**
  String get createFindPeopleExactLatitude;

  /// Create form: "Old Town, near Central Park".
  ///
  /// In en, this message translates to:
  /// **'Old Town, near Central Park'**
  String get createFindPeopleOldTownNearCentralPark;

  /// Create form: "Public area label *".
  ///
  /// In en, this message translates to:
  /// **'Public area label *'**
  String get createFindPeoplePublicAreaLabel;

  /// Create form: "Meeting place name *".
  ///
  /// In en, this message translates to:
  /// **'Meeting place name *'**
  String get createFindPeopleMeetingPlaceName;

  /// Create form: "Meeting mode *".
  ///
  /// In en, this message translates to:
  /// **'Meeting mode *'**
  String get createFindPeopleMeetingMode;

  /// Create form: "Only the approximate public area appears in Discover. Exact ".
  ///
  /// In en, this message translates to:
  /// **'Only the approximate public area appears in Discover. Exact details stay private.'**
  String get createFindPeopleOnlyApproximatePublicAreaAppearsDiscover;

  /// Create form: "Meeting location".
  ///
  /// In en, this message translates to:
  /// **'Meeting location'**
  String get createFindPeopleMeetingLocation;

  /// Create form: "Maximum occurrences (2–52)".
  ///
  /// In en, this message translates to:
  /// **'Maximum occurrences (2–52)'**
  String get createFindPeopleMaximumOccurrences252;

  /// Create form: "Series end UTC".
  ///
  /// In en, this message translates to:
  /// **'Series end UTC'**
  String get createFindPeopleSeriesEndUtc;

  /// Create form: "Recurrence rule *".
  ///
  /// In en, this message translates to:
  /// **'Recurrence rule *'**
  String get createFindPeopleRecurrenceRule;

  /// Create form: "Application deadline UTC *".
  ///
  /// In en, this message translates to:
  /// **'Application deadline UTC *'**
  String get createFindPeopleApplicationDeadlineUtc;

  /// Create form: "Poll response deadline UTC *".
  ///
  /// In en, this message translates to:
  /// **'Poll response deadline UTC *'**
  String get createFindPeoplePollResponseDeadlineUtc;

  /// Create form: "Remove slot".
  ///
  /// In en, this message translates to:
  /// **'Remove slot'**
  String get createFindPeopleRemoveSlot;

  /// Create form: "Add time option".
  ///
  /// In en, this message translates to:
  /// **'Add time option'**
  String get createFindPeopleAddTimeOption;

  /// Create form: "Set meeting time".
  ///
  /// In en, this message translates to:
  /// **'Set meeting time'**
  String get createFindPeopleSetMeetingTime;

  /// Create form: "End UTC *".
  ///
  /// In en, this message translates to:
  /// **'End UTC *'**
  String get createFindPeopleEndUtc;

  /// Create form: "Start UTC *".
  ///
  /// In en, this message translates to:
  /// **'Start UTC *'**
  String get createFindPeopleStartUtc;

  /// Create form: "Schedule mode *".
  ///
  /// In en, this message translates to:
  /// **'Schedule mode *'**
  String get createFindPeopleScheduleMode;

  /// Find People: times are stored in UTC and shown in the IANA zone value.
  ///
  /// In en, this message translates to:
  /// **'All times are stored in UTC and displayed using {value}.'**
  String createFindPeopleAllTimesAreStoredUtcDisplayed(String value);

  /// Create form: "Schedule".
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get createFindPeopleSchedule;

  /// Create form: "House rules note".
  ///
  /// In en, this message translates to:
  /// **'House rules note'**
  String get createFindPeopleHouseRulesNote;

  /// Create form: "House rules".
  ///
  /// In en, this message translates to:
  /// **'House rules'**
  String get createFindPeopleHouseRules;

  /// Create form: "Accessibility notes".
  ///
  /// In en, this message translates to:
  /// **'Accessibility notes'**
  String get createFindPeopleAccessibilityNotes;

  /// Create form: "Equipment notes".
  ///
  /// In en, this message translates to:
  /// **'Equipment notes'**
  String get createFindPeopleEquipmentNotes;

  /// Create form: "Experience requirements (one per line)".
  ///
  /// In en, this message translates to:
  /// **'Experience requirements (one per line)'**
  String get createFindPeopleExperienceRequirementsOnePerLine;

  /// Create form: "Communication languages *".
  ///
  /// In en, this message translates to:
  /// **'Communication languages *'**
  String get createFindPeopleCommunicationLanguages;

  /// Create form: "Participation goal *".
  ///
  /// In en, this message translates to:
  /// **'Participation goal *'**
  String get createFindPeopleParticipationGoal;

  /// Create form: "Skill level *".
  ///
  /// In en, this message translates to:
  /// **'Skill level *'**
  String get createFindPeopleSkillLevel;

  /// Create form: "Full description *".
  ///
  /// In en, this message translates to:
  /// **'Full description *'**
  String get createFindPeopleFullDescription;

  /// Create form: "Short description *".
  ///
  /// In en, this message translates to:
  /// **'Short description *'**
  String get createFindPeopleShortDescription;

  /// Create form: "Public content must describe a concrete activity without con".
  ///
  /// In en, this message translates to:
  /// **'Public content must describe a concrete activity without contacts or payment links.'**
  String get createFindPeoplePublicContentMustDescribeConcreteActivity;

  /// Create form: "Activity and description".
  ///
  /// In en, this message translates to:
  /// **'Activity and description'**
  String get createFindPeopleActivityDescription;

  /// Create form: "Find People draft data is being prepared…".
  ///
  /// In en, this message translates to:
  /// **'Find People draft data is being prepared…'**
  String get createFindPeopleFindPeopleDraftDataBeingPrepared;

  /// Create form: "Only what is marked 'required' blocks publishing. Everything".
  ///
  /// In en, this message translates to:
  /// **'Only what is marked “required” blocks publishing. Everything else is optional and can be added now or later.'**
  String get createSessionOnlyWhatMarkedRequiredBlocksPublishing;

  /// Create form: "Publish".
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createSessionPublish;

  /// Create form: "Save draft".
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get createSessionSaveDraft;

  /// Create form: "Never required to publish (SES-D14).".
  ///
  /// In en, this message translates to:
  /// **'Never required to publish.'**
  String get createSessionNeverRequiredPublishSesD14;

  /// Create form: "Recommended details for this category".
  ///
  /// In en, this message translates to:
  /// **'Recommended details for this category'**
  String get createSessionRecommendedDetailsCategory;

  /// Create form: "Amenities".
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get createSessionAmenities;

  /// Create form: "Block".
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get createSessionBlock;

  /// Create form: "Blocked dates".
  ///
  /// In en, this message translates to:
  /// **'Blocked dates'**
  String get createSessionBlockedDates;

  /// Create form: "Max party size".
  ///
  /// In en, this message translates to:
  /// **'Max party size'**
  String get createSessionMaxPartySize;

  /// Create form: "Terms URL (optional, https://…)".
  ///
  /// In en, this message translates to:
  /// **'Terms URL (optional, https://…)'**
  String get createSessionTermsUrlOptionalHttps;

  /// Create form: "External booking URL (https://…)".
  ///
  /// In en, this message translates to:
  /// **'External booking URL (https://…)'**
  String get createSessionExternalBookingUrlHttps;

  /// Create form: "Price per slot, EUR".
  ///
  /// In en, this message translates to:
  /// **'Price per slot, EUR'**
  String get createSessionPricePerSlotEur;

  /// Create form: "Free".
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get createSessionFree;

  /// Create form: "Price and booking".
  ///
  /// In en, this message translates to:
  /// **'Price and booking'**
  String get createSessionPriceBooking;

  /// Create form: "Next offers".
  ///
  /// In en, this message translates to:
  /// **'Next offers'**
  String get createSessionNextOffers;

  /// Create form: "Slot duration".
  ///
  /// In en, this message translates to:
  /// **'Slot duration'**
  String get createSessionSlotDuration;

  /// Create form: "No weekly rule yet — pick a preset above.".
  ///
  /// In en, this message translates to:
  /// **'No weekly rule yet — pick a preset above.'**
  String get createSessionNoWeeklyRuleYetPickPreset;

  /// Create form: "When".
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get createSessionWhen;

  /// Create form: "Confirm this location".
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get createSessionConfirmLocation;

  /// Create form: "Longitude".
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get createSessionLongitude;

  /// Create form: "Latitude".
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get createSessionLatitude;

  /// Create form: "City".
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get createSessionCity;

  /// Create form: "Address".
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get createSessionAddress;

  /// Create form: "Resource name (e.g. 'Sauna 1')".
  ///
  /// In en, this message translates to:
  /// **'Resource name (e.g. “Sauna 1”)'**
  String get createSessionResourceNameEGSauna1;

  /// Create form: "Gallery image description".
  ///
  /// In en, this message translates to:
  /// **'Gallery image description'**
  String get createSessionGalleryImageDescription;

  /// Create form: "Cover image description".
  ///
  /// In en, this message translates to:
  /// **'Cover image description'**
  String get createSessionCoverImageDescription;

  /// Create form: "Content language".
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get createSessionContentLanguage;

  /// Create form: "Cover image URL".
  ///
  /// In en, this message translates to:
  /// **'Cover image URL'**
  String get createSessionCoverImageUrl;

  /// Create form: "Full description".
  ///
  /// In en, this message translates to:
  /// **'Full description'**
  String get createSessionFullDescription;

  /// Create form: "Short description".
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get createSessionShortDescription;

  /// Create form: "Subcategory".
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get createSessionSubcategory;

  /// Create form: "Category".
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get createSessionCategory;

  /// Create form: "Title".
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get createSessionTitle;

  /// Create form: "What and where".
  ///
  /// In en, this message translates to:
  /// **'What and where'**
  String get createSessionWhatWhere;

  /// Create form: "Loading Bookable session draft…".
  ///
  /// In en, this message translates to:
  /// **'Loading Bookable session draft…'**
  String get createSessionLoadingBookableSessionDraft;

  /// Create form: "Publish".
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get createClassPublish;

  /// Create form: "Save draft".
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get createClassSaveDraft;

  /// Create form: "Enrollment state".
  ///
  /// In en, this message translates to:
  /// **'Enrollment state'**
  String get createClassEnrollmentState;

  /// Create form: "Enrollment link (https)".
  ///
  /// In en, this message translates to:
  /// **'Enrollment link (https)'**
  String get createClassEnrollmentLinkHttps;

  /// Create form: "Enrollment on the organiser site".
  ///
  /// In en, this message translates to:
  /// **'Enrollment on the organiser site'**
  String get createClassEnrollmentOrganiserSite;

  /// Create form: "The price covers".
  ///
  /// In en, this message translates to:
  /// **'The price covers'**
  String get createClassPriceCovers;

  /// Class price field: amount in cents of the currency code value.
  ///
  /// In en, this message translates to:
  /// **'Amount in cents ({value})'**
  String createClassAmountCents(String value);

  /// Create form: "Price".
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get createClassPrice;

  /// Create form: "Declared group size (optional)".
  ///
  /// In en, this message translates to:
  /// **'Declared group size (optional)'**
  String get createClassDeclaredGroupSizeOptional;

  /// Create form: "What to bring or know (one per line)".
  ///
  /// In en, this message translates to:
  /// **'What to bring or know (one per line)'**
  String get createClassWhatBringKnowOnePerLine;

  /// Create form: "Included materials (one per line)".
  ///
  /// In en, this message translates to:
  /// **'Included materials (one per line)'**
  String get createClassIncludedMaterialsOnePerLine;

  /// Create form: "Add date".
  ///
  /// In en, this message translates to:
  /// **'Add date'**
  String get createClassAddDate;

  /// Create form: "Remove date".
  ///
  /// In en, this message translates to:
  /// **'Remove date'**
  String get createClassRemoveDate;

  /// Create form: "This local time does not exist or is ambiguous".
  ///
  /// In en, this message translates to:
  /// **'This local time does not exist or is ambiguous'**
  String get createClassLocalTimeDoesNotExistAmbiguous;

  /// Create form: "Public area".
  ///
  /// In en, this message translates to:
  /// **'Public area'**
  String get createClassPublicArea;

  /// Create form: "Show only the area publicly".
  ///
  /// In en, this message translates to:
  /// **'Show only the area publicly'**
  String get createClassShowOnlyAreaPublicly;

  /// Create form: "Confirm this location".
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get createClassConfirmLocation;

  /// Create form: "Location confirmed".
  ///
  /// In en, this message translates to:
  /// **'Location confirmed'**
  String get createClassLocationConfirmed;

  /// Create form: "Online provider".
  ///
  /// In en, this message translates to:
  /// **'Online provider'**
  String get createClassOnlineProvider;

  /// Create form: "Delivery".
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get createClassDelivery;

  /// Class: times are in the IANA zone value.
  ///
  /// In en, this message translates to:
  /// **'Times are in {value}'**
  String createClassTimesAre(String value);

  /// Create form: "Fixed series".
  ///
  /// In en, this message translates to:
  /// **'Fixed series'**
  String get createClassFixedSeries;

  /// Create form: "Single class".
  ///
  /// In en, this message translates to:
  /// **'Single class'**
  String get createClassSingleClass;

  /// Create form: "Clear".
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get createClassClear;

  /// Create form: "It is not published; clear it explicitly.".
  ///
  /// In en, this message translates to:
  /// **'It is not published; clear it explicitly.'**
  String get createClassNotPublishedClearExplicitly;

  /// Create form: "This draft has an old schedule".
  ///
  /// In en, this message translates to:
  /// **'This draft has an old schedule'**
  String get createClassDraftHasOldSchedule;

  /// Create form: "Instructor bio".
  ///
  /// In en, this message translates to:
  /// **'Instructor bio'**
  String get createClassInstructorBio;

  /// Create form: "Instructor name".
  ///
  /// In en, this message translates to:
  /// **'Instructor name'**
  String get createClassInstructorName;

  /// Create form: "What participants take home".
  ///
  /// In en, this message translates to:
  /// **'What participants take home'**
  String get createClassWhatParticipantsTakeHome;

  /// Create form: "No prerequisites".
  ///
  /// In en, this message translates to:
  /// **'No prerequisites'**
  String get createClassNoPrerequisites;

  /// Create form: "Programme steps (one per line)".
  ///
  /// In en, this message translates to:
  /// **'Programme steps (one per line)'**
  String get createClassProgrammeStepsOnePerLine;

  /// Create form: "Gallery image description".
  ///
  /// In en, this message translates to:
  /// **'Gallery image description'**
  String get createClassGalleryImageDescription;

  /// Create form: "Cover image description".
  ///
  /// In en, this message translates to:
  /// **'Cover image description'**
  String get createClassCoverImageDescription;

  /// Create form: "Content language".
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get createClassContentLanguage;

  /// Create form: "Cover image".
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get createClassCoverImage;

  /// Create form: "Full description".
  ///
  /// In en, this message translates to:
  /// **'Full description'**
  String get createClassFullDescription;

  /// Create form: "Short description".
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get createClassShortDescription;

  /// Create form: "Offering kind".
  ///
  /// In en, this message translates to:
  /// **'Offering kind'**
  String get createClassOfferingKind;

  /// Create form: "This Class draft was saved by a newer app version and is rea".
  ///
  /// In en, this message translates to:
  /// **'This Class draft was saved by a newer app version and is read-only.'**
  String get createClassClassDraftWasSavedByNewer;

  /// Create form: "The GPX operation could not be completed.".
  ///
  /// In en, this message translates to:
  /// **'The GPX operation could not be completed.'**
  String get createRouteGpxOperationCouldNotCompleted;

  /// Create form: "Choose one continuous track for this Route draft.".
  ///
  /// In en, this message translates to:
  /// **'Choose one continuous track for this Route draft.'**
  String get createRouteChooseOneContinuousTrackRouteDraft;

  /// Create form: "Saving GPX files is not available on this device yet.".
  ///
  /// In en, this message translates to:
  /// **'Saving GPX files is not available on this device yet.'**
  String get createRouteSavingGpxFilesNotAvailableDevice;

  /// Create form: "Only one continuous Route track can be exported.".
  ///
  /// In en, this message translates to:
  /// **'Only one continuous Route track can be exported.'**
  String get createRouteOnlyOneContinuousRouteTrackCan;

  /// Create form: "The GPX track contains too many points.".
  ///
  /// In en, this message translates to:
  /// **'The GPX track contains too many points.'**
  String get createRouteGpxTrackContainsTooManyPoints;

  /// Create form: "The GPX file is damaged or has an unsupported structure.".
  ///
  /// In en, this message translates to:
  /// **'The GPX file is damaged or has an unsupported structure.'**
  String get createRouteGpxFileDamagedHasUnsupportedStructure;

  /// Create form: "Choose a valid GPX file.".
  ///
  /// In en, this message translates to:
  /// **'Choose a valid GPX file.'**
  String get createRouteChooseValidGpxFile;

  /// Create form: "The GPX file is too large.".
  ///
  /// In en, this message translates to:
  /// **'The GPX file is too large.'**
  String get createRouteGpxFileTooLarge;

  /// Create form: "Dismiss".
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get createRouteDismiss;

  /// Create form: "Import track".
  ///
  /// In en, this message translates to:
  /// **'Import track'**
  String get createRouteImportTrack;

  /// Create form: "Cancel".
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get createRouteCancel;

  /// Create form: "They remain off-track until reviewed and positioned.".
  ///
  /// In en, this message translates to:
  /// **'They remain off-track until reviewed and positioned.'**
  String get createRouteTheyRemainOffTrackUntilReviewed;

  /// Create form: "Review these connectors on the map before publishing.".
  ///
  /// In en, this message translates to:
  /// **'Review these connectors on the map before publishing.'**
  String get createRouteReviewTheseConnectorsMapBeforePublishing;

  /// Create form: "Choose one track".
  ///
  /// In en, this message translates to:
  /// **'Choose one track'**
  String get createRouteChooseOneTrack;

  /// Create form: "Private metadata and timestamps will be removed during impor".
  ///
  /// In en, this message translates to:
  /// **'Private metadata and timestamps will be removed during import.'**
  String get createRoutePrivateMetadataTimestampsWillRemovedDuring;

  /// Create form: "Route builder".
  ///
  /// In en, this message translates to:
  /// **'Route builder'**
  String get createRouteRouteBuilder;

  /// Create form: "Replace".
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get createRouteReplace;

  /// Create form: "The current geometry will remain available through Undo.".
  ///
  /// In en, this message translates to:
  /// **'The current geometry will remain available through Undo.'**
  String get createRouteCurrentGeometryWillRemainAvailableThrough;

  /// Create form: "Replace existing track?".
  ///
  /// In en, this message translates to:
  /// **'Replace existing track?'**
  String get createRouteReplaceExistingTrack;

  /// Create form: "Continue".
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createRouteContinue;

  /// Create form: "Back".
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get createRouteBack;

  /// Create form: "Marked trail".
  ///
  /// In en, this message translates to:
  /// **'Marked trail'**
  String get createRouteMarkedTrail;

  /// Create form: "Hard".
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get createRouteHard;

  /// Create form: "Moderate".
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get createRouteModerate;

  /// Create form: "Easy".
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get createRouteEasy;

  /// Create form: "Difficulty".
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get createRouteDifficulty;

  /// Create form: "Conditions".
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get createRouteConditions;

  /// Create form: "Subcategory".
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get createRouteSubcategory;

  /// Create form: "Category".
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get createRouteCategory;

  /// Create form: "Taxonomy".
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get createRouteTaxonomy;

  /// Create form: "Cover image URL".
  ///
  /// In en, this message translates to:
  /// **'Cover image URL'**
  String get createRouteCoverImageUrl;

  /// Create form: "Full description".
  ///
  /// In en, this message translates to:
  /// **'Full description'**
  String get createRouteFullDescription;

  /// Create form: "Short description *".
  ///
  /// In en, this message translates to:
  /// **'Short description *'**
  String get createRouteShortDescription;

  /// Create form: "Route details".
  ///
  /// In en, this message translates to:
  /// **'Route details'**
  String get createRouteRouteDetails;

  /// Create form: "Prefer unpaved trails".
  ///
  /// In en, this message translates to:
  /// **'Prefer unpaved trails'**
  String get createRoutePreferUnpavedTrails;

  /// Create form: "Avoid stairs".
  ///
  /// In en, this message translates to:
  /// **'Avoid stairs'**
  String get createRouteAvoidStairs;

  /// Create form: "Routing preferences".
  ///
  /// In en, this message translates to:
  /// **'Routing preferences'**
  String get createRouteRoutingPreferences;

  /// Create form: "Loop".
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get createRouteLoop;

  /// Create form: "One way".
  ///
  /// In en, this message translates to:
  /// **'One way'**
  String get createRouteOneWay;

  /// Create form: "Route shape".
  ///
  /// In en, this message translates to:
  /// **'Route shape'**
  String get createRouteRouteShape;

  /// Create form: "Profile".
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get createRouteProfile;

  /// Create form: "The bundled Mežaparks graph currently validates walking rout".
  ///
  /// In en, this message translates to:
  /// **'The bundled Mežaparks graph currently validates walking routes locally.'**
  String get createRouteBundledMeAparksGraphCurrentlyValidates;

  /// Create form: "Movement profile".
  ///
  /// In en, this message translates to:
  /// **'Movement profile'**
  String get createRouteMovementProfile;

  /// Create form: "Save file".
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get createRouteSaveFile;

  /// Create form: "Private metadata, notes and timestamps are never exported.".
  ///
  /// In en, this message translates to:
  /// **'Private metadata, notes and timestamps are never exported.'**
  String get createRoutePrivateMetadataNotesTimestampsAreNever;

  /// Create form: "Include route POI".
  ///
  /// In en, this message translates to:
  /// **'Include route POI'**
  String get createRouteIncludeRoutePoi;

  /// Create form: "Unavailable for this track".
  ///
  /// In en, this message translates to:
  /// **'Unavailable for this track'**
  String get createRouteUnavailableTrack;

  /// Create form: "Include elevation".
  ///
  /// In en, this message translates to:
  /// **'Include elevation'**
  String get createRouteIncludeElevation;

  /// Create form: "Export GPX".
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get createRouteExportGpx;

  /// Create form: "Export only the track and optional route POI. Draft IDs, not".
  ///
  /// In en, this message translates to:
  /// **'Export only the track and optional route POI. Draft IDs, notes, safety data and timestamps are excluded.'**
  String get createRouteExportOnlyTrackOptionalRoutePoi;

  /// Create form: "Inspect a GPX file locally, choose one track and remove priv".
  ///
  /// In en, this message translates to:
  /// **'Inspect a GPX file locally, choose one track and remove private metadata.'**
  String get createRouteInspectGpxFileLocallyChooseOne;

  /// Create form: "Import GPX".
  ///
  /// In en, this message translates to:
  /// **'Import GPX'**
  String get createRouteImportGpx;

  /// Create form: "Record movement on this device, then review accuracy, gaps a".
  ///
  /// In en, this message translates to:
  /// **'Record movement on this device, then review accuracy, gaps and privacy trimming.'**
  String get createRouteRecordMovementDeviceThenReviewAccuracy;

  /// Create form: "Record with GPS".
  ///
  /// In en, this message translates to:
  /// **'Record with GPS'**
  String get createRouteRecordWithGps;

  /// Create form: "Draw one continuous line and keep its exact geometry.".
  ///
  /// In en, this message translates to:
  /// **'Draw one continuous line and keep its exact geometry.'**
  String get createRouteDrawOneContinuousLineKeepIts;

  /// Create form: "Freehand".
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get createRouteFreehand;

  /// Create form: "Place anchors and connect them along the offline trail graph".
  ///
  /// In en, this message translates to:
  /// **'Place anchors and connect them along the offline trail graph.'**
  String get createRoutePlaceAnchorsConnectThemAlongOffline;

  /// Create form: "Points".
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get createRoutePoints;

  /// Create form: "All methods use one canonical Route model. This demo enables".
  ///
  /// In en, this message translates to:
  /// **'All methods use one canonical Route model. This demo enables points and freehand without paid services.'**
  String get createRouteAllMethodsUseOneCanonicalRoute;

  /// Create form: "How will you create the track?".
  ///
  /// In en, this message translates to:
  /// **'How will you create the track?'**
  String get createRouteHowWillYouCreateTrack;

  /// Create form: "The editor will be ready in a moment.".
  ///
  /// In en, this message translates to:
  /// **'The editor will be ready in a moment.'**
  String get createRouteEditorWillReadyMoment;

  /// Create form: "Preparing Route draft…".
  ///
  /// In en, this message translates to:
  /// **'Preparing Route draft…'**
  String get createRoutePreparingRouteDraft;

  /// Create form: "Restoring the latest persisted revision.".
  ///
  /// In en, this message translates to:
  /// **'Restoring the latest saved revision.'**
  String get createRouteRestoringLatestPersistedRevision;

  /// Create form: "Retry".
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get createRouteRetry;

  /// Create form: "Offline map could not be loaded".
  ///
  /// In en, this message translates to:
  /// **'Offline map could not be loaded'**
  String get createRouteOfflineMapCouldNotLoaded;

  /// Create form: "No network or paid routing call is required.".
  ///
  /// In en, this message translates to:
  /// **'No network or paid routing call is required.'**
  String get createRouteNoNetworkPaidRoutingCallRequired;

  /// Create form: "Loading offline trail editor…".
  ///
  /// In en, this message translates to:
  /// **'Loading offline trail editor…'**
  String get createRouteLoadingOfflineTrailEditor;

  /// Create form: "This gap needs trail routing before it can be applied.".
  ///
  /// In en, this message translates to:
  /// **'This gap needs trail routing before it can be applied.'**
  String get createRouteGapNeedsTrailRoutingBeforeCan;

  /// Create form: "Review every track gap before continuing.".
  ///
  /// In en, this message translates to:
  /// **'Review every track gap before continuing.'**
  String get createRouteReviewEveryTrackGapBeforeContinuing;

  /// Create form: "The protected recording could not be saved. Recording was st".
  ///
  /// In en, this message translates to:
  /// **'The protected recording could not be saved. Recording was stopped safely.'**
  String get createRouteProtectedRecordingCouldNotSavedRecording;

  /// Create form: "Not enough reliable movement was recorded. Delete this recor".
  ///
  /// In en, this message translates to:
  /// **'Not enough reliable movement was recorded. Delete this recording and try again.'**
  String get createRouteNotEnoughReliableMovementWasRecorded;

  /// Create form: "The safety point limit was reached. Finish and review this r".
  ///
  /// In en, this message translates to:
  /// **'The safety point limit was reached. Finish and review this recording.'**
  String get createRouteSafetyPointLimitWasReachedFinish;

  /// Create form: "Device location services are switched off.".
  ///
  /// In en, this message translates to:
  /// **'Device location services are switched off.'**
  String get createRouteDeviceLocationServicesAreSwitchedOff;

  /// Create form: "Background access was not granted. Turn off screen-lock reco".
  ///
  /// In en, this message translates to:
  /// **'Background access was not granted. Turn off screen-lock recording or allow it in settings.'**
  String get createRouteBackgroundAccessWasNotGrantedTurn;

  /// Create form: "Location access is disabled in app settings.".
  ///
  /// In en, this message translates to:
  /// **'Location access is disabled in app settings.'**
  String get createRouteLocationAccessDisabledAppSettings;

  /// Create form: "Location permission was not granted.".
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted.'**
  String get createRouteLocationPermissionWasNotGranted;

  /// Create form: "Your saved recording is preserved when recovery is possible.".
  ///
  /// In en, this message translates to:
  /// **'Your saved recording is preserved when recovery is possible.'**
  String get createRouteYourSavedRecordingPreservedWhenRecovery;

  /// Create form: "Inspect gaps, accuracy and privacy trimming before using the".
  ///
  /// In en, this message translates to:
  /// **'Inspect gaps, accuracy and privacy trimming before using the track.'**
  String get createRouteInspectGapsAccuracyPrivacyTrimmingBefore;

  /// Create form: "Filtering unsafe and noisy GPS points.".
  ///
  /// In en, this message translates to:
  /// **'Filtering unsafe and noisy GPS points.'**
  String get createRouteFilteringUnsafeNoisyGpsPoints;

  /// Create form: "Reading the protected local journal.".
  ///
  /// In en, this message translates to:
  /// **'Reading the protected local journal.'**
  String get createRouteReadingProtectedLocalJournal;

  /// Create form: "The pause stays as an explicit gap and will never be connect".
  ///
  /// In en, this message translates to:
  /// **'The pause stays as an explicit gap and will never be connected silently.'**
  String get createRoutePauseStaysAsExplicitGapWill;

  /// Create form: "Keep Recharge open while moving along the Route.".
  ///
  /// In en, this message translates to:
  /// **'Keep Recharge open while moving along the Route.'**
  String get createRouteKeepRechargeOpenWhileMovingAlong;

  /// Create form: "Recording continues with a visible system indicator.".
  ///
  /// In en, this message translates to:
  /// **'Recording continues with a visible system indicator.'**
  String get createRouteRecordingContinuesWithVisibleSystemIndicator;

  /// Create form: "Recharge requests location only for Route recording.".
  ///
  /// In en, this message translates to:
  /// **'Recharge requests location only for Route recording.'**
  String get createRouteRechargeRequestsLocationOnlyRouteRecording;

  /// Create form: "Walk, run or ride the Route. Points stay encrypted on this d".
  ///
  /// In en, this message translates to:
  /// **'Walk, run or ride the Route. Points stay encrypted on this device until you apply the track.'**
  String get createRouteWalkRunRideRoutePointsStay;

  /// Create form: "Recording ready".
  ///
  /// In en, this message translates to:
  /// **'Recording ready'**
  String get createRouteRecordingReady;

  /// Create form: "Processing track…".
  ///
  /// In en, this message translates to:
  /// **'Processing track…'**
  String get createRouteProcessingTrack;

  /// Create form: "Recovering recording…".
  ///
  /// In en, this message translates to:
  /// **'Recovering recording…'**
  String get createRouteRecoveringRecording;

  /// Create form: "Recording paused".
  ///
  /// In en, this message translates to:
  /// **'Recording paused'**
  String get createRouteRecordingPaused;

  /// Create form: "Recording Route".
  ///
  /// In en, this message translates to:
  /// **'Recording Route'**
  String get createRouteRecordingRoute;

  /// Create form: "Checking GPS access…".
  ///
  /// In en, this message translates to:
  /// **'Checking GPS access…'**
  String get createRouteCheckingGpsAccess;

  /// Create form: "Open app settings".
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get createRouteOpenAppSettings;

  /// Create form: "Recording is active".
  ///
  /// In en, this message translates to:
  /// **'Recording is active'**
  String get createRouteRecordingActive;

  /// Create form: "Connect directly".
  ///
  /// In en, this message translates to:
  /// **'Connect directly'**
  String get createRouteConnectDirectly;

  /// Route recording preview semantics: count track sections, total gaps.
  ///
  /// In en, this message translates to:
  /// **'Recorded Route preview: track sections {count}, gaps {total}'**
  String createRouteRecordedRoutePreviewTrackSectionsGaps(int count, int total);

  /// Create form: "Delete".
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get createRouteDelete;

  /// Create form: "The recovery journal and all recorded points will be removed".
  ///
  /// In en, this message translates to:
  /// **'The recovery journal and all recorded points will be removed.'**
  String get createRouteRecoveryJournalAllRecordedPointsWill;

  /// Create form: "Delete GPS recording?".
  ///
  /// In en, this message translates to:
  /// **'Delete GPS recording?'**
  String get createRouteDeleteGpsRecording;

  /// Create form: "Use this track".
  ///
  /// In en, this message translates to:
  /// **'Use this track'**
  String get createRouteUseTrack;

  /// Create form: "A Route must stay continuous. Confirm each straight connecti".
  ///
  /// In en, this message translates to:
  /// **'A Route must stay continuous. Confirm each straight connection or record the missing section again.'**
  String get createRouteRouteMustStayContinuousConfirmEach;

  /// Create form: "Track gaps".
  ///
  /// In en, this message translates to:
  /// **'Track gaps'**
  String get createRouteTrackGaps;

  /// Create form: "Hide route end".
  ///
  /// In en, this message translates to:
  /// **'Hide route end'**
  String get createRouteHideRouteEnd;

  /// Create form: "Hide route start".
  ///
  /// In en, this message translates to:
  /// **'Hide route start'**
  String get createRouteHideRouteStart;

  /// Create form: "Privacy trim".
  ///
  /// In en, this message translates to:
  /// **'Privacy trim'**
  String get createRoutePrivacyTrim;

  /// Create form: "Review recorded track".
  ///
  /// In en, this message translates to:
  /// **'Review recorded track'**
  String get createRouteReviewRecordedTrack;

  /// Create form: "Delete recording".
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get createRouteDeleteRecording;

  /// Create form: "Finish and review".
  ///
  /// In en, this message translates to:
  /// **'Finish and review'**
  String get createRouteFinishReview;

  /// Create form: "Resume recording".
  ///
  /// In en, this message translates to:
  /// **'Resume recording'**
  String get createRouteResumeRecording;

  /// Create form: "Finish".
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get createRouteFinish;

  /// Create form: "Pause".
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get createRoutePause;

  /// Create form: "Start recording".
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get createRouteStartRecording;

  /// Create form: "Requires background location permission and shows a system i".
  ///
  /// In en, this message translates to:
  /// **'Requires background location permission and shows a system indicator.'**
  String get createRouteRequiresBackgroundLocationPermissionShowsSystem;

  /// Create form: "Continue while screen is locked".
  ///
  /// In en, this message translates to:
  /// **'Continue while the screen is locked'**
  String get createRouteContinueWhileScreenLocked;

  /// Create form: "Recovered safely after the previous session. Review before r".
  ///
  /// In en, this message translates to:
  /// **'Recovered safely after the previous session. Review before resuming.'**
  String get createRouteRecoveredSafelyAfterPreviousSessionReview;

  /// Create form: "Remove waypoint".
  ///
  /// In en, this message translates to:
  /// **'Remove waypoint'**
  String get createRouteRemoveWaypoint;

  /// Create form: "Attach to anchor".
  ///
  /// In en, this message translates to:
  /// **'Attach to anchor'**
  String get createRouteAttachAnchor;

  /// Create form: "Add a viewpoint from an anchor menu.".
  ///
  /// In en, this message translates to:
  /// **'Add a viewpoint from an anchor menu.'**
  String get createRouteAddViewpointFromAnchorMenu;

  /// Create form: "Split at midpoint".
  ///
  /// In en, this message translates to:
  /// **'Split at midpoint'**
  String get createRouteSplitAtMidpoint;

  /// Create form: "Use intentional direct line".
  ///
  /// In en, this message translates to:
  /// **'Use intentional direct line'**
  String get createRouteUseIntentionalDirectLine;

  /// Create form: "Retry routing".
  ///
  /// In en, this message translates to:
  /// **'Retry routing'**
  String get createRouteRetryRouting;

  /// Create form: "Segment actions".
  ///
  /// In en, this message translates to:
  /// **'Segment actions'**
  String get createRouteSegmentActions;

  /// Create form: "Remove anchor".
  ///
  /// In en, this message translates to:
  /// **'Remove anchor'**
  String get createRouteRemoveAnchor;

  /// Create form: "Add viewpoint".
  ///
  /// In en, this message translates to:
  /// **'Add viewpoint'**
  String get createRouteAddViewpoint;

  /// Create form: "Anchor actions".
  ///
  /// In en, this message translates to:
  /// **'Anchor actions'**
  String get createRouteAnchorActions;

  /// Create form: "Move anchor east".
  ///
  /// In en, this message translates to:
  /// **'Move anchor east'**
  String get createRouteMoveAnchorEast;

  /// Create form: "Move anchor west".
  ///
  /// In en, this message translates to:
  /// **'Move anchor west'**
  String get createRouteMoveAnchorWest;

  /// Create form: "Move anchor south".
  ///
  /// In en, this message translates to:
  /// **'Move anchor south'**
  String get createRouteMoveAnchorSouth;

  /// Create form: "Move anchor north".
  ///
  /// In en, this message translates to:
  /// **'Move anchor north'**
  String get createRouteMoveAnchorNorth;

  /// Create form: "No anchors yet.".
  ///
  /// In en, this message translates to:
  /// **'No anchors yet.'**
  String get createRouteNoAnchorsYet;

  /// Create form: "Every action is available as a labelled control.".
  ///
  /// In en, this message translates to:
  /// **'Every action is available as a labelled control.'**
  String get createRouteEveryActionAvailableAsLabelledControl;

  /// Create form: "Add anchor".
  ///
  /// In en, this message translates to:
  /// **'Add anchor'**
  String get createRouteAddAnchor;

  /// Create form: "Longitude".
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get createRouteLongitude;

  /// Create form: "Latitude".
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get createRouteLatitude;

  /// Create form: "Coordinates provide a keyboard and screen-reader alternative".
  ///
  /// In en, this message translates to:
  /// **'Coordinates provide a keyboard and screen-reader alternative.'**
  String get createRouteCoordinatesProvideKeyboardScreenReaderAlternative;

  /// Create form: "Add anchor without map gestures".
  ///
  /// In en, this message translates to:
  /// **'Add anchor without map gestures'**
  String get createRouteAddAnchorWithoutMapGestures;

  /// Create form: "Last saved".
  ///
  /// In en, this message translates to:
  /// **'Last saved'**
  String get createRouteLastSaved;

  /// Create form: "Redo".
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get createRouteRedo;

  /// Create form: "Undo".
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get createRouteUndo;

  /// Create form: "Tap the map to add anchors. The local graph connects them al".
  ///
  /// In en, this message translates to:
  /// **'Tap the map to add anchors. The local graph connects them along available trails.'**
  String get createRouteTapMapAddAnchorsLocalGraph;

  /// Create form: "Draw one continuous line. Existing geometry is replaced only".
  ///
  /// In en, this message translates to:
  /// **'Draw one continuous line. Existing geometry is replaced only after confirmation.'**
  String get createRouteDrawOneContinuousLineExistingGeometry;

  /// Create form: "Offline trail editor".
  ///
  /// In en, this message translates to:
  /// **'Offline trail editor'**
  String get createRouteOfflineTrailEditor;

  /// Create form: "The selected difficulty differs from the calculated recommen".
  ///
  /// In en, this message translates to:
  /// **'The selected difficulty differs from the calculated recommendation and requires review.'**
  String get createRouteSelectedDifficultyDiffersFromCalculatedRecommendation;

  /// Create form: "Route quality".
  ///
  /// In en, this message translates to:
  /// **'Route quality'**
  String get createRouteRouteQuality;

  /// Create form: "Your profile does not have permission to submit this Route.".
  ///
  /// In en, this message translates to:
  /// **'Your profile does not have permission to submit this Route.'**
  String get createRouteYourProfileDoesNotHavePermission;

  /// Create form: "Submit Route for review".
  ///
  /// In en, this message translates to:
  /// **'Submit Route for review'**
  String get createRouteSubmitRouteReview;

  /// Create form: "Publish Route".
  ///
  /// In en, this message translates to:
  /// **'Publish Route'**
  String get createRoutePublishRoute;

  /// Create form: "Restore last saved revision".
  ///
  /// In en, this message translates to:
  /// **'Restore last saved revision'**
  String get createRouteRestoreLastSavedRevision;

  /// Create form: "Save draft".
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get createRouteSaveDraft;

  /// Create form: "Routing in progress…".
  ///
  /// In en, this message translates to:
  /// **'Routing in progress…'**
  String get createRouteRoutingProgress;

  /// Create form: "Investor demo: this version uses the bundled offline trail g".
  ///
  /// In en, this message translates to:
  /// **'Demo: this version uses the bundled offline trail graph and is marked demo-only. No paid routing call is made.'**
  String get createRouteInvestorDemoVersionUsesBundledOffline;

  /// Create form: "Route draft is structurally ready".
  ///
  /// In en, this message translates to:
  /// **'Route draft is structurally ready'**
  String get createRouteRouteDraftStructurallyReady;

  /// Create form: "Offline trail map. Tap to add a route anchor.".
  ///
  /// In en, this message translates to:
  /// **'Offline trail map. Tap to add a route anchor.'**
  String get createRouteOfflineTrailMapTapAddRoute;

  /// Create form: "Offline trail map. Draw a continuous route with one finger.".
  ///
  /// In en, this message translates to:
  /// **'Offline trail map. Draw a continuous route with one finger.'**
  String get createRouteOfflineTrailMapDrawContinuousRoute;

  /// Create form: "No Route versions are waiting for review.".
  ///
  /// In en, this message translates to:
  /// **'No Route versions are waiting for review.'**
  String get createRouteNoRouteVersionsAreWaitingReview;

  /// Create form: "The moderate.route capability is required.".
  ///
  /// In en, this message translates to:
  /// **'You need permission to moderate routes.'**
  String get createRouteModerateRouteCapabilityRequired;

  /// Create form: "Reject".
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get createRouteReject;

  /// Create form: "Reason code or concise reason".
  ///
  /// In en, this message translates to:
  /// **'Reason code or concise reason'**
  String get createRouteReasonCodeConciseReason;

  /// Create form: "Reject Route version".
  ///
  /// In en, this message translates to:
  /// **'Reject Route version'**
  String get createRouteRejectRouteVersion;

  /// Create form: "Approve".
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get createRouteApprove;

  /// Create form: "Accept".
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get createRouteAccept;

  /// Create form: "Defer".
  ///
  /// In en, this message translates to:
  /// **'Defer'**
  String get createRouteDefer;

  /// Create form: "Confirm".
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get createRouteConfirm;

  /// Create form: "Reason code".
  ///
  /// In en, this message translates to:
  /// **'Reason code'**
  String get createRouteReasonCode;

  /// Create form: "Safety decision reason".
  ///
  /// In en, this message translates to:
  /// **'Safety decision reason'**
  String get createRouteSafetyDecisionReason;

  /// Create form: "Candidate decision reason".
  ///
  /// In en, this message translates to:
  /// **'Candidate decision reason'**
  String get createRouteCandidateDecisionReason;

  /// Create form: "A new Route revision draft was created. Published geometry w".
  ///
  /// In en, this message translates to:
  /// **'A new Route revision draft was created. Published geometry was not changed.'**
  String get createRouteNewRouteRevisionDraftWasCreated;

  /// Create form: "Safety reports".
  ///
  /// In en, this message translates to:
  /// **'Safety reports'**
  String get createRouteSafetyReports;

  /// Create form: "Map update candidates".
  ///
  /// In en, this message translates to:
  /// **'Map update candidates'**
  String get createRouteMapUpdateCandidates;

  /// Create form: "Publication review".
  ///
  /// In en, this message translates to:
  /// **'Publication review'**
  String get createRoutePublicationReview;

  /// Create form: "Refresh".
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get createRouteRefresh;

  /// Create form: "Route moderation".
  ///
  /// In en, this message translates to:
  /// **'Route moderation'**
  String get createRouteRouteModeration;

  /// Create form: "Planned schedule, not live.".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule, not live.'**
  String get createScenarioPlannedScheduleNotLive;

  /// Create form: "Planned service selected for preview. Not applied to Scenari".
  ///
  /// In en, this message translates to:
  /// **'Planned service selected for preview. Not applied to Scenario.'**
  String get createScenarioPlannedServiceSelectedPreviewNotApplied;

  /// Create form: "No direct planned services found.".
  ///
  /// In en, this message translates to:
  /// **'No direct planned services found.'**
  String get createScenarioNoDirectPlannedServicesFound;

  /// Create form: "Searching direct planned services.".
  ///
  /// In en, this message translates to:
  /// **'Searching direct planned services.'**
  String get createScenarioSearchingDirectPlannedServices;

  /// Create form: "Schedule search failed. Try again.".
  ///
  /// In en, this message translates to:
  /// **'Schedule search failed. Try again.'**
  String get createScenarioScheduleSearchFailedTryAgain;

  /// Create form: "Stop search failed. Try again.".
  ///
  /// In en, this message translates to:
  /// **'Stop search failed. Try again.'**
  String get createScenarioStopSearchFailedTryAgain;

  /// Create form: "Complete the provider, stops, date and time selection.".
  ///
  /// In en, this message translates to:
  /// **'Complete the provider, stops, date and time selection.'**
  String get createScenarioCompleteProviderStopsDateTimeSelection;

  /// Create form: "The new schedule could not be saved. Existing cache was kept".
  ///
  /// In en, this message translates to:
  /// **'The new schedule could not be saved. Existing cache was kept.'**
  String get createScenarioNewScheduleCouldNotSavedExisting;

  /// Create form: "The cached schedule could not be read.".
  ///
  /// In en, this message translates to:
  /// **'The cached schedule could not be read.'**
  String get createScenarioCachedScheduleCouldNotRead2;

  /// Create form: "The downloaded schedule is invalid and was not saved.".
  ///
  /// In en, this message translates to:
  /// **'The downloaded schedule is invalid and was not saved.'**
  String get createScenarioDownloadedScheduleInvalidWasNotSaved;

  /// Create form: "The schedule could not be downloaded.".
  ///
  /// In en, this message translates to:
  /// **'The schedule could not be downloaded.'**
  String get createScenarioScheduleCouldNotDownloaded;

  /// Create form: "You appear to be offline. Cached data remains available.".
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Cached data remains available.'**
  String get createScenarioYouAppearOfflineCachedDataRemains;

  /// Create form: "Schedule downloads are disabled. Cached data remains availab".
  ///
  /// In en, this message translates to:
  /// **'Schedule downloads are disabled. Cached data remains available.'**
  String get createScenarioScheduleDownloadsAreDisabledCachedData;

  /// Create form: "Download or select a usable cached schedule first.".
  ///
  /// In en, this message translates to:
  /// **'Download or select a usable cached schedule first.'**
  String get createScenarioDownloadSelectUsableCachedScheduleFirst;

  /// Create form: "Choose a valid schedule provider.".
  ///
  /// In en, this message translates to:
  /// **'Choose a valid schedule provider.'**
  String get createScenarioChooseValidScheduleProvider;

  /// Create form: "No official schedule providers are configured.".
  ///
  /// In en, this message translates to:
  /// **'No official schedule providers are configured.'**
  String get createScenarioNoOfficialScheduleProvidersAreConfigured;

  /// Create form: "Official schedule is temporarily unavailable.".
  ///
  /// In en, this message translates to:
  /// **'Official schedule is temporarily unavailable.'**
  String get createScenarioOfficialScheduleTemporarilyUnavailable;

  /// Create form: "Cached schedule could not be read.".
  ///
  /// In en, this message translates to:
  /// **'Cached schedule could not be read.'**
  String get createScenarioCachedScheduleCouldNotRead;

  /// Create form: "Cached schedule is damaged and cannot be used.".
  ///
  /// In en, this message translates to:
  /// **'Cached schedule is damaged and cannot be used.'**
  String get createScenarioCachedScheduleDamagedCannotUsed;

  /// Create form: "No schedule is downloaded for this provider.".
  ///
  /// In en, this message translates to:
  /// **'No schedule is downloaded for this provider.'**
  String get createScenarioNoScheduleDownloadedProvider;

  /// Create form: "Cached schedule freshness is unknown. Recheck before travel.".
  ///
  /// In en, this message translates to:
  /// **'Cached schedule freshness is unknown. Recheck before travel.'**
  String get createScenarioCachedScheduleFreshnessUnknownRecheckBefore;

  /// Create form: "Checking cached schedule…".
  ///
  /// In en, this message translates to:
  /// **'Checking cached schedule…'**
  String get createScenarioCheckingCachedSchedule;

  /// Create form: "Planned schedule · not live. This selection is not yet appli".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule · not live. This selection is not yet applied to the Scenario.'**
  String get createScenarioPlannedScheduleNotLiveSelectionNot;

  /// Create form: "Selection preview".
  ///
  /// In en, this message translates to:
  /// **'Selection preview'**
  String get createScenarioSelectionPreview;

  /// Create form: "Schedule search failed.".
  ///
  /// In en, this message translates to:
  /// **'Schedule search failed.'**
  String get createScenarioScheduleSearchFailed;

  /// Create form: "No direct services found after the selected time.".
  ///
  /// In en, this message translates to:
  /// **'No direct services found after the selected time.'**
  String get createScenarioNoDirectServicesFoundAfterSelected;

  /// Create form: "Choose date".
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get createScenarioChooseDate;

  /// Create form: "Scenario date is missing".
  ///
  /// In en, this message translates to:
  /// **'Scenario date is missing'**
  String get createScenarioScenarioDateMissing;

  /// Create form: "Retry".
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get createScenarioRetry;

  /// Create form: "Use cached".
  ///
  /// In en, this message translates to:
  /// **'Use cached'**
  String get createScenarioUseCached;

  /// Create form: "Update schedule".
  ///
  /// In en, this message translates to:
  /// **'Update schedule'**
  String get createScenarioUpdateSchedule;

  /// Create form: "Download schedule".
  ///
  /// In en, this message translates to:
  /// **'Download schedule'**
  String get createScenarioDownloadSchedule;

  /// Create form: "Schedule provider".
  ///
  /// In en, this message translates to:
  /// **'Schedule provider'**
  String get createScenarioScheduleProvider;

  /// Create form: "Official schedule providers are unavailable.".
  ///
  /// In en, this message translates to:
  /// **'Official schedule providers are unavailable.'**
  String get createScenarioOfficialScheduleProvidersAreUnavailable;

  /// Create form: "Planned schedule · not live. Delays, tickets, fares, seats a".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule · not live. Delays, tickets, fares, seats and transfers are not confirmed. Recheck before travel.'**
  String get createScenarioPlannedScheduleNotLiveDelaysTickets;

  /// Create form: "Enter schedule manually".
  ///
  /// In en, this message translates to:
  /// **'Enter schedule manually'**
  String get createScenarioEnterScheduleManually;

  /// Create form: "Apply creates one undoable Scenario change.".
  ///
  /// In en, this message translates to:
  /// **'Apply creates one undoable Scenario change.'**
  String get createScenarioApplyCreatesOneUndoableScenarioChange;

  /// Create form: "This service has no valid stop coordinates and cannot be app".
  ///
  /// In en, this message translates to:
  /// **'This service has no valid stop coordinates and cannot be applied safely.'**
  String get createScenarioServiceHasNoValidStopCoordinates;

  /// Create form: "Apply to Scenario".
  ///
  /// In en, this message translates to:
  /// **'Apply to Scenario'**
  String get createScenarioApplyScenario;

  /// Create form: "Choose a date to check the official schedule.".
  ///
  /// In en, this message translates to:
  /// **'Choose a date to check the official schedule.'**
  String get createScenarioChooseDateCheckOfficialSchedule;

  /// Create form: "Find direct services".
  ///
  /// In en, this message translates to:
  /// **'Find direct services'**
  String get createScenarioFindDirectServices;

  /// Create form: "Download a schedule before searching for stops.".
  ///
  /// In en, this message translates to:
  /// **'Download a schedule before searching for stops.'**
  String get createScenarioDownloadScheduleBeforeSearchingStops;

  /// Create form: "Destination".
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get createScenarioDestination;

  /// Create form: "Origin".
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get createScenarioOrigin;

  /// Create form: "Close official schedule".
  ///
  /// In en, this message translates to:
  /// **'Close official schedule'**
  String get createScenarioCloseOfficialSchedule;

  /// Create form: "Official schedule".
  ///
  /// In en, this message translates to:
  /// **'Official schedule'**
  String get createScenarioOfficialSchedule;

  /// Create form: "Static timetable snapshot · not live.".
  ///
  /// In en, this message translates to:
  /// **'Static timetable snapshot · not live.'**
  String get createScenarioStaticTimetableSnapshotNotLive;

  /// Create form: "Find in official schedule".
  ///
  /// In en, this message translates to:
  /// **'Find in official schedule'**
  String get createScenarioFindOfficialSchedule;

  /// Create form: "Works offline and stays editable.".
  ///
  /// In en, this message translates to:
  /// **'Works offline and stays editable.'**
  String get createScenarioWorksOfflineStaysEditable;

  /// Create form: "Enter manually".
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get createScenarioEnterManually;

  /// Create form: "Add planned transport".
  ///
  /// In en, this message translates to:
  /// **'Add planned transport'**
  String get createScenarioAddPlannedTransport;

  /// Create form: "Public transport".
  ///
  /// In en, this message translates to:
  /// **'Public transport'**
  String get createScenarioPublicTransport;

  /// Create form: "Own car".
  ///
  /// In en, this message translates to:
  /// **'Own car'**
  String get createScenarioOwnCar;

  /// Create form: "Provider value".
  ///
  /// In en, this message translates to:
  /// **'Provider value'**
  String get createScenarioProviderValue;

  /// Create form: "Estimated time".
  ///
  /// In en, this message translates to:
  /// **'Estimated time'**
  String get createScenarioEstimatedTime;

  /// Create form: "Entered manually".
  ///
  /// In en, this message translates to:
  /// **'Entered manually'**
  String get createScenarioEnteredManually;

  /// Create form: "Planned schedule · not live".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule · not live'**
  String get createScenarioPlannedScheduleNotLive2;

  /// Create form: "Custom location".
  ///
  /// In en, this message translates to:
  /// **'Custom location'**
  String get createScenarioCustomLocation;

  /// Create form: "Planned transport".
  ///
  /// In en, this message translates to:
  /// **'Planned transport'**
  String get createScenarioPlannedTransport;

  /// Create form: "Add at least two independent stops. Use catalog objects or c".
  ///
  /// In en, this message translates to:
  /// **'Add at least two independent stops. Use catalog objects or custom time blocks.'**
  String get createScenarioAddAtLeastTwoIndependentStops;

  /// Create form: "Location data required for a manual leg".
  ///
  /// In en, this message translates to:
  /// **'Location data required for a manual leg'**
  String get createScenarioLocationDataRequiredManualLeg;

  /// Create form: "Scenario changed. Recheck before replacing.".
  ///
  /// In en, this message translates to:
  /// **'Scenario changed. Recheck before replacing.'**
  String get createScenarioScenarioChangedRecheckBeforeReplacing;

  /// Create form: "Saved schedule replaced.".
  ///
  /// In en, this message translates to:
  /// **'Saved schedule replaced.'**
  String get createScenarioSavedScheduleReplaced;

  /// Create form: "Recheck schedule".
  ///
  /// In en, this message translates to:
  /// **'Recheck schedule'**
  String get createScenarioRecheckSchedule;

  /// Create form: "Scenario changed. Review the service and try again.".
  ///
  /// In en, this message translates to:
  /// **'Scenario changed. Review the service and try again.'**
  String get createScenarioScenarioChangedReviewServiceTryAgain;

  /// Create form: "Official schedule added to Scenario.".
  ///
  /// In en, this message translates to:
  /// **'Official schedule added to Scenario.'**
  String get createScenarioOfficialScheduleAddedScenario;

  /// Create form: "Review".
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get createScenarioReview;

  /// Create form: "Use your primary transport or enter honest manual values.".
  ///
  /// In en, this message translates to:
  /// **'Use your primary transport or enter honest manual values.'**
  String get createScenarioUseYourPrimaryTransportEnterHonest;

  /// Create form: "Travel between stops".
  ///
  /// In en, this message translates to:
  /// **'Travel between stops'**
  String get createScenarioTravelBetweenStops;

  /// Create form: "Time lock".
  ///
  /// In en, this message translates to:
  /// **'Time lock'**
  String get createScenarioTimeLock;

  /// Create form: "Order lock".
  ///
  /// In en, this message translates to:
  /// **'Order lock'**
  String get createScenarioOrderLock;

  /// Create form: "Optional".
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get createScenarioOptional;

  /// Create form: "Mandatory".
  ///
  /// In en, this message translates to:
  /// **'Mandatory'**
  String get createScenarioMandatory;

  /// Create form: "Remove".
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get createScenarioRemove;

  /// Create form: "Move down".
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get createScenarioMoveDown;

  /// Create form: "Move up".
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get createScenarioMoveUp;

  /// Create form: "Add custom time block".
  ///
  /// In en, this message translates to:
  /// **'Add custom time block'**
  String get createScenarioAddCustomTimeBlock;

  /// Create form: "Bus and train times are stored as planned schedule · not liv".
  ///
  /// In en, this message translates to:
  /// **'Bus and train times are stored as planned schedule · not live.'**
  String get createScenarioBusTrainTimesAreStoredAs;

  /// Create form: "Add custom stop".
  ///
  /// In en, this message translates to:
  /// **'Add custom stop'**
  String get createScenarioAddCustomStop;

  /// Create form: "Add".
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get createScenarioAdd;

  /// Create form: "Find a catalog place, event, activity or Route".
  ///
  /// In en, this message translates to:
  /// **'Find a catalog place, event, activity or Route'**
  String get createScenarioFindCatalogPlaceEventActivityRoute;

  /// Create form: "Redo".
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get createScenarioRedo;

  /// Create form: "Undo".
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get createScenarioUndo;

  /// Create form: "Feed retrieved at".
  ///
  /// In en, this message translates to:
  /// **'Feed retrieved at'**
  String get createScenarioFeedRetrievedAt;

  /// Create form: "Feed version".
  ///
  /// In en, this message translates to:
  /// **'Feed version'**
  String get createScenarioFeedVersion;

  /// Create form: "Service label".
  ///
  /// In en, this message translates to:
  /// **'Service label'**
  String get createScenarioServiceLabel;

  /// Create form: "Arrival time".
  ///
  /// In en, this message translates to:
  /// **'Arrival time'**
  String get createScenarioArrivalTime;

  /// Create form: "Departure time".
  ///
  /// In en, this message translates to:
  /// **'Departure time'**
  String get createScenarioDepartureTime;

  /// Create form: "Destination stop".
  ///
  /// In en, this message translates to:
  /// **'Destination stop'**
  String get createScenarioDestinationStop;

  /// Create form: "Origin stop".
  ///
  /// In en, this message translates to:
  /// **'Origin stop'**
  String get createScenarioOriginStop;

  /// Create form: "Service calendar".
  ///
  /// In en, this message translates to:
  /// **'Service calendar'**
  String get createScenarioServiceCalendar;

  /// Create form: "The saved item was kept unchanged and cannot be rechecked au".
  ///
  /// In en, this message translates to:
  /// **'The saved item was kept unchanged and cannot be rechecked automatically.'**
  String get createScenarioSavedItemWasKeptUnchangedCannot;

  /// Create form: "The saved item was kept unchanged because cached schedule da".
  ///
  /// In en, this message translates to:
  /// **'The saved item was kept unchanged because cached schedule data is unavailable.'**
  String get createScenarioSavedItemWasKeptUnchangedBecause;

  /// Create form: "The saved item was kept unchanged. Recheck later or enter tr".
  ///
  /// In en, this message translates to:
  /// **'The saved item was kept unchanged. Recheck later or enter transport manually.'**
  String get createScenarioSavedItemWasKeptUnchangedRecheck;

  /// Create form: "Review every difference before replacing the saved snapshot.".
  ///
  /// In en, this message translates to:
  /// **'Review every difference before replacing the saved snapshot.'**
  String get createScenarioReviewEveryDifferenceBeforeReplacingSaved;

  /// Create form: "The cached official schedule matches the saved snapshot. It ".
  ///
  /// In en, this message translates to:
  /// **'The cached official schedule matches the saved snapshot. It is still not live.'**
  String get createScenarioCachedOfficialScheduleMatchesSavedSnapshot;

  /// Create form: "Saved data is incomplete".
  ///
  /// In en, this message translates to:
  /// **'Saved data is incomplete'**
  String get createScenarioSavedDataIncomplete;

  /// Create form: "Recheck unavailable".
  ///
  /// In en, this message translates to:
  /// **'Recheck unavailable'**
  String get createScenarioRecheckUnavailable;

  /// Create form: "Service not found".
  ///
  /// In en, this message translates to:
  /// **'Service not found'**
  String get createScenarioServiceNotFound;

  /// Create form: "No schedule changes found".
  ///
  /// In en, this message translates to:
  /// **'No schedule changes found'**
  String get createScenarioNoScheduleChangesFound;

  /// Create form: "Close".
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get createScenarioClose;

  /// Create form: "Replace saved schedule".
  ///
  /// In en, this message translates to:
  /// **'Replace saved schedule'**
  String get createScenarioReplaceSavedSchedule;

  /// Create form: "Planned schedule · not live. Replace changes only the saved ".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule · not live. Replace changes only the saved snapshot after explicit confirmation.'**
  String get createScenarioPlannedScheduleNotLiveReplaceChanges;

  /// Create form: "Changes in the cached official schedule".
  ///
  /// In en, this message translates to:
  /// **'Changes in the cached official schedule'**
  String get createScenarioChangesCachedOfficialSchedule;

  /// Create form: "Close schedule recheck".
  ///
  /// In en, this message translates to:
  /// **'Close schedule recheck'**
  String get createScenarioCloseScheduleRecheck;

  /// Create form: "Schedule recheck".
  ///
  /// In en, this message translates to:
  /// **'Schedule recheck'**
  String get createScenarioScheduleRecheck;

  /// Create form: "Discard".
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get createScenarioDiscard;

  /// Create form: "Edit prompt".
  ///
  /// In en, this message translates to:
  /// **'Edit prompt'**
  String get createScenarioEditPrompt;

  /// Create form: "Still unverified".
  ///
  /// In en, this message translates to:
  /// **'Still unverified'**
  String get createScenarioStillUnverified;

  /// Create form: "Preview readiness: needs your review".
  ///
  /// In en, this message translates to:
  /// **'Preview readiness: needs your review'**
  String get createScenarioPreviewReadinessNeedsYourReview;

  /// Create form: "Preview readiness: ready to review".
  ///
  /// In en, this message translates to:
  /// **'Preview readiness: ready to review'**
  String get createScenarioPreviewReadinessReadyReview;

  /// Create form: "Catalog snapshot".
  ///
  /// In en, this message translates to:
  /// **'Catalog snapshot'**
  String get createScenarioCatalogSnapshot;

  /// Create form: "Proposed stops".
  ///
  /// In en, this message translates to:
  /// **'Proposed stops'**
  String get createScenarioProposedStops;

  /// Create form: "Generate preview".
  ///
  /// In en, this message translates to:
  /// **'Generate preview'**
  String get createScenarioGeneratePreview;

  /// Create form: "Building preview…".
  ///
  /// In en, this message translates to:
  /// **'Building preview…'**
  String get createScenarioBuildingPreview;

  /// Create form: "Use an example".
  ///
  /// In en, this message translates to:
  /// **'Use an example'**
  String get createScenarioUseExample;

  /// Create form: "A relaxed afternoon in Riga with culture and dinner".
  ///
  /// In en, this message translates to:
  /// **'A relaxed afternoon in Riga with culture and dinner'**
  String get createScenarioRelaxedAfternoonRigaWithCultureDinner;

  /// Create form: "What would you like to do?".
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get createScenarioWhatWouldYouLikeDo;

  /// Create form: "Describe the mood and priorities. This demo uses only the lo".
  ///
  /// In en, this message translates to:
  /// **'Describe the mood and priorities. This demo uses only the local Recharge catalog; it does not call an external AI.'**
  String get createScenarioDescribeMoodPrioritiesDemoUsesOnly;

  /// Create form: "Local demo".
  ///
  /// In en, this message translates to:
  /// **'Local demo'**
  String get createScenarioLocalDemo;

  /// Create form: "Build with AI".
  ///
  /// In en, this message translates to:
  /// **'Build with AI'**
  String get createScenarioBuildWithAi;

  /// Create form: "Save travel".
  ///
  /// In en, this message translates to:
  /// **'Save travel'**
  String get createScenarioSaveTravel;

  /// Create form: "Travel mode".
  ///
  /// In en, this message translates to:
  /// **'Travel mode'**
  String get createScenarioTravelMode;

  /// Create form: "Manual values stay locked until you edit them.".
  ///
  /// In en, this message translates to:
  /// **'Manual values stay locked until you edit them.'**
  String get createScenarioManualValuesStayLockedUntilYou;

  /// Create form: "Add to Scenario".
  ///
  /// In en, this message translates to:
  /// **'Add to Scenario'**
  String get createScenarioAddScenario;

  /// Create form: "Service or route *".
  ///
  /// In en, this message translates to:
  /// **'Service or route *'**
  String get createScenarioServiceRoute;

  /// Create form: "Transport".
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get createScenarioTransport;

  /// Create form: "Planned schedule · not live. Recheck the service before trav".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule · not live. Recheck the service before travel.'**
  String get createScenarioPlannedScheduleNotLiveRecheckService;

  /// Create form: "Primary transport".
  ///
  /// In en, this message translates to:
  /// **'Primary transport'**
  String get createScenarioPrimaryTransport;

  /// Create form: "Own car is fully supported. Public transport uses planned sc".
  ///
  /// In en, this message translates to:
  /// **'Own car is fully supported. Public transport uses planned schedules, not live data.'**
  String get createScenarioOwnCarFullySupportedPublicTransport;

  /// Create form: "How will you travel?".
  ///
  /// In en, this message translates to:
  /// **'How will you travel?'**
  String get createScenarioHowWillYouTravel;

  /// Create form: "Budget basis".
  ///
  /// In en, this message translates to:
  /// **'Budget basis'**
  String get createScenarioBudgetBasis;

  /// Create form: "Pace".
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get createScenarioPace;

  /// Create form: "People".
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get createScenarioPeople;

  /// Create form: "Party".
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get createScenarioParty;

  /// Create form: "Dated trip".
  ///
  /// In en, this message translates to:
  /// **'Dated trip'**
  String get createScenarioDatedTrip;

  /// Create form: "Flexible template".
  ///
  /// In en, this message translates to:
  /// **'Flexible template'**
  String get createScenarioFlexibleTemplate;

  /// Create form: "Format".
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get createScenarioFormat;

  /// Create form: "Scenario title *".
  ///
  /// In en, this message translates to:
  /// **'Scenario title *'**
  String get createScenarioScenarioTitle;

  /// Create form: "Public and unlisted Scenario publishing remains disabled unt".
  ///
  /// In en, this message translates to:
  /// **'Public and unlisted Scenario publishing remains disabled until publisher capabilities and moderation are implemented.'**
  String get createScenarioPublicUnlistedScenarioPublishingRemainsDisabled;

  /// Create form: "Planned schedule · not live. Recheck departures, delays and ".
  ///
  /// In en, this message translates to:
  /// **'Planned schedule · not live. Recheck departures, delays and cancellations before travel.'**
  String get createScenarioPlannedScheduleNotLiveRecheckDepartures;

  /// Create form: "This action saves a personal Scenario. It does not publish i".
  ///
  /// In en, this message translates to:
  /// **'This action saves a personal Scenario. It does not publish it to the catalog.'**
  String get createScenarioActionSavesPersonalScenarioDoesNot;

  /// Create form: "Ready for My Scenarios".
  ///
  /// In en, this message translates to:
  /// **'Ready for My Scenarios'**
  String get createScenarioReadyMyScenarios;

  /// Create form: "Warnings".
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get createScenarioWarnings;

  /// Create form: "Unknown travel".
  ///
  /// In en, this message translates to:
  /// **'Unknown travel'**
  String get createScenarioUnknownTravel;

  /// Create form: "Time blocks".
  ///
  /// In en, this message translates to:
  /// **'Time blocks'**
  String get createScenarioTimeBlocks;

  /// Create form: "Activity".
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get createScenarioActivity;

  /// Create form: "Active stops".
  ///
  /// In en, this message translates to:
  /// **'Active stops'**
  String get createScenarioActiveStops;

  /// Create form: "Scenario data is unavailable.".
  ///
  /// In en, this message translates to:
  /// **'Scenario data is unavailable.'**
  String get createScenarioScenarioDataUnavailable;

  /// Create form: "Save to My Scenarios".
  ///
  /// In en, this message translates to:
  /// **'Save to My Scenarios'**
  String get createScenarioSaveMyScenarios;

  /// Create form: "Back".
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get createScenarioBack;

  /// Create form: "Expanded from a Quick Plan as an independent copy. Legacy st".
  ///
  /// In en, this message translates to:
  /// **'Expanded from a Quick Plan as an independent copy. Legacy stops are private custom locations until you review them.'**
  String get createScenarioExpandedFromQuickPlanAsIndependent;

  /// Create form: "Build a city, day, weekend or trip plan from independent sto".
  ///
  /// In en, this message translates to:
  /// **'Build a city, day, weekend or trip plan from independent stops. A Scenario is not a Route and does not change a Quick Plan.'**
  String get createScenarioBuildCityDayWeekendTripPlan;

  /// Create form: "Scenario plan".
  ///
  /// In en, this message translates to:
  /// **'Scenario plan'**
  String get createScenarioScenarioPlan;

  /// Create form: "Title".
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get createScenarioTitle;

  /// Create form: "Use coordinates for any location in Latvia. The stop stays p".
  ///
  /// In en, this message translates to:
  /// **'Use coordinates for any location in Latvia. The stop stays private by default.'**
  String get createScenarioUseCoordinatesAnyLocationLatviaStop;

  /// Create form: "Add time block".
  ///
  /// In en, this message translates to:
  /// **'Add time block'**
  String get createScenarioAddTimeBlock;

  /// Create form: "Feed SHA-256".
  ///
  /// In en, this message translates to:
  /// **'Feed SHA-256'**
  String get createScenarioFeedSha256;

  /// Create form: "Feed retrieved".
  ///
  /// In en, this message translates to:
  /// **'Feed retrieved'**
  String get createScenarioFeedRetrieved2;

  /// Create form: "Licence".
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get createScenarioLicence;

  /// Create form: "Stops".
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get createScenarioStops;

  /// Create form: "Planned time".
  ///
  /// In en, this message translates to:
  /// **'Planned time'**
  String get createScenarioPlannedTime;

  /// Create form: "Service date".
  ///
  /// In en, this message translates to:
  /// **'Service date'**
  String get createScenarioServiceDate;

  /// Create form: "Provider".
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get createScenarioProvider;

  /// Find People private preview: exact address label.
  ///
  /// In en, this message translates to:
  /// **'Exact address'**
  String get createFindPeopleExactAddressLabel;

  /// Find People private preview: exact point label.
  ///
  /// In en, this message translates to:
  /// **'Exact point'**
  String get createFindPeopleExactGeoLabel;

  /// Find People private preview: online access reference label.
  ///
  /// In en, this message translates to:
  /// **'Online access reference'**
  String get createFindPeopleOnlineAccessLabel;

  /// Find People private preview: value not set.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get createFindPeopleNotSet;

  /// Find People private preview: value configured (hidden).
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get createFindPeopleConfigured;

  /// Scenario transit: the selection is only a preview.
  ///
  /// In en, this message translates to:
  /// **'Selection preview only. Scenario is unchanged.'**
  String get createScenarioSelectionPreviewUnchanged;

  /// Scenario AI preview: activity time; value is a localized duration.
  ///
  /// In en, this message translates to:
  /// **'Activity time: {value}'**
  String createScenarioActivityTime(String value);

  /// Duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String createScenarioDurationMinutes(int count);

  /// Duration in hours.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String createScenarioDurationHours(int count);

  /// Duration in hours (start) and minutes (end).
  ///
  /// In en, this message translates to:
  /// **'{start} h {end} min'**
  String createScenarioDurationHoursMinutes(int start, int end);

  /// Scenario transit option: duration and the planned/not-live mark.
  ///
  /// In en, this message translates to:
  /// **'{count} min · Planned schedule · not live'**
  String createScenarioMinutesNotLive(int count);

  /// Scenario transit: when the feed was retrieved (UTC as saved).
  ///
  /// In en, this message translates to:
  /// **'Feed retrieved {value}'**
  String createScenarioFeedRetrievedLine(String value);

  /// Scenario transit cache: current.
  ///
  /// In en, this message translates to:
  /// **'Cached schedule is current.'**
  String get createScenarioCacheCurrent;

  /// Scenario transit cache: current, retrieved at value (UTC).
  ///
  /// In en, this message translates to:
  /// **'Cached schedule is current · {value}.'**
  String createScenarioCacheCurrentAt(String value);

  /// Scenario transit cache: stale.
  ///
  /// In en, this message translates to:
  /// **'Cached schedule is stale. You may use it with a warning or update it.'**
  String get createScenarioCacheStale;

  /// Scenario transit cache: stale, retrieved at value (UTC).
  ///
  /// In en, this message translates to:
  /// **'Cached schedule is stale · {value}. You may use it with a warning or update it.'**
  String createScenarioCacheStaleAt(String value);

  /// Create findPeople step "activity" title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get createStepFindPeopleActivityTitle;

  /// Create findPeople step "activity" description.
  ///
  /// In en, this message translates to:
  /// **'Describe what you want to do and who it suits.'**
  String get createStepFindPeopleActivityDescription;

  /// Create findPeople step "schedule" title.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get createStepFindPeopleScheduleTitle;

  /// Create findPeople step "schedule" description.
  ///
  /// In en, this message translates to:
  /// **'Choose one time, a poll, or a finite recurring series.'**
  String get createStepFindPeopleScheduleDescription;

  /// Create findPeople step "meeting" title.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get createStepFindPeopleMeetingTitle;

  /// Create findPeople step "meeting" description.
  ///
  /// In en, this message translates to:
  /// **'Keep the public area separate from private meeting details.'**
  String get createStepFindPeopleMeetingDescription;

  /// Create findPeople step "group" title.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get createStepFindPeopleGroupTitle;

  /// Create findPeople step "group" description.
  ///
  /// In en, this message translates to:
  /// **'Set capacity, applications, verification, waitlist, and costs.'**
  String get createStepFindPeopleGroupDescription;

  /// Create findPeople step "hosts" title.
  ///
  /// In en, this message translates to:
  /// **'Hosts & access'**
  String get createStepFindPeopleHostsTitle;

  /// Create findPeople step "hosts" description.
  ///
  /// In en, this message translates to:
  /// **'Configure publisher, visibility, communication, and sharing.'**
  String get createStepFindPeopleHostsDescription;

  /// Create findPeople step "publish" title.
  ///
  /// In en, this message translates to:
  /// **'Preview & publish'**
  String get createStepFindPeoplePublishTitle;

  /// Create findPeople step "publish" description.
  ///
  /// In en, this message translates to:
  /// **'Review public/private data and complete safety confirmations.'**
  String get createStepFindPeoplePublishDescription;

  /// Create route step "method" title.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get createStepRouteMethodTitle;

  /// Create route step "method" description.
  ///
  /// In en, this message translates to:
  /// **'Choose how the continuous track is created'**
  String get createStepRouteMethodDescription;

  /// Create route step "profile" title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get createStepRouteProfileTitle;

  /// Create route step "profile" description.
  ///
  /// In en, this message translates to:
  /// **'Set movement profile and routing preferences'**
  String get createStepRouteProfileDescription;

  /// Create route step "editor" title.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get createStepRouteEditorTitle;

  /// Create route step "editor" description.
  ///
  /// In en, this message translates to:
  /// **'Edit anchors and continuous route segments'**
  String get createStepRouteEditorDescription;

  /// Create route step "details" title.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get createStepRouteDetailsTitle;

  /// Create route step "details" description.
  ///
  /// In en, this message translates to:
  /// **'Add route conditions and practical information'**
  String get createStepRouteDetailsDescription;

  /// Create route step "review" title.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get createStepRouteReviewTitle;

  /// Create route step "review" description.
  ///
  /// In en, this message translates to:
  /// **'Review geometry, warnings and readiness'**
  String get createStepRouteReviewDescription;

  /// Create session step "whatWhere" title.
  ///
  /// In en, this message translates to:
  /// **'What and where'**
  String get createStepSessionWhatWhereTitle;

  /// Create session step "whatWhere" description.
  ///
  /// In en, this message translates to:
  /// **'Resource, category, media, location, timezone'**
  String get createStepSessionWhatWhereDescription;

  /// Create session step "when" title.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get createStepSessionWhenTitle;

  /// Create session step "when" description.
  ///
  /// In en, this message translates to:
  /// **'Weekly schedule, duration, buffer, notice'**
  String get createStepSessionWhenDescription;

  /// Create session step "priceAndBooking" title.
  ///
  /// In en, this message translates to:
  /// **'Price and booking'**
  String get createStepSessionPriceAndBookingTitle;

  /// Create session step "priceAndBooking" description.
  ///
  /// In en, this message translates to:
  /// **'Price, max party size, external booking URL'**
  String get createStepSessionPriceAndBookingDescription;

  /// Create classWorkshop step "basics" title.
  ///
  /// In en, this message translates to:
  /// **'Offering'**
  String get createStepClassWorkshopBasicsTitle;

  /// Create classWorkshop step "basics" description.
  ///
  /// In en, this message translates to:
  /// **'Kind, title, descriptions, category, criteria and media'**
  String get createStepClassWorkshopBasicsDescription;

  /// Create classWorkshop step "learning" title.
  ///
  /// In en, this message translates to:
  /// **'Programme and instructor'**
  String get createStepClassWorkshopLearningTitle;

  /// Create classWorkshop step "learning" description.
  ///
  /// In en, this message translates to:
  /// **'Outcomes, programme, prerequisites and instructor'**
  String get createStepClassWorkshopLearningDescription;

  /// Create classWorkshop step "schedule" title.
  ///
  /// In en, this message translates to:
  /// **'Dates and place'**
  String get createStepClassWorkshopScheduleTitle;

  /// Create classWorkshop step "schedule" description.
  ///
  /// In en, this message translates to:
  /// **'Single class or fixed series, timezone, delivery, place'**
  String get createStepClassWorkshopScheduleDescription;

  /// Create classWorkshop step "participation" title.
  ///
  /// In en, this message translates to:
  /// **'Participation'**
  String get createStepClassWorkshopParticipationTitle;

  /// Create classWorkshop step "participation" description.
  ///
  /// In en, this message translates to:
  /// **'Materials, requirements, group size, price, enrollment'**
  String get createStepClassWorkshopParticipationDescription;

  /// Create scenario step "context" title.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get createStepScenarioContextTitle;

  /// Create scenario step "context" description.
  ///
  /// In en, this message translates to:
  /// **'Format, date mode, party, pace and budget'**
  String get createStepScenarioContextDescription;

  /// Create scenario step "composer" title.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get createStepScenarioComposerTitle;

  /// Create scenario step "composer" description.
  ///
  /// In en, this message translates to:
  /// **'Independent stops, time blocks and their order'**
  String get createStepScenarioComposerDescription;

  /// Create scenario step "review" title.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get createStepScenarioReviewTitle;

  /// Create scenario step "review" description.
  ///
  /// In en, this message translates to:
  /// **'Totals, warnings and personal save readiness'**
  String get createStepScenarioReviewDescription;

  /// Session schedule preset: every day 9:00–21:00.
  ///
  /// In en, this message translates to:
  /// **'Every day 9:00–21:00'**
  String get createSessionPresetEveryday;

  /// Session schedule preset: weekdays 9:00–18:00.
  ///
  /// In en, this message translates to:
  /// **'Weekdays 9:00–18:00'**
  String get createSessionPresetWeekdays;

  /// Find People house rule; value is the stable rule id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, be_on_time{Be on time}respect_boundaries{Respect boundaries}no_harassment{No harassment}no_sales{No sales}no_substances{No alcohol or drugs}bring_required_gear{Bring required gear}follow_venue_rules{Follow venue rules}leave_no_trace{Leave no trace} other{Rule}}'**
  String createFindPeopleHouseRule(String value);

  /// Find People co-host right; value is the stable capability id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, review_applications{Review applications}manage_schedule{Manage schedule}manage_participants{Manage participants}moderate_conversation{Moderate conversation} other{Right}}'**
  String createFindPeopleCohostRight(String value);

  /// Find People co-host invitation accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get createFindPeopleCohostAccepted;

  /// Find People co-host invitation pending.
  ///
  /// In en, this message translates to:
  /// **'Invitation pending'**
  String get createFindPeopleCohostPending;

  /// Find People field: seat-fit policy.
  ///
  /// In en, this message translates to:
  /// **'Seat-fit policy'**
  String get createFindPeopleSeatFitPolicy;

  /// Find People field: visibility (required).
  ///
  /// In en, this message translates to:
  /// **'Visibility *'**
  String get createFindPeopleVisibilityRequired;

  /// Create field: a date in YYYY-MM-DD.
  ///
  /// In en, this message translates to:
  /// **'Date (YYYY-MM-DD)'**
  String get createFormDateIso;

  /// Class: ambiguous local time — take the first (summer time) instance.
  ///
  /// In en, this message translates to:
  /// **'First (summer time)'**
  String get createClassFirstSummerTime;

  /// Route shape: out and back.
  ///
  /// In en, this message translates to:
  /// **'Out & back'**
  String get createRouteOutAndBack;

  /// Scenario item editor: edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get createScenarioEdit;

  /// Scenario time block title hint.
  ///
  /// In en, this message translates to:
  /// **'Coffee, rest, free time…'**
  String get createScenarioTimeBlockHint;

  /// Scenario review: private or local travel.
  ///
  /// In en, this message translates to:
  /// **'Private / local travel'**
  String get createScenarioPrivateLocalTravel;

  /// Scenario recheck field: route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get createScenarioRouteLabel;

  /// Scenario recheck field: carrier.
  ///
  /// In en, this message translates to:
  /// **'Carrier'**
  String get createScenarioCarrierLabel;

  /// Scenario stop search: the selected stop; value is the stop name from the feed.
  ///
  /// In en, this message translates to:
  /// **'Selected: {value}'**
  String createScenarioSelectedStop(String value);

  /// Scenario transport field: departure HH:mm.
  ///
  /// In en, this message translates to:
  /// **'Departure (HH:mm)'**
  String get createScenarioDepartureHhMm;

  /// Scenario transport field: arrival HH:mm.
  ///
  /// In en, this message translates to:
  /// **'Arrival (HH:mm)'**
  String get createScenarioArrivalHhMm;

  /// Route moderation: resolve and restore.
  ///
  /// In en, this message translates to:
  /// **'Resolve & restore'**
  String get createRouteResolveRestore;

  /// Route moderation: resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get createRouteResolve;

  /// Add to Scenario: notice for a stable intake code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, targetsUnavailable{Scenarios are unavailable. Retry from Details.}chooseTarget{Choose a Scenario or create a new one.}targetNotEditable{This Scenario is no longer editable.}titleRequired{Enter a Scenario title.}openFailed{Could not open this Scenario.}signInAgain{Sign in again before adding items to Scenario.}confirmDuplicate{Confirm adding another occurrence.}confirmUnavailable{Confirm use of the unavailable saved snapshot.}confirmScheduleAdjustment{Confirm conversion to a flexible template stop.}revisionConflict{Scenario changed. Go back, reopen it and review again.}intentExpired{This selection expired. Return to Details and try again.}targetGone{This Scenario is no longer available. Choose another one.}lockedLegBoundary{A locked logistics leg protects this insertion point.}persistenceUnavailable{Could not save. Your selection is retained; retry Apply.} other{Could not add this object. Review the selection and retry.}}'**
  String scenarioIntakeNotice(String code);

  /// Add to Scenario: catalog object type of a selected stop (stable value).
  ///
  /// In en, this message translates to:
  /// **'{value, select, event{Event}place{Place}activity{Activity}route{Route}bookableSession{Session} other{Object}}'**
  String scenarioIntakeObjectType(String value);

  /// Add to Scenario: source status of a selected stop (stable value).
  ///
  /// In en, this message translates to:
  /// **'{value, select, ready{Ready}stale{Needs refresh}unresolved{Not resolved}unavailable{Unavailable} other{Unknown}}'**
  String scenarioIntakeSourceStatus(String value);

  /// Add to Scenario cannot start from this surface or selection.
  ///
  /// In en, this message translates to:
  /// **'Add to Scenario is unavailable.'**
  String get scenarioIntakeUnavailable;

  /// Add to Scenario sheet title.
  ///
  /// In en, this message translates to:
  /// **'Add to Scenario'**
  String get scenarioIntakeTitle;

  /// Add to Scenario: close button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close Add to Scenario'**
  String get scenarioIntakeClose;

  /// Add to Scenario: target step heading.
  ///
  /// In en, this message translates to:
  /// **'Choose a personal Scenario'**
  String get scenarioIntakeChooseTarget;

  /// Add to Scenario: which targets are listed.
  ///
  /// In en, this message translates to:
  /// **'Only your editable private drafts are shown.'**
  String get scenarioIntakeOnlyPrivateDrafts;

  /// Add to Scenario: no target yet.
  ///
  /// In en, this message translates to:
  /// **'No saved Scenario yet. Create one below.'**
  String get scenarioIntakeNoTargets;

  /// Add to Scenario: target without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get scenarioIntakeUntitled;

  /// Add to Scenario: create a new target.
  ///
  /// In en, this message translates to:
  /// **'Create new Scenario'**
  String get scenarioIntakeCreateNew;

  /// Add to Scenario: what the new target is.
  ///
  /// In en, this message translates to:
  /// **'Private · one day · saved only with the stop'**
  String get scenarioIntakeCreateNewHint;

  /// Add to Scenario: new Scenario title field.
  ///
  /// In en, this message translates to:
  /// **'Scenario title'**
  String get scenarioIntakeTitleField;

  /// Add to Scenario: go to placement.
  ///
  /// In en, this message translates to:
  /// **'Continue to placement'**
  String get scenarioIntakeContinue;

  /// Add to Scenario: target title when none is known.
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get scenarioIntakeScenarioFallback;

  /// Add to Scenario: day field.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get scenarioIntakeDay;

  /// Add to Scenario: not tied to a day.
  ///
  /// In en, this message translates to:
  /// **'Unscheduled'**
  String get scenarioIntakeUnscheduled;

  /// Add to Scenario: insertion point field.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get scenarioIntakeInsert;

  /// Add to Scenario: insert at the end of the day.
  ///
  /// In en, this message translates to:
  /// **'At end'**
  String get scenarioIntakeAtEnd;

  /// Add to Scenario: stop role heading.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get scenarioIntakeRole;

  /// Add to Scenario: mandatory stop.
  ///
  /// In en, this message translates to:
  /// **'Mandatory'**
  String get scenarioIntakeMandatory;

  /// Add to Scenario: optional stop.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get scenarioIntakeOptional;

  /// Add to Scenario: back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get scenarioIntakeBack;

  /// Add to Scenario: go to review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get scenarioIntakeReview;

  /// Add to Scenario: confirm a duplicate occurrence.
  ///
  /// In en, this message translates to:
  /// **'Add another occurrence'**
  String get scenarioIntakeAddAnother;

  /// Add to Scenario: why a duplicate is asked about.
  ///
  /// In en, this message translates to:
  /// **'This exact catalog object already exists in the Scenario.'**
  String get scenarioIntakeAddAnotherHint;

  /// Add to Scenario: confirm using an unavailable saved snapshot.
  ///
  /// In en, this message translates to:
  /// **'Use saved unavailable snapshot'**
  String get scenarioIntakeUseUnavailable;

  /// Add to Scenario: confirm converting to a flexible template stop.
  ///
  /// In en, this message translates to:
  /// **'Use as a flexible template stop'**
  String get scenarioIntakeUseTemplateStop;

  /// Add to Scenario: why a template stop is asked about.
  ///
  /// In en, this message translates to:
  /// **'The source has a fixed date, but this Scenario is a template.'**
  String get scenarioIntakeUseTemplateStopHint;

  /// Add to Scenario: logistics are not recalculated.
  ///
  /// In en, this message translates to:
  /// **'Logistics are not recalculated live. Existing unlocked boundary estimates will be invalidated safely.'**
  String get scenarioIntakeLogisticsNotice;

  /// Add to Scenario: apply button with the number of stops.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String scenarioIntakeAddCount(int count);

  /// Add to Scenario: stop duration unknown.
  ///
  /// In en, this message translates to:
  /// **'Duration unknown'**
  String get scenarioIntakeDurationUnknown;

  /// Add to Scenario: fixed start of a stop, formatted in the object zone.
  ///
  /// In en, this message translates to:
  /// **'Fixed {time}'**
  String scenarioIntakeFixedStart(String time);

  /// Add to Scenario: move a stop up.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get scenarioIntakeMoveUp;

  /// Add to Scenario: move a stop down.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get scenarioIntakeMoveDown;

  /// Add to Scenario: screen reader text while stops are added.
  ///
  /// In en, this message translates to:
  /// **'Adding selected stops to Scenario'**
  String get scenarioIntakeApplyingSemantics;

  /// Add to Scenario: screen reader text while targets load.
  ///
  /// In en, this message translates to:
  /// **'Loading your Scenarios'**
  String get scenarioIntakeLoadingSemantics;

  /// Add to Scenario: progress text while stops are added.
  ///
  /// In en, this message translates to:
  /// **'Adding to Scenario…'**
  String get scenarioIntakeApplying;

  /// Add to Scenario: progress text while targets load.
  ///
  /// In en, this message translates to:
  /// **'Loading your Scenarios…'**
  String get scenarioIntakeLoading;

  /// Add to Scenario: the same request was already saved.
  ///
  /// In en, this message translates to:
  /// **'Already saved · no duplicate was created.'**
  String get scenarioIntakeReplayed;

  /// Add to Scenario: stay on the current page.
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get scenarioIntakeStay;

  /// Add to Scenario: open the target Scenario.
  ///
  /// In en, this message translates to:
  /// **'Open Scenario'**
  String get scenarioIntakeOpenScenario;

  /// Add to Scenario: the sheet could not be prepared.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare Add to Scenario.'**
  String get scenarioIntakePrepareFailed;

  /// Add to Scenario: retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get scenarioIntakeRetry;

  /// Add to Scenario target summary: template Scenario without dates.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get scenarioIntakeTemplate;

  /// Add to Scenario target summary: dated Scenario without a known first date.
  ///
  /// In en, this message translates to:
  /// **'Dated'**
  String get scenarioIntakeDated;

  /// Discover: "Расписание".
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get discoverSchedule;

  /// Discover: "Show on map".
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get discoverShowOnMap;

  /// Discover: "Читать далее".
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get discoverReadMore;

  /// Discover: "Свернуть".
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get discoverShowLess;

  /// Discover: "Точный адрес не опубликован".
  ///
  /// In en, this message translates to:
  /// **'Exact address not published'**
  String get discoverExactAddressNotPublished;

  /// Discover: "Место не опубликовано".
  ///
  /// In en, this message translates to:
  /// **'Location not published'**
  String get discoverLocationNotPublished;

  /// Discover: "Ссылка предоставляется сервисом бронирования".
  ///
  /// In en, this message translates to:
  /// **'The link comes from the booking service'**
  String get discoverLinkFromBookingService;

  /// Discover: "Онлайн".
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get discoverOnline;

  /// Discover: "Фактическое время и условия подтверждаются на сайте партнёра".
  ///
  /// In en, this message translates to:
  /// **'The actual time and terms are confirmed on the partner’s website.'**
  String get discoverPartnerConfirmsTime;

  /// Discover: "Время для записи".
  ///
  /// In en, this message translates to:
  /// **'Times to book'**
  String get discoverTimesToBook;

  /// Discover: "Расписание требует обновления — проверьте время на сайте.".
  ///
  /// In en, this message translates to:
  /// **'The schedule needs a refresh — check the time on the website.'**
  String get discoverScheduleNeedsRefresh;

  /// Discover: "В текущем окне время не указано.".
  ///
  /// In en, this message translates to:
  /// **'No time is listed in the current window.'**
  String get discoverNoTimeInWindow;

  /// Discover: "Координаты недоступны публично".
  ///
  /// In en, this message translates to:
  /// **'Coordinates are not public'**
  String get discoverCoordinatesNotPublic;

  /// Discover: "Данные доступа не публикуются".
  ///
  /// In en, this message translates to:
  /// **'Access details are not published'**
  String get discoverAccessDetailsNotPublished;

  /// Discover: "Приблизительная публичная зона встречи".
  ///
  /// In en, this message translates to:
  /// **'Approximate public meeting area'**
  String get discoverApproximateMeetingArea;

  /// Discover: "Free".
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get discoverFree;

  /// Discover: "Гибридный формат".
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get discoverHybrid;

  /// Discover: "Оффлайн".
  ///
  /// In en, this message translates to:
  /// **'In person'**
  String get discoverInPerson;

  /// Discover: "Проверить запись на сайте".
  ///
  /// In en, this message translates to:
  /// **'Check enrollment on the website'**
  String get discoverCheckEnrollmentOnSite;

  /// Discover: "Запись через приложение пока не подключена".
  ///
  /// In en, this message translates to:
  /// **'In-app enrollment is not connected yet'**
  String get discoverInAppEnrollmentUnavailable;

  /// Discover: "Способ записи пока не указан".
  ///
  /// In en, this message translates to:
  /// **'Enrollment method not specified yet'**
  String get discoverEnrollmentMethodUnknown;

  /// Discover: "Условия участия уточняются на месте".
  ///
  /// In en, this message translates to:
  /// **'Terms of participation are confirmed on site'**
  String get discoverTermsOnSite;

  /// Discover: "Запись закрыта".
  ///
  /// In en, this message translates to:
  /// **'Enrollment closed'**
  String get discoverEnrollmentClosed;

  /// Discover: "Наличие мест, итоговая стоимость и условия — на сайте органи".
  ///
  /// In en, this message translates to:
  /// **'Availability, final price and terms are on the organizer’s website'**
  String get discoverAvailabilityOnOrganizerSite;

  /// Discover: "Место уточняется".
  ///
  /// In en, this message translates to:
  /// **'Location to be confirmed'**
  String get discoverLocationTbc;

  /// Discover: "Инструкции предоставит организатор".
  ///
  /// In en, this message translates to:
  /// **'The organizer will send instructions'**
  String get discoverOrganizerSendsInstructions;

  /// Discover: "Онлайн-занятие".
  ///
  /// In en, this message translates to:
  /// **'Online class'**
  String get discoverOnlineClass;

  /// Discover: "Организатор подтверждён".
  ///
  /// In en, this message translates to:
  /// **'Organizer verified'**
  String get discoverOrganizerVerified;

  /// Discover: "Профиль подтверждён".
  ///
  /// In en, this message translates to:
  /// **'Profile verified'**
  String get discoverProfileVerified;

  /// Discover: "Преподаватель".
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get discoverTeacher;

  /// Discover: "Длительность занятия".
  ///
  /// In en, this message translates to:
  /// **'Session duration'**
  String get discoverSessionDuration;

  /// Discover: "Длительность курса".
  ///
  /// In en, this message translates to:
  /// **'Course duration'**
  String get discoverCourseDuration;

  /// Discover: "Цена".
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get discoverPrice;

  /// Discover: "Цена за человека / курс".
  ///
  /// In en, this message translates to:
  /// **'Price per person / course'**
  String get discoverPricePerPersonCourse;

  /// Discover: "Цена за человека / занятие".
  ///
  /// In en, this message translates to:
  /// **'Price per person / session'**
  String get discoverPricePerPersonSession;

  /// Discover: "Даты уточняются".
  ///
  /// In en, this message translates to:
  /// **'Dates to be confirmed'**
  String get discoverDatesTbc;

  /// Discover: "Практический опыт".
  ///
  /// In en, this message translates to:
  /// **'Hands-on experience'**
  String get discoverKindHandsOn;

  /// Discover: "Курс".
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get discoverKindCourse;

  /// Discover: "Мастер-класс".
  ///
  /// In en, this message translates to:
  /// **'Masterclass'**
  String get discoverKindMasterclass;

  /// Discover: "Воркшоп".
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get discoverKindWorkshop;

  /// Discover: "Занятие".
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get discoverKindClass;

  /// Discover: "Набор завершён".
  ///
  /// In en, this message translates to:
  /// **'Closed to new people'**
  String get discoverRecruitmentClosed;

  /// Discover: "Встреча отменена".
  ///
  /// In en, this message translates to:
  /// **'Meetup cancelled'**
  String get discoverMeetupCancelled;

  /// Discover: "Встреча завершена".
  ///
  /// In en, this message translates to:
  /// **'Meetup ended'**
  String get discoverMeetupEnded;

  /// Discover: "Группа заполнена".
  ///
  /// In en, this message translates to:
  /// **'Group is full'**
  String get discoverGroupFull;

  /// Discover: "Только лист ожидания".
  ///
  /// In en, this message translates to:
  /// **'Waitlist only'**
  String get discoverWaitlistOnly;

  /// Discover: "Набор открыт".
  ///
  /// In en, this message translates to:
  /// **'Open to join'**
  String get discoverRecruitmentOpen;

  /// Discover: "Собираются варианты времени".
  ///
  /// In en, this message translates to:
  /// **'Collecting time options'**
  String get discoverCollectingTimeOptions;

  /// Discover: "Delivery available".
  ///
  /// In en, this message translates to:
  /// **'Delivery available'**
  String get discoverDeliveryAvailable;

  /// Discover: "Deposit required".
  ///
  /// In en, this message translates to:
  /// **'Deposit required'**
  String get discoverDepositRequired;

  /// Discover: "No deposit required".
  ///
  /// In en, this message translates to:
  /// **'No deposit required'**
  String get discoverNoDepositRequired;

  /// Discover: "Price on request".
  ///
  /// In en, this message translates to:
  /// **'Price on request'**
  String get discoverPriceOnRequest;

  /// Discover: "Записаться".
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get discoverSignUp;

  /// Discover: "Добавить в календарь".
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get discoverAddToCalendar;

  /// Discover: "О событии".
  ///
  /// In en, this message translates to:
  /// **'About the event'**
  String get discoverAboutEvent;

  /// Discover: "Профиль".
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get discoverProfile;

  /// Discover: "Профиль клуба".
  ///
  /// In en, this message translates to:
  /// **'Club profile'**
  String get discoverClubProfile;

  /// Discover: "Организатор".
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get discoverOrganizer;

  /// Discover: "Duration".
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get discoverDuration;

  /// Discover: "Количество участников неизвестно".
  ///
  /// In en, this message translates to:
  /// **'Number of participants unknown'**
  String get discoverParticipantCountUnknown;

  /// Discover: "Участники".
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get discoverParticipants;

  /// Discover: "Add to Scenario".
  ///
  /// In en, this message translates to:
  /// **'Add to Scenario'**
  String get discoverAddToScenario;

  /// Discover: "Share".
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get discoverShare;

  /// Discover: "EVENT".
  ///
  /// In en, this message translates to:
  /// **'EVENT'**
  String get discoverBadgeEvent;

  /// Discover: "Currently unavailable".
  ///
  /// In en, this message translates to:
  /// **'Currently unavailable'**
  String get discoverCurrentlyUnavailable;

  /// Discover: "Confirm on provider site".
  ///
  /// In en, this message translates to:
  /// **'Confirm on provider site'**
  String get discoverConfirmOnProviderSite;

  /// Discover: "Rate plan".
  ///
  /// In en, this message translates to:
  /// **'Rate plan'**
  String get discoverRatePlan;

  /// Discover: "What is rented".
  ///
  /// In en, this message translates to:
  /// **'What is rented'**
  String get discoverWhatIsRented;

  /// Discover: "RENTAL".
  ///
  /// In en, this message translates to:
  /// **'RENTAL'**
  String get discoverBadgeRental;

  /// Discover: "Гибко".
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get discoverFlexible;

  /// Discover: "О занятии".
  ///
  /// In en, this message translates to:
  /// **'About the class'**
  String get discoverAboutClass;

  /// Discover: "Закрыто".
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get discoverClosed;

  /// Discover: "Часы работы".
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get discoverOpeningHours;

  /// Discover: "О месте".
  ///
  /// In en, this message translates to:
  /// **'About the place'**
  String get discoverAboutPlace;

  /// Discover: "Время".
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get discoverTime;

  /// Discover: "От вас".
  ///
  /// In en, this message translates to:
  /// **'From you'**
  String get discoverFromYou;

  /// Discover: "Об услуге".
  ///
  /// In en, this message translates to:
  /// **'About the service'**
  String get discoverAboutService;

  /// Discover: "Специалист".
  ///
  /// In en, this message translates to:
  /// **'Specialist'**
  String get discoverSpecialist;

  /// Discover: "Организация".
  ///
  /// In en, this message translates to:
  /// **'Organisation'**
  String get discoverOrganization;

  /// Discover: "Group size".
  ///
  /// In en, this message translates to:
  /// **'Group size'**
  String get discoverGroupSize;

  /// Discover: "Требования".
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get discoverRequirements;

  /// Discover: "Материалы и что включено".
  ///
  /// In en, this message translates to:
  /// **'Materials and what is included'**
  String get discoverMaterialsIncluded;

  /// Discover: "Расходы не указаны".
  ///
  /// In en, this message translates to:
  /// **'Costs not specified'**
  String get discoverCostsNotSpecified;

  /// Discover: "Без обязательных расходов".
  ///
  /// In en, this message translates to:
  /// **'No required costs'**
  String get discoverNoRequiredCosts;

  /// Discover: "Желаемый размер".
  ///
  /// In en, this message translates to:
  /// **'Desired size'**
  String get discoverDesiredSize;

  /// Discover: "Сейчас в группе".
  ///
  /// In en, this message translates to:
  /// **'In the group now'**
  String get discoverInGroupNow;

  /// Discover: "Ожидаемые расходы".
  ///
  /// In en, this message translates to:
  /// **'Expected costs'**
  String get discoverExpectedCosts;

  /// Discover: "Требования к участникам".
  ///
  /// In en, this message translates to:
  /// **'Participant requirements'**
  String get discoverParticipantRequirements;

  /// Discover: "Формат встречи".
  ///
  /// In en, this message translates to:
  /// **'Meetup format'**
  String get discoverMeetupFormat;

  /// Discover: "Время встречи".
  ///
  /// In en, this message translates to:
  /// **'Meetup time'**
  String get discoverMeetupTime;

  /// Discover: "Варианты времени".
  ///
  /// In en, this message translates to:
  /// **'Time options'**
  String get discoverTimeOptions;

  /// Discover: "О встрече".
  ///
  /// In en, this message translates to:
  /// **'About the meetup'**
  String get discoverAboutMeetup;

  /// Discover: "Публикатор".
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get discoverPublisher;

  /// Discover: "Поделиться и другие действия".
  ///
  /// In en, this message translates to:
  /// **'Share and more actions'**
  String get discoverShareAndMore;

  /// Discover: "Mark as visited".
  ///
  /// In en, this message translates to:
  /// **'Mark as visited'**
  String get discoverMarkVisited;

  /// Discover: "Create route".
  ///
  /// In en, this message translates to:
  /// **'Create route'**
  String get discoverCreateRoute;

  /// Discover: "Посмотреть маршрут".
  ///
  /// In en, this message translates to:
  /// **'View route'**
  String get discoverViewRoute;

  /// Discover: "Create similar".
  ///
  /// In en, this message translates to:
  /// **'Create similar'**
  String get discoverCreateSimilar;

  /// Discover: "Find similar".
  ///
  /// In en, this message translates to:
  /// **'Find similar'**
  String get discoverFindSimilar;

  /// Discover: "Проверить время на сайте".
  ///
  /// In en, this message translates to:
  /// **'Check the time on the website'**
  String get discoverCheckTimeOnSite;

  /// Discover: "Проверить и забронировать".
  ///
  /// In en, this message translates to:
  /// **'Review and book'**
  String get discoverReviewAndBook;

  /// Discover: "Request sent".
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get discoverRequestSent;

  /// Discover: "Date set".
  ///
  /// In en, this message translates to:
  /// **'Date set'**
  String get discoverDateSet;

  /// Discover: "Any date".
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get discoverAnyDate;

  /// Discover: "Done".
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get discoverDone;

  /// Discover: "Used as entered for time matching.".
  ///
  /// In en, this message translates to:
  /// **'Used as entered for time matching.'**
  String get discoverWindowAsEntered;

  /// Discover: "Effective window".
  ///
  /// In en, this message translates to:
  /// **'Effective window'**
  String get discoverEffectiveWindow;

  /// Discover: "Buffer on each side".
  ///
  /// In en, this message translates to:
  /// **'Buffer on each side'**
  String get discoverBufferEachSide;

  /// Discover: "End".
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get discoverEnd;

  /// Discover: "Start".
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get discoverStart;

  /// Discover: "Change date".
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get discoverChangeDate;

  /// Discover: "Flexible".
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get discoverFlexibleTime;

  /// Discover: "Exact".
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get discoverExact;

  /// Discover: "Back to filters".
  ///
  /// In en, this message translates to:
  /// **'Back to filters'**
  String get discoverBackToFilters;

  /// Discover: "Reset".
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get discoverReset;

  /// Discover: "Exact time".
  ///
  /// In en, this message translates to:
  /// **'Exact time'**
  String get discoverExactTime;

  /// Discover: "Apply filters".
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get discoverApplyFilters;

  /// Discover: "Include return trip".
  ///
  /// In en, this message translates to:
  /// **'Include return trip'**
  String get discoverIncludeReturnTrip;

  /// Discover: "Transit".
  ///
  /// In en, this message translates to:
  /// **'Public transport'**
  String get discoverTransit;

  /// Discover: "Driving".
  ///
  /// In en, this message translates to:
  /// **'Driving'**
  String get discoverDriving;

  /// Discover: "Walking".
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get discoverWalking;

  /// Discover: "Map point".
  ///
  /// In en, this message translates to:
  /// **'Map point'**
  String get discoverMapPoint;

  /// Discover: "Travel".
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get discoverTravel;

  /// Discover: "No buffer".
  ///
  /// In en, this message translates to:
  /// **'No buffer'**
  String get discoverNoBuffer;

  /// Discover: "Change flexibility".
  ///
  /// In en, this message translates to:
  /// **'Change flexibility'**
  String get discoverChangeFlexibility;

  /// Discover: "Window edge buffer".
  ///
  /// In en, this message translates to:
  /// **'Window edge buffer'**
  String get discoverWindowEdgeBuffer;

  /// Discover: "Today".
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get discoverToday;

  /// Discover: "When".
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get discoverWhen;

  /// Discover: "Save".
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get discoverSave;

  /// Discover: "Отмена".
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get discoverCancel;

  /// Discover: "Enter an amount from €0 to €10,000".
  ///
  /// In en, this message translates to:
  /// **'Enter an amount from €0 to €10,000'**
  String get discoverEnterBudget;

  /// Discover: "Amount in EUR".
  ///
  /// In en, this message translates to:
  /// **'Amount in EUR'**
  String get discoverAmountInEur;

  /// Discover: "Budget per person".
  ///
  /// In en, this message translates to:
  /// **'Budget per person'**
  String get discoverBudgetPerPerson;

  /// Discover: "Enter a number from 1 to 99".
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 99'**
  String get discoverEnterPeople;

  /// Discover: "For example, 6".
  ///
  /// In en, this message translates to:
  /// **'For example, 6'**
  String get discoverExampleSix;

  /// Discover: "Number of people".
  ///
  /// In en, this message translates to:
  /// **'Number of people'**
  String get discoverNumberOfPeople;

  /// Discover: "Any area".
  ///
  /// In en, this message translates to:
  /// **'Any area'**
  String get discoverAnyArea;

  /// Discover: "Any duration".
  ///
  /// In en, this message translates to:
  /// **'Any duration'**
  String get discoverAnyDuration;

  /// Discover: "Any distance".
  ///
  /// In en, this message translates to:
  /// **'Any distance'**
  String get discoverAnyDistance;

  /// Discover: "Only available".
  ///
  /// In en, this message translates to:
  /// **'Only available'**
  String get discoverOnlyAvailable;

  /// Discover: "Open now".
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get discoverOpenNow;

  /// Discover: "Time available".
  ///
  /// In en, this message translates to:
  /// **'Time available'**
  String get discoverTimeAvailable;

  /// Discover: "Search filters".
  ///
  /// In en, this message translates to:
  /// **'Search filters'**
  String get discoverSearchFilters;

  /// Discover: "Social evening".
  ///
  /// In en, this message translates to:
  /// **'Social evening'**
  String get discoverSocialEvening;

  /// Discover: "Active morning".
  ///
  /// In en, this message translates to:
  /// **'Active morning'**
  String get discoverActiveMorning;

  /// Discover: "Sunset break".
  ///
  /// In en, this message translates to:
  /// **'Sunset break'**
  String get discoverSunsetBreak;

  /// Discover: "After work".
  ///
  /// In en, this message translates to:
  /// **'After work'**
  String get discoverAfterWork;

  /// Discover: "Your regular searches will appear here automatically.".
  ///
  /// In en, this message translates to:
  /// **'Your regular searches will appear here automatically.'**
  String get discoverRegularSearchesHint;

  /// Discover: "Calm evening".
  ///
  /// In en, this message translates to:
  /// **'Calm evening'**
  String get discoverCalmEvening;

  /// Discover: "Low budget".
  ///
  /// In en, this message translates to:
  /// **'Low budget'**
  String get discoverLowBudget;

  /// Discover: "For two".
  ///
  /// In en, this message translates to:
  /// **'For two'**
  String get discoverForTwo;

  /// Discover: "Near me now".
  ///
  /// In en, this message translates to:
  /// **'Near me now'**
  String get discoverNearMeNow;

  /// Discover: "Apply radius".
  ///
  /// In en, this message translates to:
  /// **'Apply radius'**
  String get discoverApplyRadius;

  /// Discover: "Custom radius".
  ///
  /// In en, this message translates to:
  /// **'Custom radius'**
  String get discoverCustomRadius;

  /// Discover: "Search radius".
  ///
  /// In en, this message translates to:
  /// **'Search radius'**
  String get discoverSearchRadius;

  /// Discover: "Any budget".
  ///
  /// In en, this message translates to:
  /// **'Any budget'**
  String get discoverAnyBudget;

  /// Discover: "For example, 8".
  ///
  /// In en, this message translates to:
  /// **'For example, 8'**
  String get discoverExampleEight;

  /// Discover: "Just me".
  ///
  /// In en, this message translates to:
  /// **'Just me'**
  String get discoverJustMe;

  /// Discover: "Any group".
  ///
  /// In en, this message translates to:
  /// **'Any group'**
  String get discoverAnyGroup;

  /// Discover: "Choose search dates".
  ///
  /// In en, this message translates to:
  /// **'Choose search dates'**
  String get discoverChooseSearchDates;

  /// Discover: "Choose dates".
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get discoverChooseDates;

  /// Discover: "This weekend".
  ///
  /// In en, this message translates to:
  /// **'This weekend'**
  String get discoverThisWeekend;

  /// Discover: "Tomorrow".
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get discoverTomorrow;

  /// Discover: "Choose date".
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get discoverChooseDate;

  /// Discover: "Until end of day".
  ///
  /// In en, this message translates to:
  /// **'Until end of day'**
  String get discoverUntilEndOfDay;

  /// Discover: "Recent searches".
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get discoverRecentSearches;

  /// Discover: "Quick plans".
  ///
  /// In en, this message translates to:
  /// **'Quick plans'**
  String get discoverQuickPlans;

  /// Discover: "See all".
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get discoverSeeAll;

  /// Discover: "Search activity, place or plan".
  ///
  /// In en, this message translates to:
  /// **'Search activity, place or plan'**
  String get discoverSearchHint;

  /// Discover: "Search Recharge".
  ///
  /// In en, this message translates to:
  /// **'Search Recharge'**
  String get discoverSearchRecharge;

  /// Discover: "Join activity".
  ///
  /// In en, this message translates to:
  /// **'Join activity'**
  String get discoverJoinActivity;

  /// Discover: "Participants unknown".
  ///
  /// In en, this message translates to:
  /// **'Participants unknown'**
  String get discoverParticipantsUnknown;

  /// Discover: "Capacity unknown".
  ///
  /// In en, this message translates to:
  /// **'Capacity unknown'**
  String get discoverCapacityUnknown;

  /// Discover: "Opening hours unknown".
  ///
  /// In en, this message translates to:
  /// **'Opening hours unknown'**
  String get discoverOpeningHoursUnknown;

  /// Discover: "Time not confirmed".
  ///
  /// In en, this message translates to:
  /// **'Time not confirmed'**
  String get discoverTimeNotConfirmed;

  /// Discover: "Does not fit".
  ///
  /// In en, this message translates to:
  /// **'Does not fit'**
  String get discoverDoesNotFit;

  /// Discover: "Partial attendance possible".
  ///
  /// In en, this message translates to:
  /// **'Partial attendance possible'**
  String get discoverPartialAttendance;

  /// Discover: "Fits your time".
  ///
  /// In en, this message translates to:
  /// **'Fits your time'**
  String get discoverFitsYourTime;

  /// Discover: "Optional contribution".
  ///
  /// In en, this message translates to:
  /// **'Optional contribution'**
  String get discoverOptionalContribution;

  /// Discover: "No contribution specified".
  ///
  /// In en, this message translates to:
  /// **'No contribution specified'**
  String get discoverNoContribution;

  /// Discover: "Difficulty not set".
  ///
  /// In en, this message translates to:
  /// **'Difficulty not set'**
  String get discoverDifficultyNotSet;

  /// Discover: "Any time".
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get discoverAnyTime;

  /// Discover: "What awaits you".
  ///
  /// In en, this message translates to:
  /// **'What awaits you'**
  String get discoverWhatAwaitsYou;

  /// Discover: "Save the activity for later".
  ///
  /// In en, this message translates to:
  /// **'Save the activity for later'**
  String get discoverPerkSaveForLater;

  /// Discover: "Organizer details available before joining".
  ///
  /// In en, this message translates to:
  /// **'Organizer details available before joining'**
  String get discoverPerkOrganizerDetails;

  /// Discover: "Clear meeting point and timing".
  ///
  /// In en, this message translates to:
  /// **'Clear meeting point and timing'**
  String get discoverPerkMeetingPoint;

  /// Discover: "Расстояние".
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get discoverDistance;

  /// Discover: "Location".
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get discoverLocation;

  /// Discover: "Route geometry".
  ///
  /// In en, this message translates to:
  /// **'Route geometry'**
  String get discoverRouteGeometry;

  /// Discover: "Date and time".
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get discoverDateAndTime;

  /// Discover: "Route map".
  ///
  /// In en, this message translates to:
  /// **'Route map'**
  String get discoverRouteMap;

  /// Discover: "Route from this".
  ///
  /// In en, this message translates to:
  /// **'Route from this'**
  String get discoverRouteFromThis;

  /// Discover: "Add to private history".
  ///
  /// In en, this message translates to:
  /// **'Add to private history'**
  String get discoverAddToPrivateHistory;

  /// Discover: "Open Create Hub".
  ///
  /// In en, this message translates to:
  /// **'Open Create Hub'**
  String get discoverOpenCreateHub;

  /// Discover: "Search with this category".
  ///
  /// In en, this message translates to:
  /// **'Search with this category'**
  String get discoverSearchThisCategory;

  /// Discover: "Add this stop to a personal plan".
  ///
  /// In en, this message translates to:
  /// **'Add this stop to a personal plan'**
  String get discoverAddStopToPlan;

  /// Discover: "Open nearby context".
  ///
  /// In en, this message translates to:
  /// **'Open nearby context'**
  String get discoverOpenNearbyContext;

  /// Discover: "Map".
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get discoverMap;

  /// Discover: "Turn this activity into a route, compare similar options, or".
  ///
  /// In en, this message translates to:
  /// **'Turn this activity into a route, compare similar options, or save it for later.'**
  String get discoverPlanHint;

  /// Discover: "Not saved".
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get discoverNotSaved;

  /// Discover: "Plan this recharge".
  ///
  /// In en, this message translates to:
  /// **'Plan this recharge'**
  String get discoverPlanThisRecharge;

  /// Discover: "Отправить".
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get discoverSend;

  /// Discover: "Критическую опасность выбирайте только при непосредственном ".
  ///
  /// In en, this message translates to:
  /// **'Choose critical danger only when people are at immediate risk.'**
  String get discoverCriticalOnlyImmediateRisk;

  /// Discover: "Опишите проблему без личных данных".
  ///
  /// In en, this message translates to:
  /// **'Describe the problem without personal data'**
  String get discoverDescribeWithoutPersonalData;

  /// Discover: "Комментарий (необязательно)".
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get discoverCommentOptional;

  /// Discover: "Критическая опасность".
  ///
  /// In en, this message translates to:
  /// **'Critical danger'**
  String get discoverSeverityCritical;

  /// Discover: "Опасно".
  ///
  /// In en, this message translates to:
  /// **'Dangerous'**
  String get discoverSeverityDanger;

  /// Discover: "Требует внимания".
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get discoverSeverityWarning;

  /// Discover: "Информация".
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get discoverSeverityInfo;

  /// Discover: "Серьёзность".
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get discoverSeverity;

  /// Discover: "Другое".
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get discoverIssueOther;

  /// Discover: "Неверная линия маршрута".
  ///
  /// In en, this message translates to:
  /// **'Wrong route line'**
  String get discoverIssueWrongLine;

  /// Discover: "Препятствие".
  ///
  /// In en, this message translates to:
  /// **'Obstacle'**
  String get discoverIssueObstacle;

  /// Discover: "Опасное покрытие".
  ///
  /// In en, this message translates to:
  /// **'Hazardous surface'**
  String get discoverIssueHazardousSurface;

  /// Discover: "Тропа закрыта".
  ///
  /// In en, this message translates to:
  /// **'Trail closed'**
  String get discoverIssueTrailClosed;

  /// Discover: "Что произошло".
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get discoverWhatHappened;

  /// Discover: "Проблема на маршруте".
  ///
  /// In en, this message translates to:
  /// **'Problem on the route'**
  String get discoverRouteIssue;

  /// Discover: "Сообщить о проблеме на маршруте".
  ///
  /// In en, this message translates to:
  /// **'Report a problem on the route'**
  String get discoverReportRouteIssue;

  /// Discover: "Elevation data is unavailable and is not shown as zero.".
  ///
  /// In en, this message translates to:
  /// **'Elevation data is unavailable and is not shown as zero.'**
  String get discoverElevationUnavailable;

  /// Discover: "Elevation data is partial; ascent and descent are not presen".
  ///
  /// In en, this message translates to:
  /// **'Elevation data is partial; ascent and descent are not presented as complete.'**
  String get discoverElevationPartial;

  /// Discover: "Demo data".
  ///
  /// In en, this message translates to:
  /// **'Demo data'**
  String get discoverDemoData;

  /// Discover: "Field verified".
  ///
  /// In en, this message translates to:
  /// **'Field verified'**
  String get discoverFieldVerified;

  /// Discover: "Published Route".
  ///
  /// In en, this message translates to:
  /// **'Published Route'**
  String get discoverPublishedRoute;

  /// Discover: "Open details".
  ///
  /// In en, this message translates to:
  /// **'Open details'**
  String get discoverOpenDetails;

  /// Discover: "Select for Scenario".
  ///
  /// In en, this message translates to:
  /// **'Select for Scenario'**
  String get discoverSelectForScenario;

  /// Discover: "Any".
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get discoverAny;

  /// Discover: "Search this area".
  ///
  /// In en, this message translates to:
  /// **'Search this area'**
  String get discoverSearchThisArea;

  /// Discover: "Reset route progress".
  ///
  /// In en, this message translates to:
  /// **'Reset route progress'**
  String get discoverResetRouteProgress;

  /// Discover: "Start route".
  ///
  /// In en, this message translates to:
  /// **'Start route'**
  String get discoverStartRoute;

  /// Discover: "Next stop".
  ///
  /// In en, this message translates to:
  /// **'Next stop'**
  String get discoverNextStop;

  /// Discover: "Ready to start".
  ///
  /// In en, this message translates to:
  /// **'Ready to start'**
  String get discoverReadyToStart;

  /// Discover: "Route complete".
  ///
  /// In en, this message translates to:
  /// **'Route complete'**
  String get discoverRouteComplete;

  /// Discover: "Copy".
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get discoverCopy;

  /// Discover: "Create route listing".
  ///
  /// In en, this message translates to:
  /// **'Create route listing'**
  String get discoverCreateRouteListing;

  /// Discover: "Search similar route".
  ///
  /// In en, this message translates to:
  /// **'Search similar route'**
  String get discoverSearchSimilarRoute;

  /// Discover: "Edit route".
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get discoverEditRoute;

  /// Discover: "Scenario route".
  ///
  /// In en, this message translates to:
  /// **'Scenario route'**
  String get discoverScenarioRoute;

  /// Discover: "No activities in this area".
  ///
  /// In en, this message translates to:
  /// **'No activities in this area'**
  String get discoverNoActivitiesInArea;

  /// Discover: "Повторить".
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get discoverRetry;

  /// Discover: "Map search failed".
  ///
  /// In en, this message translates to:
  /// **'Map search failed'**
  String get discoverMapSearchFailed;

  /// Discover: "Map results".
  ///
  /// In en, this message translates to:
  /// **'Map results'**
  String get discoverMapResults;

  /// Discover: "Apply".
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get discoverApply;

  /// Discover: "Saved on map".
  ///
  /// In en, this message translates to:
  /// **'Saved on map'**
  String get discoverSavedOnMap;

  /// Discover: "Build route from smart search".
  ///
  /// In en, this message translates to:
  /// **'Build route from smart search'**
  String get discoverRouteFromSmart;

  /// Discover: "Create listing from smart search".
  ///
  /// In en, this message translates to:
  /// **'Create listing from smart search'**
  String get discoverCreateFromSmart;

  /// Discover: "Apply smart search to map".
  ///
  /// In en, this message translates to:
  /// **'Apply smart search to map'**
  String get discoverApplySmartToMap;

  /// Discover: "Smart".
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get discoverSmart;

  /// Discover: "Build route from saved conditions".
  ///
  /// In en, this message translates to:
  /// **'Build route from saved conditions'**
  String get discoverRouteFromSaved;

  /// Discover: "Create listing from saved conditions".
  ///
  /// In en, this message translates to:
  /// **'Create listing from saved conditions'**
  String get discoverCreateFromSaved;

  /// Discover: "Apply saved conditions to map".
  ///
  /// In en, this message translates to:
  /// **'Apply saved conditions to map'**
  String get discoverApplySavedToMap;

  /// Discover: "Saved".
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get discoverSaved;

  /// Discover: "Create here".
  ///
  /// In en, this message translates to:
  /// **'Create here'**
  String get discoverCreateHere;

  /// Discover: "Search".
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get discoverSearch;

  /// Discover: "Clear".
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get discoverClear;

  /// Discover: "Search on map".
  ///
  /// In en, this message translates to:
  /// **'Search on map'**
  String get discoverSearchOnMap;

  /// Discover: "Map area".
  ///
  /// In en, this message translates to:
  /// **'Map area'**
  String get discoverMapArea;

  /// Discover: "Recharge idea".
  ///
  /// In en, this message translates to:
  /// **'Recharge idea'**
  String get discoverRechargeIdea;

  /// Discover: "Map area idea".
  ///
  /// In en, this message translates to:
  /// **'Map area idea'**
  String get discoverMapAreaIdea;

  /// Discover: "Scenario copied".
  ///
  /// In en, this message translates to:
  /// **'Scenario copied'**
  String get discoverScenarioCopied;

  /// Discover: "Scenario saved".
  ///
  /// In en, this message translates to:
  /// **'Scenario saved'**
  String get discoverScenarioSaved;

  /// Discover: "Recenter".
  ///
  /// In en, this message translates to:
  /// **'Recenter'**
  String get discoverRecenter;

  /// Discover: "Use current location".
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get discoverUseCurrentLocation;

  /// Discover: "Cancel Scenario selection".
  ///
  /// In en, this message translates to:
  /// **'Cancel Scenario selection'**
  String get discoverCancelScenarioSelection;

  /// Discover: "All".
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discoverAll;

  /// Discover: "Search failed".
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get discoverSearchFailed;

  /// Discover: "Reset conditions".
  ///
  /// In en, this message translates to:
  /// **'Reset conditions'**
  String get discoverResetConditions;

  /// Discover: "No activities match these conditions".
  ///
  /// In en, this message translates to:
  /// **'No activities match these conditions'**
  String get discoverNoMatches;

  /// Discover: "Showing nearby activities".
  ///
  /// In en, this message translates to:
  /// **'Showing nearby activities'**
  String get discoverShowingNearby;

  /// Discover: "Radius".
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get discoverRadius;

  /// Discover: "Tonight".
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get discoverTonight;

  /// Discover: "Date".
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get discoverDate;

  /// Discover: "Budget".
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get discoverBudget;

  /// Discover: "Show no-ticket activities".
  ///
  /// In en, this message translates to:
  /// **'Show no-ticket activities'**
  String get discoverShowNoTicket;

  /// Discover: "Free only".
  ///
  /// In en, this message translates to:
  /// **'Free only'**
  String get discoverFreeOnly;

  /// Discover: "Outdoor".
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get discoverOutdoor;

  /// Discover: "Free today".
  ///
  /// In en, this message translates to:
  /// **'Free today'**
  String get discoverFreeToday;

  /// Discover: "Search conditions".
  ///
  /// In en, this message translates to:
  /// **'Search conditions'**
  String get discoverSearchConditions;

  /// Discover: "Open saved conditions on map".
  ///
  /// In en, this message translates to:
  /// **'Open saved conditions on map'**
  String get discoverOpenSavedOnMap;

  /// Discover: "Delete saved conditions".
  ///
  /// In en, this message translates to:
  /// **'Delete saved conditions'**
  String get discoverDeleteSaved;

  /// Discover: "No recent searches yet".
  ///
  /// In en, this message translates to:
  /// **'No recent searches yet'**
  String get discoverNoRecentSearches;

  /// Discover: "Create listing from current search".
  ///
  /// In en, this message translates to:
  /// **'Create listing from current search'**
  String get discoverCreateListingFromSearch;

  /// Discover: "Conditions".
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get discoverConditions;

  /// Discover: "View map".
  ///
  /// In en, this message translates to:
  /// **'View map'**
  String get discoverViewMap;

  /// Discover: "Categories".
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get discoverCategories;

  /// Discover: "Quick scenarios".
  ///
  /// In en, this message translates to:
  /// **'Quick scenarios'**
  String get discoverQuickScenarios;

  /// Discover: "Create from current search".
  ///
  /// In en, this message translates to:
  /// **'Create from current search'**
  String get discoverCreateFromCurrentSearch;

  /// Discover: "Понятые параметры".
  ///
  /// In en, this message translates to:
  /// **'Understood parameters'**
  String get discoverUnderstoodParameters;

  /// Discover: "Текстовый запрос".
  ///
  /// In en, this message translates to:
  /// **'Text query'**
  String get discoverTextQuery;

  /// Discover: "Понятно".
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get discoverGotIt;

  /// Discover: "Как работает Smart Search".
  ///
  /// In en, this message translates to:
  /// **'How Smart Search works'**
  String get discoverSmartSearchHow;

  /// Discover: "Скажите, что хотите найти".
  ///
  /// In en, this message translates to:
  /// **'Say what you want to find'**
  String get discoverSayWhatToFind;

  /// Discover: "Напишите или скажите, что найти".
  ///
  /// In en, this message translates to:
  /// **'Write or say what to find'**
  String get discoverSmartSearchPrompt;

  /// Discover: "Начать поиск".
  ///
  /// In en, this message translates to:
  /// **'Start search'**
  String get discoverStartSearch;

  /// Discover: "Удалить запрос".
  ///
  /// In en, this message translates to:
  /// **'Delete query'**
  String get discoverDeleteQuery;

  /// Discover: "Недавние Smart Search".
  ///
  /// In en, this message translates to:
  /// **'Recent smart searches'**
  String get discoverRecentSmartSearches;

  /// Discover: "Популярные запросы".
  ///
  /// In en, this message translates to:
  /// **'Popular queries'**
  String get discoverPopularQueries;

  /// Discover: "До €20".
  ///
  /// In en, this message translates to:
  /// **'Up to €20'**
  String get discoverChipUpTo20;

  /// Discover: "1–2 часа".
  ///
  /// In en, this message translates to:
  /// **'1–2 hours'**
  String get discoverChipOneTwoHours;

  /// Discover: "Спокойный вечер".
  ///
  /// In en, this message translates to:
  /// **'Calm evening'**
  String get discoverChipCalmEvening;

  /// Discover: "Для двоих".
  ///
  /// In en, this message translates to:
  /// **'For two'**
  String get discoverChipForTwo;

  /// Discover: "Рядом сейчас".
  ///
  /// In en, this message translates to:
  /// **'Near me now'**
  String get discoverChipNearNow;

  /// Discover: "Голосовой запрос".
  ///
  /// In en, this message translates to:
  /// **'Voice query'**
  String get discoverVoiceQuery;

  /// Discover: "Напишите или скажите,\nчто хотите найти".
  ///
  /// In en, this message translates to:
  /// **'Write or say\\nwhat you want to find'**
  String get discoverSmartSearchPromptTwoLines;

  /// Discover: "Smart Search".
  ///
  /// In en, this message translates to:
  /// **'Smart Search'**
  String get discoverSmartSearch;

  /// Discover: "Hours unknown".
  ///
  /// In en, this message translates to:
  /// **'Hours unknown'**
  String get discoverHoursUnknown;

  /// Discover: "Time unknown".
  ///
  /// In en, this message translates to:
  /// **'Time unknown'**
  String get discoverTimeUnknown;

  /// Discover: "Partial fit".
  ///
  /// In en, this message translates to:
  /// **'Partial fit'**
  String get discoverPartialFit;

  /// Discover: "Matches your time".
  ///
  /// In en, this message translates to:
  /// **'Matches your time'**
  String get discoverMatchesYourTime;

  /// Discover: "Открыть настройки".
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get discoverOpenSettings;

  /// Discover: "Нет доступа к геопозиции".
  ///
  /// In en, this message translates to:
  /// **'No access to location'**
  String get discoverNoLocationAccess;

  /// Discover: "Не удалось загрузить ленту".
  ///
  /// In en, this message translates to:
  /// **'Could not load the feed'**
  String get discoverFeedFailed;

  /// Discover: "Убрать время".
  ///
  /// In en, this message translates to:
  /// **'Remove the time'**
  String get discoverRemoveTime;

  /// Discover: "Без обратной дороги".
  ///
  /// In en, this message translates to:
  /// **'Without the return trip'**
  String get discoverNoReturnTrip;

  /// Discover: "Расширить время".
  ///
  /// In en, this message translates to:
  /// **'Widen the time'**
  String get discoverWidenTime;

  /// Discover: "Обновить".
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get discoverRefresh;

  /// Discover: "Пока в ленте ничего нет".
  ///
  /// In en, this message translates to:
  /// **'Nothing in the feed yet'**
  String get discoverFeedEmpty;

  /// Discover: "Загружаем ленту...".
  ///
  /// In en, this message translates to:
  /// **'Loading the feed…'**
  String get discoverFeedLoading;

  /// Discover: "Точки на маршруте".
  ///
  /// In en, this message translates to:
  /// **'Points on the route'**
  String get discoverWaypoints;

  /// Discover: "Высота".
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get discoverElevation;

  /// Discover: "Сброс высоты".
  ///
  /// In en, this message translates to:
  /// **'Descent'**
  String get discoverDescent;

  /// Discover: "Набор высоты".
  ///
  /// In en, this message translates to:
  /// **'Ascent'**
  String get discoverAscent;

  /// Discover: "Не удалось загрузить карту маршрута".
  ///
  /// In en, this message translates to:
  /// **'Could not load the route map'**
  String get discoverRouteMapFailed;

  /// Discover: "Открыть на карте".
  ///
  /// In en, this message translates to:
  /// **'Open on map'**
  String get discoverOpenOnMap;

  /// Discover: "В одну сторону".
  ///
  /// In en, this message translates to:
  /// **'One way'**
  String get discoverShapeOneWay;

  /// Discover: "Туда и обратно".
  ///
  /// In en, this message translates to:
  /// **'Out and back'**
  String get discoverShapeOutAndBack;

  /// Discover: "Кольцевой".
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get discoverShapeLoop;

  /// Discover: "Страница".
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get discoverPublisherPage;

  /// Discover: "Автор".
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get discoverPublisherAuthor;

  /// Discover: "Route details".
  ///
  /// In en, this message translates to:
  /// **'Route details'**
  String get discoverRouteDetails;

  /// Discover: a distance; value is an already formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String discoverDistanceKm(String value);

  /// Discover: distance from the reader.
  ///
  /// In en, this message translates to:
  /// **'{value} km from you'**
  String discoverDistanceFromYou(String value);

  /// Discover: distance to a Route start point.
  ///
  /// In en, this message translates to:
  /// **'Start point · {value} km away'**
  String discoverStartPointAway(String value);

  /// Discover: waypoint distance from the Route start.
  ///
  /// In en, this message translates to:
  /// **'{value} km from the start'**
  String discoverFromStartKm(String value);

  /// Discover: a length in metres; value is an already formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String discoverMeters(String value);

  /// Discover: Route ascent with an up arrow.
  ///
  /// In en, this message translates to:
  /// **'↑ {value} m'**
  String discoverAscentShort(String value);

  /// Discover: Route lowest and highest elevation.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} m'**
  String discoverElevationRange(String min, String max);

  /// Discover: number of gaps in a Route track.
  ///
  /// In en, this message translates to:
  /// **'Track gaps: {count}'**
  String discoverTrackGaps(int count);

  /// Discover: number of straight-line Route segments.
  ///
  /// In en, this message translates to:
  /// **'Direct segments: {count}'**
  String discoverDirectSegments(int count);

  /// Discover: number of straight-line Route segments inside a summary line.
  ///
  /// In en, this message translates to:
  /// **'direct segments: {count}'**
  String discoverDirectSegmentsInline(int count);

  /// Discover: a duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String discoverMinutes(int minutes);

  /// Discover: a duration range in minutes.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} min'**
  String discoverMinutesRange(int min, int max);

  /// Discover: a duration in hours; value may be a decimal already formatted.
  ///
  /// In en, this message translates to:
  /// **'{value} h'**
  String discoverHours(String value);

  /// Discover: a duration in hours and minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String discoverHoursMinutes(int hours, int minutes);

  /// Discover: a duration in days.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String discoverDays(int days);

  /// Discover: an upper bound of a group size.
  ///
  /// In en, this message translates to:
  /// **'up to {count}'**
  String discoverUpTo(int count);

  /// Discover: declared group limit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{up to {count} person} other{up to {count} people}}'**
  String discoverUpToPeople(int count);

  /// Discover: expected cost per person; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'About {price} per person'**
  String discoverAboutPerPerson(String price);

  /// Discover: a date line of a cancelled occurrence.
  ///
  /// In en, this message translates to:
  /// **'{date} · Cancelled'**
  String discoverCancelledSuffix(String date);

  /// Discover: Rental quantities are declared, not live.
  ///
  /// In en, this message translates to:
  /// **'Listed quantities are Creator-declared, not a live booking guarantee or confirmed-fresh count. Confirm on the provider site before relying on them.'**
  String get discoverRentalQuantitiesDisclaimer;

  /// Discover: Rental delivery radius.
  ///
  /// In en, this message translates to:
  /// **'Delivery available within {value} km'**
  String discoverDeliveryWithin(String value);

  /// Discover: Rental minimum and maximum period.
  ///
  /// In en, this message translates to:
  /// **'Rental period: {min} – {max}'**
  String discoverRentalPeriod(String min, String max);

  /// Discover: Rental minimum renter age.
  ///
  /// In en, this message translates to:
  /// **'Min age {age}'**
  String discoverMinAge(int age);

  /// Discover: Rental: an ID is checked at handover.
  ///
  /// In en, this message translates to:
  /// **'ID required at handover'**
  String get discoverIdRequired;

  /// Discover: Rental deposit; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Deposit: {price}'**
  String discoverDeposit(String price);

  /// Discover: number of proposed times of a meetup.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} time option} other{{count} time options}}'**
  String discoverTimeOptionCount(int count);

  /// Discover: the first time and how many more.
  ///
  /// In en, this message translates to:
  /// **'{time} · {count} more'**
  String discoverFirstAndMore(String time, int count);

  /// Discover: a proposed (not final) meetup time.
  ///
  /// In en, this message translates to:
  /// **'Option · {time}'**
  String discoverTimeOptionCandidate(String time);

  /// Discover: a date with start and end time, in the object zone.
  ///
  /// In en, this message translates to:
  /// **'{date} · {start}–{end}'**
  String discoverDateTimeRange(String date, String start, String end);

  /// Discover: budget limit; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Up to {price}'**
  String discoverUpToBudget(String price);

  /// Discover: time window flexibility.
  ///
  /// In en, this message translates to:
  /// **'±{minutes} min'**
  String discoverFlexibilityMinutes(int minutes);

  /// Discover: the effective window replaces the entered one.
  ///
  /// In en, this message translates to:
  /// **'Used for matching instead of {start}–{end}.'**
  String discoverUsedInsteadOf(String start, String end);

  /// Discover: Activity typical duration.
  ///
  /// In en, this message translates to:
  /// **'Typical duration: {value}'**
  String discoverTypicalDuration(String value);

  /// Discover: Activity suggested group size.
  ///
  /// In en, this message translates to:
  /// **'Suggested group: {min}–{max}'**
  String discoverSuggestedGroup(int min, int max);

  /// Discover: Activity best time of day (already localized).
  ///
  /// In en, this message translates to:
  /// **'Best time: {value}'**
  String discoverBestTime(String value);

  /// Discover: Activity amount hint; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Amount hint: {price}'**
  String discoverAmountHint(String price);

  /// Discover: booking button with the price.
  ///
  /// In en, this message translates to:
  /// **'Book for {price}'**
  String discoverBookFor(String price);

  /// Discover: number of map results in the area.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} place or activity in this area} other{{count} places and activities in this area}}'**
  String discoverResultsInArea(int count);

  /// Discover: number of stops.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} stop} other{{count} stops}}'**
  String discoverStops(int count);

  /// Discover: current stop of a Route.
  ///
  /// In en, this message translates to:
  /// **'Stop {current} of {total}'**
  String discoverStopOf(int current, int total);

  /// Discover: search radius.
  ///
  /// In en, this message translates to:
  /// **'Radius: {value} km'**
  String discoverRadiusKm(String value);

  /// Discover: remove an item from the Scenario selection.
  ///
  /// In en, this message translates to:
  /// **'Remove #{order} from selection'**
  String discoverRemoveFromSelection(int order);

  /// Discover: mood of a map Route idea; value is the stable mood id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm} social{Social} active{Active} other{Custom}}'**
  String discoverMood(String value);

  /// Discover: object type word in a summary line.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get discoverRouteLabel;

  /// Discover: how Smart Search works.
  ///
  /// In en, this message translates to:
  /// **'Type a query or use voice input. Recharge reads the time, place, budget and mood and shows suitable options.'**
  String get discoverSmartSearchHowBody;

  /// Discover: Smart Search popular prompt; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Calm evening nearby'**
  String get discoverSmartPromptCalmEveningNearby;

  /// Discover: Smart Search popular prompt; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Find something interesting for 2 hours'**
  String get discoverSmartPromptSomethingForTwoHours;

  /// Discover: Smart Search popular prompt; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Where to go for two nearby'**
  String get discoverSmartPromptForTwoNearby;

  /// Discover: Smart Search example query; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Something calm nearby tonight, up to 20 EUR'**
  String get discoverSmartPromptExample;

  /// Discover: Smart Search example hint shown to the reader; the quoted query is sent to the parser.
  ///
  /// In en, this message translates to:
  /// **'For example: “Something calm nearby tonight, up to €20”'**
  String get discoverSmartPromptExampleHint;

  /// Discover: Smart Search chip query; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Something interesting nearby now'**
  String get discoverSmartPromptNearNow;

  /// Discover: Smart Search chip query; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Where to go for two'**
  String get discoverSmartPromptForTwo;

  /// Discover: Smart Search chip query; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Calm evening'**
  String get discoverSmartPromptCalmEvening;

  /// Discover: Smart Search chip query; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Find a plan for 2 hours'**
  String get discoverSmartPromptTwoHours;

  /// Discover: Smart Search chip query; sent to the query parser (English or Russian only; lv keeps English).
  ///
  /// In en, this message translates to:
  /// **'Find something up to 20 EUR'**
  String get discoverSmartPromptUpTo20;

  /// Discover: Rental base rate; unit is the stable billing unit (hour, day, week), price is formatted money.
  ///
  /// In en, this message translates to:
  /// **'{type, select, hour{{price} / hour} week{{price} / week} other{{price} / day}}'**
  String discoverRentalBaseRate(String type, String price);

  /// Discover: Rental rate step from a minimum number of billing units; unit is the stable billing unit, price is formatted money.
  ///
  /// In en, this message translates to:
  /// **'{type, select, hour{From {count, plural, one{{count} hour} other{{count} hours}}: {price} / hour} week{From {count, plural, one{{count} week} other{{count} weeks}}: {price} / week} other{From {count, plural, one{{count} day} other{{count} days}}: {price} / day}}'**
  String discoverRentalRateStep(String type, String price, int count);

  /// Discover: declared Rental quantity (not a live availability).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unit listed} other{{count} units listed}}'**
  String discoverRentalUnitsListed(int count);

  /// Discover: Activity season (already localized).
  ///
  /// In en, this message translates to:
  /// **'Season: {value}'**
  String discoverSeason(String value);

  /// Discover: Route length metric label.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get discoverLength;

  /// Discover: participants metric label.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get discoverPeople;

  /// Discover: Route profile: cycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get discoverCycling;

  /// Discover: Route difficulty: easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get discoverDifficultyEasy;

  /// Discover: Route difficulty: moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get discoverDifficultyModerate;

  /// Discover: Route difficulty: hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get discoverDifficultyHard;

  /// Discover: opening status: open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get discoverOpen;

  /// Discover: snackbar after adding stops to a Scenario.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Added {count} stop to Scenario} other{Added {count} stops to Scenario}}'**
  String discoverAddedToScenario(int count);

  /// Discover: a passed Route stop with its duration.
  ///
  /// In en, this message translates to:
  /// **'Completed · {minutes} min'**
  String discoverCompletedDuration(int minutes);

  /// Discover: restart a Route walk-through.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get discoverRestart;

  /// Discover: finish a Route walk-through.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get discoverFinish;

  /// Discover: search radius is unlimited.
  ///
  /// In en, this message translates to:
  /// **'Radius: any area'**
  String get discoverRadiusAnyArea;

  /// Discover: a Route point without its own title.
  ///
  /// In en, this message translates to:
  /// **'Point on the route'**
  String get discoverWaypoint;

  /// Discover: number of results found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} found} other{{count} found}}'**
  String discoverFoundCount(int count);

  /// Discover: number of people in a search.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} person} other{{count} people}}'**
  String discoverPeopleCount(int count);

  /// Discover: budget chip; value is a number in the market currency.
  ///
  /// In en, this message translates to:
  /// **'Under {value}'**
  String discoverUnder(String value);

  /// Discover: a flexible time window.
  ///
  /// In en, this message translates to:
  /// **'Flexible ±{minutes} min'**
  String discoverFlexibleWindow(int minutes);

  /// Discover: a custom value option.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get discoverCustom;

  /// Discover: a chosen custom value; value is already formatted.
  ///
  /// In en, this message translates to:
  /// **'Custom · {value}'**
  String discoverCustomValue(String value);

  /// Discover: a number of hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour} other{{count} hours}}'**
  String discoverHoursLong(int count);

  /// Discover: about an hour.
  ///
  /// In en, this message translates to:
  /// **'~ 1 hour'**
  String get discoverAboutOneHour;

  /// Discover: a range of hours.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} hours'**
  String discoverHoursRange(int min, int max);

  /// Discover: filter title: availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get discoverAvailability;

  /// Discover: filter title: mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get discoverMoodTitle;

  /// Discover: travel time to an object.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min travel'**
  String discoverTravelMinutes(int minutes);

  /// Discover: estimated travel time to an object.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min travel · est.'**
  String discoverTravelMinutesEstimated(int minutes);

  /// Discover: a time slot was chosen for the reader.
  ///
  /// In en, this message translates to:
  /// **'Time slot chosen'**
  String get discoverSlotChosen;

  /// Discover: time fit: fits.
  ///
  /// In en, this message translates to:
  /// **'Fits'**
  String get discoverFits;

  /// Discover: remove from saved.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get discoverUnsave;

  /// Discover: recommended Route difficulty (already localized).
  ///
  /// In en, this message translates to:
  /// **'Recommended {value}'**
  String discoverRecommendedDifficulty(String value);

  /// Discover: number of points of interest on a Route.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} point of interest} other{{count} points of interest}}'**
  String discoverPoiCount(int count);

  /// Discover: Route surface heading.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get discoverSurfaceTitle;

  /// Discover: Route surface; id is the stable surface id (OSM tag value).
  ///
  /// In en, this message translates to:
  /// **'{value, select, asphalt{Asphalt}paved{Paved}concrete{Concrete}paving_stones{Paving stones}sett{Cobblestones}compacted{Compacted}fine_gravel{Fine gravel}gravel{Gravel}dirt{Dirt}earth{Earth}ground{Ground}grass{Grass}sand{Sand}unpaved{Unpaved}wood{Wood}mixed{Mixed} other{Other surface}}'**
  String discoverSurface(String value);

  /// Discover: Route length with unknown surface; length is formatted metres.
  ///
  /// In en, this message translates to:
  /// **'Surface data is unknown for {meters}.'**
  String discoverUnknownSurface(String meters);

  /// Discover: a Find People request cannot join a Scenario.
  ///
  /// In en, this message translates to:
  /// **'A Find People request cannot be added to a Scenario.'**
  String get discoverIntakeFindPeopleNotSupported;

  /// Discover: a result has no stable catalog identity.
  ///
  /// In en, this message translates to:
  /// **'This result cannot be added: it has no stable catalog identity.'**
  String get discoverIntakeMissingIdentity;

  /// Discover: a result has no usable location.
  ///
  /// In en, this message translates to:
  /// **'This result has no usable catalog location.'**
  String get discoverIntakeNoLocation;

  /// Discover: the Scenario selection is full.
  ///
  /// In en, this message translates to:
  /// **'A Scenario intake can contain up to {count} items.'**
  String discoverIntakeLimitReached(int count);

  /// Discover: screen reader text of the Scenario selection tray.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} stop selected for Scenario.} other{{count} stops selected for Scenario.}}'**
  String discoverStopsSelected(int count);

  /// Discover: number of selected objects.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String discoverSelectedCount(int count);

  /// Discover: why a search time window was not applied; issue is the stable code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, unknownTimezone{The time zone of this area is unknown.}dayEnded{This day has already ended here.}boundsRequired{Choose a start and an end.}nonexistentLocalTime{This local time does not exist because of the clock change.}endBeforeStart{The end must be after the start.}invalidTravelContext{The travel settings are not valid.}serviceUnavailable{Time matching is unavailable right now.} other{The time window could not be applied.}}'**
  String discoverTimeWindowIssue(String code);

  /// Discover: feed notice for a stable code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, emptyArea{Nothing found in this area. Try a larger radius or fewer filters.}loadFailed{Could not load the data. Try again.}dataUnavailable{The data is unavailable.}offline{No internet connection.} other{Could not load the feed. Try again.}}'**
  String discoverFeedNotice(String code);

  /// Add to Scenario: progress line for the sheet stage (stable stage name).
  ///
  /// In en, this message translates to:
  /// **'{state, select, target{1 of 3 · Scenario}placement{2 of 3 · Placement}review{3 of 3 · Review}success{Complete}applying{Saving} other{Preparing}}'**
  String scenarioIntakeStep(String state);

  /// Add to Scenario review: where the stops go (stable value); shown after the Scenario title.
  ///
  /// In en, this message translates to:
  /// **'{state, select, unscheduled{Unscheduled}atEnd{At end} other{After selected stop}}'**
  String scenarioIntakePlacement(String state);

  /// Add to Scenario: label before a stop title (the title is shown as is).
  ///
  /// In en, this message translates to:
  /// **'After:'**
  String get scenarioIntakeAfterLabel;

  /// Add to Scenario: screen reader label before a selected stop title (the title is shown as is).
  ///
  /// In en, this message translates to:
  /// **'Selected stop {count}:'**
  String scenarioIntakeCandidateLabel(int count);

  /// Add to Scenario: success heading; the Scenario title is shown separately as is.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Added {count} stop to the Scenario} other{Added {count} stops to the Scenario}}'**
  String scenarioIntakeSuccess(int count);

  /// Add to Scenario target summary: number of days (count) and active items (total).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}} · {total, plural, one{{total} active item} other{{total} active items}}'**
  String scenarioIntakeTargetCounts(int count, int total);

  /// Discover home: quick scenario or route idea title; id is stable.
  ///
  /// In en, this message translates to:
  /// **'{value, select, freeToday{Free today}nearMe{Near me}eveningPlans{Evening plans}coffeeReset{Coffee reset}freeCityReset{Free city reset}socialEvening{Social evening}activeBoost{Active boost} other{Idea}}'**
  String discoverHomeIdeaTitle(String value);

  /// Discover home: quick scenario or route idea subtitle; id is stable.
  ///
  /// In en, this message translates to:
  /// **'{value, select, freeToday{Activities nearby without tickets}nearMe{Use the map radius and quick list}eveningPlans{Find something after work}coffeeReset{A calm cafe start with an easy city walk.}freeCityReset{A free low-pressure route for a quick recharge.}socialEvening{Start social, then keep the night nearby.}activeBoost{Move first, then cool down on a walk.} other{A quick plan nearby.}}'**
  String discoverHomeIdeaSubtitle(String value);

  /// Discover: home section: new.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get discoverHomeNew;

  /// Discover: home section: for you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get discoverHomeForYou;

  /// Discover: home section: quick events.
  ///
  /// In en, this message translates to:
  /// **'Quick events'**
  String get discoverHomeQuickEvents;

  /// Discover: home section: nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get discoverHomeNearby;

  /// Discover: home section: popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get discoverHomePopular;

  /// Discover: home section: Route ideas.
  ///
  /// In en, this message translates to:
  /// **'Route ideas'**
  String get discoverRouteIdeas;

  /// Discover: open the Scenario builder.
  ///
  /// In en, this message translates to:
  /// **'Builder'**
  String get discoverBuilder;

  /// Discover: build a Route from a template.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get discoverBuild;

  /// Discover: open Create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get discoverCreate;

  /// Discover: resume a saved search.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get discoverResume;

  /// Discover: Route template: walkable.
  ///
  /// In en, this message translates to:
  /// **'Walkable'**
  String get discoverWalkable;

  /// Discover: Route template: free and paid stops.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get discoverMixedPrice;

  /// Discover: tooltip: show a Route idea on the map; title is localized.
  ///
  /// In en, this message translates to:
  /// **'Map {message} route'**
  String discoverMapTemplateRoute(String message);

  /// Discover: tooltip: create a Route from an idea; title is localized.
  ///
  /// In en, this message translates to:
  /// **'Create {message} route'**
  String discoverCreateTemplateRoute(String message);

  /// Discover: home: what the For you block holds.
  ///
  /// In en, this message translates to:
  /// **'Personal picks, saved ideas and creator tools stay one tap away.'**
  String get discoverForYouHint;

  /// Discover: idea title from Smart Search without a query.
  ///
  /// In en, this message translates to:
  /// **'Smart search idea'**
  String get discoverSmartSearchIdea;

  /// Discover: label before meetup languages (shown as published).
  ///
  /// In en, this message translates to:
  /// **'Languages:'**
  String get discoverLanguagesLabel;

  /// Discover: label before the equipment note (user content, shown as is).
  ///
  /// In en, this message translates to:
  /// **'Equipment:'**
  String get discoverEquipmentLabel;

  /// Discover: label before the accessibility note (user content, shown as is).
  ///
  /// In en, this message translates to:
  /// **'Accessibility:'**
  String get discoverAccessibilityLabel;

  /// Discover: Rental: label before the publishing page id.
  ///
  /// In en, this message translates to:
  /// **'Listed by page'**
  String get discoverListedByPageLabel;

  /// Discover: Rental: label before the publisher id.
  ///
  /// In en, this message translates to:
  /// **'Listed by'**
  String get discoverListedByLabel;

  /// Discover: label before what a class teaches (user content, shown as is).
  ///
  /// In en, this message translates to:
  /// **'What you will learn:'**
  String get discoverLearningOutcomesLabel;

  /// Discover: label before the organizer name (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Organizer:'**
  String get discoverOrganizerLabel;

  /// Discover: label before the linked Place title (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Linked Place:'**
  String get discoverLinkedPlaceLabel;

  /// Discover: label before the informal access caution (user content, shown as is).
  ///
  /// In en, this message translates to:
  /// **'Informal access:'**
  String get discoverInformalAccessLabel;

  /// Discover: screen reader label before a passed stop title (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Completed at stop {index}:'**
  String discoverCompletedAtStopLabel(int index);

  /// Discover: screen reader label before the focused stop title (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Focused stop {index}:'**
  String discoverFocusedStopLabel(int index);

  /// Discover: label before the current stop title (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Now: stop {index} ·'**
  String discoverNowAtStopLabel(int index);

  /// Discover: screen reader label before a selected stop title (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Selected stop {index}:'**
  String discoverSelectedStopLabel(int index);

  /// Discover: a Route idea by mood; value is the stable mood id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm route}social{Social route}active{Active route} other{Custom route}}'**
  String discoverMoodRoute(String value);

  /// Discover: a Route idea listing title by mood; value is the stable mood id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm recharge route}social{Social recharge route}active{Active recharge route} other{Custom recharge route}}'**
  String discoverMoodRechargeRoute(String value);

  /// Discover: a saved Route idea title by mood; value is the stable mood id.
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm recharge scenario}social{Social recharge scenario}active{Active recharge scenario} other{Custom recharge scenario}}'**
  String discoverMoodRechargeScenario(String value);

  /// Discover: label before a contribution note; value is the localized contribution kind.
  ///
  /// In en, this message translates to:
  /// **'Optional {value}:'**
  String discoverOptionalContributionLabel(String value);

  /// Discover: idea title for a category; type is the category name (G04, not translated).
  ///
  /// In en, this message translates to:
  /// **'{type} idea'**
  String discoverIdeaForCategory(String type);

  /// Discover: label before the understood intent (the reader prompt is shown as is).
  ///
  /// In en, this message translates to:
  /// **'Intent:'**
  String get discoverIntentLabel;

  /// Discover: label before the applied search conditions.
  ///
  /// In en, this message translates to:
  /// **'Applied:'**
  String get discoverAppliedLabel;

  /// Discover: label before a Route version id.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get discoverVersionLabel;

  /// Discover: remove an object from a selection (its title follows as is).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get discoverRemove;

  /// Discover: an external link could not be opened (its host follows as is).
  ///
  /// In en, this message translates to:
  /// **'Could not open'**
  String get discoverCouldNotOpenLink;

  /// Discover: screen reader text of a Collection mini map.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Map of {count} place in this Collection. Use the list below to browse it without the map.} other{Map of {count} places in this Collection. Use the list below to browse them without the map.}}'**
  String discoverCollectionMapSemantics(int count);

  /// Discover: screen reader text of a Route preview thumbnail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Route preview: {count} segment} other{Route preview: {count} segments}}'**
  String discoverRoutePreview(int count);

  /// Discover: categories search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get discoverSearchCategories;

  /// Discover: clear the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get discoverClearSearch;

  /// Discover: no category matches the search.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get discoverNoCategories;

  /// Discover: a category link points nowhere.
  ///
  /// In en, this message translates to:
  /// **'Category not found'**
  String get discoverCategoryNotFound;

  /// Discover: open a Route.
  ///
  /// In en, this message translates to:
  /// **'Open Route'**
  String get discoverOpenRoute;

  /// Discover: a picked date that is today; date is formatted.
  ///
  /// In en, this message translates to:
  /// **'Today, {date}'**
  String discoverTodayDate(String date);

  /// Discover: label before a publisher name (shown as is).
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get discoverByLabel;

  /// Discover: Details type badge (upper case).
  ///
  /// In en, this message translates to:
  /// **'PLACE'**
  String get discoverBadgePlace;

  /// Discover: Details type badge (upper case).
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get discoverBadgeActivity;

  /// Discover: Details type badge (upper case).
  ///
  /// In en, this message translates to:
  /// **'FIND PEOPLE'**
  String get discoverBadgeFindPeople;

  /// Discover: Details type badge (upper case).
  ///
  /// In en, this message translates to:
  /// **'SESSION'**
  String get discoverBadgeSession;

  /// Discover: Details type badge (upper case).
  ///
  /// In en, this message translates to:
  /// **'CLASS / WORKSHOP'**
  String get discoverBadgeClassWorkshop;

  /// L4.6: public Professional Page — title.
  ///
  /// In en, this message translates to:
  /// **'Professional Page'**
  String get identityProfessionalPage;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Verification revoked'**
  String get identityVerificationRevoked;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Verification rejected'**
  String get identityVerificationRejected;

  /// L4.6: public Professional Page — text.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get identityVerificationPending;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Private professional'**
  String get identityKindPrivateProfessional;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Venue operator'**
  String get identityKindVenueOperator;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Representative office'**
  String get identityKindRepresentativeOffice;

  /// L4.6: public Professional Page — button label.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get identityRetry;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get identityCreate;

  /// L4.6: Profile, workspace switcher — button label.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters'**
  String get identityMinTwoChars;

  /// L4.6: Professional Page profile editor — button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get identityCancel;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'The page starts in Pending review. Market, locale, timezone and currency come from the active market configuration.'**
  String get identityPageStartsPending;

  /// L4.6: Profile, workspace switcher — field label.
  ///
  /// In en, this message translates to:
  /// **'Page type'**
  String get identityPageType;

  /// L4.6: Profile, workspace switcher — field label.
  ///
  /// In en, this message translates to:
  /// **'Page name'**
  String get identityPageName;

  /// L4.6: Profile, workspace switcher — button label.
  ///
  /// In en, this message translates to:
  /// **'Create Professional Page'**
  String get identityCreatePage;

  /// L4.6: Profile, workspace switcher — title.
  ///
  /// In en, this message translates to:
  /// **'Presentation preview only. Roles and permissions do not change.'**
  String get identityPreviewOnlyRoles;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'View as'**
  String get identityViewAs;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'You have not created a Professional Page yet.'**
  String get identityNoPageYet;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Create content'**
  String get identityCreateContent;

  /// L4.6: public Professional Page — button label.
  ///
  /// In en, this message translates to:
  /// **'Manage page'**
  String get identityManagePage;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Personal profile · Verification revoked'**
  String get identityPersonalRevoked;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Personal profile · Verification expired'**
  String get identityPersonalExpired;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Personal profile · Verification rejected'**
  String get identityPersonalRejected;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Verified · Tools follow your permissions'**
  String get identityVerifiedTools;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Personal profile · Verification pending'**
  String get identityPersonalPending;

  /// L4.6: Profile, workspace switcher — text.
  ///
  /// In en, this message translates to:
  /// **'Personal profile · Verification not started'**
  String get identityPersonalNotStarted;

  /// L4.6: Profile, workspace switcher — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Admin access active · separate from publishing'**
  String get identityAdminSeparate;

  /// L4.6: Profile, workspace switcher — title.
  ///
  /// In en, this message translates to:
  /// **'Admin tools'**
  String get identityAdminTools;

  /// L4.6: Profile, workspace switcher — button label.
  ///
  /// In en, this message translates to:
  /// **'Request additional page'**
  String get identityRequestAdditionalPage;

  /// L4.6: Profile, workspace switcher — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Moderators will review your request.'**
  String get identityModeratorsWillReview;

  /// L4.6: Profile, workspace switcher — title.
  ///
  /// In en, this message translates to:
  /// **'Additional page request pending'**
  String get identityLimitRequestPending;

  /// L4.6: Profile, workspace switcher — title.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get identityCreator;

  /// L4.6: Profile, workspace switcher — button label.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get identityOk;

  /// L4.6: Profile, workspace switcher — dialog text.
  ///
  /// In en, this message translates to:
  /// **'This mock account has explicit Admin capabilities. Operational Admin tools are connected in IDP-05A.'**
  String get identityAdminMockNotice;

  /// L4.6: Profile, workspace switcher — dialog text.
  ///
  /// In en, this message translates to:
  /// **'Admin access active'**
  String get identityAdminAccessActive;

  /// L4.6: public Professional Page — text.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get identityPageNotFound;

  /// L4.6: public Professional Page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Content appears here only through an approved publisher projection.'**
  String get identityContentViaProjection;

  /// L4.6: public Professional Page — title.
  ///
  /// In en, this message translates to:
  /// **'No published content yet'**
  String get identityNoPublishedContent;

  /// L4.6: public Professional Page — text.
  ///
  /// In en, this message translates to:
  /// **'Published content'**
  String get identityPublishedContent;

  /// L4.6: public Professional Page — button label.
  ///
  /// In en, this message translates to:
  /// **'Edit page'**
  String get identityEditPage;

  /// L4.6: public Professional Page — button label.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get identityShare;

  /// L4.6: public Professional Page — text.
  ///
  /// In en, this message translates to:
  /// **'Verified Professional Page'**
  String get identityVerifiedPage;

  /// L4.6: public Professional Page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'This preview does not publish or verify the page.'**
  String get identityPreviewDoesNotPublish;

  /// L4.6: public Professional Page — title.
  ///
  /// In en, this message translates to:
  /// **'Public page preview'**
  String get identityPublicPagePreview;

  /// L4.6: public Professional Page — text.
  ///
  /// In en, this message translates to:
  /// **'Preview. This page is not publicly visible.'**
  String get identityPreviewNotPublic;

  /// L4.6: Professional Page workspace — text.
  ///
  /// In en, this message translates to:
  /// **'Page account, memberships and international settings.'**
  String get identityPageAccountSettings;

  /// L4.6: Professional Page workspace — text.
  ///
  /// In en, this message translates to:
  /// **'Content is scoped to this exact Professional Page.'**
  String get identityContentScoped;

  /// L4.6: Professional Page workspace — text.
  ///
  /// In en, this message translates to:
  /// **'Professional Page overview and moderation status.'**
  String get identityOverviewModeration;

  /// L4.6: Professional Page workspace — button label.
  ///
  /// In en, this message translates to:
  /// **'Preview only. The page is not public until verification is approved.'**
  String get identityPreviewUntilVerified;

  /// L4.6: Professional Page workspace — button label.
  ///
  /// In en, this message translates to:
  /// **'Preview public page'**
  String get identityPreviewPublicPage;

  /// L4.6: Professional Page workspace — text.
  ///
  /// In en, this message translates to:
  /// **'No page is invented for this preview. Create a page to activate its workspace and publisher context.'**
  String get identityNoPageInvented;

  /// L4.6: Professional Page workspace — text.
  ///
  /// In en, this message translates to:
  /// **'Content appears only after the user creates or joins a real Professional Page.'**
  String get identityContentAfterRealPage;

  /// L4.6: Professional Page workspace — text.
  ///
  /// In en, this message translates to:
  /// **'Professional Page preview'**
  String get identityPagePreview;

  /// L4.6: Professional Page workspace — button label.
  ///
  /// In en, this message translates to:
  /// **'Switch Professional Page'**
  String get identitySwitchPage;

  /// L4.6: Professional Page workspace — button label.
  ///
  /// In en, this message translates to:
  /// **'Create or select Professional Page'**
  String get identityCreateOrSelectPage;

  /// L4.6: Professional Page team invitations — text.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get identityUserId;

  /// L4.6: Professional Page team invitations — text.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get identitySendInvitation;

  /// L4.6: Professional Page team invitations — text.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get identityCapabilities;

  /// L4.6: Professional Page team invitations — field label.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get identityRole;

  /// L4.6: Professional Page team invitations — field label.
  ///
  /// In en, this message translates to:
  /// **'Invite by'**
  String get identityInviteBy;

  /// L4.6: Professional Page team invitations — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Invite a team member'**
  String get identityInviteMember;

  /// L4.6: Professional Page team invitations — button label.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get identityRevoke;

  /// L4.6: Professional Page team invitations — text.
  ///
  /// In en, this message translates to:
  /// **'No invitations sent from this page yet.'**
  String get identityNoInvitations;

  /// L4.6: Professional Page team invitations — text.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to manage the team.'**
  String get identityNoTeamPermission;

  /// L4.6: Professional Page profile editor — button label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get identitySave;

  /// L4.6: Professional Page profile editor — text.
  ///
  /// In en, this message translates to:
  /// **'Not set.'**
  String get identityNotSet;

  /// L4.6: Professional Page profile editor — text.
  ///
  /// In en, this message translates to:
  /// **'Custom activity label'**
  String get identityCustomActivityLabel;

  /// L4.6: Professional Page profile editor — text.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get identityDescription;

  /// L4.6: Professional Page profile editor — text.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get identityShortDescription;

  /// L4.6: Profile, workspace switcher — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Personal profile, Professional Pages and Admin access'**
  String get identitySwitchWorkspaceHint;

  /// L4.6: Profile, workspace switcher — title.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get identitySwitchWorkspace;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Date to be set'**
  String get profileDateTbd;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Draft listing'**
  String get profileDraftListing;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Smart search idea'**
  String get profileSmartSearchIdea;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Published route'**
  String get profilePublishedRoute;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Ready to publish'**
  String get profileReadyToPublish;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'No city'**
  String get profileNoCity;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Untitled listing'**
  String get profileUntitledListing;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Route map'**
  String get profileRouteMap;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get profileEditRoute;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get profileWalking;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get profileFree;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Open Quick Plan for the next generated idea'**
  String get profileOpenQuickPlanNext;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Build next route'**
  String get profileBuildNextRoute;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Map published listing'**
  String get profileMapPublishedListing;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Open route map'**
  String get profileOpenRouteMap;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Find draft audience'**
  String get profileFindDraftAudience;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Finish draft'**
  String get profileFinishDraft;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Creator next steps'**
  String get profileCreatorNextSteps;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Map listing area'**
  String get profileMapListingArea;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Search similar listing'**
  String get profileSearchSimilarListing;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Continue draft'**
  String get profileContinueDraft;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Open Create'**
  String get profileOpenCreate;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Creator listing'**
  String get profileCreatorListing;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Build route'**
  String get profileBuildRoute;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'New listing'**
  String get profileNewListing;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Manage drafts and published listings from the same workspace.'**
  String get profileManageDrafts;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Creator publications'**
  String get profileCreatorPublications;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Create listing from latest smart search'**
  String get profileListingFromLatestSmart;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Build route from latest smart search'**
  String get profileRouteFromLatestSmart;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Map smart'**
  String get profileMapSmart;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Resume smart'**
  String get profileResumeSmart;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Any area'**
  String get profileAnyArea;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Smart route'**
  String get profileSmartRoute;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get profileSmart;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Latest smart search'**
  String get profileLatestSmartSearch;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Create listing from latest search'**
  String get profileListingFromLatestSearch;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Build route from latest search'**
  String get profileRouteFromLatestSearch;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Map search'**
  String get profileMapSearch;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Resume search'**
  String get profileResumeSearch;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get profileConditions;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Latest search'**
  String get profileLatestSearch;

  /// L4.6: Profile page — button label.
  ///
  /// In en, this message translates to:
  /// **'Map route'**
  String get profileMapRoute;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get profileScenario;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Latest route'**
  String get profileLatestRoute;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Create a personal recharge scenario'**
  String get profilePersonalScenario;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Build a route'**
  String get profileBuildARoute;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Use Search and Map conditions'**
  String get profileUseSearchMap;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Find next activity'**
  String get profileFindNextActivity;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Saved plan'**
  String get profileSavedPlan;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Review saved plan'**
  String get profileReviewSavedPlan;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Use saved searches and scenarios as inspiration'**
  String get profileUseSavedInspiration;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Build route idea'**
  String get profileBuildRouteIdea;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Draft event or place from taxonomy'**
  String get profileDraftFromTaxonomy;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Create Hub'**
  String get profileCreateHub;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Move from route idea to Create Hub'**
  String get profileIdeaToHub;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Publish idea'**
  String get profilePublishIdea;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Smart prompt'**
  String get profileSmartPrompt;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Open Builder with route controls'**
  String get profileOpenBuilderControls;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Generate scenario'**
  String get profileGenerateScenario;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Searches'**
  String get profileSearches;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get profileRoutes;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get profileSaved;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Untitled activity'**
  String get profileUntitledActivity;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Continue in Search conditions'**
  String get profileContinueInSearch;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get profileFindPeople;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Open the Scenario block in Create Hub'**
  String get profileOpenScenarioBlock;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Create Scenario'**
  String get profileCreateScenario;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Open the Route block in Create Hub'**
  String get profileOpenRouteBlock;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Create route'**
  String get profileCreateRoute;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Open taxonomy-based creator flow'**
  String get profileOpenTaxonomyFlow;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'View all events'**
  String get profileViewAllEvents;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Start from Recharge Create Hub'**
  String get profileStartFromHub;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'No created events yet'**
  String get profileNoCreatedEvents;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Create first event'**
  String get profileCreateFirstEvent;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Event insights'**
  String get profileEventInsights;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Created events'**
  String get profileCreatedEvents;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Manage page'**
  String get profileManagePage;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get profilePhotos;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get profileVisited;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get profileCreated;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Profile workspace'**
  String get profileWorkspace;

  /// L4.6: Profile page — text.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get profileSignInRequired;

  /// L4.6: Profile page — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Check verification and available tools in Settings'**
  String get profileCheckVerification;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Creator tools'**
  String get profileCreatorTools;

  /// L4.6: Profile page — title.
  ///
  /// In en, this message translates to:
  /// **'Saved list'**
  String get profileSavedList;

  /// L4.6: Profile page — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// L4.6: Profile, Scenario library — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Object updates off'**
  String get profileObjectUpdatesOff;

  /// L4.6: Profile, Scenario library — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Object updates on'**
  String get profileObjectUpdatesOn;

  /// L4.6: Profile, Scenario library — text.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get profileCompleted;

  /// L4.6: Profile, Scenario library — title.
  ///
  /// In en, this message translates to:
  /// **'Active and upcoming'**
  String get profileActiveUpcoming;

  /// L4.6: Scenario builder (Quick Plan) — chip label.
  ///
  /// In en, this message translates to:
  /// **'Any area'**
  String get quickPlanAnyArea;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Any price'**
  String get quickPlanAnyPrice;

  /// L4.6: Scenario builder (Quick Plan) — chip label.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get quickPlanAllCategories;

  /// L4.6: Scenario builder (Quick Plan) — chip label.
  ///
  /// In en, this message translates to:
  /// **'Smart route'**
  String get quickPlanSmartRoute;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Recharge idea'**
  String get quickPlanRechargeIdea;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Move first, cool down outside, then keep energy steady.'**
  String get quickPlanTplActiveHint;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Active boost'**
  String get quickPlanTplActive;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Meet people first, then keep the evening moving nearby.'**
  String get quickPlanTplSocialHint;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Social evening'**
  String get quickPlanTplSocial;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Free city reset'**
  String get quickPlanTplFreeCity;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Start gently, then take a low-pressure city walk.'**
  String get quickPlanTplCoffeeHint;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Coffee reset'**
  String get quickPlanTplCoffee;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Reset builder'**
  String get quickPlanResetBuilder;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'No stops match these conditions'**
  String get quickPlanNoStopsMatch;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get quickPlanAdd;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Suggested stops'**
  String get quickPlanSuggestedStops;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove stop'**
  String get quickPlanRemoveStop;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get quickPlanMoveDown;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get quickPlanMoveUp;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Publish optimized route'**
  String get quickPlanPublishOptimized;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Map route'**
  String get quickPlanMapRoute;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Optimize'**
  String get quickPlanOptimize;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Free only'**
  String get quickPlanFreeOnly;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Route fit'**
  String get quickPlanRouteFit;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Walking route'**
  String get quickPlanWalkingRoute;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get quickPlanMoodActive;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get quickPlanMoodSocial;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get quickPlanMoodCalm;

  /// L4.6: Scenario builder (Quick Plan) — chip label.
  ///
  /// In en, this message translates to:
  /// **'Create listing from smart search'**
  String get quickPlanListingFromSmart;

  /// L4.6: Scenario builder (Quick Plan) — chip label.
  ///
  /// In en, this message translates to:
  /// **'Open smart search on map'**
  String get quickPlanOpenSmartOnMap;

  /// L4.6: Scenario builder (Quick Plan) — chip label.
  ///
  /// In en, this message translates to:
  /// **'Apply smart search to builder'**
  String get quickPlanApplySmartToBuilder;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Smart search'**
  String get quickPlanSmartSearch;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Create listing from saved conditions'**
  String get quickPlanListingFromSaved;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Open saved conditions on map'**
  String get quickPlanOpenSavedOnMap;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Apply saved conditions to builder'**
  String get quickPlanApplySavedToBuilder;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Saved conditions'**
  String get quickPlanSavedConditions;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Build from saved intent'**
  String get quickPlanBuildFromSaved;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Ready route ideas'**
  String get quickPlanReadyIdeas;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Publish route'**
  String get quickPlanPublishRoute;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get quickPlanSearch;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get quickPlanMap;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get quickPlanCopy;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get quickPlanSave;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Build a recharge route'**
  String get quickPlanBuildRechargeRoute;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Route preview'**
  String get quickPlanRoutePreview;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Continue with snapshot'**
  String get quickPlanContinueSnapshot;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get quickPlanRefresh;

  /// L4.6: Scenario builder (Quick Plan) — dialog text.
  ///
  /// In en, this message translates to:
  /// **'Refresh the preview or continue with the latest available snapshot.'**
  String get quickPlanRefreshOrContinue;

  /// L4.6: Scenario builder (Quick Plan) — dialog text.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan changed'**
  String get quickPlanChanged;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Create independent Scenario'**
  String get quickPlanCreateIndependent;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get quickPlanCancel;

  /// L4.6: Scenario builder (Quick Plan) — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Only your own notes are eligible; this legacy plan has none.'**
  String get quickPlanNoNotes;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Copy my private notes'**
  String get quickPlanCopyNotes;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Legacy stops have no catalog object IDs, so selected stops will enter Scenario as private custom locations.'**
  String get quickPlanLegacyStopsHint;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'A new independent Scenario will be created. Later changes will not sync in either direction.'**
  String get quickPlanIndependentHint;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Expand to Scenario'**
  String get quickPlanExpandToScenario;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Copy selected stops into a new independent Scenario. This Quick Plan stays unchanged.'**
  String get quickPlanCopyStopsHint;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Need a larger city or trip plan?'**
  String get quickPlanNeedLargerPlan;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Save this plan'**
  String get quickPlanSavePlan;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get quickPlanOpenMap;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get quickPlanEditPlan;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'No stops fit these conditions yet. Edit the plan to add one.'**
  String get quickPlanNoStopsFit;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get quickPlanYourRoute;

  /// L4.6: Scenario builder (Quick Plan) — snackbar message.
  ///
  /// In en, this message translates to:
  /// **'Could not expand this Quick Plan'**
  String get quickPlanExpandFailed;

  /// L4.6: Scenario builder (Quick Plan) — snackbar message.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan copied'**
  String get quickPlanCopied;

  /// L4.6: Scenario builder (Quick Plan) — snackbar message.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan saved'**
  String get quickPlanSaved;

  /// L4.6: Scenario builder (Quick Plan) — snackbar message.
  ///
  /// In en, this message translates to:
  /// **'Not synced. Your local changes are retained; refresh to retry.'**
  String get quickPlanNotSynced;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get quickPlanLeave;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Open read-only'**
  String get quickPlanOpenReadOnly;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get quickPlanDecline;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get quickPlanAccept;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get quickPlanRevoke;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel invite'**
  String get quickPlanCancelInvite;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Delete current personal plan'**
  String get quickPlanDeletePersonal;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Import personal plan'**
  String get quickPlanImportPersonal;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Import recharge.quickPlan JSON'**
  String get quickPlanImportJson;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Invite to current saved plan'**
  String get quickPlanInviteToSaved;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Invite existing user ID'**
  String get quickPlanInviteUserId;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Use a known user ID. Pending actions take effect after server confirmation.'**
  String get quickPlanUseKnownUserId;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan invitations'**
  String get quickPlanInvitations;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get quickPlanContinue;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Leave plan'**
  String get quickPlanLeavePlan;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Content hidden. Refresh to verify access.'**
  String get quickPlanContentHidden;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh access'**
  String get quickPlanRefreshAccess;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close invited plan'**
  String get quickPlanCloseInvited;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Invited Quick Plan'**
  String get quickPlanInvitedPlan;

  /// L4.6: Scenario builder (Quick Plan) — text.
  ///
  /// In en, this message translates to:
  /// **'Route steps'**
  String get quickPlanRouteSteps;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Your recharge plan'**
  String get quickPlanYourPlan;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get quickPlanReset;

  /// L4.6: Scenario builder (Quick Plan) — button label.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get quickPlanEdit;

  /// L4.6: Scenario builder (Quick Plan) — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Invitations and access'**
  String get quickPlanInvitationsAccess;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'Quick Plan'**
  String get quickPlanQuickPlan;

  /// L4.6: Scenario builder (Quick Plan) — title.
  ///
  /// In en, this message translates to:
  /// **'My quick plan'**
  String get quickPlanMyQuickPlan;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get favoritesFree;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Any area'**
  String get favoritesAnyArea;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Smart route'**
  String get favoritesSmartRoute;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Recharge idea'**
  String get favoritesRechargeIdea;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get favoritesAnyTime;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'ROUTE'**
  String get favoritesBadgeRoute;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'PLACE'**
  String get favoritesBadgePlace;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'EVENT'**
  String get favoritesBadgeEvent;

  /// L4.6: Favorites — button label.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get favoritesShowAll;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this filter yet'**
  String get favoritesFilterEmpty;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get favoritesRemove;

  /// L4.6: Favorites — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get favoritesMoreActions;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get favoritesRoutes;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get favoritesPlaces;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get favoritesEvents;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get favoritesAll;

  /// L4.6: Favorites — button label.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get favoritesMap;

  /// L4.6: Favorites — button label.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get favoritesResume;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Create listing from smart search'**
  String get favoritesListingFromSmart;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Delete smart search'**
  String get favoritesDeleteSmart;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Smart search'**
  String get favoritesSmartSearch;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Create listing from saved conditions'**
  String get favoritesListingFromSaved;

  /// L4.6: Favorites — chip label.
  ///
  /// In en, this message translates to:
  /// **'Delete saved conditions'**
  String get favoritesDeleteSaved;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Saved conditions'**
  String get favoritesSavedConditions;

  /// L4.6: Favorites — secondary line.
  ///
  /// In en, this message translates to:
  /// **'Conditions and prompts ready to continue'**
  String get favoritesSavedIntentsHint;

  /// L4.6: Favorites — title.
  ///
  /// In en, this message translates to:
  /// **'Saved intents'**
  String get favoritesSavedIntents;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Open Discover'**
  String get favoritesOpenDiscover;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'No saved events yet'**
  String get favoritesEmpty;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get favoritesRetry;

  /// L4.6: Favorites — text.
  ///
  /// In en, this message translates to:
  /// **'Could not load favorites'**
  String get favoritesLoadFailed;

  /// L4.6: Favorites — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh favorites'**
  String get favoritesRefresh;

  /// L4.6: Visit history — text.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get visitedRemoveFromHistory;

  /// L4.6: Visit history — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Visit actions'**
  String get visitedActions;

  /// L4.6: Visit history — button label.
  ///
  /// In en, this message translates to:
  /// **'Clear period'**
  String get visitedClearPeriod;

  /// L4.6: Visit history — text.
  ///
  /// In en, this message translates to:
  /// **'No visits in this period'**
  String get visitedEmptyPeriod;

  /// L4.6: Visit history — button label.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get visitedClear;

  /// L4.6: Visit history — snackbar message.
  ///
  /// In en, this message translates to:
  /// **'Visit removed'**
  String get visitedRemoved;

  /// L4.6: Visit history — button label.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get visitedRemove;

  /// L4.6: Visit history — button label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get visitedCancel;

  /// L4.6: Visit history — dialog text.
  ///
  /// In en, this message translates to:
  /// **'Remove visit?'**
  String get visitedRemoveVisit;

  /// L4.6: Visit history — text.
  ///
  /// In en, this message translates to:
  /// **'Select visit day'**
  String get visitedSelectDay;

  /// L4.6: Visit history — text.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get visitedSelectMonth;

  /// L4.6: Visit history — title.
  ///
  /// In en, this message translates to:
  /// **'Visit history'**
  String get visitedTitle;

  /// L4.6: Visit history — title.
  ///
  /// In en, this message translates to:
  /// **'Places you explicitly mark as visited will appear here.'**
  String get visitedEmptyHint;

  /// L4.6: Visit history — title.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get visitedEmpty;

  /// L4.6: Visit history — title.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get visitedRetry;

  /// L4.6: Visit history — title.
  ///
  /// In en, this message translates to:
  /// **'Try again.'**
  String get visitedTryAgain;

  /// L4.6: Visit history — title.
  ///
  /// In en, this message translates to:
  /// **'Could not load visits'**
  String get visitedLoadFailed;

  /// L4.6: Visit history — button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh visit history'**
  String get visitedRefresh;

  /// L4.6: Visit history — text.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get visitedSignInRequired;

  /// L4.6: invite a team member by email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get identityEmail;

  /// L4.6: invite a team member by phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get identityPhone;

  /// L4.6: Quick Plan template subtitle.
  ///
  /// In en, this message translates to:
  /// **'A simple free route for a calm recharge window.'**
  String get quickPlanTplFreeCityHint;

  /// L4.6: workspace controller message for a stable code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, workspace_recovered{The unavailable page was reset to your personal profile.}workspace_load_failed{Unable to load workspaces.}workspace_switched{Workspace switched.}workspace_access_unavailable{Access to the selected page is unavailable.}workspace_switch_failed{Unable to switch the workspace.}admin_preview_selected{Admin preview selected.}page_created{Professional Page created and sent for review.}self_service_page_limit_reached{You have reached the limit of 3 pages. Send a request to the moderators.}page_create_failed{Unable to create the Professional Page.}page_limit_request_sent{Request for an additional page sent.}page_limit_request_unavailable{The request is available after you create three pages.}page_limit_request_failed{Unable to send the request to the moderators.} other{Unable to load workspaces.}}'**
  String identityWorkspaceNotice(String code);

  /// L4.6: team invitation message for a stable or server code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, invitation_sent{Invitation sent.}invitation_send_failed{Unable to send the invitation.}invitation_revoked{Invitation revoked.}invitation_revoke_failed{Unable to revoke the invitation.}invitations_load_failed{Unable to load the team invitations.}invitation_target_invalid{Enter a valid user ID, email or phone number.}owner_relationship_not_invitable{Ownership cannot be granted by invitation.}inviter_not_active_member{Only an active team member can send invitations.}inviter_missing_team_manage_capability{You do not have permission to manage the team.}cannot_delegate_capability_not_held{You cannot grant a capability you do not have yourself.}revoke_actor_not_active_member{Only an active team member can revoke invitations.}invitation_not_found{This invitation no longer exists.} other{Unable to send the invitation.}}'**
  String identityTeamNotice(String code);

  /// L4.6: page profile editor message for a stable or server code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, profile_load_failed{Unable to load the page profile.}profile_updated{Profile updated.}profile_update_failed{Unable to update the profile.}default_locale_value_required{Enter a value for the page’s default language.}unsupported_locale{That language is not supported by this page.}value_length_out_of_bounds{That text is empty or too long.}actor_not_active_member{Only an active team member can edit the profile.}actor_missing_page_manage_capability{You do not have permission to edit the page profile.}stale_overlay_revision{This field changed elsewhere. Reload and try again.} other{Unable to update the profile.}}'**
  String identityProfileNotice(String code);

  /// L4.6: public page load message for a stable code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, page_load_failed{Unable to load this page.}page_preview_failed{Unable to load the page preview.} other{Unable to load this page.}}'**
  String identityPublicPageNotice(String code);

  /// L4.6: local inbox notification title for a template code.
  ///
  /// In en, this message translates to:
  /// **'{code, select, identity_page_created_user{Professional Page created}identity_page_created_moderators{New Professional Page}identity_page_limit_request_user{Request sent}identity_page_limit_request_moderators{Additional page request} other{Notification}}'**
  String identityInboxTitle(String code);

  /// L4.6: local inbox notification body for a template code (the page name, if any, is shown separately).
  ///
  /// In en, this message translates to:
  /// **'{code, select, identity_page_created_user{Review status: pending.}identity_page_created_moderators{A new page was created and needs review.}identity_page_limit_request_user{Moderators will review the additional Professional Page.} other{}}'**
  String identityInboxBody(String code);

  /// L4.6: moderators inbox body for a page limit request.
  ///
  /// In en, this message translates to:
  /// **'The user requested a limit of {count, plural, one{{count} page} other{{count} pages}}.'**
  String identityInboxLimitBody(int count);

  /// L4.6: profile role title for a stable role id (Creator stays untranslated until the glossary).
  ///
  /// In en, this message translates to:
  /// **'{value, select, pro_generator{Pro generator}creator{Creator}user{User} other{Creator}}'**
  String profileRoleTitle(String value);

  /// L4.6: Quick Plan route fit level (stable value).
  ///
  /// In en, this message translates to:
  /// **'{value, select, needsStops{Needs stops}ready{Ready}goodWithTweaks{Good with tweaks} other{Needs tuning}}'**
  String quickPlanFitLevel(String value);

  /// L4.6: Quick Plan route fit summary (stable value).
  ///
  /// In en, this message translates to:
  /// **'{value, select, needsStops{Add at least one stop to make this route useful.}ready{This route is ready for map or publishing.}goodWithTweaks{A small optimization can make this route easier to follow.} other{Optimize the route before sending it to Map or Create.}}'**
  String quickPlanFitSummary(String value);

  /// L4.6: route fit insight.
  ///
  /// In en, this message translates to:
  /// **'No stops selected'**
  String get quickPlanFitNoStops;

  /// L4.6: route fit insight: minutes over the limit.
  ///
  /// In en, this message translates to:
  /// **'Trim about {minutes} min'**
  String quickPlanFitTrim(int minutes);

  /// L4.6: route fit insight: the route fits the time limit.
  ///
  /// In en, this message translates to:
  /// **'Fits {minutes} min'**
  String quickPlanFitFits(int minutes);

  /// L4.6: route fit insight.
  ///
  /// In en, this message translates to:
  /// **'Room for one more stop'**
  String get quickPlanFitRoom;

  /// L4.6: route fit insight.
  ///
  /// In en, this message translates to:
  /// **'Remove paid stops for free-only mode'**
  String get quickPlanFitRemovePaid;

  /// L4.6: route fit insight.
  ///
  /// In en, this message translates to:
  /// **'Free route'**
  String get quickPlanFitFreeRoute;

  /// L4.6: route fit insight: total price (formatted money).
  ///
  /// In en, this message translates to:
  /// **'{price} total'**
  String quickPlanFitTotalPrice(String price);

  /// L4.6: route fit insight.
  ///
  /// In en, this message translates to:
  /// **'Shorten transfers for walking mode'**
  String get quickPlanFitShortenTransfers;

  /// L4.6: route fit insight: total distance (formatted number).
  ///
  /// In en, this message translates to:
  /// **'{km} km total'**
  String quickPlanFitTotalDistance(String km);

  /// L4.6: label before a draft title (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Open Search with'**
  String get profileOpenSearchWith;

  /// L4.6: an invited Quick Plan could not be verified.
  ///
  /// In en, this message translates to:
  /// **'Access unavailable. Refresh to retry.'**
  String get quickPlanAccessUnavailable;

  /// L4.6: an invitation action is not confirmed yet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Refresh to retry.'**
  String get quickPlanNotConfirmed;

  /// L4.6: a route template was applied; message is the localized template title.
  ///
  /// In en, this message translates to:
  /// **'{message} applied'**
  String quickPlanTemplateApplied(String message);

  /// L4.6: screen reader label to apply a template; message is the localized template title.
  ///
  /// In en, this message translates to:
  /// **'Apply {message} template'**
  String quickPlanApplyTemplate(String message);

  /// L4.6: expand selected stops into a Scenario.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Expand {count} stop to Scenario} other{Expand {count} stops to Scenario}}'**
  String quickPlanExpandStops(int count);

  /// L4.6: page workspace section.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get identitySectionPage;

  /// L4.6: page workspace section.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get identitySectionContent;

  /// L4.6: page workspace section.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get identitySectionAccount;

  /// L4.6: edit a profile field; message is the localized field name.
  ///
  /// In en, this message translates to:
  /// **'Edit {message}'**
  String identityEditField(String message);

  /// L4.6: team invitation status.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get identityInvitationPending;

  /// L4.6: team invitation status.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get identityInvitationRevoked;

  /// L4.6: team invitation status.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get identityInvitationExpired;

  /// L4.6: page kind.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get identityKindCompany;

  /// L4.6: page kind.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get identityKindOrganization;

  /// L4.6: page verification.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get identityUnverified;

  /// L4.6: page verification.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get identityVerified;

  /// L4.6: personal profile label before the city (shown as is).
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get profilePersonal;

  /// L4.6: profile section.
  ///
  /// In en, this message translates to:
  /// **'Bookings & requests'**
  String get profileBookingsRequests;

  /// L4.6: object kind.
  ///
  /// In en, this message translates to:
  /// **'One-time event'**
  String get profileOneTimeEvent;

  /// L4.6: missing draft fields; message is a localized list.
  ///
  /// In en, this message translates to:
  /// **'Missing: {message}'**
  String profileMissingFields(String message);

  /// L4.6: a missing draft field (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, title{title}category{category}city{city}cover{cover image} other{start time}}'**
  String profileMissingField(String value);

  /// L4.6: listing stage.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get profileStagePublished;

  /// L4.6: listing stage.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get profileStageDraft;

  /// L4.6: published listing is complete.
  ///
  /// In en, this message translates to:
  /// **'Published-ready'**
  String get profilePublishedReady;

  /// L4.6: number of missing fields.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} missing} other{{count} missing}}'**
  String profileMissingCount(int count);

  /// L4.6: filter: all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get profileAll;

  /// L4.6: retry pending invitation actions.
  ///
  /// In en, this message translates to:
  /// **'Refresh / retry pending'**
  String get quickPlanRetryPending;

  /// L4.6: label before a plan id.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get quickPlanPlanLabel;

  /// L4.6: Quick Plan invitation status (server code).
  ///
  /// In en, this message translates to:
  /// **'{code, select, pending{Pending}active{Active}accepted{Accepted}declined{Declined}revoked{Revoked}left{Left} other{Unknown status}}'**
  String quickPlanGrantStatus(String code);

  /// L4.6: label before an invitee user id.
  ///
  /// In en, this message translates to:
  /// **'Invitee'**
  String get quickPlanInvitee;

  /// L4.6: label before an owner user id.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get quickPlanOwner;

  /// L4.6: invite again.
  ///
  /// In en, this message translates to:
  /// **'Re-invite'**
  String get quickPlanReinvite;

  /// L4.6: Quick Plan hero line by mood (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm route, ready to follow or adjust.}social{Social route, ready to follow or adjust.}active{Active route, ready to follow or adjust.} other{Custom route, ready to follow or adjust.}}'**
  String quickPlanMoodReady(String value);

  /// L4.6: Quick Plan heading by mood (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm plan}social{Social plan}active{Active plan} other{Custom plan}}'**
  String quickPlanMoodPlan(String value);

  /// L4.6: saved Quick Plan title by mood (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, calm{Calm quick plan}social{Social quick plan}active{Active quick plan} other{Custom quick plan}}'**
  String quickPlanMoodQuickPlan(String value);

  /// L4.6: a template is applied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get quickPlanApplied;

  /// L4.6: use a template.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get quickPlanUse;

  /// L4.6: favorite action.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get favoritesEdit;

  /// L4.6: favorite action.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get favoritesOpen;

  /// L4.6: favorite action.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get favoritesRoute;

  /// L4.6: visit filter: month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get visitedMonth;

  /// L4.6: visit filter: day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get visitedDay;

  /// L4.6: Android notification while a Route records in the background.
  ///
  /// In en, this message translates to:
  /// **'Route recording is active'**
  String get routeRecordingNotificationTitle;

  /// L4.6: Android notification while a Route records in the background (GPS privacy: keep the meaning).
  ///
  /// In en, this message translates to:
  /// **'Recharge is saving your route while the app is in the background.'**
  String get routeRecordingNotificationText;

  /// L4.6: Activity form: save the step and go to the next one.
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get createFormSaveContinue;

  /// L4.6: Class / Workshop form: the publisher is the instructor.
  ///
  /// In en, this message translates to:
  /// **'I lead this class myself'**
  String get createClassLeadMyself;

  /// L4.6: Profile page — section label in capitals.
  ///
  /// In en, this message translates to:
  /// **'CONTROL CENTER'**
  String get profileControlCenter;

  /// L4.6: Profile page — section label in capitals.
  ///
  /// In en, this message translates to:
  /// **'LATEST CREATED EVENTS'**
  String get profileLatestCreatedEvents;

  /// L4.6: Profile page — section label in capitals.
  ///
  /// In en, this message translates to:
  /// **'QUICK ACTIONS'**
  String get profileQuickActions;

  /// L4.6: Profile page — heading of the creator workspace block.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get profileWorkspaceHeading;

  /// L4.6: Profile page — number of searches the reader can continue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} search to continue} other{{count} searches to continue}}'**
  String profileSearchContinuations(int count);

  /// L4.6: Profile page — number of saved activities.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} activity} other{{count} activities}}'**
  String profileActivitiesCount(int count);

  /// L4.6: Profile page — number of saved routes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} route} other{{count} routes}}'**
  String profileRoutesCount(int count);

  /// L4.6: Profile page — number of saved ideas.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} saved idea ready} other{{count} saved ideas ready}}'**
  String profileSavedIdeasReady(int count);

  /// L4.6: Profile page — label before the reader's own search text, shown as is after a colon.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get profileResume;

  /// L4.6: Scenario builder (Quick Plan) — a shared plan opened without editing rights.
  ///
  /// In en, this message translates to:
  /// **'Read-only · online access required'**
  String get quickPlanReadOnlyOnline;

  /// L4.6: Scenario builder (Quick Plan) — heading of the plan conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get quickPlanConditions;

  /// L4.6: Scenario builder (Quick Plan) — label before the reader's own search text, shown as is after a colon.
  ///
  /// In en, this message translates to:
  /// **'Intent'**
  String get quickPlanIntentLabel;

  /// L4.6: Visit history — subtitle under the title.
  ///
  /// In en, this message translates to:
  /// **'Private, self-reported places you visited.'**
  String get visitedPrivateHint;

  /// L4.6: Visit history — a visit the reader marked themselves.
  ///
  /// In en, this message translates to:
  /// **'Self-reported'**
  String get visitedSelfReported;

  /// L4.6: Professional Page profile editor — card heading.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get identityProfile;

  /// L4.6: Professional Page team invitations — card heading.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get identityTeam;

  /// L4.6: Professional Page team invitations — the invitee field is empty.
  ///
  /// In en, this message translates to:
  /// **'Required.'**
  String get identityRequired;

  /// L4.6: Profile, workspace switcher — section label in capitals.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL'**
  String get identitySectionPersonal;

  /// L4.6: Profile, workspace switcher — section label in capitals; the role term stays in English until the glossary review.
  ///
  /// In en, this message translates to:
  /// **'PROFESSIONAL PAGES'**
  String get identitySectionProfessionalPages;

  /// L4.6: Profile, workspace switcher — section label in capitals.
  ///
  /// In en, this message translates to:
  /// **'ADMINISTRATION'**
  String get identitySectionAdministration;

  /// L4.6: Profile, workspace switcher — used self-service pages; count is used, max is the limit.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, one{{count} of {max} self-service page used} other{{count} of {max} self-service pages used}}'**
  String identityPagesUsed(int count, int max);

  /// L4.6: public Professional Page — number of published items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} published item} other{{count} published items}}'**
  String identityPublishedItems(int count);

  /// L4.6: Profile, Scenario library — card heading.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get profileScenarioLibrary;

  /// L4.6: Home — tagline in capitals under the RECHARGE wordmark.
  ///
  /// In en, this message translates to:
  /// **'VACATION APP'**
  String get discoverHomeTagline;

  /// L4.6: Create, category picker — search field; count is the number of subcategories.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Search {count} category} other{Search {count} categories}}'**
  String createTaxonomySearchCategories(int count);

  /// L4.6: Create, Place — number of opening-hours rules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} opening rule} other{{count} opening rules}}'**
  String createFormOpeningRules(int count);

  /// L4.6: Create, Place — adds the standard opening hours to every day.
  ///
  /// In en, this message translates to:
  /// **'Add 09:00–21:00'**
  String get createFormAddHours;

  /// L4.6: Create — minimum visit duration chip.
  ///
  /// In en, this message translates to:
  /// **'Minimum {minutes} min'**
  String createFormMinimumVisitChip(int minutes);

  /// L4.6: Create — participants so far and the limit.
  ///
  /// In en, this message translates to:
  /// **'Capacity {current}/{max}'**
  String createFormCapacityOf(int current, int max);

  /// L4.6: Create — a distance in meters; value is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String createFormMetersValue(String value);

  /// L4.6: Create, Route — number of track points.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} point} other{{count} points}}'**
  String createFormPointsCount(int count);

  /// L4.6: Route moderation — label before a version id.
  ///
  /// In en, this message translates to:
  /// **'version'**
  String get createRouteVersionLabel;

  /// L4.6: Route moderation — label before a geometry hash.
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get createRouteGeometryLabel;

  /// L4.6: Create, Activity — optional contribution option.
  ///
  /// In en, this message translates to:
  /// **'Purchase (e.g. coffee at the counter)'**
  String get createActivityPurchaseHint;

  /// L4.6: Create, Activity — smallest suggested group.
  ///
  /// In en, this message translates to:
  /// **'Group, min people'**
  String get createActivityGroupMin;

  /// L4.6: Create — duration range.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} min'**
  String createFormMinutesRange(int min, int max);

  /// L4.6: Create — rights confirmation for images.
  ///
  /// In en, this message translates to:
  /// **'I have permission to use these images'**
  String get createFormImagesPermission;

  /// L4.6: Create, Class / Workshop — multi-line field.
  ///
  /// In en, this message translates to:
  /// **'Outcomes (one per line)'**
  String get createClassOutcomesPerLine;

  /// L4.6: Create, Class / Workshop — multi-line field.
  ///
  /// In en, this message translates to:
  /// **'Prerequisites (one per line)'**
  String get createClassPrerequisitesPerLine;

  /// L4.6: Create, Class / Workshop — the repeated hour when clocks go back.
  ///
  /// In en, this message translates to:
  /// **'Second (winter time)'**
  String get createClassFoldSecond;

  /// L4.6: Create, Class / Workshop — start time field with its format.
  ///
  /// In en, this message translates to:
  /// **'Start (HH:MM)'**
  String get createClassStartHhmm;

  /// L4.6: Create, Class / Workshop — end time field with its format.
  ///
  /// In en, this message translates to:
  /// **'End (HH:MM)'**
  String get createClassEndHhmm;

  /// L4.6: Create, Collection review — the title is still empty.
  ///
  /// In en, this message translates to:
  /// **'(no title yet)'**
  String get createCollectionNoTitleYet;

  /// L4.6: Create, Collection — heading of removing a published item.
  ///
  /// In en, this message translates to:
  /// **'Published — remove without review'**
  String get createCollectionPublishedRemove;

  /// L4.6: Create, Collection — type of a catalog object (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, place{Place}route{Route}bookableSession{Session}classWorkshop{Class / Workshop}rental{Rental} other{Object}}'**
  String createCollectionObjectType(String value);

  /// L4.6: Create, Event — label before the admission preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get createEventPreviewLabel;

  /// L4.6: Create, Event — switch for the optional response.
  ///
  /// In en, this message translates to:
  /// **'Optional “Interested” response'**
  String get createEventInterestedOptional;

  /// L4.6: Create, Event — label before the availability state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get createEventAvailabilityLabel;

  /// L4.6: Create, Event — availability state (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, available{available}lowAvailability{few places left}soldOut{sold out}waitlistAvailable{waitlist open}registrationClosed{registration closed}cancelled{cancelled}stale{out of date} other{unknown}}'**
  String createEventAvailabilityState(String value);

  /// L4.6: Create, Event — how fresh the availability is (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, current{current}stale{out of date} other{unknown}}'**
  String createEventAvailabilityFreshness(String value);

  /// L4.6: Create, Event — label before the suggested event type.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get createEventSuggestedLabel;

  /// L4.6: Create, Event — event type (stable wire name).
  ///
  /// In en, this message translates to:
  /// **'{value, select, performance{Performance}screening{Screening}exhibition{Exhibition}open_stage{Open stage}meet_greet{Meet and greet}talk{Talk}discussion{Discussion}conference{Conference}networking{Networking}social_meetup{Social meetup}hosted_game{Hosted game}open_play{Open play}competition{Competition}class_session{Class}workshop{Workshop}retreat_camp{Retreat or camp}wellness_session{Wellness session}tasting{Tasting}shared_meal{Shared meal}party{Party}celebration{Celebration}festival{Festival}market_fair{Market or fair}auction{Auction}launch_promotion{Launch or promotion}open_day{Open day}tour_excursion{Tour or excursion}outdoor_gathering{Outdoor gathering}community_action{Community action}volunteering{Volunteering}fundraiser{Fundraiser}family_program{Family program}ceremony{Ceremony} other{Other}}'**
  String createEventArchetype(String value);

  /// L4.6: Create, Event — what visitors do (stable wire name).
  ///
  /// In en, this message translates to:
  /// **'{value, select, mode_watch{Watch}mode_attend{Attend}mode_play{Play}mode_compete{Compete}mode_perform{Perform}mode_practice{Practice}mode_learn{Learn}mode_create{Create}mode_meet_people{Meet people}mode_date{Date}mode_visit{Visit}mode_explore{Explore}mode_eat_drink{Eat and drink}mode_shop{Shop}mode_support{Support}mode_volunteer{Volunteer}mode_travel{Travel} other{Other}}'**
  String createEventParticipationMode(String value);

  /// L4.6: Create, Event — screen reader label; message is the localized role.
  ///
  /// In en, this message translates to:
  /// **'{message}: additional attendee role'**
  String createEventAdditionalRole(String message);

  /// L4.6: Create, Event — rights confirmation; the star marks a required field.
  ///
  /// In en, this message translates to:
  /// **'I have the right to publish this media *'**
  String get createEventMediaRights;

  /// L4.6: Create, Event — switch.
  ///
  /// In en, this message translates to:
  /// **'All-day event'**
  String get createEventAllDay;

  /// L4.6: Create, Event — field for an IANA time zone.
  ///
  /// In en, this message translates to:
  /// **'IANA timezone'**
  String get createEventIanaTimezone;

  /// L4.6: Create, Event — dates generated from the schedule.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} occurrence materialized} other{{count} occurrences materialized}}'**
  String createEventOccurrencesCount(int count);

  /// L4.6: Create, Event — label before the next date.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get createEventNextDateLabel;

  /// L4.6: Create, Event — price field; value is the currency code.
  ///
  /// In en, this message translates to:
  /// **'Price ({value})'**
  String createEventPriceIn(String value);

  /// L4.6: Create — go to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createFormContinue;

  /// L4.6: Create, Event — section heading.
  ///
  /// In en, this message translates to:
  /// **'Capacity & inventory'**
  String get createEventCapacityInventory;

  /// L4.6: Create, Event — label before the per-channel pool counts.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get createEventPoolsLabel;

  /// L4.6: Create, Event — field.
  ///
  /// In en, this message translates to:
  /// **'Zone/table reference'**
  String get createEventZoneReference;

  /// L4.6: Create, Find People — field.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma-separated, up to 8)'**
  String get createFindPeopleTagsField;

  /// L4.6: Create, Find People — field.
  ///
  /// In en, this message translates to:
  /// **'Pace (optional)'**
  String get createFindPeoplePaceOptional;

  /// L4.6: Create, Find People — hint of the private access reference.
  ///
  /// In en, this message translates to:
  /// **'Session-scoped secure reference; never shown publicly'**
  String get createFindPeopleSecretRefHint;

  /// L4.6: Create — money amount field.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get createFormAmount;

  /// L4.6: Create, Find People — step title.
  ///
  /// In en, this message translates to:
  /// **'Hosts, visibility, and communication'**
  String get createFindPeopleHostsTitle;

  /// L4.6: Create, Find People — step subtitle.
  ///
  /// In en, this message translates to:
  /// **'Co-host permissions remain inactive until the invited user accepts the role.'**
  String get createFindPeopleCohostInactive;

  /// L4.6: Create, Find People — confirmation; the star marks a required field.
  ///
  /// In en, this message translates to:
  /// **'I confirm that all details are accurate *'**
  String get createFindPeopleAccuracyConfirm;

  /// L4.6: Create — the reader cannot edit this draft.
  ///
  /// In en, this message translates to:
  /// **'Read-only draft'**
  String get createFormReadOnlyDraft;

  /// L4.6: Create, Place — required field; the star marks it.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get createFormDescriptionRequired;

  /// L4.6: Create, Place — recommended field.
  ///
  /// In en, this message translates to:
  /// **'Description (recommended)'**
  String get createFormDescriptionRecommended;

  /// L4.6: Create, Place — length hint.
  ///
  /// In en, this message translates to:
  /// **'20–180 characters.'**
  String get createPlaceShortDescHint;

  /// L4.6: Create, Place — subtitle of the directions section.
  ///
  /// In en, this message translates to:
  /// **'Optional: entrance, path or meeting point'**
  String get createPlaceDirectionsHint;

  /// L4.6: Create, Place — opening hours option.
  ///
  /// In en, this message translates to:
  /// **'Open 24/7'**
  String get createPlaceOpen247;

  /// L4.6: Create, Place — disabled opening hours option.
  ///
  /// In en, this message translates to:
  /// **'Seasonal (Phase 2)'**
  String get createPlaceSeasonalPhase2;

  /// L4.6: Create — date field showing its format.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get createFormDateFormatHint;

  /// L4.6: Create, Place — closed-until date field.
  ///
  /// In en, this message translates to:
  /// **'Until (inclusive)'**
  String get createPlaceUntilInclusive;

  /// L4.6: Create, Place — switch.
  ///
  /// In en, this message translates to:
  /// **'A shorter visit can still work'**
  String get createPlaceShortVisit;

  /// L4.6: Create, Place — subtitle of the photos section.
  ///
  /// In en, this message translates to:
  /// **'A cover is recommended and can be added later.'**
  String get createPlaceCoverRecommended;

  /// L4.6: Create, Place — subtitle of the gallery section.
  ///
  /// In en, this message translates to:
  /// **'Optional · maximum 12'**
  String get createPlaceGalleryOptional;

  /// L4.6: Create, Place — acknowledges the warnings.
  ///
  /// In en, this message translates to:
  /// **'I reviewed these warnings'**
  String get createPlaceWarningsReviewed;

  /// L4.6: Create — progress of a review.
  ///
  /// In en, this message translates to:
  /// **'Reviewing…'**
  String get createFormReviewing;

  /// L4.6: Create, Place — recommended visit length in the preview.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min recommended'**
  String createPlaceRecommendedMinutes(int minutes);

  /// L4.6: Create, Place — disabled action in the preview.
  ///
  /// In en, this message translates to:
  /// **'Route (primary action)'**
  String get createPlaceRoutePrimary;

  /// L4.6: Create, Place — why an existing place looks like a duplicate (stable code).
  ///
  /// In en, this message translates to:
  /// **'{code, select, title_match{similar name}category_match{same category}official_domain_match{same website}phone_match{same phone} other{similar details}}'**
  String createPlaceDuplicateReason(String code);

  /// L4.6: Create, Rental — field.
  ///
  /// In en, this message translates to:
  /// **'Brand / model (optional)'**
  String get createRentalBrandModel;

  /// L4.6: Create, Rental — confirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm this category is correct'**
  String get createRentalConfirmCategory;

  /// L4.6: Create, Rental — field.
  ///
  /// In en, this message translates to:
  /// **'Size / variant'**
  String get createRentalSizeVariant;

  /// L4.6: Create — when something was confirmed; date is formatted.
  ///
  /// In en, this message translates to:
  /// **'Confirmed {date}'**
  String createFormConfirmedOn(String date);

  /// L4.6: Create, Rental — blocked units.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unit blocked} other{{count} units blocked}}'**
  String createRentalUnitsBlocked(int count);

  /// L4.6: Create, Rental — subtitle of the suggested defaults.
  ///
  /// In en, this message translates to:
  /// **'Editable — nothing applies automatically.'**
  String get createRentalDefaultsEditable;

  /// L4.6: Create, Rental — checkbox.
  ///
  /// In en, this message translates to:
  /// **'ID required at handover'**
  String get createRentalIdRequired;

  /// L4.6: Create, Rental — field.
  ///
  /// In en, this message translates to:
  /// **'Currency (ISO 4217)'**
  String get createRentalCurrencyField;

  /// L4.6: Create, Rental — a rate step; price is the amount in minor units with its currency code.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{From {count} unit: {price} minor} other{From {count} units: {price} minor}}'**
  String createRentalRateStep(int count, String price);

  /// L4.6: Create, Rental — field.
  ///
  /// In en, this message translates to:
  /// **'Deposit (minor units, 0 = none)'**
  String get createRentalDepositField;

  /// L4.6: Create, Rental — notice on the review step.
  ///
  /// In en, this message translates to:
  /// **'Private — not public: exact pickup address, geo and handover instructions are entered separately and never appear here.'**
  String get createRentalPrivateNotice;

  /// L4.6: Create, Rental — attestation.
  ///
  /// In en, this message translates to:
  /// **'I have the right to offer this for rent'**
  String get createRentalRightToOffer;

  /// L4.6: Create — progress through the steps.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String createFormStepOf(int current, int total);

  /// L4.6: Create, Route — section title.
  ///
  /// In en, this message translates to:
  /// **'GPX export'**
  String get createRouteGpxExport;

  /// L4.6: Create, Route — export result.
  ///
  /// In en, this message translates to:
  /// **'GPX file saved.'**
  String get createRouteGpxSaved;

  /// L4.6: Create — file size; value is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String createFormBytes(String value);

  /// L4.6: Create — file size; value is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String createFormKilobytes(String value);

  /// L4.6: Create — file size; value is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String createFormMegabytes(String value);

  /// L4.6: Create, Route — kind of a GPX candidate (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, track{Track} other{Route}}'**
  String createRouteGpxKind(String value);

  /// L4.6: Create, Route — number of GPX segments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} segment} other{{count} segments}}'**
  String createRouteSegmentsCount(int count);

  /// L4.6: Create, Route — checkbox.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Connect {count} gap with straight lines} other{Connect {count} gaps with straight lines}}'**
  String createRouteConnectGaps(int count);

  /// L4.6: Create, Route — switch.
  ///
  /// In en, this message translates to:
  /// **'Import {count} POI'**
  String createRouteImportPoi(int count);

  /// L4.6: Create, Route — list title.
  ///
  /// In en, this message translates to:
  /// **'Anchors ({count})'**
  String createRouteAnchorsTitle(int count);

  /// L4.6: Create, Route — screen reader label; start is the latitude, end the longitude.
  ///
  /// In en, this message translates to:
  /// **'Anchor {index}, latitude {start}, longitude {end}'**
  String createRouteAnchorSemantics(int index, String start, String end);

  /// L4.6: Create, Route — list title.
  ///
  /// In en, this message translates to:
  /// **'Segments ({count})'**
  String createRouteSegmentsTitle(int count);

  /// L4.6: Create, Route — empty list.
  ///
  /// In en, this message translates to:
  /// **'A segment appears after the second anchor.'**
  String get createRouteSegmentAppears;

  /// L4.6: Create, Route — list row.
  ///
  /// In en, this message translates to:
  /// **'Segment {index}'**
  String createRouteSegmentN(int index);

  /// L4.6: Create, Route — list title.
  ///
  /// In en, this message translates to:
  /// **'Waypoints ({count})'**
  String createRouteWaypointsTitle(int count);

  /// L4.6: Create, Route — dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Anchor {index}'**
  String createRouteAnchorN(int index);

  /// L4.6: Create, Route recording — accepted GPS points.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} accepted point} other{{count} accepted points}}'**
  String createRouteAcceptedPoints(int count);

  /// L4.6: Create, Route recording — value is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} m avg'**
  String createRouteAverageAccuracy(String value);

  /// L4.6: Create, Route recording — excluded GPS points.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unsafe point excluded.} other{{count} unsafe points excluded.}}'**
  String createRouteUnsafePoints(int count);

  /// L4.6: Create, Route recording — a gap; total is in seconds.
  ///
  /// In en, this message translates to:
  /// **'Gap {index}: {meters} m, {total} s'**
  String createRouteGapLabel(int index, int meters, int total);

  /// L4.6: Create, Route recording — saved GPS points.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} GPS point saved} other{{count} GPS points saved}}'**
  String createRouteGpsPointsSaved(int count);

  /// L4.6: Create, Route recording — status.
  ///
  /// In en, this message translates to:
  /// **'GPS needs attention'**
  String get createRouteGpsAttention;

  /// L4.6: Create, Route recording — an unknown recording failure; no code is shown.
  ///
  /// In en, this message translates to:
  /// **'GPS recording could not continue safely.'**
  String get createRouteGpsUnsafeStop;

  /// L4.6: Create, Route review.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} blocking check} other{{count} blocking checks}}'**
  String createRouteBlockingChecks(int count);

  /// L4.6: Create, Route review.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} warning to review} other{{count} warnings to review}}'**
  String createRouteWarningsToReview(int count);

  /// L4.6: Create, Route review — value is a formatted number.
  ///
  /// In en, this message translates to:
  /// **'{value} m unknown'**
  String createRouteUnknownSurfaceMeters(String value);

  /// L4.6: Create, Scenario — the single day of the plan.
  ///
  /// In en, this message translates to:
  /// **'Day 1'**
  String get createScenarioDayOne;

  /// L4.6: Create, Scenario — progress.
  ///
  /// In en, this message translates to:
  /// **'Rechecking…'**
  String get createScenarioRechecking;

  /// L4.6: Create, Scenario — a leg without a time.
  ///
  /// In en, this message translates to:
  /// **'time not entered'**
  String get createScenarioTimeNotEntered;

  /// L4.6: Create, Scenario — field.
  ///
  /// In en, this message translates to:
  /// **'Duration, minutes'**
  String get createScenarioDurationMinutesField;

  /// L4.6: Create, Scenario — hint of a custom stop.
  ///
  /// In en, this message translates to:
  /// **'Park, viewpoint, private address…'**
  String get createScenarioStopHint;

  /// L4.6: Create, Scenario review.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} blocking issue} other{{count} blocking issues}}'**
  String createScenarioBlockingIssues(int count);

  /// L4.6: Create, Scenario — schedule recheck result.
  ///
  /// In en, this message translates to:
  /// **'A changed service was found'**
  String get createScenarioServiceChanged;

  /// L4.6: Create, Scenario — how recent the schedule data is.
  ///
  /// In en, this message translates to:
  /// **'Freshness'**
  String get createScenarioFreshnessLabel;

  /// L4.6: Create, Scenario — schedule freshness (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, current{current}stale{stale}unavailable{unavailable} other{unknown}}'**
  String createScenarioFreshness(String value);

  /// L4.6: Create, Scenario — earliest departure; time is formatted.
  ///
  /// In en, this message translates to:
  /// **'After {time}'**
  String createScenarioAfterTime(String time);

  /// L4.6: Create, Scenario — a stop search found nothing.
  ///
  /// In en, this message translates to:
  /// **'No stops found.'**
  String get createScenarioNoStopsFound;

  /// L4.6: Create, Scenario — screen reader label of a departure; start and end are times.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}, {minutes} minutes, planned schedule not live'**
  String createScenarioDepartureSemantics(
    String start,
    String end,
    int minutes,
  );

  /// L4.6: Create, Scenario — field.
  ///
  /// In en, this message translates to:
  /// **'Carrier (optional)'**
  String get createScenarioCarrierOptional;

  /// L4.6: Create, Scenario — hint with example services.
  ///
  /// In en, this message translates to:
  /// **'Train 802 / Bus 7480'**
  String get createScenarioServiceHint;

  /// L4.6: Create, Scenario — required field; the star marks it.
  ///
  /// In en, this message translates to:
  /// **'Duration, min *'**
  String get createScenarioDurationMinRequired;

  /// L4.6: Create, Scenario — field.
  ///
  /// In en, this message translates to:
  /// **'Duration, min'**
  String get createScenarioDurationMin;

  /// L4.6: Create, Scenario — field.
  ///
  /// In en, this message translates to:
  /// **'Distance, km'**
  String get createScenarioDistanceKm;

  /// L4.6: Create, Scenario — field.
  ///
  /// In en, this message translates to:
  /// **'Parking / ticket / other cost (optional)'**
  String get createScenarioOtherCost;

  /// L4.6: Create, Session — field.
  ///
  /// In en, this message translates to:
  /// **'Timezone (IANA, e.g. Europe/Riga)'**
  String get createSessionTimezoneField;

  /// L4.6: Create — state of a confirmation button.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get createFormConfirmed;

  /// L4.6: Create, Session — pause after a slot.
  ///
  /// In en, this message translates to:
  /// **'Buffer {minutes} min'**
  String createSessionBuffer(int minutes);

  /// L4.6: Create, Session — minimum notice before a slot.
  ///
  /// In en, this message translates to:
  /// **'notice {minutes} min'**
  String createSessionNotice(int minutes);

  /// L4.6: Create, Session — after the buffer and notice values.
  ///
  /// In en, this message translates to:
  /// **'platform defaults, change anytime'**
  String get createSessionPlatformDefaults;

  /// L4.6: Create, Session — price chip; Sessions are priced in euro here.
  ///
  /// In en, this message translates to:
  /// **'€ Fixed'**
  String get createSessionPriceFixed;

  /// L4.6: Create, Session — section heading.
  ///
  /// In en, this message translates to:
  /// **'Optional — add now or after publishing'**
  String get createSessionOptionalLater;

  /// L4.6: Discover, categories — screen reader count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} result} other{{count} results}}'**
  String discoverResultsCount(int count);

  /// L4.6: Discover, category page — heading.
  ///
  /// In en, this message translates to:
  /// **'Subcategories'**
  String get discoverSubcategories;

  /// L4.6: Discover, search filters — heading.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get discoverFilterMode;

  /// L4.6: Discover, Details — the travel time is an estimate.
  ///
  /// In en, this message translates to:
  /// **'estimated'**
  String get discoverEstimated;

  /// L4.6: Discover, Details — label before a slot id.
  ///
  /// In en, this message translates to:
  /// **'Slot'**
  String get discoverSlotLabel;

  /// L4.6: Discover — section heading.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get discoverGuides;

  /// L4.6: Discover, guides — number of objects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String discoverItemsCount(int count);

  /// L4.6: Professional Page workspace — verification (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, unverified{Unverified}pending{Verification pending}verified{Verified}rejected{Verification rejected}revoked{Verification revoked} other{Unverified}}'**
  String identityVerificationStatus(String value);

  /// L4.6: Professional Page team — role in the team (stable id).
  ///
  /// In en, this message translates to:
  /// **'{value, select, owner{Owner}manager{Manager} other{Editor}}'**
  String identityRelationship(String value);

  /// L4.8: server refusal — another account is signed in now.
  ///
  /// In en, this message translates to:
  /// **'The signed-in account changed. Refresh and try again.'**
  String get errorAccountChanged;

  /// L4.8: server refusal — a privacy restriction pauses changes to this data.
  ///
  /// In en, this message translates to:
  /// **'This action is unavailable while your data processing is restricted.'**
  String get errorProcessingRestricted;

  /// L4.8: server refusal — the object is still published.
  ///
  /// In en, this message translates to:
  /// **'Withdraw the publication first, then try again.'**
  String get errorPublicationActive;

  /// L4.8: Visit history refusal.
  ///
  /// In en, this message translates to:
  /// **'A visit date cannot be in the future.'**
  String get libraryErrorVisitFuture;

  /// L4.8: Visit history refusal — the place has no usable time zone.
  ///
  /// In en, this message translates to:
  /// **'This place has no valid time zone, so the visit cannot be recorded.'**
  String get libraryErrorPlaceTimezone;

  /// L4.8: Quick Plan refusal.
  ///
  /// In en, this message translates to:
  /// **'This plan has reached its invitation limit.'**
  String get quickPlanErrorInviteLimit;

  /// L4.8: Scenario refusal — a shared link is out of date.
  ///
  /// In en, this message translates to:
  /// **'This link has expired.'**
  String get scenarioErrorLinkExpired;

  /// L4.8: Route refusal.
  ///
  /// In en, this message translates to:
  /// **'This route is too large to save.'**
  String get routeErrorTooLarge;

  /// L4.8: Route refusal.
  ///
  /// In en, this message translates to:
  /// **'This route has too many points.'**
  String get routeErrorTooManyPoints;

  /// L4.8: Route refusal.
  ///
  /// In en, this message translates to:
  /// **'The route track is not valid.'**
  String get routeErrorGeometry;

  /// L4.8: Route refusal — the source licence does not allow this.
  ///
  /// In en, this message translates to:
  /// **'The licence of this route source does not allow this.'**
  String get routeErrorLicense;

  /// L4.8: Route refusal — the origin of the track cannot be confirmed.
  ///
  /// In en, this message translates to:
  /// **'The origin of this track could not be confirmed.'**
  String get routeErrorProvenance;

  /// L4.8: Route refusal — privacy trim values.
  ///
  /// In en, this message translates to:
  /// **'The hidden start and end of the route are not valid.'**
  String get routeErrorTrimInvalid;

  /// L4.8: Route refusal.
  ///
  /// In en, this message translates to:
  /// **'Add a route title first.'**
  String get routeErrorTitleRequired;

  /// L4.8: Route refusal.
  ///
  /// In en, this message translates to:
  /// **'The limit for sharing this route has been reached.'**
  String get routeErrorDistributionLimit;

  /// L4.8: sign-in session refusal.
  ///
  /// In en, this message translates to:
  /// **'This account is blocked.'**
  String get identityErrorAccountBlocked;

  /// L4.8: sign-in session refusal.
  ///
  /// In en, this message translates to:
  /// **'This account is restricted.'**
  String get identityErrorAccountRestricted;

  /// L4.8: sign-in session refusal.
  ///
  /// In en, this message translates to:
  /// **'Too many active sessions. Sign out on another device and try again.'**
  String get identityErrorSessionLimit;

  /// L4.8: sign-in session refusal.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get identityErrorRecentAuth;

  /// L4.8: client refusal — the local change queue is full.
  ///
  /// In en, this message translates to:
  /// **'Too many unsent changes. Connect to the internet and try again.'**
  String get localErrorStorageFull;

  /// L4.8: client refusal — a queued import cannot be repeated.
  ///
  /// In en, this message translates to:
  /// **'This import cannot be repeated. Import the file again.'**
  String get localErrorImportNotReappliable;

  /// L4.9.5: Category System category `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Music & nightlife'**
  String get taxCategoryMusicNightlife;

  /// L4.9.5: Category System category `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Comedy & performance'**
  String get taxCategoryComedyTheatrePerformance;

  /// L4.9.5: Category System category `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cinema & screenings'**
  String get taxCategoryCinemaScreenings;

  /// L4.9.5: Category System category `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Art, culture & museums'**
  String get taxCategoryArtCultureMuseums;

  /// L4.9.5: Category System category `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Education & talks'**
  String get taxCategoryEducationTalks;

  /// L4.9.5: Category System category `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Business & networking'**
  String get taxCategoryBusinessNetworking;

  /// L4.9.5: Category System category `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Workshops & masterclasses'**
  String get taxCategoryWorkshopsMasterclasses;

  /// L4.9.5: Category System category `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Languages & social learning'**
  String get taxCategoryLanguageSocialLearning;

  /// L4.9.5: Category System category `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Food & drinks'**
  String get taxCategoryFoodDrinks;

  /// L4.9.5: Category System category `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Games & indoor'**
  String get taxCategoryGamesIndoor;

  /// L4.9.5: Category System category `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get taxCategorySport;

  /// L4.9.5: Category System category `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get taxCategoryDance;

  /// L4.9.5: Category System category `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Outdoor, nature & walking'**
  String get taxCategoryOutdoorNatureWalking;

  /// L4.9.5: Category System category `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Water activities'**
  String get taxCategoryWaterActivities;

  /// L4.9.5: Category System category `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Winter & seasonal'**
  String get taxCategoryWinterSeasonal;

  /// L4.9.5: Category System category `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Travel & tours'**
  String get taxCategoryTravelTours;

  /// L4.9.5: Category System category `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family & kids'**
  String get taxCategoryFamilyKids;

  /// L4.9.5: Category System category `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pets & animals'**
  String get taxCategoryPetsAnimals;

  /// L4.9.5: Category System category `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Community & charity'**
  String get taxCategoryCommunityCharity;

  /// L4.9.5: Category System category `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Markets & fairs'**
  String get taxCategoryMarketsFairs;

  /// L4.9.5: Category System category `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Holidays & seasonal'**
  String get taxCategoryHolidaysSeasonal;

  /// L4.9.5: Category System category `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Wellness & recharge'**
  String get taxCategoryWellnessRecharge;

  /// L4.9.5: Category System category `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Adrenaline & entertainment'**
  String get taxCategoryAdrenalineEntertainment;

  /// L4.9.5: Category System category `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get taxCategoryAttractions;

  /// L4.9.5: Category System category `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Auto & moto'**
  String get taxCategoryAutoMoto;

  /// L4.9.5: Category System category `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Geek & tech'**
  String get taxCategoryGeekTech;

  /// L4.9.5: Category System category `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dating & singles'**
  String get taxCategoryDatingSingles;

  /// L4.9.5: Category System category `other` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get taxCategoryOther;

  /// L4.9.5: Category System subcategory `concert` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Concert'**
  String get taxSubcategoryConcert;

  /// L4.9.5: Category System subcategory `live_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Live music'**
  String get taxSubcategoryLiveMusic;

  /// L4.9.5: Category System subcategory `acoustic_evening` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Acoustic evening'**
  String get taxSubcategoryAcousticEvening;

  /// L4.9.5: Category System subcategory `jazz` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get taxSubcategoryJazz;

  /// L4.9.5: Category System subcategory `classical_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Classical music'**
  String get taxSubcategoryClassicalMusic;

  /// L4.9.5: Category System subcategory `rock_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Rock music'**
  String get taxSubcategoryRockMusic;

  /// L4.9.5: Category System subcategory `pop_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pop music'**
  String get taxSubcategoryPopMusic;

  /// L4.9.5: Category System subcategory `electronic_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Electronic music'**
  String get taxSubcategoryElectronicMusic;

  /// L4.9.5: Category System subcategory `techno` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Techno'**
  String get taxSubcategoryTechno;

  /// L4.9.5: Category System subcategory `house_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'House music'**
  String get taxSubcategoryHouseMusic;

  /// L4.9.5: Category System subcategory `latin_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Latin music'**
  String get taxSubcategoryLatinMusic;

  /// L4.9.5: Category System subcategory `dj_party` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'DJ party'**
  String get taxSubcategoryDjParty;

  /// L4.9.5: Category System subcategory `club_night` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Club night'**
  String get taxSubcategoryClubNight;

  /// L4.9.5: Category System subcategory `karaoke` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Karaoke'**
  String get taxSubcategoryKaraoke;

  /// L4.9.5: Category System subcategory `open_mic_music` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Open mic music'**
  String get taxSubcategoryOpenMicMusic;

  /// L4.9.5: Category System subcategory `rooftop_party` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Rooftop party'**
  String get taxSubcategoryRooftopParty;

  /// L4.9.5: Category System subcategory `beach_party` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach party'**
  String get taxSubcategoryBeachParty;

  /// L4.9.5: Category System subcategory `themed_party` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Themed party'**
  String get taxSubcategoryThemedParty;

  /// L4.9.5: Category System subcategory `music_festival` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Music festival'**
  String get taxSubcategoryMusicFestival;

  /// L4.9.5: Category System subcategory `listening_party` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Listening party'**
  String get taxSubcategoryListeningParty;

  /// L4.9.5: Category System subcategory `jam_session` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Jam session'**
  String get taxSubcategoryJamSession;

  /// L4.9.5: Category System subcategory `night_bar` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Night bar'**
  String get taxSubcategoryNightBar;

  /// L4.9.5: Category System subcategory `afterwork_drinks` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Afterwork drinks'**
  String get taxSubcategoryAfterworkDrinks;

  /// L4.9.5: Category System subcategory `late_night_social` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Late night social'**
  String get taxSubcategoryLateNightSocial;

  /// L4.9.5: Category System subcategory `group_singing` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Group singing'**
  String get taxSubcategoryGroupSinging;

  /// L4.9.5: Category System subcategory `organ_concert` in `music_nightlife` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Organ concert'**
  String get taxSubcategoryOrganConcert;

  /// L4.9.5: Category System subcategory `standup` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Stand-up'**
  String get taxSubcategoryStandup;

  /// L4.9.5: Category System subcategory `comedy_open_mic` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Comedy open mic'**
  String get taxSubcategoryComedyOpenMic;

  /// L4.9.5: Category System subcategory `theatre` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get taxSubcategoryTheatre;

  /// L4.9.5: Category System subcategory `improvisation` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Improvisation'**
  String get taxSubcategoryImprovisation;

  /// L4.9.5: Category System subcategory `magic_show` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Magic show'**
  String get taxSubcategoryMagicShow;

  /// L4.9.5: Category System subcategory `circus` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Circus'**
  String get taxSubcategoryCircus;

  /// L4.9.5: Category System subcategory `poetry_night` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Poetry night'**
  String get taxSubcategoryPoetryNight;

  /// L4.9.5: Category System subcategory `storytelling` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Storytelling'**
  String get taxSubcategoryStorytelling;

  /// L4.9.5: Category System subcategory `puppet_show` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Puppet show'**
  String get taxSubcategoryPuppetShow;

  /// L4.9.5: Category System subcategory `ballet` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Ballet'**
  String get taxSubcategoryBallet;

  /// L4.9.5: Category System subcategory `opera` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Opera'**
  String get taxSubcategoryOpera;

  /// L4.9.5: Category System subcategory `cabaret` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cabaret'**
  String get taxSubcategoryCabaret;

  /// L4.9.5: Category System subcategory `street_performance` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Street performance'**
  String get taxSubcategoryStreetPerformance;

  /// L4.9.5: Category System subcategory `performance_art` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Performance art'**
  String get taxSubcategoryPerformanceArt;

  /// L4.9.5: Category System subcategory `drag_show` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Drag show'**
  String get taxSubcategoryDragShow;

  /// L4.9.5: Category System subcategory `musical` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Musical'**
  String get taxSubcategoryMusical;

  /// L4.9.5: Category System subcategory `experimental_theatre` in `comedy_theatre_performance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Experimental theatre'**
  String get taxSubcategoryExperimentalTheatre;

  /// L4.9.5: Category System subcategory `cinema` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get taxSubcategoryCinema;

  /// L4.9.5: Category System subcategory `movie_screening` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Movie screening'**
  String get taxSubcategoryMovieScreening;

  /// L4.9.5: Category System subcategory `open_air_cinema` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Open-air cinema'**
  String get taxSubcategoryOpenAirCinema;

  /// L4.9.5: Category System subcategory `film_festival` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Film festival'**
  String get taxSubcategoryFilmFestival;

  /// L4.9.5: Category System subcategory `documentary` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Documentary'**
  String get taxSubcategoryDocumentary;

  /// L4.9.5: Category System subcategory `short_films` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Short films'**
  String get taxSubcategoryShortFilms;

  /// L4.9.5: Category System subcategory `retro_cinema` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Retro cinema'**
  String get taxSubcategoryRetroCinema;

  /// L4.9.5: Category System subcategory `animation` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get taxSubcategoryAnimation;

  /// L4.9.5: Category System subcategory `sports_screening` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sports screening'**
  String get taxSubcategorySportsScreening;

  /// L4.9.5: Category System subcategory `movie_discussion` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Movie discussion'**
  String get taxSubcategoryMovieDiscussion;

  /// L4.9.5: Category System subcategory `premiere` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Premiere'**
  String get taxSubcategoryPremiere;

  /// L4.9.5: Category System subcategory `independent_film` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Independent film'**
  String get taxSubcategoryIndependentFilm;

  /// L4.9.5: Category System subcategory `cinema_club` in `cinema_screenings` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cinema club'**
  String get taxSubcategoryCinemaClub;

  /// L4.9.5: Category System subcategory `exhibition` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Exhibition'**
  String get taxSubcategoryExhibition;

  /// L4.9.5: Category System subcategory `gallery` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get taxSubcategoryGallery;

  /// L4.9.5: Category System subcategory `museum` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Museum'**
  String get taxSubcategoryMuseum;

  /// L4.9.5: Category System subcategory `museum_night` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Museum night'**
  String get taxSubcategoryMuseumNight;

  /// L4.9.5: Category System subcategory `gallery_walk` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Gallery walk'**
  String get taxSubcategoryGalleryWalk;

  /// L4.9.5: Category System subcategory `artist_talk` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Artist talk'**
  String get taxSubcategoryArtistTalk;

  /// L4.9.5: Category System subcategory `art_walk` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Art walk'**
  String get taxSubcategoryArtWalk;

  /// L4.9.5: Category System subcategory `photography_exhibition` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Photography exhibition'**
  String get taxSubcategoryPhotographyExhibition;

  /// L4.9.5: Category System subcategory `street_art` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Street art'**
  String get taxSubcategoryStreetArt;

  /// L4.9.5: Category System subcategory `architecture` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get taxSubcategoryArchitecture;

  /// L4.9.5: Category System subcategory `cultural_heritage` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cultural heritage'**
  String get taxSubcategoryCulturalHeritage;

  /// L4.9.5: Category System subcategory `monument` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Monument'**
  String get taxSubcategoryMonument;

  /// L4.9.5: Category System subcategory `memorial` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Memorial'**
  String get taxSubcategoryMemorial;

  /// L4.9.5: Category System subcategory `sculpture` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sculpture'**
  String get taxSubcategorySculpture;

  /// L4.9.5: Category System subcategory `historic_landmark` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Historic landmark'**
  String get taxSubcategoryHistoricLandmark;

  /// L4.9.5: Category System subcategory `literature_evening` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Literature evening'**
  String get taxSubcategoryLiteratureEvening;

  /// L4.9.5: Category System subcategory `book_reading` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Book reading'**
  String get taxSubcategoryBookReading;

  /// L4.9.5: Category System subcategory `history_walk` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'History walk'**
  String get taxSubcategoryHistoryWalk;

  /// L4.9.5: Category System subcategory `design_event` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Design event'**
  String get taxSubcategoryDesignEvent;

  /// L4.9.5: Category System subcategory `craft_exhibition` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Craft exhibition'**
  String get taxSubcategoryCraftExhibition;

  /// L4.9.5: Category System subcategory `public_art` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Public art'**
  String get taxSubcategoryPublicArt;

  /// L4.9.5: Category System subcategory `creative_meetup` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Creative meetup'**
  String get taxSubcategoryCreativeMeetup;

  /// L4.9.5: Category System subcategory `fashion_event` in `art_culture_museums` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fashion event'**
  String get taxSubcategoryFashionEvent;

  /// L4.9.5: Category System subcategory `lecture` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Lecture'**
  String get taxSubcategoryLecture;

  /// L4.9.5: Category System subcategory `public_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Public talk'**
  String get taxSubcategoryPublicTalk;

  /// L4.9.5: Category System subcategory `discussion` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get taxSubcategoryDiscussion;

  /// L4.9.5: Category System subcategory `debate` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Debate'**
  String get taxSubcategoryDebate;

  /// L4.9.5: Category System subcategory `panel_discussion` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Panel discussion'**
  String get taxSubcategoryPanelDiscussion;

  /// L4.9.5: Category System subcategory `science_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Science talk'**
  String get taxSubcategoryScienceTalk;

  /// L4.9.5: Category System subcategory `history_lecture` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'History lecture'**
  String get taxSubcategoryHistoryLecture;

  /// L4.9.5: Category System subcategory `psychology_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Psychology talk'**
  String get taxSubcategoryPsychologyTalk;

  /// L4.9.5: Category System subcategory `finance_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Finance talk'**
  String get taxSubcategoryFinanceTalk;

  /// L4.9.5: Category System subcategory `career_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Career talk'**
  String get taxSubcategoryCareerTalk;

  /// L4.9.5: Category System subcategory `legal_info_session` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Legal info session'**
  String get taxSubcategoryLegalInfoSession;

  /// L4.9.5: Category System subcategory `book_club` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Book club'**
  String get taxSubcategoryBookClub;

  /// L4.9.5: Category System subcategory `practical_seminar` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Practical seminar'**
  String get taxSubcategoryPracticalSeminar;

  /// L4.9.5: Category System subcategory `self_development` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Self development'**
  String get taxSubcategorySelfDevelopment;

  /// L4.9.5: Category System subcategory `health_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Health talk'**
  String get taxSubcategoryHealthTalk;

  /// L4.9.5: Category System subcategory `technology_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Technology talk'**
  String get taxSubcategoryTechnologyTalk;

  /// L4.9.5: Category System subcategory `startup_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Startup talk'**
  String get taxSubcategoryStartupTalk;

  /// L4.9.5: Category System subcategory `parenting_talk` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Parenting talk'**
  String get taxSubcategoryParentingTalk;

  /// L4.9.5: Category System subcategory `community_discussion` in `education_talks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Community discussion'**
  String get taxSubcategoryCommunityDiscussion;

  /// L4.9.5: Category System subcategory `networking` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Networking'**
  String get taxSubcategoryNetworking;

  /// L4.9.5: Category System subcategory `business_breakfast` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Business breakfast'**
  String get taxSubcategoryBusinessBreakfast;

  /// L4.9.5: Category System subcategory `business_lunch` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Business lunch'**
  String get taxSubcategoryBusinessLunch;

  /// L4.9.5: Category System subcategory `conference` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Conference'**
  String get taxSubcategoryConference;

  /// L4.9.5: Category System subcategory `product_presentation` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Product presentation'**
  String get taxSubcategoryProductPresentation;

  /// L4.9.5: Category System subcategory `product_launch` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Product launch'**
  String get taxSubcategoryProductLaunch;

  /// L4.9.5: Category System subcategory `startup_meetup` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Startup meetup'**
  String get taxSubcategoryStartupMeetup;

  /// L4.9.5: Category System subcategory `pitch_night` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pitch night'**
  String get taxSubcategoryPitchNight;

  /// L4.9.5: Category System subcategory `investor_meetup` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Investor meetup'**
  String get taxSubcategoryInvestorMeetup;

  /// L4.9.5: Category System subcategory `job_fair` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Job fair'**
  String get taxSubcategoryJobFair;

  /// L4.9.5: Category System subcategory `portfolio_review` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Portfolio review'**
  String get taxSubcategoryPortfolioReview;

  /// L4.9.5: Category System subcategory `freelancers_meetup` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Freelancers meetup'**
  String get taxSubcategoryFreelancersMeetup;

  /// L4.9.5: Category System subcategory `demo_day` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Demo day'**
  String get taxSubcategoryDemoDay;

  /// L4.9.5: Category System subcategory `expo` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Expo'**
  String get taxSubcategoryExpo;

  /// L4.9.5: Category System subcategory `founder_meetup` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Founder meetup'**
  String get taxSubcategoryFounderMeetup;

  /// L4.9.5: Category System subcategory `industry_meetup` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Industry meetup'**
  String get taxSubcategoryIndustryMeetup;

  /// L4.9.5: Category System subcategory `career_networking` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Career networking'**
  String get taxSubcategoryCareerNetworking;

  /// L4.9.5: Category System subcategory `coworking_event` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Coworking event'**
  String get taxSubcategoryCoworkingEvent;

  /// L4.9.5: Category System subcategory `business_workshop` in `business_networking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Business workshop'**
  String get taxSubcategoryBusinessWorkshop;

  /// L4.9.5: Category System subcategory `workshop` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get taxSubcategoryWorkshop;

  /// L4.9.5: Category System subcategory `masterclass` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Masterclass'**
  String get taxSubcategoryMasterclass;

  /// L4.9.5: Category System subcategory `course` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get taxSubcategoryCourse;

  /// L4.9.5: Category System subcategory `pottery` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pottery'**
  String get taxSubcategoryPottery;

  /// L4.9.5: Category System subcategory `ceramics` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Ceramics'**
  String get taxSubcategoryCeramics;

  /// L4.9.5: Category System subcategory `drawing` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get taxSubcategoryDrawing;

  /// L4.9.5: Category System subcategory `painting` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get taxSubcategoryPainting;

  /// L4.9.5: Category System subcategory `photography` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get taxSubcategoryPhotography;

  /// L4.9.5: Category System subcategory `cooking_class` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cooking class'**
  String get taxSubcategoryCookingClass;

  /// L4.9.5: Category System subcategory `sewing` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sewing'**
  String get taxSubcategorySewing;

  /// L4.9.5: Category System subcategory `floristics` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Floristics'**
  String get taxSubcategoryFloristics;

  /// L4.9.5: Category System subcategory `candle_making` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Candle making'**
  String get taxSubcategoryCandleMaking;

  /// L4.9.5: Category System subcategory `public_speaking` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Public speaking'**
  String get taxSubcategoryPublicSpeaking;

  /// L4.9.5: Category System subcategory `creative_class` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Creative class'**
  String get taxSubcategoryCreativeClass;

  /// L4.9.5: Category System subcategory `craft_workshop` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Craft workshop'**
  String get taxSubcategoryCraftWorkshop;

  /// L4.9.5: Category System subcategory `writing_workshop` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Writing workshop'**
  String get taxSubcategoryWritingWorkshop;

  /// L4.9.5: Category System subcategory `music_lesson` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Music lesson'**
  String get taxSubcategoryMusicLesson;

  /// L4.9.5: Category System subcategory `dance_workshop` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance workshop'**
  String get taxSubcategoryDanceWorkshop;

  /// L4.9.5: Category System subcategory `beauty_workshop` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beauty workshop'**
  String get taxSubcategoryBeautyWorkshop;

  /// L4.9.5: Category System subcategory `wellness_workshop` in `workshops_masterclasses` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Wellness workshop'**
  String get taxSubcategoryWellnessWorkshop;

  /// L4.9.5: Category System subcategory `language_exchange` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Language exchange'**
  String get taxSubcategoryLanguageExchange;

  /// L4.9.5: Category System subcategory `english_club` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'English club'**
  String get taxSubcategoryEnglishClub;

  /// L4.9.5: Category System subcategory `dutch_club` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dutch club'**
  String get taxSubcategoryDutchClub;

  /// L4.9.5: Category System subcategory `latvian_club` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Latvian club'**
  String get taxSubcategoryLatvianClub;

  /// L4.9.5: Category System subcategory `conversation_club` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Conversation club'**
  String get taxSubcategoryConversationClub;

  /// L4.9.5: Category System subcategory `international_meetup` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'International meetup'**
  String get taxSubcategoryInternationalMeetup;

  /// L4.9.5: Category System subcategory `expats_meetup` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Expats meetup'**
  String get taxSubcategoryExpatsMeetup;

  /// L4.9.5: Category System subcategory `tandem_meeting` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tandem meeting'**
  String get taxSubcategoryTandemMeeting;

  /// L4.9.5: Category System subcategory `language_cafe` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Language cafe'**
  String get taxSubcategoryLanguageCafe;

  /// L4.9.5: Category System subcategory `language_walk` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Language walk'**
  String get taxSubcategoryLanguageWalk;

  /// L4.9.5: Category System subcategory `speed_friending` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Speed friending'**
  String get taxSubcategorySpeedFriending;

  /// L4.9.5: Category System subcategory `speaking_club` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Speaking club'**
  String get taxSubcategorySpeakingClub;

  /// L4.9.5: Category System subcategory `culture_exchange` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Culture exchange'**
  String get taxSubcategoryCultureExchange;

  /// L4.9.5: Category System subcategory `newcomers_meetup` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Newcomers meetup'**
  String get taxSubcategoryNewcomersMeetup;

  /// L4.9.5: Category System subcategory `study_group` in `language_social_learning` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Study group'**
  String get taxSubcategoryStudyGroup;

  /// L4.9.5: Category System subcategory `coffee` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get taxSubcategoryCoffee;

  /// L4.9.5: Category System subcategory `breakfast` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get taxSubcategoryBreakfast;

  /// L4.9.5: Category System subcategory `brunch` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Brunch'**
  String get taxSubcategoryBrunch;

  /// L4.9.5: Category System subcategory `lunch` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get taxSubcategoryLunch;

  /// L4.9.5: Category System subcategory `dinner` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get taxSubcategoryDinner;

  /// L4.9.5: Category System subcategory `dessert` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dessert'**
  String get taxSubcategoryDessert;

  /// L4.9.5: Category System subcategory `street_food` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Street food'**
  String get taxSubcategoryStreetFood;

  /// L4.9.5: Category System subcategory `food_tasting` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Food tasting'**
  String get taxSubcategoryFoodTasting;

  /// L4.9.5: Category System subcategory `drink_tasting` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Drink tasting'**
  String get taxSubcategoryDrinkTasting;

  /// L4.9.5: Category System subcategory `wine_tasting` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Wine tasting'**
  String get taxSubcategoryWineTasting;

  /// L4.9.5: Category System subcategory `beer_tasting` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beer tasting'**
  String get taxSubcategoryBeerTasting;

  /// L4.9.5: Category System subcategory `cocktail_tasting` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cocktail tasting'**
  String get taxSubcategoryCocktailTasting;

  /// L4.9.5: Category System subcategory `tea_ceremony` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tea ceremony'**
  String get taxSubcategoryTeaCeremony;

  /// L4.9.5: Category System subcategory `bbq` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'BBQ'**
  String get taxSubcategoryBbq;

  /// L4.9.5: Category System subcategory `picnic` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Picnic'**
  String get taxSubcategoryPicnic;

  /// L4.9.5: Category System subcategory `food_tour` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Food tour'**
  String get taxSubcategoryFoodTour;

  /// L4.9.5: Category System subcategory `bar_crawl` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bar crawl'**
  String get taxSubcategoryBarCrawl;

  /// L4.9.5: Category System subcategory `pub_crawl` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pub crawl'**
  String get taxSubcategoryPubCrawl;

  /// L4.9.5: Category System subcategory `happy_hour` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Happy hour'**
  String get taxSubcategoryHappyHour;

  /// L4.9.5: Category System subcategory `restaurant_visit` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Restaurant visit'**
  String get taxSubcategoryRestaurantVisit;

  /// L4.9.5: Category System subcategory `cafe_visit` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cafe visit'**
  String get taxSubcategoryCafeVisit;

  /// L4.9.5: Category System subcategory `bakery_visit` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bakery visit'**
  String get taxSubcategoryBakeryVisit;

  /// L4.9.5: Category System subcategory `vegan_food` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Vegan food'**
  String get taxSubcategoryVeganFood;

  /// L4.9.5: Category System subcategory `local_food` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local food'**
  String get taxSubcategoryLocalFood;

  /// L4.9.5: Category System subcategory `fine_dining` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fine dining'**
  String get taxSubcategoryFineDining;

  /// L4.9.5: Category System subcategory `family_meal` in `food_drinks` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family meal'**
  String get taxSubcategoryFamilyMeal;

  /// L4.9.5: Category System subcategory `quiz` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get taxSubcategoryQuiz;

  /// L4.9.5: Category System subcategory `board_games` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Board games'**
  String get taxSubcategoryBoardGames;

  /// L4.9.5: Category System subcategory `mafia` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Mafia'**
  String get taxSubcategoryMafia;

  /// L4.9.5: Category System subcategory `poker_no_gambling` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Poker (no gambling)'**
  String get taxSubcategoryPokerNoGambling;

  /// L4.9.5: Category System subcategory `chess` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get taxSubcategoryChess;

  /// L4.9.5: Category System subcategory `escape_room` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Escape room'**
  String get taxSubcategoryEscapeRoom;

  /// L4.9.5: Category System subcategory `quest` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Quest'**
  String get taxSubcategoryQuest;

  /// L4.9.5: Category System subcategory `city_game` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'City game'**
  String get taxSubcategoryCityGame;

  /// L4.9.5: Category System subcategory `treasure_hunt` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Treasure hunt'**
  String get taxSubcategoryTreasureHunt;

  /// L4.9.5: Category System subcategory `bowling` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bowling'**
  String get taxSubcategoryBowling;

  /// L4.9.5: Category System subcategory `billiards` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Billiards'**
  String get taxSubcategoryBilliards;

  /// L4.9.5: Category System subcategory `darts` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Darts'**
  String get taxSubcategoryDarts;

  /// L4.9.5: Category System subcategory `mini_golf` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Mini golf'**
  String get taxSubcategoryMiniGolf;

  /// L4.9.5: Category System subcategory `arcade` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Arcade'**
  String get taxSubcategoryArcade;

  /// L4.9.5: Category System subcategory `vr_arcade` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'VR arcade'**
  String get taxSubcategoryVrArcade;

  /// L4.9.5: Category System subcategory `video_games` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Video games'**
  String get taxSubcategoryVideoGames;

  /// L4.9.5: Category System subcategory `table_games` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Table games'**
  String get taxSubcategoryTableGames;

  /// L4.9.5: Category System subcategory `card_games` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Card games'**
  String get taxSubcategoryCardGames;

  /// L4.9.5: Category System subcategory `role_playing_game` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Role playing game'**
  String get taxSubcategoryRolePlayingGame;

  /// L4.9.5: Category System subcategory `indoor_competition` in `games_indoor` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Indoor competition'**
  String get taxSubcategoryIndoorCompetition;

  /// L4.9.5: Category System subcategory `football` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get taxSubcategoryFootball;

  /// L4.9.5: Category System subcategory `basketball` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get taxSubcategoryBasketball;

  /// L4.9.5: Category System subcategory `volleyball` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Volleyball'**
  String get taxSubcategoryVolleyball;

  /// L4.9.5: Category System subcategory `beach_volleyball` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach volleyball'**
  String get taxSubcategoryBeachVolleyball;

  /// L4.9.5: Category System subcategory `tennis` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tennis'**
  String get taxSubcategoryTennis;

  /// L4.9.5: Category System subcategory `table_tennis` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Table tennis'**
  String get taxSubcategoryTableTennis;

  /// L4.9.5: Category System subcategory `badminton` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Badminton'**
  String get taxSubcategoryBadminton;

  /// L4.9.5: Category System subcategory `squash` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Squash'**
  String get taxSubcategorySquash;

  /// L4.9.5: Category System subcategory `padel` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Padel'**
  String get taxSubcategoryPadel;

  /// L4.9.5: Category System subcategory `running` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get taxSubcategoryRunning;

  /// L4.9.5: Category System subcategory `trail_running` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Trail running'**
  String get taxSubcategoryTrailRunning;

  /// L4.9.5: Category System subcategory `cycling` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get taxSubcategoryCycling;

  /// L4.9.5: Category System subcategory `swimming` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get taxSubcategorySwimming;

  /// L4.9.5: Category System subcategory `boxing` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Boxing'**
  String get taxSubcategoryBoxing;

  /// L4.9.5: Category System subcategory `martial_arts` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Martial arts'**
  String get taxSubcategoryMartialArts;

  /// L4.9.5: Category System subcategory `climbing` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Climbing'**
  String get taxSubcategoryClimbing;

  /// L4.9.5: Category System subcategory `bouldering` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bouldering'**
  String get taxSubcategoryBouldering;

  /// L4.9.5: Category System subcategory `fitness` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get taxSubcategoryFitness;

  /// L4.9.5: Category System subcategory `gym` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get taxSubcategoryGym;

  /// L4.9.5: Category System subcategory `crossfit` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Crossfit'**
  String get taxSubcategoryCrossfit;

  /// L4.9.5: Category System subcategory `calisthenics` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Calisthenics'**
  String get taxSubcategoryCalisthenics;

  /// L4.9.5: Category System subcategory `yoga` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get taxSubcategoryYoga;

  /// L4.9.5: Category System subcategory `pilates` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pilates'**
  String get taxSubcategoryPilates;

  /// L4.9.5: Category System subcategory `stretching` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Stretching'**
  String get taxSubcategoryStretching;

  /// L4.9.5: Category System subcategory `dance_fitness` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance fitness'**
  String get taxSubcategoryDanceFitness;

  /// L4.9.5: Category System subcategory `nordic_walking` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Nordic walking'**
  String get taxSubcategoryNordicWalking;

  /// L4.9.5: Category System subcategory `skating` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Skating'**
  String get taxSubcategorySkating;

  /// L4.9.5: Category System subcategory `skateboarding` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Skateboarding'**
  String get taxSubcategorySkateboarding;

  /// L4.9.5: Category System subcategory `rollerblading` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Rollerblading'**
  String get taxSubcategoryRollerblading;

  /// L4.9.5: Category System subcategory `golf` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Golf'**
  String get taxSubcategoryGolf;

  /// L4.9.5: Category System subcategory `frisbee` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Frisbee'**
  String get taxSubcategoryFrisbee;

  /// L4.9.5: Category System subcategory `disc_golf` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Disc golf'**
  String get taxSubcategoryDiscGolf;

  /// L4.9.5: Category System subcategory `running_race` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Running race'**
  String get taxSubcategoryRunningRace;

  /// L4.9.5: Category System subcategory `cycling_race` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cycling race'**
  String get taxSubcategoryCyclingRace;

  /// L4.9.5: Category System subcategory `fitness_challenge` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fitness challenge'**
  String get taxSubcategoryFitnessChallenge;

  /// L4.9.5: Category System subcategory `amateur_tournament` in `sport` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Amateur tournament'**
  String get taxSubcategoryAmateurTournament;

  /// L4.9.5: Category System subcategory `salsa` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Salsa'**
  String get taxSubcategorySalsa;

  /// L4.9.5: Category System subcategory `bachata` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bachata'**
  String get taxSubcategoryBachata;

  /// L4.9.5: Category System subcategory `kizomba` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kizomba'**
  String get taxSubcategoryKizomba;

  /// L4.9.5: Category System subcategory `tango` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tango'**
  String get taxSubcategoryTango;

  /// L4.9.5: Category System subcategory `hip_hop` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Hip-hop'**
  String get taxSubcategoryHipHop;

  /// L4.9.5: Category System subcategory `contemporary_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Contemporary dance'**
  String get taxSubcategoryContemporaryDance;

  /// L4.9.5: Category System subcategory `ballroom_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Ballroom dance'**
  String get taxSubcategoryBallroomDance;

  /// L4.9.5: Category System subcategory `folk_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Folk dance'**
  String get taxSubcategoryFolkDance;

  /// L4.9.5: Category System subcategory `dance_social` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance social'**
  String get taxSubcategoryDanceSocial;

  /// L4.9.5: Category System subcategory `dance_battle` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance battle'**
  String get taxSubcategoryDanceBattle;

  /// L4.9.5: Category System subcategory `zumba` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Zumba'**
  String get taxSubcategoryZumba;

  /// L4.9.5: Category System subcategory `partner_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Partner dance'**
  String get taxSubcategoryPartnerDance;

  /// L4.9.5: Category System subcategory `latin_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Latin dance'**
  String get taxSubcategoryLatinDance;

  /// L4.9.5: Category System subcategory `heels_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Heels dance'**
  String get taxSubcategoryHeelsDance;

  /// L4.9.5: Category System subcategory `street_dance` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Street dance'**
  String get taxSubcategoryStreetDance;

  /// L4.9.5: Category System subcategory `dance_class` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance class'**
  String get taxSubcategoryDanceClass;

  /// L4.9.5: Category System subcategory `dance_practice` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance practice'**
  String get taxSubcategoryDancePractice;

  /// L4.9.5: Category System subcategory `dance_show` in `dance` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dance show'**
  String get taxSubcategoryDanceShow;

  /// L4.9.5: Category System subcategory `hiking` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get taxSubcategoryHiking;

  /// L4.9.5: Category System subcategory `nature_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Nature walk'**
  String get taxSubcategoryNatureWalk;

  /// L4.9.5: Category System subcategory `city_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'City walk'**
  String get taxSubcategoryCityWalk;

  /// L4.9.5: Category System subcategory `historical_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Historical walk'**
  String get taxSubcategoryHistoricalWalk;

  /// L4.9.5: Category System subcategory `sunset_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sunset walk'**
  String get taxSubcategorySunsetWalk;

  /// L4.9.5: Category System subcategory `sunrise_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sunrise walk'**
  String get taxSubcategorySunriseWalk;

  /// L4.9.5: Category System subcategory `forest_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Forest walk'**
  String get taxSubcategoryForestWalk;

  /// L4.9.5: Category System subcategory `lake_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Lake walk'**
  String get taxSubcategoryLakeWalk;

  /// L4.9.5: Category System subcategory `river_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'River walk'**
  String get taxSubcategoryRiverWalk;

  /// L4.9.5: Category System subcategory `architecture_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Architecture walk'**
  String get taxSubcategoryArchitectureWalk;

  /// L4.9.5: Category System subcategory `hidden_gems_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Hidden gems walk'**
  String get taxSubcategoryHiddenGemsWalk;

  /// L4.9.5: Category System subcategory `photography_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Photography walk'**
  String get taxSubcategoryPhotographyWalk;

  /// L4.9.5: Category System subcategory `birdwatching` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Birdwatching'**
  String get taxSubcategoryBirdwatching;

  /// L4.9.5: Category System subcategory `mushroom_picking` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Mushroom picking'**
  String get taxSubcategoryMushroomPicking;

  /// L4.9.5: Category System subcategory `berry_picking` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Berry picking'**
  String get taxSubcategoryBerryPicking;

  /// L4.9.5: Category System subcategory `picnic_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Picnic walk'**
  String get taxSubcategoryPicnicWalk;

  /// L4.9.5: Category System subcategory `park_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Park walk'**
  String get taxSubcategoryParkWalk;

  /// L4.9.5: Category System subcategory `beach_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach walk'**
  String get taxSubcategoryBeachWalk;

  /// L4.9.5: Category System subcategory `promenade_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Promenade walk'**
  String get taxSubcategoryPromenadeWalk;

  /// L4.9.5: Category System subcategory `park` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Park'**
  String get taxSubcategoryPark;

  /// L4.9.5: Category System subcategory `beach` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get taxSubcategoryBeach;

  /// L4.9.5: Category System subcategory `promenade` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Promenade'**
  String get taxSubcategoryPromenade;

  /// L4.9.5: Category System subcategory `viewpoint` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Viewpoint'**
  String get taxSubcategoryViewpoint;

  /// L4.9.5: Category System subcategory `forest` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get taxSubcategoryForest;

  /// L4.9.5: Category System subcategory `lake` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Lake'**
  String get taxSubcategoryLake;

  /// L4.9.5: Category System subcategory `waterfall` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Waterfall'**
  String get taxSubcategoryWaterfall;

  /// L4.9.5: Category System subcategory `cave` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cave'**
  String get taxSubcategoryCave;

  /// L4.9.5: Category System subcategory `natural_landmark` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Natural landmark'**
  String get taxSubcategoryNaturalLandmark;

  /// L4.9.5: Category System subcategory `outdoor_workout` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Outdoor workout'**
  String get taxSubcategoryOutdoorWorkout;

  /// L4.9.5: Category System subcategory `nature_escape` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Nature escape'**
  String get taxSubcategoryNatureEscape;

  /// L4.9.5: Category System subcategory `slow_walk` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Slow walk'**
  String get taxSubcategorySlowWalk;

  /// L4.9.5: Category System subcategory `stargazing` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Stargazing'**
  String get taxSubcategoryStargazing;

  /// L4.9.5: Category System subcategory `northern_lights_watch` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Northern lights watch'**
  String get taxSubcategoryNorthernLightsWatch;

  /// L4.9.5: Category System subcategory `meteor_shower_watch` in `outdoor_nature_walking` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Meteor shower watch'**
  String get taxSubcategoryMeteorShowerWatch;

  /// L4.9.5: Category System subcategory `sup` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'SUP'**
  String get taxSubcategorySup;

  /// L4.9.5: Category System subcategory `kayak` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kayak'**
  String get taxSubcategoryKayak;

  /// L4.9.5: Category System subcategory `canoe` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Canoe'**
  String get taxSubcategoryCanoe;

  /// L4.9.5: Category System subcategory `boat_trip` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Boat trip'**
  String get taxSubcategoryBoatTrip;

  /// L4.9.5: Category System subcategory `catamaran` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Catamaran'**
  String get taxSubcategoryCatamaran;

  /// L4.9.5: Category System subcategory `canal_cruise` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Canal cruise'**
  String get taxSubcategoryCanalCruise;

  /// L4.9.5: Category System subcategory `rowing` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Rowing'**
  String get taxSubcategoryRowing;

  /// L4.9.5: Category System subcategory `sailing` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sailing'**
  String get taxSubcategorySailing;

  /// L4.9.5: Category System subcategory `fishing` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fishing'**
  String get taxSubcategoryFishing;

  /// L4.9.5: Category System subcategory `wakeboarding` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Wakeboarding'**
  String get taxSubcategoryWakeboarding;

  /// L4.9.5: Category System subcategory `water_bike` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Water bike'**
  String get taxSubcategoryWaterBike;

  /// L4.9.5: Category System subcategory `jet_ski` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Jet ski'**
  String get taxSubcategoryJetSki;

  /// L4.9.5: Category System subcategory `beach_activity` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach activity'**
  String get taxSubcategoryBeachActivity;

  /// L4.9.5: Category System subcategory `water_tour` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Water tour'**
  String get taxSubcategoryWaterTour;

  /// L4.9.5: Category System subcategory `diving` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Diving'**
  String get taxSubcategoryDiving;

  /// L4.9.5: Category System subcategory `snorkeling` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Snorkeling'**
  String get taxSubcategorySnorkeling;

  /// L4.9.5: Category System subcategory `surfing` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Surfing'**
  String get taxSubcategorySurfing;

  /// L4.9.5: Category System subcategory `windsurfing` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Windsurfing'**
  String get taxSubcategoryWindsurfing;

  /// L4.9.5: Category System subcategory `kitesurfing` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kitesurfing'**
  String get taxSubcategoryKitesurfing;

  /// L4.9.5: Category System subcategory `beach_day` in `water_activities` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach day'**
  String get taxSubcategoryBeachDay;

  /// L4.9.5: Category System subcategory `winter_walk` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Winter walk'**
  String get taxSubcategoryWinterWalk;

  /// L4.9.5: Category System subcategory `ice_skating` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Ice skating'**
  String get taxSubcategoryIceSkating;

  /// L4.9.5: Category System subcategory `skiing` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Skiing'**
  String get taxSubcategorySkiing;

  /// L4.9.5: Category System subcategory `snowboarding` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Snowboarding'**
  String get taxSubcategorySnowboarding;

  /// L4.9.5: Category System subcategory `sledding` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sledding'**
  String get taxSubcategorySledding;

  /// L4.9.5: Category System subcategory `winter_hiking` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Winter hiking'**
  String get taxSubcategoryWinterHiking;

  /// L4.9.5: Category System subcategory `christmas_market_walk` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Christmas market walk'**
  String get taxSubcategoryChristmasMarketWalk;

  /// L4.9.5: Category System subcategory `winter_photo_route` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Winter photo route'**
  String get taxSubcategoryWinterPhotoRoute;

  /// L4.9.5: Category System subcategory `sauna_cold_plunge` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sauna and cold plunge'**
  String get taxSubcategorySaunaColdPlunge;

  /// L4.9.5: Category System subcategory `ice_fishing` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Ice fishing'**
  String get taxSubcategoryIceFishing;

  /// L4.9.5: Category System subcategory `winter_festival` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Winter festival'**
  String get taxSubcategoryWinterFestival;

  /// L4.9.5: Category System subcategory `autumn_leaf_walk` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Autumn leaf walk'**
  String get taxSubcategoryAutumnLeafWalk;

  /// L4.9.5: Category System subcategory `spring_blossom_walk` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Spring blossom walk'**
  String get taxSubcategorySpringBlossomWalk;

  /// L4.9.5: Category System subcategory `summer_outdoor` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Summer outdoor'**
  String get taxSubcategorySummerOutdoor;

  /// L4.9.5: Category System subcategory `seasonal_walk` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Seasonal walk'**
  String get taxSubcategorySeasonalWalk;

  /// L4.9.5: Category System subcategory `snow_activity` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Snow activity'**
  String get taxSubcategorySnowActivity;

  /// L4.9.5: Category System subcategory `cold_plunge` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cold plunge'**
  String get taxSubcategoryColdPlunge;

  /// L4.9.5: Category System subcategory `holiday_lights_walk` in `winter_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Holiday lights walk'**
  String get taxSubcategoryHolidayLightsWalk;

  /// L4.9.5: Category System subcategory `day_trip` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Day trip'**
  String get taxSubcategoryDayTrip;

  /// L4.9.5: Category System subcategory `weekend_trip` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Weekend trip'**
  String get taxSubcategoryWeekendTrip;

  /// L4.9.5: Category System subcategory `local_experience` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local experience'**
  String get taxSubcategoryLocalExperience;

  /// L4.9.5: Category System subcategory `tourist_excursion` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tourist excursion'**
  String get taxSubcategoryTouristExcursion;

  /// L4.9.5: Category System subcategory `city_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'City tour'**
  String get taxSubcategoryCityTour;

  /// L4.9.5: Category System subcategory `food_tasting_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Food tasting tour'**
  String get taxSubcategoryFoodTastingTour;

  /// L4.9.5: Category System subcategory `craft_experience` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Craft experience'**
  String get taxSubcategoryCraftExperience;

  /// L4.9.5: Category System subcategory `farm_experience` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Farm experience'**
  String get taxSubcategoryFarmExperience;

  /// L4.9.5: Category System subcategory `castle_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Castle tour'**
  String get taxSubcategoryCastleTour;

  /// L4.9.5: Category System subcategory `nature_reserve_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Nature reserve tour'**
  String get taxSubcategoryNatureReserveTour;

  /// L4.9.5: Category System subcategory `coastal_trip` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Coastal trip'**
  String get taxSubcategoryCoastalTrip;

  /// L4.9.5: Category System subcategory `train_day_trip` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Train day trip'**
  String get taxSubcategoryTrainDayTrip;

  /// L4.9.5: Category System subcategory `local_guide_experience` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local guide experience'**
  String get taxSubcategoryLocalGuideExperience;

  /// L4.9.5: Category System subcategory `bike_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bike tour'**
  String get taxSubcategoryBikeTour;

  /// L4.9.5: Category System subcategory `walking_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Walking tour'**
  String get taxSubcategoryWalkingTour;

  /// L4.9.5: Category System subcategory `historical_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Historical tour'**
  String get taxSubcategoryHistoricalTour;

  /// L4.9.5: Category System subcategory `architecture_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Architecture tour'**
  String get taxSubcategoryArchitectureTour;

  /// L4.9.5: Category System subcategory `photo_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Photo tour'**
  String get taxSubcategoryPhotoTour;

  /// L4.9.5: Category System subcategory `hidden_gems_tour` in `travel_tours` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Hidden gems tour'**
  String get taxSubcategoryHiddenGemsTour;

  /// L4.9.5: Category System subcategory `family_activity` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family activity'**
  String get taxSubcategoryFamilyActivity;

  /// L4.9.5: Category System subcategory `kids_workshop` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids workshop'**
  String get taxSubcategoryKidsWorkshop;

  /// L4.9.5: Category System subcategory `playground_event` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Playground event'**
  String get taxSubcategoryPlaygroundEvent;

  /// L4.9.5: Category System subcategory `family_picnic` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family picnic'**
  String get taxSubcategoryFamilyPicnic;

  /// L4.9.5: Category System subcategory `kids_theatre` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids theatre'**
  String get taxSubcategoryKidsTheatre;

  /// L4.9.5: Category System subcategory `kids_museum_event` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids museum event'**
  String get taxSubcategoryKidsMuseumEvent;

  /// L4.9.5: Category System subcategory `family_sports_day` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family sports day'**
  String get taxSubcategoryFamilySportsDay;

  /// L4.9.5: Category System subcategory `parent_child_class` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Parent-child class'**
  String get taxSubcategoryParentChildClass;

  /// L4.9.5: Category System subcategory `creative_kids_class` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Creative kids class'**
  String get taxSubcategoryCreativeKidsClass;

  /// L4.9.5: Category System subcategory `kids_cooking_class` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids cooking class'**
  String get taxSubcategoryKidsCookingClass;

  /// L4.9.5: Category System subcategory `kids_outdoor_walk` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids outdoor walk'**
  String get taxSubcategoryKidsOutdoorWalk;

  /// L4.9.5: Category System subcategory `birthday_activity` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Birthday activity'**
  String get taxSubcategoryBirthdayActivity;

  /// L4.9.5: Category System subcategory `family_farm_visit` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family farm visit'**
  String get taxSubcategoryFamilyFarmVisit;

  /// L4.9.5: Category System subcategory `family_route` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Family route'**
  String get taxSubcategoryFamilyRoute;

  /// L4.9.5: Category System subcategory `kids_party` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids party'**
  String get taxSubcategoryKidsParty;

  /// L4.9.5: Category System subcategory `educational_kids_event` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Educational kids event'**
  String get taxSubcategoryEducationalKidsEvent;

  /// L4.9.5: Category System subcategory `baby_friendly_activity` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Baby-friendly activity'**
  String get taxSubcategoryBabyFriendlyActivity;

  /// L4.9.5: Category System subcategory `kids_camp` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids camp'**
  String get taxSubcategoryKidsCamp;

  /// L4.9.5: Category System subcategory `day_camp` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Day camp'**
  String get taxSubcategoryDayCamp;

  /// L4.9.5: Category System subcategory `teen_meetup` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Teen meetup'**
  String get taxSubcategoryTeenMeetup;

  /// L4.9.5: Category System subcategory `teen_event` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Teen event'**
  String get taxSubcategoryTeenEvent;

  /// L4.9.5: Category System subcategory `kids_quest` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids quest'**
  String get taxSubcategoryKidsQuest;

  /// L4.9.5: Category System subcategory `kids_science_event` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids science event'**
  String get taxSubcategoryKidsScienceEvent;

  /// L4.9.5: Category System subcategory `kids_disco` in `family_kids` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids disco'**
  String get taxSubcategoryKidsDisco;

  /// L4.9.5: Category System subcategory `dog_walk` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dog walk'**
  String get taxSubcategoryDogWalk;

  /// L4.9.5: Category System subcategory `dog_meetup` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dog meetup'**
  String get taxSubcategoryDogMeetup;

  /// L4.9.5: Category System subcategory `dog_park_meetup` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dog park meetup'**
  String get taxSubcategoryDogParkMeetup;

  /// L4.9.5: Category System subcategory `pet_friendly_cafe` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet-friendly cafe'**
  String get taxSubcategoryPetFriendlyCafe;

  /// L4.9.5: Category System subcategory `dog_training` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dog training'**
  String get taxSubcategoryDogTraining;

  /// L4.9.5: Category System subcategory `pet_photo_session` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet photo session'**
  String get taxSubcategoryPetPhotoSession;

  /// L4.9.5: Category System subcategory `animal_shelter_visit` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Animal shelter visit'**
  String get taxSubcategoryAnimalShelterVisit;

  /// L4.9.5: Category System subcategory `farm_animal_experience` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Farm animal experience'**
  String get taxSubcategoryFarmAnimalExperience;

  /// L4.9.5: Category System subcategory `horse_riding` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Horse riding'**
  String get taxSubcategoryHorseRiding;

  /// L4.9.5: Category System subcategory `pony_riding` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pony riding'**
  String get taxSubcategoryPonyRiding;

  /// L4.9.5: Category System subcategory `cat_cafe` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cat cafe'**
  String get taxSubcategoryCatCafe;

  /// L4.9.5: Category System subcategory `pet_adoption` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet adoption'**
  String get taxSubcategoryPetAdoption;

  /// L4.9.5: Category System subcategory `pet_charity` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet charity'**
  String get taxSubcategoryPetCharity;

  /// L4.9.5: Category System subcategory `pet_friendly_walk` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet-friendly walk'**
  String get taxSubcategoryPetFriendlyWalk;

  /// L4.9.5: Category System subcategory `dog_sport` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dog sport'**
  String get taxSubcategoryDogSport;

  /// L4.9.5: Category System subcategory `pet_owner_meetup` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet owner meetup'**
  String get taxSubcategoryPetOwnerMeetup;

  /// L4.9.5: Category System subcategory `dog_show` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dog show'**
  String get taxSubcategoryDogShow;

  /// L4.9.5: Category System subcategory `pet_exhibition` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet exhibition'**
  String get taxSubcategoryPetExhibition;

  /// L4.9.5: Category System subcategory `pet_fair` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet fair'**
  String get taxSubcategoryPetFair;

  /// L4.9.5: Category System subcategory `pet_care_talk` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pet care talk'**
  String get taxSubcategoryPetCareTalk;

  /// L4.9.5: Category System subcategory `animal_therapy` in `pets_animals` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Animal therapy'**
  String get taxSubcategoryAnimalTherapy;

  /// L4.9.5: Category System subcategory `charity_event` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Charity event'**
  String get taxSubcategoryCharityEvent;

  /// L4.9.5: Category System subcategory `volunteer_activity` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Volunteer activity'**
  String get taxSubcategoryVolunteerActivity;

  /// L4.9.5: Category System subcategory `community_cleanup` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Community cleanup'**
  String get taxSubcategoryCommunityCleanup;

  /// L4.9.5: Category System subcategory `donation_event` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Donation event'**
  String get taxSubcategoryDonationEvent;

  /// L4.9.5: Category System subcategory `neighborhood_event` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Neighborhood event'**
  String get taxSubcategoryNeighborhoodEvent;

  /// L4.9.5: Category System subcategory `fundraising_dinner` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fundraising dinner'**
  String get taxSubcategoryFundraisingDinner;

  /// L4.9.5: Category System subcategory `charity_run` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Charity run'**
  String get taxSubcategoryCharityRun;

  /// L4.9.5: Category System subcategory `animal_shelter_volunteering` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Animal shelter volunteering'**
  String get taxSubcategoryAnimalShelterVolunteering;

  /// L4.9.5: Category System subcategory `food_bank_volunteering` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Food bank volunteering'**
  String get taxSubcategoryFoodBankVolunteering;

  /// L4.9.5: Category System subcategory `tree_planting` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tree planting'**
  String get taxSubcategoryTreePlanting;

  /// L4.9.5: Category System subcategory `beach_cleanup` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Beach cleanup'**
  String get taxSubcategoryBeachCleanup;

  /// L4.9.5: Category System subcategory `park_cleanup` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Park cleanup'**
  String get taxSubcategoryParkCleanup;

  /// L4.9.5: Category System subcategory `community_garden` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Community garden'**
  String get taxSubcategoryCommunityGarden;

  /// L4.9.5: Category System subcategory `public_square` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Public square'**
  String get taxSubcategoryPublicSquare;

  /// L4.9.5: Category System subcategory `local_community_meetup` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local community meetup'**
  String get taxSubcategoryLocalCommunityMeetup;

  /// L4.9.5: Category System subcategory `mutual_aid` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Mutual aid'**
  String get taxSubcategoryMutualAid;

  /// L4.9.5: Category System subcategory `social_impact_event` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Social impact event'**
  String get taxSubcategorySocialImpactEvent;

  /// L4.9.5: Category System subcategory `environmental_action` in `community_charity` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Environmental action'**
  String get taxSubcategoryEnvironmentalAction;

  /// L4.9.5: Category System subcategory `local_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local market'**
  String get taxSubcategoryLocalMarket;

  /// L4.9.5: Category System subcategory `flea_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Flea market'**
  String get taxSubcategoryFleaMarket;

  /// L4.9.5: Category System subcategory `seasonal_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Seasonal market'**
  String get taxSubcategorySeasonalMarket;

  /// L4.9.5: Category System subcategory `christmas_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Christmas market'**
  String get taxSubcategoryChristmasMarket;

  /// L4.9.5: Category System subcategory `farmers_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Farmers market'**
  String get taxSubcategoryFarmersMarket;

  /// L4.9.5: Category System subcategory `craft_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Craft market'**
  String get taxSubcategoryCraftMarket;

  /// L4.9.5: Category System subcategory `design_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Design market'**
  String get taxSubcategoryDesignMarket;

  /// L4.9.5: Category System subcategory `vintage_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Vintage market'**
  String get taxSubcategoryVintageMarket;

  /// L4.9.5: Category System subcategory `book_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Book market'**
  String get taxSubcategoryBookMarket;

  /// L4.9.5: Category System subcategory `food_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Food market'**
  String get taxSubcategoryFoodMarket;

  /// L4.9.5: Category System subcategory `flower_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Flower market'**
  String get taxSubcategoryFlowerMarket;

  /// L4.9.5: Category System subcategory `art_fair` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Art fair'**
  String get taxSubcategoryArtFair;

  /// L4.9.5: Category System subcategory `pop_up_shop` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pop-up shop'**
  String get taxSubcategoryPopUpShop;

  /// L4.9.5: Category System subcategory `street_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Street market'**
  String get taxSubcategoryStreetMarket;

  /// L4.9.5: Category System subcategory `handmade_fair` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Handmade fair'**
  String get taxSubcategoryHandmadeFair;

  /// L4.9.5: Category System subcategory `charity_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Charity market'**
  String get taxSubcategoryCharityMarket;

  /// L4.9.5: Category System subcategory `kids_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Kids market'**
  String get taxSubcategoryKidsMarket;

  /// L4.9.5: Category System subcategory `night_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Night market'**
  String get taxSubcategoryNightMarket;

  /// L4.9.5: Category System subcategory `local_brands_market` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local brands market'**
  String get taxSubcategoryLocalBrandsMarket;

  /// L4.9.5: Category System subcategory `clothing_swap` in `markets_fairs` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Clothing swap'**
  String get taxSubcategoryClothingSwap;

  /// L4.9.5: Category System subcategory `christmas` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Christmas'**
  String get taxSubcategoryChristmas;

  /// L4.9.5: Category System subcategory `new_year` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'New Year'**
  String get taxSubcategoryNewYear;

  /// L4.9.5: Category System subcategory `halloween` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Halloween'**
  String get taxSubcategoryHalloween;

  /// L4.9.5: Category System subcategory `easter` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Easter'**
  String get taxSubcategoryEaster;

  /// L4.9.5: Category System subcategory `valentines_day` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Valentine\'s Day'**
  String get taxSubcategoryValentinesDay;

  /// L4.9.5: Category System subcategory `jani` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Jāņi (Midsummer)'**
  String get taxSubcategoryJani;

  /// L4.9.5: Category System subcategory `city_festival` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'City festival'**
  String get taxSubcategoryCityFestival;

  /// L4.9.5: Category System subcategory `summer_festival` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Summer festival'**
  String get taxSubcategorySummerFestival;

  /// L4.9.5: Category System subcategory `autumn_event` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Autumn event'**
  String get taxSubcategoryAutumnEvent;

  /// L4.9.5: Category System subcategory `spring_event` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Spring event'**
  String get taxSubcategorySpringEvent;

  /// L4.9.5: Category System subcategory `school_holiday` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'School holiday'**
  String get taxSubcategorySchoolHoliday;

  /// L4.9.5: Category System subcategory `national_holiday` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'National holiday'**
  String get taxSubcategoryNationalHoliday;

  /// L4.9.5: Category System subcategory `local_tradition` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Local tradition'**
  String get taxSubcategoryLocalTradition;

  /// L4.9.5: Category System subcategory `midsummer` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Midsummer'**
  String get taxSubcategoryMidsummer;

  /// L4.9.5: Category System subcategory `fireworks` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fireworks'**
  String get taxSubcategoryFireworks;

  /// L4.9.5: Category System subcategory `public_celebration` in `holidays_seasonal` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Public celebration'**
  String get taxSubcategoryPublicCelebration;

  /// L4.9.5: Category System subcategory `recharge_walk` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Recharge walk'**
  String get taxSubcategoryRechargeWalk;

  /// L4.9.5: Category System subcategory `calm_walk` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Calm walk'**
  String get taxSubcategoryCalmWalk;

  /// L4.9.5: Category System subcategory `mindful_walk` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Mindful walk'**
  String get taxSubcategoryMindfulWalk;

  /// L4.9.5: Category System subcategory `coffee_walk` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Coffee walk'**
  String get taxSubcategoryCoffeeWalk;

  /// L4.9.5: Category System subcategory `tea_walk` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tea walk'**
  String get taxSubcategoryTeaWalk;

  /// L4.9.5: Category System subcategory `sunset_reset` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sunset reset'**
  String get taxSubcategorySunsetReset;

  /// L4.9.5: Category System subcategory `nature_reset` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Nature reset'**
  String get taxSubcategoryNatureReset;

  /// L4.9.5: Category System subcategory `digital_detox` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Digital detox'**
  String get taxSubcategoryDigitalDetox;

  /// L4.9.5: Category System subcategory `slow_morning` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Slow morning'**
  String get taxSubcategorySlowMorning;

  /// L4.9.5: Category System subcategory `evening_reset` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Evening reset'**
  String get taxSubcategoryEveningReset;

  /// L4.9.5: Category System subcategory `sauna` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sauna'**
  String get taxSubcategorySauna;

  /// L4.9.5: Category System subcategory `spa` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Spa'**
  String get taxSubcategorySpa;

  /// L4.9.5: Category System subcategory `massage` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Massage'**
  String get taxSubcategoryMassage;

  /// L4.9.5: Category System subcategory `breathwork` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Breathwork'**
  String get taxSubcategoryBreathwork;

  /// L4.9.5: Category System subcategory `meditation` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get taxSubcategoryMeditation;

  /// L4.9.5: Category System subcategory `sound_healing` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Sound healing'**
  String get taxSubcategorySoundHealing;

  /// L4.9.5: Category System subcategory `wellness_class` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Wellness class'**
  String get taxSubcategoryWellnessClass;

  /// L4.9.5: Category System subcategory `relaxation_session` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Relaxation session'**
  String get taxSubcategoryRelaxationSession;

  /// L4.9.5: Category System subcategory `mental_health_meetup` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Mental health meetup'**
  String get taxSubcategoryMentalHealthMeetup;

  /// L4.9.5: Category System subcategory `quiet_social` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Quiet social'**
  String get taxSubcategoryQuietSocial;

  /// L4.9.5: Category System subcategory `couple_recharge` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Couple recharge'**
  String get taxSubcategoryCoupleRecharge;

  /// L4.9.5: Category System subcategory `solo_recharge` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Solo recharge'**
  String get taxSubcategorySoloRecharge;

  /// L4.9.5: Category System subcategory `friends_recharge` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Friends recharge'**
  String get taxSubcategoryFriendsRecharge;

  /// L4.9.5: Category System subcategory `pirts_ritual` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Pirts ritual (Latvian sauna)'**
  String get taxSubcategoryPirtsRitual;

  /// L4.9.5: Category System subcategory `retreat` in `wellness_recharge` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Retreat'**
  String get taxSubcategoryRetreat;

  /// L4.9.5: Category System subcategory `laser_tag` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Laser tag'**
  String get taxSubcategoryLaserTag;

  /// L4.9.5: Category System subcategory `paintball` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Paintball'**
  String get taxSubcategoryPaintball;

  /// L4.9.5: Category System subcategory `airsoft` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Airsoft'**
  String get taxSubcategoryAirsoft;

  /// L4.9.5: Category System subcategory `karting` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Karting'**
  String get taxSubcategoryKarting;

  /// L4.9.5: Category System subcategory `shooting_range` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Shooting range'**
  String get taxSubcategoryShootingRange;

  /// L4.9.5: Category System subcategory `archery` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Archery'**
  String get taxSubcategoryArchery;

  /// L4.9.5: Category System subcategory `axe_throwing` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Axe throwing'**
  String get taxSubcategoryAxeThrowing;

  /// L4.9.5: Category System subcategory `trampoline_park` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Trampoline park'**
  String get taxSubcategoryTrampolinePark;

  /// L4.9.5: Category System subcategory `rope_park` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Rope park'**
  String get taxSubcategoryRopePark;

  /// L4.9.5: Category System subcategory `zipline` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Zipline'**
  String get taxSubcategoryZipline;

  /// L4.9.5: Category System subcategory `wind_tunnel` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Wind tunnel'**
  String get taxSubcategoryWindTunnel;

  /// L4.9.5: Category System subcategory `hot_air_balloon` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Hot air balloon'**
  String get taxSubcategoryHotAirBalloon;

  /// L4.9.5: Category System subcategory `skydiving` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Skydiving'**
  String get taxSubcategorySkydiving;

  /// L4.9.5: Category System subcategory `bungee_jumping` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Bungee jumping'**
  String get taxSubcategoryBungeeJumping;

  /// L4.9.5: Category System subcategory `parkour` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Parkour'**
  String get taxSubcategoryParkour;

  /// L4.9.5: Category System subcategory `obstacle_course` in `adrenaline_entertainment` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Obstacle course'**
  String get taxSubcategoryObstacleCourse;

  /// L4.9.5: Category System subcategory `zoo` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Zoo'**
  String get taxSubcategoryZoo;

  /// L4.9.5: Category System subcategory `petting_zoo` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Petting zoo'**
  String get taxSubcategoryPettingZoo;

  /// L4.9.5: Category System subcategory `aquarium` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Aquarium'**
  String get taxSubcategoryAquarium;

  /// L4.9.5: Category System subcategory `amusement_park` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Amusement park'**
  String get taxSubcategoryAmusementPark;

  /// L4.9.5: Category System subcategory `water_park` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Water park'**
  String get taxSubcategoryWaterPark;

  /// L4.9.5: Category System subcategory `adventure_park` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Adventure park'**
  String get taxSubcategoryAdventurePark;

  /// L4.9.5: Category System subcategory `botanical_garden` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Botanical garden'**
  String get taxSubcategoryBotanicalGarden;

  /// L4.9.5: Category System subcategory `planetarium` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Planetarium'**
  String get taxSubcategoryPlanetarium;

  /// L4.9.5: Category System subcategory `science_center` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Science center'**
  String get taxSubcategoryScienceCenter;

  /// L4.9.5: Category System subcategory `observation_deck` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Observation deck'**
  String get taxSubcategoryObservationDeck;

  /// L4.9.5: Category System subcategory `ferris_wheel` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Ferris wheel'**
  String get taxSubcategoryFerrisWheel;

  /// L4.9.5: Category System subcategory `seasonal_attraction` in `attractions` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Seasonal attraction'**
  String get taxSubcategorySeasonalAttraction;

  /// L4.9.5: Category System subcategory `car_meetup` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Car meetup'**
  String get taxSubcategoryCarMeetup;

  /// L4.9.5: Category System subcategory `retro_cars` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Retro cars'**
  String get taxSubcategoryRetroCars;

  /// L4.9.5: Category System subcategory `car_show` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Car show'**
  String get taxSubcategoryCarShow;

  /// L4.9.5: Category System subcategory `auto_exhibition` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Auto exhibition'**
  String get taxSubcategoryAutoExhibition;

  /// L4.9.5: Category System subcategory `tuning_meetup` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tuning meetup'**
  String get taxSubcategoryTuningMeetup;

  /// L4.9.5: Category System subcategory `drift_event` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Drift event'**
  String get taxSubcategoryDriftEvent;

  /// L4.9.5: Category System subcategory `offroad_trip` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Off-road trip'**
  String get taxSubcategoryOffroadTrip;

  /// L4.9.5: Category System subcategory `motorcycle_ride` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Motorcycle ride'**
  String get taxSubcategoryMotorcycleRide;

  /// L4.9.5: Category System subcategory `motorcycle_meetup` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Motorcycle meetup'**
  String get taxSubcategoryMotorcycleMeetup;

  /// L4.9.5: Category System subcategory `scooter_meetup` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Scooter meetup'**
  String get taxSubcategoryScooterMeetup;

  /// L4.9.5: Category System subcategory `car_photo_meet` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Car photo meet'**
  String get taxSubcategoryCarPhotoMeet;

  /// L4.9.5: Category System subcategory `drive_in_cinema` in `auto_moto` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Drive-in cinema'**
  String get taxSubcategoryDriveInCinema;

  /// L4.9.5: Category System subcategory `anime_meetup` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Anime meetup'**
  String get taxSubcategoryAnimeMeetup;

  /// L4.9.5: Category System subcategory `cosplay_event` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Cosplay event'**
  String get taxSubcategoryCosplayEvent;

  /// L4.9.5: Category System subcategory `comic_con` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Comic Con'**
  String get taxSubcategoryComicCon;

  /// L4.9.5: Category System subcategory `esports_tournament` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Esports tournament'**
  String get taxSubcategoryEsportsTournament;

  /// L4.9.5: Category System subcategory `lan_party` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'LAN party'**
  String get taxSubcategoryLanParty;

  /// L4.9.5: Category System subcategory `retro_gaming` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Retro gaming'**
  String get taxSubcategoryRetroGaming;

  /// L4.9.5: Category System subcategory `tabletop_wargames` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tabletop wargames'**
  String get taxSubcategoryTabletopWargames;

  /// L4.9.5: Category System subcategory `trading_card_games` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Trading card games'**
  String get taxSubcategoryTradingCardGames;

  /// L4.9.5: Category System subcategory `hackathon` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Hackathon'**
  String get taxSubcategoryHackathon;

  /// L4.9.5: Category System subcategory `game_dev_meetup` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Game dev meetup'**
  String get taxSubcategoryGameDevMeetup;

  /// L4.9.5: Category System subcategory `tech_meetup` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Tech meetup'**
  String get taxSubcategoryTechMeetup;

  /// L4.9.5: Category System subcategory `robotics_event` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Robotics event'**
  String get taxSubcategoryRoboticsEvent;

  /// L4.9.5: Category System subcategory `fandom_meetup` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Fandom meetup'**
  String get taxSubcategoryFandomMeetup;

  /// L4.9.5: Category System subcategory `collectors_meetup` in `geek_tech` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Collectors meetup'**
  String get taxSubcategoryCollectorsMeetup;

  /// L4.9.5: Category System subcategory `speed_dating` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Speed dating'**
  String get taxSubcategorySpeedDating;

  /// L4.9.5: Category System subcategory `singles_party` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Singles party'**
  String get taxSubcategorySinglesParty;

  /// L4.9.5: Category System subcategory `singles_mixer` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Singles mixer'**
  String get taxSubcategorySinglesMixer;

  /// L4.9.5: Category System subcategory `singles_dinner` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Singles dinner'**
  String get taxSubcategorySinglesDinner;

  /// L4.9.5: Category System subcategory `blind_date_event` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Blind date event'**
  String get taxSubcategoryBlindDateEvent;

  /// L4.9.5: Category System subcategory `dating_game_event` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Dating game event'**
  String get taxSubcategoryDatingGameEvent;

  /// L4.9.5: Category System subcategory `singles_activity` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Singles activity'**
  String get taxSubcategorySinglesActivity;

  /// L4.9.5: Category System subcategory `matchmaking_event` in `dating_singles` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Matchmaking event'**
  String get taxSubcategoryMatchmakingEvent;

  /// L4.9.5: Category System subcategory `other_event` in `other` (stable id; G04).
  ///
  /// In en, this message translates to:
  /// **'Other event'**
  String get taxSubcategoryOtherEvent;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get discoverHomeShortSport;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Walks'**
  String get discoverHomeShortWalks;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get discoverHomeShortGames;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get discoverHomeShortDance;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get discoverHomeShortMusic;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get discoverHomeShortArt;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get discoverHomeShortFood;

  /// L4.9.5: Home — short category chip name (the full name is taxCategory…).
  ///
  /// In en, this message translates to:
  /// **'Wellness'**
  String get discoverHomeShortWellness;

  /// Details: button that asks for a machine translation of the publication text.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get contentTranslationAction;

  /// Details: shows a translation already loaded on this screen.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get contentTranslationShowTranslation;

  /// Details: machine translation in progress.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get contentTranslationLoading;

  /// Details: mandatory label above a machine translation.
  ///
  /// In en, this message translates to:
  /// **'Translated automatically'**
  String get contentTranslationLabel;

  /// Details: hides the machine translation and returns to the original.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get contentTranslationShowOriginal;

  /// Details: explains what machine translation does not cover.
  ///
  /// In en, this message translates to:
  /// **'Terms, safety notes and names stay in the original language.'**
  String get contentTranslationKeptOriginal;

  /// Details translation refused: the reader has no Session.
  ///
  /// In en, this message translates to:
  /// **'Sign in to translate.'**
  String get contentTranslationErrorSignIn;

  /// Details translation refused: the capability is switched off.
  ///
  /// In en, this message translates to:
  /// **'Translation is not available right now.'**
  String get contentTranslationErrorDisabled;

  /// Details translation refused: source and target language match.
  ///
  /// In en, this message translates to:
  /// **'This text is already in your language.'**
  String get contentTranslationErrorSameLanguage;

  /// Details translation refused: unsupported target language.
  ///
  /// In en, this message translates to:
  /// **'Translation into this language is not available.'**
  String get contentTranslationErrorUnsupported;

  /// Details translation refused: the publication cannot be translated now.
  ///
  /// In en, this message translates to:
  /// **'This text cannot be translated.'**
  String get contentTranslationErrorSource;

  /// Details translation refused: a newer revision of the publication exists.
  ///
  /// In en, this message translates to:
  /// **'This publication has been updated. Refresh the page.'**
  String get contentTranslationErrorRevision;

  /// Details translation refused: the daily limit is reached.
  ///
  /// In en, this message translates to:
  /// **'Translation limit reached for today. Try again tomorrow.'**
  String get contentTranslationErrorQuota;

  /// Details translation refused: the monthly budget is used up.
  ///
  /// In en, this message translates to:
  /// **'Translation is temporarily unavailable.'**
  String get contentTranslationErrorBudget;

  /// Details translation failed; the original stays on screen.
  ///
  /// In en, this message translates to:
  /// **'Could not translate. The original is shown.'**
  String get contentTranslationErrorProvider;

  /// Create: picker for the language the author wrote the text in.
  ///
  /// In en, this message translates to:
  /// **'Language of this text'**
  String get createContentLanguageLabel;

  /// Create: why the author should choose the text language.
  ///
  /// In en, this message translates to:
  /// **'Readers can translate the text only if you choose its language.'**
  String get createContentLanguageHelp;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Seller details'**
  String get sellerDataTitle;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Needed before you publish paid or bookable content (EU Digital Services Act).'**
  String get sellerDataIntro;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Private person'**
  String get sellerStatusPrivate;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Business (trader)'**
  String get sellerStatusTrader;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Contact email'**
  String get sellerEmail;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Contact phone (+371…)'**
  String get sellerPhone;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'At least one contact.'**
  String get sellerContactHint;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Legal name'**
  String get sellerLegalName;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get sellerRegistrationNumber;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'VAT number (optional)'**
  String get sellerVatId;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get sellerAddressLine;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get sellerCity;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get sellerPostalCode;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Country code (LV)'**
  String get sellerCountryCode;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'What you offer (for EU tax reporting)'**
  String get sellerDac7Title;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Personal services'**
  String get sellerDac7Services;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Rental of goods'**
  String get sellerDac7Rental;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sellerSave;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Seller details saved.'**
  String get sellerSaved;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Seller details are not available right now.'**
  String get sellerUnavailable;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Check the fields.'**
  String get sellerInvalid;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Details were changed elsewhere. Reload and try again.'**
  String get sellerConflict;

  /// ADR 0023 seller declaration (DSA Art. 30).
  ///
  /// In en, this message translates to:
  /// **'Fill in your seller details in the profile to publish paid or bookable content.'**
  String get contentErrorSellerDeclarationRequired;

  /// N3c: title and tooltip of the per-category channel settings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationsChannelSettings;

  /// N3c: push channel switch.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notificationsChannelPush;

  /// N3c: inbox channel switch.
  ///
  /// In en, this message translates to:
  /// **'In the inbox'**
  String get notificationsChannelInApp;

  /// N3c: a locked category keeps its inbox record.
  ///
  /// In en, this message translates to:
  /// **'Always kept in the inbox'**
  String get notificationsChannelLocked;

  /// N3c: category booking.receipts.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmations'**
  String get notificationsCategoryBookingReceipts;

  /// N3c: category booking.changes.
  ///
  /// In en, this message translates to:
  /// **'Booking changes'**
  String get notificationsCategoryBookingChanges;

  /// N3c: channel settings update failed.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be saved'**
  String get notificationsChannelSaveFailed;

  /// N3c: channel settings load failed.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be loaded'**
  String get notificationsChannelLoadFailed;

  /// N3c dev: tooltip of the self-test button.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get notificationsPushTest;

  /// N3c dev: self-test scheduled.
  ///
  /// In en, this message translates to:
  /// **'Minimise the app: the test notification arrives in 5 seconds'**
  String get notificationsPushTestScheduled;

  /// N3c dev: self-test failed.
  ///
  /// In en, this message translates to:
  /// **'The test notification could not be sent'**
  String get notificationsPushTestFailed;

  /// N3c: a push arrived while the app is open.
  ///
  /// In en, this message translates to:
  /// **'New notification'**
  String get notificationsPushArrived;

  /// N3c: open the inbox from the in-app notice.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationsPushOpen;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'lv', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'lv':
      return AppLocalizationsLv();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
