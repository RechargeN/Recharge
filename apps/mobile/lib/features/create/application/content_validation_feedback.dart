import '../domain/entities/content_validation_violation.dart';
import '../domain/entities/create_draft_entity.dart';

/// Client text for the server's public validation details of Place, Rental
/// and Collection (M1 stage 3, owner decision 3-A). Only a known code on its
/// exact field path renders; anything else stays the general refusal message,
/// as for Activity (`activity_validation_feedback.dart`).
const Map<String, (String, String)> _place = <String, (String, String)>{
  'place.title': ('/body/title', 'Use 3–120 characters.'),
  'place.title.all_caps': (
    '/body/title',
    'Do not write the title in capitals.',
  ),
  'place.title.contact_like': (
    '/body/title',
    'Keep contacts out of the title.',
  ),
  'place.place_kind': ('/body/placeKind', 'Choose what kind of place it is.'),
  'place.relationship_to_place': (
    '/body/relationshipToPlace',
    'Choose your relationship to this place.',
  ),
  'place.short_description': (
    '/body/shortDescription',
    'Use 20–180 characters.',
  ),
  'place.full_description': (
    '/body/fullDescription',
    'Shorten the description.',
  ),
  'place.content_locale': ('/body/contentLocale', 'Choose the text language.'),
  'place.content_locale.unsupported': (
    '/body/contentLocale',
    'This language is not supported here.',
  ),
  'place.category_id': ('/body/categoryId', 'Choose a category.'),
  'place.subcategory_id': ('/body/subcategoryId', 'Choose a subcategory.'),
  'place.subcategory.not_applicable': (
    '/body/subcategoryId',
    'Choose a subcategory available for places.',
  ),
  'place.taxonomy_unavailable': (
    '/body/subcategoryId',
    'Category data is unavailable. Try again later.',
  ),
  'place.location': ('/body/location', 'Set the location.'),
  'place.location.point': ('/body/location/point', 'Set the map pin.'),
  'place.location.pin_unconfirmed': (
    '/body/location/pinConfirmed',
    'Confirm the map pin.',
  ),
  'place.location.outside_service_area': (
    '/body/location/point',
    'The pin is outside the service area.',
  ),
  'place.location.address_or_label_missing': (
    '/body/location/formattedAddress',
    'Add an address or a location label.',
  ),
  'place.hours': ('/body/hours', 'Choose how the opening hours work.'),
  'place.hours.mode': ('/body/hours/mode', 'Choose an opening-hours mode.'),
  'place.hours.mode_unsupported': (
    '/body/hours/mode',
    'Seasonal hours are not supported yet.',
  ),
  'place.hours.weekly_required': (
    '/body/hours/weeklyPeriods',
    'Add the weekly opening hours.',
  ),
  'place.hours.period_invalid': (
    '/body/hours/weeklyPeriods',
    'Check the opening times.',
  ),
  'place.hours.period_overlap': (
    '/body/hours/weeklyPeriods',
    'Opening times overlap.',
  ),
  'place.contacts.phone': (
    '/body/contacts/phone',
    'Use 7–15 digits; only + ( ) . - and spaces besides digits.',
  ),
  'place.contacts.email': ('/body/contacts/email', 'Check the email address.'),
  'place.contacts.website': (
    '/body/contacts/website',
    'Use a secure https link.',
  ),
  'place.contacts.bookingUrl': (
    '/body/contacts/bookingUrl',
    'Use a secure https link.',
  ),
  'place.media.cover_missing': ('/body/media/coverImage', 'Add a cover image.'),
  'place.media.gallery_too_large': (
    '/body/media/gallery',
    'Remove some gallery images.',
  ),
  'place.pricing.entry_type': (
    '/body/pricing/entryType',
    'Choose whether entry is free or paid.',
  ),
  'place.pricing.currency_code': (
    '/body/pricing/currencyCode',
    'Use the market currency.',
  ),
  'place.pricing.entry_price_from_required': (
    '/body/pricing/entryPriceFrom',
    'Add the entry price.',
  ),
  'place.pricing.note_required': (
    '/body/pricing/pricingNote',
    'Add a pricing note.',
  ),
  'place.provenance.source_type': (
    '/body/provenance/sourceType',
    'Your relationship to the place does not match how it was added.',
  ),
  'place.local_id_unreplaced': (
    '/body',
    'Save the draft again before submitting.',
  ),
};

