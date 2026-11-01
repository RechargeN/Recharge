import '../domain/entities/content_validation_violation.dart';
import '../domain/entities/create_draft_entity.dart';

/// Client text for the server's public validation details of Place, Rental
/// and Collection (M1 stage 3, owner decision 3-A). L4: the values are ARB
/// message ids (`validation*`, `fieldLabel*`) that the UI resolves. Only a known code on its
/// exact field path renders; anything else stays the general refusal message,
/// as for Activity (`activity_validation_feedback.dart`).
const Map<String, (String, String)> _place = <String, (String, String)>{
  'place.title': ('/body/title', 'validationUse3120Characters'),
  'place.title.all_caps': (
    '/body/title',
    'validationDoNotWriteTheTitleInCapitals',
  ),
  'place.title.contact_like': (
    '/body/title',
    'validationKeepContactsOutOfTheTitle',
  ),
  'place.place_kind': (
    '/body/placeKind',
    'validationChooseWhatKindOfPlaceItIs',
  ),
  'place.relationship_to_place': (
    '/body/relationshipToPlace',
    'validationChooseYourRelationshipToThisPlace',
  ),
  'place.short_description': (
    '/body/shortDescription',
    'validationUse20180Characters',
  ),
  'place.full_description': (
    '/body/fullDescription',
    'validationShortenTheDescription',
  ),
  'place.content_locale': (
    '/body/contentLocale',
    'validationChooseTheTextLanguage',
  ),
  'place.content_locale.unsupported': (
    '/body/contentLocale',
    'validationThisLanguageIsNotSupportedHere',
  ),
  'place.category_id': ('/body/categoryId', 'validationChooseACategory'),
  'place.subcategory_id': (
    '/body/subcategoryId',
    'validationChooseASubcategory',
  ),
  'place.subcategory.not_applicable': (
    '/body/subcategoryId',
    'validationChooseASubcategoryAvailableForPlaces',
  ),
  'place.taxonomy_unavailable': (
    '/body/subcategoryId',
    'validationCategoryDataIsUnavailableTryAgainLater',
  ),
  'place.location': ('/body/location', 'validationSetTheLocation'),
  'place.location.point': ('/body/location/point', 'validationSetTheMapPin'),
  'place.location.pin_unconfirmed': (
    '/body/location/pinConfirmed',
    'validationConfirmTheMapPin',
  ),
  'place.location.outside_service_area': (
    '/body/location/point',
    'validationThePinIsOutsideTheServiceArea',
  ),
  'place.location.address_or_label_missing': (
    '/body/location/formattedAddress',
    'validationAddAnAddressOrALocationLabel',
  ),
  'place.hours': ('/body/hours', 'validationChooseHowTheOpeningHoursWork'),
  'place.hours.mode': (
    '/body/hours/mode',
    'validationChooseAnOpeningHoursMode',
  ),
  'place.hours.mode_unsupported': (
    '/body/hours/mode',
    'validationSeasonalHoursAreNotSupportedYet',
  ),
  'place.hours.weekly_required': (
    '/body/hours/weeklyPeriods',
    'validationAddTheWeeklyOpeningHours',
  ),
  'place.hours.period_invalid': (
    '/body/hours/weeklyPeriods',
    'validationCheckTheOpeningTimes',
  ),
  'place.hours.period_overlap': (
    '/body/hours/weeklyPeriods',
    'validationOpeningTimesOverlap',
  ),
  'place.contacts.phone': (
    '/body/contacts/phone',
    'validationUse715DigitsOnlyAndSpaces',
  ),
  'place.contacts.email': (
    '/body/contacts/email',
    'validationCheckTheEmailAddress',
  ),
  'place.contacts.website': (
    '/body/contacts/website',
    'validationUseASecureHttpsLink',
  ),
  'place.contacts.bookingUrl': (
    '/body/contacts/bookingUrl',
    'validationUseASecureHttpsLink',
  ),
  'place.media.cover_missing': (
    '/body/media/coverImage',
    'validationAddACoverImage',
  ),
  'place.media.gallery_too_large': (
    '/body/media/gallery',
    'validationRemoveSomeGalleryImages',
  ),
  'place.pricing.entry_type': (
    '/body/pricing/entryType',
    'validationChooseWhetherEntryIsFreeOrPaid',
  ),
  'place.pricing.currency_code': (
    '/body/pricing/currencyCode',
    'validationUseTheMarketCurrency',
  ),
  'place.pricing.entry_price_from_required': (
    '/body/pricing/entryPriceFrom',
    'validationAddTheEntryPrice',
  ),
  'place.pricing.note_required': (
    '/body/pricing/pricingNote',
    'validationAddAPricingNote',
  ),
  'place.provenance.source_type': (
    '/body/provenance/sourceType',
    'validationYourRelationshipToThePlaceDoesNot',
  ),
  'place.local_id_unreplaced': (
    '/body',
    'validationSaveTheDraftAgainBeforeSubmitting',
  ),
};

