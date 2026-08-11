import 'dart:math' as math;

import '../entities/create_draft_entity.dart';
import '../entities/place_creation_policy.dart';
import '../entities/place_draft_data.dart';
import '../entities/place_validation_issue.dart';

class ValidatePlaceDraftUseCase {
  const ValidatePlaceDraftUseCase();

  List<PlaceValidationIssue> call(
    CreateDraftEntity draft, {
    required Set<String> supportedContentLocales,
    required String activeMarketCityId,
    double? activeMarketCenterLat,
    double? activeMarketCenterLng,
    double marketPublishRadiusKm = 75,
    bool canPublish = true,
    PlaceCreationPolicy policy = PlaceCreationPolicy.safeFallback,
  }) {
    if (draft.objectType != CreateObjectType.place) {
      return const <PlaceValidationIssue>[];
    }
    final PlaceDraftData? place = draft.placeData;
    final List<PlaceValidationIssue> issues = <PlaceValidationIssue>[];

    void error(String code, String section, String field) {
      issues.add(
        PlaceValidationIssue(
          code: code,
          severity: PlaceValidationSeverity.error,
          sectionId: section,
          fieldId: field,
          messageKey: 'place.validation.$code',
        ),
      );
    }

    void warning(String code, String section, [String? field]) {
      issues.add(
        PlaceValidationIssue(
          code: code,
          severity: PlaceValidationSeverity.warning,
          sectionId: section,
          fieldId: field,
          messageKey: 'place.validation.$code',
        ),
      );
    }

    if (!canPublish) error('permission_denied', 'identity', 'publisherRef');
    if (place == null) {
      error('details_missing', 'identity', 'placeData');
      return issues;
    }
    if (place.placeKind == null) {
      error('kind_required', 'identity', 'placeKind');
    }
    if (!place.publisherRef.isValid) {
      error('publisher_invalid', 'identity', 'publisherRef');
    }
    final String title = draft.title.trim();
    if (title.length < 2 || title.length > 100) {
      error('title_length', 'identity', 'title');
    }
    if (_containsContact(title)) error('title_contact', 'identity', 'title');
    if (_isAllCaps(title)) error('title_all_caps', 'identity', 'title');
    final String shortDescription = draft.shortDescription.trim();
    if (policy.shortDescription.isRequired &&
        (shortDescription.length < 20 || shortDescription.length > 180)) {
      error('short_description_length', 'identity', 'shortDescription');
    } else if (shortDescription.isNotEmpty &&
        (shortDescription.length < 10 || shortDescription.length > 180)) {
      error('short_description_length', 'identity', 'shortDescription');
    }
    final String fullDescription = draft.fullDescription.trim();
    if (fullDescription.isNotEmpty &&
        (fullDescription.length < 50 || fullDescription.length > 5000)) {
      error('full_description_length', 'identity', 'fullDescription');
    }
    if (!supportedContentLocales.contains(place.contentLocale)) {
      error('locale_unsupported', 'identity', 'contentLocale');
    }
    if (draft.mainCategory.trim().isEmpty) {
      error('category_required', 'category', 'mainCategory');
    }
    if (draft.subcategory.trim().isEmpty) {
      error('subcategory_required', 'category', 'subcategory');
    }
    final PlaceLocationDraft location = place.location;
    if (location.marketCityId.trim().isEmpty || location.city.trim().isEmpty) {
      error('market_required', 'location', 'marketCityId');
    } else if (activeMarketCityId.isNotEmpty &&
        location.marketCityId != activeMarketCityId) {
      error('outside_market', 'location', 'marketCityId');
    }
    if (location.countryCode.trim().isEmpty) {
      error('country_required', 'location', 'countryCode');
    }
    if (location.timezoneId.trim().isEmpty) {
      error('timezone_required', 'location', 'timezoneId');
    }
    if (!_validPoint(location.latitude, location.longitude)) {
      error('pin_invalid', 'location', 'point');
    } else if (!location.pinConfirmed) {
      error('pin_unconfirmed', 'location', 'pinConfirmed');
    } else if (activeMarketCenterLat != null &&
        activeMarketCenterLng != null &&
        !(activeMarketCenterLat == 0 && activeMarketCenterLng == 0) &&
        _distanceKm(
              location.latitude!,
              location.longitude!,
              activeMarketCenterLat,
              activeMarketCenterLng,
            ) >
            marketPublishRadiusKm) {
      error('outside_market', 'location', 'point');
    }
    if (_blank(location.formattedAddress) && _blank(location.locationLabel)) {
      error('address_or_label_required', 'location', 'formattedAddress');
    }
    if (policy.accessNote.isVisible &&
        (location.entranceHint?.length ?? 0) > 300) {
      error('entrance_hint_too_long', 'location', 'entranceHint');
    }
    if (location.accuracy == PlaceLocationAccuracy.approximate) {
      warning('pin_approximate', 'location', 'accuracy');
    }

    _validateHours(place, policy, error, warning);
    if (policy.visitPlanning.isVisible) {
      _validateVisitPlanning(place.visitPlanning, error);
    }
    _validatePricing(place.pricing, policy, error, warning);
    if (policy.contacts.isVisible || policy.booking.isVisible) {
      _validateContacts(place.contacts, error, warning);
    }
    _validateOperationalStatus(place.operationalStatus, error);

    if (policy.cover.isRequired && draft.media.coverImage.trim().isEmpty) {
      error('cover_required', 'media', 'coverImage');
    }
    if (draft.media.gallery.length > 12) {
      error('gallery_limit', 'media', 'gallery');
    }
    return issues;
  }

