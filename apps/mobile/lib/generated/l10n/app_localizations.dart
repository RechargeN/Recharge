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