const Map<String, (String, String)> _rental = <String, (String, String)>{
  'rental.locale': (
    '/body/contentLocale',
    'validationThisLanguageIsNotSupportedHere',
  ),
  'rental.locale_unavailable': (
    '/body/contentLocale',
    'validationThisLanguageIsNotSupportedHere',
  ),
  'rental.title_length': ('/body/title', 'validationCheckTheTitleLength'),
  'rental.short_description_length': (
    '/body/shortDescription',
    'validationCheckTheShortDescriptionLength',
  ),
  'rental.full_description_length': (
    '/body/fullDescription',
    'validationCheckTheDescriptionLength',
  ),
  'rental.category_required': ('/body/categoryId', 'validationChooseACategory'),
  'rental.category_not_confirmed': (
    '/body/categoryConfirmed',
    'validationConfirmTheCategory',
  ),
  'rental.subcategory_required': (
    '/body/subcategoryId',
    'validationNameWhatYouRentOut',
  ),
  'rental.policy_unavailable': (
    '/body/subcategoryId',
    'validationThisCategoryCannotBeRentedOutHere',
  ),
  'rental.cover_required': ('/body/mediaRefs', 'validationAddACoverPhoto'),
  'rental.inventory_required': (
    '/body/inventoryGroups',
    'validationAddWhatYouRentOut',
  ),
  'rental.inventory_no_available_group': (
    '/body/inventoryGroups',
    'validationMakeAtLeastOneItemAvailable',
  ),
  'rental.coverage_required': (
    '/body/availability/coverage',
    'validationConfirmWhenTheItemsAreAvailable',
  ),
  'rental.coverage_stale': (
    '/body/availability/coverage/confirmedAtUtc',
    'validationConfirmTheAvailabilityAgainItIsOlder',
  ),
  'rental.coverage_confirmed_in_future': (
    '/body/availability/coverage/confirmedAtUtc',
    'validationCheckTheDeviceClockAndConfirmThe',
  ),
  'rental.handover_required': (
    '/body/handover',
    'validationDescribeTheHandover',
  ),
  'rental.handover_precision_too_fine': (
    '/body/handover/publicGeoPrecisionMeters',
    'validationShowTheApproximateAreaAt500M',
  ),
  'rental.handover_public_address_required': (
    '/body/handover/publicAddress',
    'validationAddThePublicBusinessAddress',
  ),
  'rental.delivery_radius': (
    '/body/handover/deliveryRadiusKm',
    'validationUseADeliveryRadiusUpTo50',
  ),
  'rental.delivery_fee_required': (
    '/body/handover/deliveryFee',
    'validationAddTheDeliveryFeeZeroIfFree',
  ),
  'rental.terms_required': ('/body/terms', 'validationAddTheRentalTerms'),
  'rental.safety_notice_required': (
    '/body/terms/safetyNotice',
    'validationAddASafetyNoticeForThisCategory',
  ),
  'rental.min_renter_age_required': (
    '/body/terms/minRenterAge',
    'validationSetTheMinimumRenterAge',
  ),
  'rental.id_requirement_required': (
    '/body/terms/idRequiredAtHandover',
    'validationThisCategoryRequiresAnIDAtHandover',
  ),
  'rental.pricing_required': ('/body/pricing', 'validationAddThePrices'),
  'rental.damage_policy_required': (
    '/body/pricing/damagePolicy',
    'validationDescribeTheDamagePolicy',
  ),
  'rental.cancellation_policy_required': (
    '/body/pricing/cancellationPolicyId',
    'validationChooseACancellationPolicy',
  ),
  'rental.external_url_fragment': (
    '/body/fulfillment/externalBookingUrl',
    'validationRemoveThePartFromTheBookingLink',
  ),
  'rental.external_url_unsafe': (
    '/body/fulfillment/externalBookingUrl',
    'validationUseASecureHttpsBookingLink',
  ),
  'rental.attestation_required': (
    '/body/attestation',
    'validationConfirmTheRentalStatements',
  ),
  'rental.attestation_stale_policy': (
    '/body/attestation/policyVersion',
    'validationTheRentalRulesChangedConfirmTheStatements',
  ),
  'rental.local_id_unreplaced': (
    '/body',
    'validationSaveTheDraftAgainBeforeSubmitting',
  ),
};

