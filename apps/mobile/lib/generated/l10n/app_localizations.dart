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

  /// Legacy local currency preference label; prices keep the currency of their data.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

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
  /// **'Publishing requires a verified creator account.'**
  String get contentErrorCreatorVerificationRequired;

  /// Identity: creator verification unavailable.
  ///
  /// In en, this message translates to:
  /// **'Creator verification is temporarily unavailable.'**
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