  static void _validateHours(
    PlaceDraftData place,
    PlaceCreationPolicy policy,
    void Function(String, String, String) error,
    void Function(String, String, [String?]) warning,
  ) {
    if (!policy.hours.isVisible) return;
    final PlaceHoursDraft hours = place.hours;
    if (hours.mode == null) {
      if (policy.hours.isRequired) {
        error('hours_mode_required', 'hours', 'mode');
      }
      return;
    }
    if (hours.mode == PlaceHoursMode.regular && hours.weeklyPeriods.isEmpty) {
      error('hours_period_required', 'hours', 'weeklyPeriods');
    }
    if ((hours.mode == PlaceHoursMode.alwaysOpen ||
            hours.mode == PlaceHoursMode.unknown) &&
        hours.weeklyPeriods.isNotEmpty) {
      error('hours_periods_not_allowed', 'hours', 'weeklyPeriods');
    }
    if (hours.mode == PlaceHoursMode.unknown && hours.exceptions.isNotEmpty) {
      error('hours_exceptions_not_allowed', 'hours', 'exceptions');
    }
    if (hours.mode == PlaceHoursMode.seasonal) {
      error('seasonal_not_supported', 'hours', 'mode');
    }
    if (hours.mode == PlaceHoursMode.unknown) {
      warning('hours_unknown', 'hours', 'mode');
    }
    for (final LocalOpeningPeriod period in hours.weeklyPeriods) {
      if (!_validPeriod(period)) {
        error('hours_period_invalid', 'hours', 'weeklyPeriods');
      }
    }
    if (_hasOverlaps(hours.weeklyPeriods)) {
      error('hours_overlap', 'hours', 'weeklyPeriods');
    }
    for (final OpeningException exception in hours.exceptions) {
      if (!_validLocalDate(exception.localDate)) {
        error('hours_exception_date_invalid', 'hours', 'exceptions');
      }
      if (exception.kind == OpeningExceptionKind.closedAllDay &&
          exception.periods.isNotEmpty) {
        error('hours_exception_periods_not_allowed', 'hours', 'exceptions');
      }
      if (exception.kind == OpeningExceptionKind.customHours &&
          exception.periods.isEmpty) {
        error('hours_exception_period_required', 'hours', 'exceptions');
      }
      for (final LocalOpeningPeriod period in exception.periods) {
        if (!_validPeriod(period)) {
          error('hours_exception_period_invalid', 'hours', 'exceptions');
        }
      }
      if (_hasOverlaps(exception.periods)) {
        error('hours_exception_overlap', 'hours', 'exceptions');
      }
    }
  }

