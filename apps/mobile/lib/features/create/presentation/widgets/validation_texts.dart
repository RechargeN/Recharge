import '../../../../core/localization/l10n_context.dart';

/// L4: Create validation message ids → localized text. Generated from the
/// tables in `content_validation_feedback.dart` and
/// `activity_validation_feedback.dart`; an unknown id shows the general
/// validation refusal, never the id.
String validationMessageText(AppLocalizations l10n, String id) => switch (id) {
  'validationAPlaceInTheGuideIsNo' => l10n.validationAPlaceInTheGuideIsNo,
  'validationAPlaceInTheGuideWasNot' => l10n.validationAPlaceInTheGuideWasNot,
  'validationAddACoverImage' => l10n.validationAddACoverImage,
  'validationAddACoverPhoto' => l10n.validationAddACoverPhoto,
  'validationAddAPricingNote' => l10n.validationAddAPricingNote,
  'validationAddASafetyNoticeForThisCategory' =>
    l10n.validationAddASafetyNoticeForThisCategory,
  'validationAddAShortDescription' => l10n.validationAddAShortDescription,
  'validationAddATitle' => l10n.validationAddATitle,
  'validationAddAnAddressOrALocationLabel' =>
    l10n.validationAddAnAddressOrALocationLabel,
  'validationAddAtLeastThreePlaces' => l10n.validationAddAtLeastThreePlaces,
  'validationAddPlacesToTheGuide' => l10n.validationAddPlacesToTheGuide,
  'validationAddTheDeliveryFeeZeroIfFree' =>
    l10n.validationAddTheDeliveryFeeZeroIfFree,
  'validationAddTheEntryPrice' => l10n.validationAddTheEntryPrice,
  'validationAddThePrices' => l10n.validationAddThePrices,
  'validationAddThePublicBusinessAddress' =>
    l10n.validationAddThePublicBusinessAddress,
  'validationAddTheRentalTerms' => l10n.validationAddTheRentalTerms,
  'validationAddTheWeeklyOpeningHours' =>
    l10n.validationAddTheWeeklyOpeningHours,
  'validationAddWhatYouRentOut' => l10n.validationAddWhatYouRentOut,
  'validationCategoryDataIsUnavailableTryAgainLater' =>
    l10n.validationCategoryDataIsUnavailableTryAgainLater,
  'validationCategoryRequirementsAreUnavailableTryAgainLater' =>
    l10n.validationCategoryRequirementsAreUnavailableTryAgainLater,
  'validationCheckTheAccessCaution' => l10n.validationCheckTheAccessCaution,
  'validationCheckTheAmount' => l10n.validationCheckTheAmount,
  'validationCheckTheBestTime' => l10n.validationCheckTheBestTime,
  'validationCheckTheCategoryCriteria' =>
    l10n.validationCheckTheCategoryCriteria,
  'validationCheckTheContribution' => l10n.validationCheckTheContribution,
  'validationCheckTheDescriptionLength' =>
    l10n.validationCheckTheDescriptionLength,
  'validationCheckTheDeviceClockAndConfirmThe' =>
    l10n.validationCheckTheDeviceClockAndConfirmThe,
  'validationCheckTheDurationRange' => l10n.validationCheckTheDurationRange,
  'validationCheckTheEmailAddress' => l10n.validationCheckTheEmailAddress,
  'validationCheckTheGalleryImages' => l10n.validationCheckTheGalleryImages,
  'validationCheckTheGroupSize' => l10n.validationCheckTheGroupSize,
  'validationCheckTheLinkedPlace' => l10n.validationCheckTheLinkedPlace,
  'validationCheckTheOpeningTimes' => l10n.validationCheckTheOpeningTimes,
  'validationCheckTheShortDescriptionLength' =>
    l10n.validationCheckTheShortDescriptionLength,
  'validationCheckTheTitleLength' => l10n.validationCheckTheTitleLength,
  'validationChooseACancellationPolicy' =>
    l10n.validationChooseACancellationPolicy,
  'validationChooseACategory' => l10n.validationChooseACategory,
  'validationChooseAContributionKind' => l10n.validationChooseAContributionKind,
  'validationChooseAKindForThisContribution' =>
    l10n.validationChooseAKindForThisContribution,
  'validationChooseASeason' => l10n.validationChooseASeason,
  'validationChooseASubcategory' => l10n.validationChooseASubcategory,
  'validationChooseASubcategoryAvailableForActivity' =>
    l10n.validationChooseASubcategoryAvailableForActivity,
  'validationChooseASubcategoryAvailableForPlaces' =>
    l10n.validationChooseASubcategoryAvailableForPlaces,
  'validationChooseASubcategoryFromTheCategoryList' =>
    l10n.validationChooseASubcategoryFromTheCategoryList,
  'validationChooseATimeOfDay' => l10n.validationChooseATimeOfDay,
  'validationChooseAnOpeningHoursMode' =>
    l10n.validationChooseAnOpeningHoursMode,
  'validationChooseHowTheOpeningHoursWork' =>
    l10n.validationChooseHowTheOpeningHoursWork,
  'validationChooseTheTextLanguage' => l10n.validationChooseTheTextLanguage,
  'validationChooseWhatKindOfPlaceItIs' =>
    l10n.validationChooseWhatKindOfPlaceItIs,
  'validationChooseWhetherEntryIsFreeOrPaid' =>
    l10n.validationChooseWhetherEntryIsFreeOrPaid,
  'validationChooseYourRelationshipToThisPlace' =>
    l10n.validationChooseYourRelationshipToThisPlace,
  'validationCompleteThisCategoryCriterion' =>
    l10n.validationCompleteThisCategoryCriterion,
  'validationConfirmTheAvailabilityAgainItIsOlder' =>
    l10n.validationConfirmTheAvailabilityAgainItIsOlder,
  'validationConfirmTheCategory' => l10n.validationConfirmTheCategory,
  'validationConfirmTheMapPin' => l10n.validationConfirmTheMapPin,
  'validationConfirmTheRentalStatements' =>
    l10n.validationConfirmTheRentalStatements,
  'validationConfirmWhenTheItemsAreAvailable' =>
    l10n.validationConfirmWhenTheItemsAreAvailable,
  'validationDescribeHowToGetThere' => l10n.validationDescribeHowToGetThere,
  'validationDescribeTheDamagePolicy' => l10n.validationDescribeTheDamagePolicy,
  'validationDescribeTheHandover' => l10n.validationDescribeTheHandover,
  'validationDescribeTheInformalAccess' =>
    l10n.validationDescribeTheInformalAccess,
  'validationDescribeTheOptionalContribution' =>
    l10n.validationDescribeTheOptionalContribution,
  'validationDoNotWriteTheTitleInCapitals' =>
    l10n.validationDoNotWriteTheTitleInCapitals,
  'validationKeepContactsOutOfTheTitle' =>
    l10n.validationKeepContactsOutOfTheTitle,
  'validationLinkedPlaceIsUnavailableForPublication' =>
    l10n.validationLinkedPlaceIsUnavailableForPublication,
  'validationMakeAtLeastOneItemAvailable' =>
    l10n.validationMakeAtLeastOneItemAvailable,
  'validationMinimumMustNotExceedMaximum' =>
    l10n.validationMinimumMustNotExceedMaximum,
  'validationNameTheArea' => l10n.validationNameTheArea,
  'validationNameWhatYouRentOut' => l10n.validationNameWhatYouRentOut,
  'validationOnlySavedPublishedPlacesCanBeAdded' =>
    l10n.validationOnlySavedPublishedPlacesCanBeAdded,
  'validationOpeningTimesOverlap' => l10n.validationOpeningTimesOverlap,
  'validationPlacesCouldNotBeCheckedTryAgain' =>
    l10n.validationPlacesCouldNotBeCheckedTryAgain,
  'validationRemoveDuplicateImages' => l10n.validationRemoveDuplicateImages,
  'validationRemoveSomeGalleryImages' => l10n.validationRemoveSomeGalleryImages,
  'validationRemoveSomePlaces' => l10n.validationRemoveSomePlaces,
  'validationRemoveThePartFromTheBookingLink' =>
    l10n.validationRemoveThePartFromTheBookingLink,
  'validationReviewTheGuideAgainItChangedAfter' =>
    l10n.validationReviewTheGuideAgainItChangedAfter,
  'validationReviewTheGuideBeforeSubmitting' =>
    l10n.validationReviewTheGuideBeforeSubmitting,
  'validationSaveTheDraftAgainBeforeSubmitting' =>
    l10n.validationSaveTheDraftAgainBeforeSubmitting,
  'validationSaveThePlacesInTheGuideBefore' =>
    l10n.validationSaveThePlacesInTheGuideBefore,
  'validationSeasonalHoursAreNotSupportedYet' =>
    l10n.validationSeasonalHoursAreNotSupportedYet,
  'validationSetTheLocation' => l10n.validationSetTheLocation,
  'validationSetTheMapPin' => l10n.validationSetTheMapPin,
  'validationSetTheMinimumRenterAge' => l10n.validationSetTheMinimumRenterAge,
  'validationSetTheTypicalDuration' => l10n.validationSetTheTypicalDuration,
  'validationSetValidCoordinates' => l10n.validationSetValidCoordinates,
  'validationShortenACuratorNoteTo300Characters' =>
    l10n.validationShortenACuratorNoteTo300Characters,
  'validationShortenTheDescription' => l10n.validationShortenTheDescription,
  'validationShowTheApproximateAreaAt500M' =>
    l10n.validationShowTheApproximateAreaAt500M,
  'validationSomePlacesChangedStatusReviewTheGuide' =>
    l10n.validationSomePlacesChangedStatusReviewTheGuide,
  'validationTheLinkedPlaceIsNoLongerPublic' =>
    l10n.validationTheLinkedPlaceIsNoLongerPublic,
  'validationTheLinkedPlaceWasNotFoundRemove' =>
    l10n.validationTheLinkedPlaceWasNotFoundRemove,
  'validationThePinIsOutsideTheServiceArea' =>
    l10n.validationThePinIsOutsideTheServiceArea,
  'validationTheRentalRulesChangedConfirmTheStatements' =>
    l10n.validationTheRentalRulesChangedConfirmTheStatements,
  'validationThisCategoryCannotBeRentedOutHere' =>
    l10n.validationThisCategoryCannotBeRentedOutHere,
  'validationThisCategoryRequiresAnIDAtHandover' =>
    l10n.validationThisCategoryRequiresAnIDAtHandover,
  'validationThisLanguageIsNotSupportedHere' =>
    l10n.validationThisLanguageIsNotSupportedHere,
  'validationUse10140Characters' => l10n.validationUse10140Characters,
  'validationUse10300Characters' => l10n.validationUse10300Characters,
  'validationUse20180Characters' => l10n.validationUse20180Characters,
  'validationUse3120Characters' => l10n.validationUse3120Characters,
  'validationUse580Characters' => l10n.validationUse580Characters,
  'validationUse715DigitsOnlyAndSpaces' =>
    l10n.validationUse715DigitsOnlyAndSpaces,
  'validationUseADeliveryRadiusUpTo50' =>
    l10n.validationUseADeliveryRadiusUpTo50,
  'validationUseAPositiveAmount' => l10n.validationUseAPositiveAmount,
  'validationUseASecureHttpsBookingLink' =>
    l10n.validationUseASecureHttpsBookingLink,
  'validationUseASecureHttpsLink' => l10n.validationUseASecureHttpsLink,
  'validationUseAtMost1000Characters' => l10n.validationUseAtMost1000Characters,
  'validationUseAtMost12GalleryImages' =>
    l10n.validationUseAtMost12GalleryImages,
  'validationUseAtMost200Characters' => l10n.validationUseAtMost200Characters,
  'validationUseAtMost300Characters' => l10n.validationUseAtMost300Characters,
  'validationUsePositiveWholeMinutes' => l10n.validationUsePositiveWholeMinutes,
  'validationUsePositiveWholeNumbers' => l10n.validationUsePositiveWholeNumbers,
  'validationUseTheMarketCurrency' => l10n.validationUseTheMarketCurrency,
  'validationYourRelationshipToThePlaceDoesNot' =>
    l10n.validationYourRelationshipToThePlaceDoesNot,
  _ => l10n.contentErrorValidationFailed,
};