const Map<String, (String, String)> _rental = <String, (String, String)>{
  'rental.title_length': ('/body/title', 'Check the title length.'),
  'rental.short_description_length': (
    '/body/shortDescription',
    'Check the short description length.',
  ),
  'rental.full_description_length': (
    '/body/fullDescription',
    'Check the description length.',
  ),
  'rental.category_required': ('/body/categoryId', 'Choose a category.'),
  'rental.category_not_confirmed': (
    '/body/categoryConfirmed',
    'Confirm the category.',
  ),
  'rental.subcategory_required': (
    '/body/subcategoryId',
    'Name what you rent out.',
  ),
  'rental.policy_unavailable': (
    '/body/subcategoryId',
    'This category cannot be rented out here yet.',
  ),
  'rental.cover_required': ('/body/mediaRefs', 'Add a cover photo.'),
  'rental.inventory_required': (
    '/body/inventoryGroups',
    'Add what you rent out.',
  ),
  'rental.inventory_no_available_group': (
    '/body/inventoryGroups',
    'Make at least one item available.',
  ),
  'rental.coverage_required': (
    '/body/availability/coverage',
    'Confirm when the items are available.',
  ),
  'rental.coverage_stale': (
    '/body/availability/coverage/confirmedAtUtc',
    'Confirm the availability again; it is older than a week.',
  ),
  'rental.coverage_confirmed_in_future': (
    '/body/availability/coverage/confirmedAtUtc',
    'Check the device clock and confirm the availability again.',
  ),
  'rental.handover_required': ('/body/handover', 'Describe the handover.'),
  'rental.handover_precision_too_fine': (
    '/body/handover/publicGeoPrecisionMeters',
    'Show the approximate area at 500 m or coarser.',
  ),
  'rental.handover_public_address_required': (
    '/body/handover/publicAddress',
    'Add the public business address.',
  ),
  'rental.delivery_radius': (
    '/body/handover/deliveryRadiusKm',
    'Use a delivery radius up to 50 km.',
  ),
  'rental.delivery_fee_required': (
    '/body/handover/deliveryFee',
    'Add the delivery fee (zero if free).',
  ),
  'rental.terms_required': ('/body/terms', 'Add the rental terms.'),
  'rental.safety_notice_required': (
    '/body/terms/safetyNotice',
    'Add a safety notice for this category.',
  ),
  'rental.min_renter_age_required': (
    '/body/terms/minRenterAge',
    'Set the minimum renter age.',
  ),
  'rental.id_requirement_required': (
    '/body/terms/idRequiredAtHandover',
    'This category requires an ID at handover.',
  ),
  'rental.pricing_required': ('/body/pricing', 'Add the prices.'),
  'rental.damage_policy_required': (
    '/body/pricing/damagePolicy',
    'Describe the damage policy.',
  ),
  'rental.cancellation_policy_required': (
    '/body/pricing/cancellationPolicyId',
    'Choose a cancellation policy.',
  ),
  'rental.external_url_fragment': (
    '/body/fulfillment/externalBookingUrl',
    'Remove the # part from the booking link.',
  ),
  'rental.external_url_unsafe': (
    '/body/fulfillment/externalBookingUrl',
    'Use a secure https booking link.',
  ),
  'rental.attestation_required': (
    '/body/attestation',
    'Confirm the rental statements.',
  ),
  'rental.attestation_stale_policy': (
    '/body/attestation/policyVersion',
    'The rental rules changed. Confirm the statements again.',
  ),
  'rental.local_id_unreplaced': (
    '/body',
    'Save the draft again before submitting.',
  ),
};