  static void _validateVisitPlanning(
    PlaceVisitPlanningDraft planning,
    void Function(String, String, String) error,
  ) {
    final int? recommended = planning.recommendedVisitMinutes;
    final int? minimum = planning.minimumVisitMinutes;
    if (recommended != null && (recommended < 10 || recommended > 1440)) {
      error('visit_duration_invalid', 'planning', 'recommendedVisitMinutes');
    }
    if (minimum != null &&
        (minimum <= 0 || (recommended != null && minimum > recommended))) {
      error('minimum_visit_invalid', 'planning', 'minimumVisitMinutes');
    }
    if (planning.allowsShortVisit && minimum == null) {
      error('minimum_visit_required', 'planning', 'minimumVisitMinutes');
    }
    if (planning.arrivalBufferMinutes < 0 ||
        planning.arrivalBufferMinutes > 120 ||
        planning.exitBufferMinutes < 0 ||
        planning.exitBufferMinutes > 120) {
      error('visit_buffer_invalid', 'planning', 'arrivalBufferMinutes');
    }
    if ((planning.busyTimeNotes?.length ?? 0) > 300) {
      error('busy_time_notes_too_long', 'planning', 'busyTimeNotes');
    }
  }

  static void _validatePricing(
    PlacePricingDraft pricing,
    PlaceCreationPolicy policy,
    void Function(String, String, String) error,
    void Function(String, String, [String?]) warning,
  ) {
    final PlaceEntryType? type = pricing.entryType;
    if (policy.admission.isVisible &&
        (type == PlaceEntryType.paid || type == PlaceEntryType.mixed)) {
      if (pricing.entryPriceFrom == null) {
        error('entry_price_required', 'pricing', 'entryPriceFrom');
      }
    }
    if (policy.admission.isVisible &&
        type == PlaceEntryType.mixed &&
        _blank(pricing.pricingNote)) {
      error('mixed_pricing_note_required', 'pricing', 'pricingNote');
    }
    if (policy.admission.isVisible && type == PlaceEntryType.unknown) {
      warning('entry_type_unknown', 'pricing', 'entryType');
    }
    final Iterable<double?> activeAmounts = <double?>[
      if (policy.admission.isVisible) ...<double?>[
        pricing.entryPriceFrom,
        pricing.entryPriceTo,
      ],
      if (policy.typicalSpend.isVisible) ...<double?>[
        pricing.typicalSpendFrom,
        pricing.typicalSpendTo,
      ],
    ];
    for (final double? amount in activeAmounts) {
      if (amount != null && amount < 0) {
        error('price_negative', 'pricing', 'entryPriceFrom');
      }
    }
    if (policy.admission.isVisible &&
        _rangeInvalid(pricing.entryPriceFrom, pricing.entryPriceTo)) {
      error('entry_price_range_invalid', 'pricing', 'entryPriceTo');
    }
    if (policy.typicalSpend.isVisible &&
        _rangeInvalid(pricing.typicalSpendFrom, pricing.typicalSpendTo)) {
      error('spend_range_invalid', 'pricing', 'typicalSpendTo');
    }
    if ((policy.admission.isVisible || policy.typicalSpend.isVisible) &&
        !_blank(pricing.officialPricingUrl) &&
        !_validHttpsUrl(pricing.officialPricingUrl!)) {
      error('pricing_url_invalid', 'pricing', 'officialPricingUrl');
    }
    if ((policy.admission.isVisible || policy.typicalSpend.isVisible) &&
        (pricing.pricingNote?.length ?? 0) > 300) {
      error('pricing_note_too_long', 'pricing', 'pricingNote');
    }
  }

  static void _validateContacts(
    PlaceContactsDraft contacts,
    void Function(String, String, String) error,
    void Function(String, String, [String?]) warning,
  ) {
    for (final MapEntry<String, String?> entry in <String, String?>{
      'websiteUrl': contacts.websiteUrl,
      'bookingUrl': contacts.bookingUrl,
      for (int index = 0; index < contacts.socialUrls.length; index++)
        'socialUrls.$index': contacts.socialUrls[index],
    }.entries) {
      if (!_blank(entry.value) && !_validHttpsUrl(entry.value!)) {
        error('contact_url_invalid', 'contacts', entry.key);
      }
    }
    if (!_blank(contacts.email) &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(contacts.email!)) {
      error('email_invalid', 'contacts', 'email');
    }
    if (!_blank(contacts.phone) &&
        contacts.phone!.replaceAll(RegExp(r'\D'), '').length < 7) {
      error('phone_invalid', 'contacts', 'phone');
    }
    if (_blank(contacts.websiteUrl) &&
        _blank(contacts.phone) &&
        _blank(contacts.email) &&
        _blank(contacts.bookingUrl)) {
      warning('contacts_missing', 'contacts');
    }
  }