/// A form field name id → localized text; unknown ids read as "Draft".
String fieldLabelText(AppLocalizations l10n, String id) => switch (id) {
  'fieldLabelAddress' => l10n.fieldLabelAddress,
  'fieldLabelArea' => l10n.fieldLabelArea,
  'fieldLabelAvailability' => l10n.fieldLabelAvailability,
  'fieldLabelBookingLink' => l10n.fieldLabelBookingLink,
  'fieldLabelCancellationPolicy' => l10n.fieldLabelCancellationPolicy,
  'fieldLabelCategory' => l10n.fieldLabelCategory,
  'fieldLabelCategoryCriteria' => l10n.fieldLabelCategoryCriteria,
  'fieldLabelCoverImage' => l10n.fieldLabelCoverImage,
  'fieldLabelCurrency' => l10n.fieldLabelCurrency,
  'fieldLabelDamagePolicy' => l10n.fieldLabelDamagePolicy,
  'fieldLabelDeliveryFee' => l10n.fieldLabelDeliveryFee,
  'fieldLabelDeliveryRadius' => l10n.fieldLabelDeliveryRadius,
  'fieldLabelDescription' => l10n.fieldLabelDescription,
  'fieldLabelDraft' => l10n.fieldLabelDraft,
  'fieldLabelEmail' => l10n.fieldLabelEmail,
  'fieldLabelEntry' => l10n.fieldLabelEntry,
  'fieldLabelEntryPrice' => l10n.fieldLabelEntryPrice,
  'fieldLabelGallery' => l10n.fieldLabelGallery,
  'fieldLabelGuideReview' => l10n.fieldLabelGuideReview,
  'fieldLabelHandover' => l10n.fieldLabelHandover,
  'fieldLabelHandoverAddress' => l10n.fieldLabelHandoverAddress,
  'fieldLabelHandoverArea' => l10n.fieldLabelHandoverArea,
  'fieldLabelIDAtHandover' => l10n.fieldLabelIDAtHandover,
  'fieldLabelItems' => l10n.fieldLabelItems,
  'fieldLabelKindOfPlace' => l10n.fieldLabelKindOfPlace,
  'fieldLabelLocation' => l10n.fieldLabelLocation,
  'fieldLabelMapPin' => l10n.fieldLabelMapPin,
  'fieldLabelMinimumAge' => l10n.fieldLabelMinimumAge,
  'fieldLabelOpeningHours' => l10n.fieldLabelOpeningHours,
  'fieldLabelPhone' => l10n.fieldLabelPhone,
  'fieldLabelPhotos' => l10n.fieldLabelPhotos,
  'fieldLabelPlacesInTheGuide' => l10n.fieldLabelPlacesInTheGuide,
  'fieldLabelPrices' => l10n.fieldLabelPrices,
  'fieldLabelPricingNote' => l10n.fieldLabelPricingNote,
  'fieldLabelSafetyNotice' => l10n.fieldLabelSafetyNotice,
  'fieldLabelShortDescription' => l10n.fieldLabelShortDescription,
  'fieldLabelStatements' => l10n.fieldLabelStatements,
  'fieldLabelSubcategory' => l10n.fieldLabelSubcategory,
  'fieldLabelTerms' => l10n.fieldLabelTerms,
  'fieldLabelTextLanguage' => l10n.fieldLabelTextLanguage,
  'fieldLabelTitle' => l10n.fieldLabelTitle,
  'fieldLabelWebsite' => l10n.fieldLabelWebsite,
  'fieldLabelYourRelationship' => l10n.fieldLabelYourRelationship,
  _ => l10n.fieldLabelDraft,
};

/// Field path → localized message for a map of field path → message id.
Map<String, String> localizedFieldMessages(
  AppLocalizations l10n,
  Map<String, String> ids,
) => <String, String>{
  for (final MapEntry<String, String> entry in ids.entries)
    entry.key: validationMessageText(l10n, entry.value),
};