const Map<String, (String, String)> _collection = <String, (String, String)>{
  'collection.title_required': ('/body/title', 'Add a title.'),
  'collection.short_description_required': (
    '/body/shortDescription',
    'Add a short description.',
  ),
  'collection.full_description_length': (
    '/body/fullDescription',
    'Shorten the description.',
  ),
  'collection.category_required': ('/body/categoryId', 'Choose a category.'),
  'collection.subcategory_required': (
    '/body/subcategoryId',
    'Choose a subcategory.',
  ),
  'collection.subcategory_not_applicable': (
    '/body/subcategoryId',
    'Choose a subcategory from the category list.',
  ),
  'collection.cover_image_required': (
    '/body/media/coverImage',
    'Add a cover image.',
  ),
  'collection.area_required': ('/body/areaLabel', 'Name the area.'),
  'collection.items_required': ('/body/items', 'Add places to the guide.'),
  'collection.min_items': ('/body/items', 'Add at least three places.'),
  'collection.too_many_items': ('/body/items', 'Remove some places.'),
  'collection.item_ref_invalid': (
    '/body/items',
    'Only saved, published places can be added.',
  ),
  'collection.item_ref_unknown': (
    '/body/items',
    'A place in the guide was not found. Remove or replace it.',
  ),
  'collection.item_ref_forbidden': (
    '/body/items',
    'A place in the guide is no longer public. Remove or replace it.',
  ),
  'collection.curator_note_length': (
    '/body/items',
    'Shorten a curator note to 300 characters.',
  ),
  'collection.published_objects_unavailable': (
    '/body/items',
    'Places could not be checked. Try again later.',
  ),
  'collection.composition_review_required': (
    '/body/compositionReview',
    'Review the guide before submitting.',
  ),
  'collection.composition_review_stale': (
    '/body/compositionReview',
    'Review the guide again: it changed after the review.',
  ),
  'collection.composition_review_mismatch': (
    '/body/compositionReview',
    'Some places changed status. Review the guide again.',
  ),
  'collection.local_id_unreplaced': (
    '/body',
    'Save the places in the guide before submitting.',
  ),
};

const Map<String, String> _labels = <String, String>{
  '/body': 'Draft',
  '/body/title': 'Title',
  '/body/placeKind': 'Kind of place',
  '/body/relationshipToPlace': 'Your relationship',
  '/body/shortDescription': 'Short description',
  '/body/fullDescription': 'Description',
  '/body/contentLocale': 'Text language',
  '/body/categoryId': 'Category',
  '/body/categoryConfirmed': 'Category',
  '/body/subcategoryId': 'Subcategory',
  '/body/location': 'Location',
  '/body/location/point': 'Map pin',
  '/body/location/pinConfirmed': 'Map pin',
  '/body/location/formattedAddress': 'Address',
  '/body/hours': 'Opening hours',
  '/body/hours/mode': 'Opening hours',
  '/body/hours/weeklyPeriods': 'Opening hours',
  '/body/contacts/phone': 'Phone',
  '/body/contacts/email': 'Email',
  '/body/contacts/website': 'Website',
  '/body/contacts/bookingUrl': 'Booking link',
  '/body/media/coverImage': 'Cover image',
  '/body/media/gallery': 'Gallery',
  '/body/mediaRefs': 'Photos',
  '/body/pricing': 'Prices',
  '/body/pricing/entryType': 'Entry',
  '/body/pricing/currencyCode': 'Currency',
  '/body/pricing/entryPriceFrom': 'Entry price',
  '/body/pricing/pricingNote': 'Pricing note',
  '/body/pricing/damagePolicy': 'Damage policy',
  '/body/pricing/cancellationPolicyId': 'Cancellation policy',
  '/body/provenance/sourceType': 'Your relationship',
  '/body/inventoryGroups': 'Items',
  '/body/availability/coverage': 'Availability',
  '/body/availability/coverage/confirmedAtUtc': 'Availability',
  '/body/handover': 'Handover',
  '/body/handover/publicGeoPrecisionMeters': 'Handover area',
  '/body/handover/publicAddress': 'Handover address',
  '/body/handover/deliveryRadiusKm': 'Delivery radius',
  '/body/handover/deliveryFee': 'Delivery fee',
  '/body/terms': 'Terms',
  '/body/terms/safetyNotice': 'Safety notice',
  '/body/terms/minRenterAge': 'Minimum age',
  '/body/terms/idRequiredAtHandover': 'ID at handover',
  '/body/fulfillment/externalBookingUrl': 'Booking link',
  '/body/attestation': 'Statements',
  '/body/attestation/policyVersion': 'Statements',
  '/body/areaLabel': 'Area',
  '/body/items': 'Places in the guide',
  '/body/compositionReview': 'Guide review',
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
        () => 'Complete this category criterion.',
      );
    }
  }
  return Map<String, String>.unmodifiable(result);
}

/// A readable name of a field path; the criteria get their own label.
String contentFieldLabel(String fieldPath) =>
    _labels[fieldPath] ??
    (fieldPath.startsWith('/body/criteria/') ? 'Category criteria' : 'Draft');