  static void _validateOperationalStatus(
    PlaceOperationalStatusDraft status,
    void Function(String, String, String) error,
  ) {
    if (status.status == PlaceOperationalStatus.temporarilyClosed) {
      if (!_validLocalDate(status.closedFromLocalDate)) {
        error('closure_start_required', 'hours', 'closedFromLocalDate');
      }
      if (status.closedUntilLocalDate != null &&
          (!_validLocalDate(status.closedUntilLocalDate) ||
              status.closedUntilLocalDate!.compareTo(
                    status.closedFromLocalDate ?? '',
                  ) <
                  0)) {
        error('closure_end_invalid', 'hours', 'closedUntilLocalDate');
      }
    }
    if ((status.publicNote?.length ?? 0) > 200) {
      error('closure_note_too_long', 'hours', 'operationalStatus.publicNote');
    }
  }

  static bool _validPeriod(LocalOpeningPeriod period) {
    if (period.dayOfWeek < 1 || period.dayOfWeek > 7) return false;
    if (period.openMinute < 0 || period.openMinute > 1439) return false;
    if (period.closeMinute < 0 || period.closeMinute > 1439) return false;
    if (!period.closesNextDay && period.closeMinute <= period.openMinute) {
      return false;
    }
    return period.durationMinutes > 0 && period.durationMinutes < 1440;
  }

  static bool _hasOverlaps(List<LocalOpeningPeriod> periods) {
    final Map<int, List<(int, int)>> byDay = <int, List<(int, int)>>{};
    for (final LocalOpeningPeriod period in periods) {
      if (!_validPeriod(period)) continue;
      byDay.putIfAbsent(period.dayOfWeek, () => <(int, int)>[]).add((
        period.openMinute,
        period.closesNextDay ? 1440 : period.closeMinute,
      ));
      if (period.closesNextDay && period.closeMinute > 0) {
        final int nextDay = period.dayOfWeek == 7 ? 1 : period.dayOfWeek + 1;
        byDay.putIfAbsent(nextDay, () => <(int, int)>[]).add((
          0,
          period.closeMinute,
        ));
      }
    }
    for (final List<(int, int)> ranges in byDay.values) {
      ranges.sort(((int, int) a, (int, int) b) => a.$1.compareTo(b.$1));
      for (int index = 1; index < ranges.length; index++) {
        if (ranges[index].$1 < ranges[index - 1].$2) return true;
      }
    }
    return false;
  }

  static bool _validPoint(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static bool _validLocalDate(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed != null &&
        '${parsed.year.toString().padLeft(4, '0')}-'
                '${parsed.month.toString().padLeft(2, '0')}-'
                '${parsed.day.toString().padLeft(2, '0')}' ==
            value;
  }

  static bool _validHttpsUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static bool _containsContact(String value) {
    return value.contains('@') ||
        RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(value) ||
        value.replaceAll(RegExp(r'\D'), '').length >= 7;
  }

  static bool _isAllCaps(String value) {
    final String letters = value.replaceAll(
      RegExp(r'[^A-Za-z\u00c0-\u024f\u0400-\u04ff]'),
      '',
    );
    return letters.length >= 4 &&
        letters == letters.toUpperCase() &&
        letters != letters.toLowerCase();
  }

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  static bool _rangeInvalid(double? from, double? to) {
    return from != null && to != null && from > to;
  }

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;
    final double latDelta = (lat2 - lat1) * math.pi / 180;
    final double lonDelta = (lon2 - lon1) * math.pi / 180;
    final double a =
        math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(lonDelta / 2) *
            math.sin(lonDelta / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