const Map<String, (String, String)> _collection = <String, (String, String)>{
  'collection.locale': (
    '/body/contentLocale',
    'validationThisLanguageIsNotSupportedHere',
  ),
  'collection.locale_unavailable': (
    '/body/contentLocale',
    'validationThisLanguageIsNotSupportedHere',
  ),
  'collection.title_required': ('/body/title', 'validationAddATitle'),
  'collection.short_description_required': (
    '/body/shortDescription',
    'validationAddAShortDescription',
  ),
  'collection.full_description_length': (
    '/body/fullDescription',
    'validationShortenTheDescription',
  ),
  'collection.category_required': (
    '/body/categoryId',
    'validationChooseACategory',
  ),
  'collection.subcategory_required': (
    '/body/subcategoryId',
    'validationChooseASubcategory',
  ),
  'collection.subcategory_not_applicable': (
    '/body/subcategoryId',
    'validationChooseASubcategoryFromTheCategoryList',
  ),
  'collection.cover_image_required': (
    '/body/media/coverImage',
    'validationAddACoverImage',
  ),
  'collection.area_required': ('/body/areaLabel', 'validationNameTheArea'),
  'collection.items_required': ('/body/items', 'validationAddPlacesToTheGuide'),
  'collection.min_items': ('/body/items', 'validationAddAtLeastThreePlaces'),
  'collection.too_many_items': ('/body/items', 'validationRemoveSomePlaces'),
  'collection.item_ref_invalid': (
    '/body/items',
    'validationOnlySavedPublishedPlacesCanBeAdded',
  ),
  'collection.item_ref_unknown': (
    '/body/items',
    'validationAPlaceInTheGuideWasNot',
  ),
  'collection.item_ref_forbidden': (
    '/body/items',
    'validationAPlaceInTheGuideIsNo',
  ),
  'collection.curator_note_length': (
    '/body/items',
    'validationShortenACuratorNoteTo300Characters',
  ),
  'collection.published_objects_unavailable': (
    '/body/items',
    'validationPlacesCouldNotBeCheckedTryAgain',
  ),
  'collection.composition_review_required': (
    '/body/compositionReview',
    'validationReviewTheGuideBeforeSubmitting',
  ),
  'collection.composition_review_stale': (
    '/body/compositionReview',
    'validationReviewTheGuideAgainItChangedAfter',
  ),
  'collection.composition_review_mismatch': (
    '/body/compositionReview',
    'validationSomePlacesChangedStatusReviewTheGuide',
  ),
  'collection.local_id_unreplaced': (
    '/body',
    'validationSaveThePlacesInTheGuideBefore',
  ),
};

const Map<String, String> _labels = <String, String>{
  '/body': 'fieldLabelDraft',
  '/body/title': 'fieldLabelTitle',
  '/body/placeKind': 'fieldLabelKindOfPlace',
  '/body/relationshipToPlace': 'fieldLabelYourRelationship',
  '/body/shortDescription': 'fieldLabelShortDescription',
  '/body/fullDescription': 'fieldLabelDescription',
  '/body/contentLocale': 'fieldLabelTextLanguage',
  '/body/categoryId': 'fieldLabelCategory',
  '/body/categoryConfirmed': 'fieldLabelCategory',
  '/body/subcategoryId': 'fieldLabelSubcategory',
  '/body/location': 'fieldLabelLocation',
  '/body/location/point': 'fieldLabelMapPin',
  '/body/location/pinConfirmed': 'fieldLabelMapPin',
  '/body/location/formattedAddress': 'fieldLabelAddress',
  '/body/hours': 'fieldLabelOpeningHours',
  '/body/hours/mode': 'fieldLabelOpeningHours',
  '/body/hours/weeklyPeriods': 'fieldLabelOpeningHours',
  '/body/contacts/phone': 'fieldLabelPhone',
  '/body/contacts/email': 'fieldLabelEmail',
  '/body/contacts/website': 'fieldLabelWebsite',
  '/body/contacts/bookingUrl': 'fieldLabelBookingLink',
  '/body/media/coverImage': 'fieldLabelCoverImage',
  '/body/media/gallery': 'fieldLabelGallery',
  '/body/mediaRefs': 'fieldLabelPhotos',
  '/body/pricing': 'fieldLabelPrices',
  '/body/pricing/entryType': 'fieldLabelEntry',
  '/body/pricing/currencyCode': 'fieldLabelCurrency',
  '/body/pricing/entryPriceFrom': 'fieldLabelEntryPrice',
  '/body/pricing/pricingNote': 'fieldLabelPricingNote',
  '/body/pricing/damagePolicy': 'fieldLabelDamagePolicy',
  '/body/pricing/cancellationPolicyId': 'fieldLabelCancellationPolicy',
  '/body/provenance/sourceType': 'fieldLabelYourRelationship',
  '/body/inventoryGroups': 'fieldLabelItems',
  '/body/availability/coverage': 'fieldLabelAvailability',
  '/body/availability/coverage/confirmedAtUtc': 'fieldLabelAvailability',
  '/body/handover': 'fieldLabelHandover',
  '/body/handover/publicGeoPrecisionMeters': 'fieldLabelHandoverArea',
  '/body/handover/publicAddress': 'fieldLabelHandoverAddress',
  '/body/handover/deliveryRadiusKm': 'fieldLabelDeliveryRadius',
  '/body/handover/deliveryFee': 'fieldLabelDeliveryFee',
  '/body/terms': 'fieldLabelTerms',
  '/body/terms/safetyNotice': 'fieldLabelSafetyNotice',
  '/body/terms/minRenterAge': 'fieldLabelMinimumAge',
  '/body/terms/idRequiredAtHandover': 'fieldLabelIDAtHandover',
  '/body/fulfillment/externalBookingUrl': 'fieldLabelBookingLink',
  '/body/attestation': 'fieldLabelStatements',
  '/body/attestation/policyVersion': 'fieldLabelStatements',
  '/body/areaLabel': 'fieldLabelArea',
  '/body/items': 'fieldLabelPlacesInTheGuide',
  '/body/compositionReview': 'fieldLabelGuideReview',
};

Map<String, (String, String)>? _tableFor(CreateObjectType type) =>
    switch (type) {
      CreateObjectType.place => _place,
      CreateObjectType.rental => _rental,
      CreateObjectType.collection => _collection,
      _ => null,
    };

/// Field path → client text for the known details of [type]; unknown codes or
/// a code on another path are left out (the general message covers them).
Map<String, String> contentFieldFeedback(
  CreateObjectType type,
  List<ContentValidationViolation> violations,
) {
  final Map<String, (String, String)>? table = _tableFor(type);
  if (table == null) return const <String, String>{};
  final Map<String, String> result = <String, String>{};
  for (final ContentValidationViolation item in violations) {
    final (String, String)? known = table[item.code];
    if (known != null && known.$1 == item.fieldPath) {
      result.putIfAbsent(item.fieldPath, () => known.$2);
    } else if (item.code == 'place.criteria.required_missing' &&
        type == CreateObjectType.place &&
        item.fieldPath.startsWith('/body/criteria/')) {
      result.putIfAbsent(
        item.fieldPath,
        () => 'validationCompleteThisCategoryCriterion',
      );
    }
  }
  return Map<String, String>.unmodifiable(result);
}

/// A readable name of a field path; the criteria get their own label.
String contentFieldLabel(String fieldPath) =>
    _labels[fieldPath] ??
    (fieldPath.startsWith('/body/criteria/')
        ? 'fieldLabelCategoryCriteria'
        : 'fieldLabelDraft');
