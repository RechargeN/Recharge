import '../entities/create_draft_entity.dart';
import '../entities/event_draft_data.dart';
import '../entities/event_validation_issue.dart';
import 'validate_event_classification_usecase.dart';
import 'validate_event_access_configuration_usecase.dart';
import 'build_event_content_body.dart';

class ValidateEventDraftUseCase {
  const ValidateEventDraftUseCase({
    ValidateEventClassificationUseCase validateClassification =
        const ValidateEventClassificationUseCase(),
    ValidateEventAccessConfigurationUseCase validateAccess =
        const ValidateEventAccessConfigurationUseCase(),
    EventAccessReadiness Function()? accessReadiness,
  }) : _validateClassification = validateClassification,
       _validateAccess = validateAccess,
       _accessReadiness = accessReadiness;

  final ValidateEventClassificationUseCase _validateClassification;
  final ValidateEventAccessConfigurationUseCase _validateAccess;
  final EventAccessReadiness Function()? _accessReadiness;

  EventAccessReadiness get accessReadiness =>
      _accessReadiness?.call() ?? const EventAccessReadiness();

  List<EventValidationIssue> call(
    CreateDraftEntity draft, {
    int? throughStep,
    DateTime? nowUtc,
    bool includeClassification = true,
    bool includeAccessConfiguration = false,
  }) {
    final EventDraftData? event = draft.eventData;
    if (draft.objectType != CreateObjectType.event || event == null) {
      return const <EventValidationIssue>[
        EventValidationIssue(
          code: 'event_data_missing',
          fieldId: 'eventData',
          step: 0,
        ),
      ];
    }
    final List<EventValidationIssue> issues = <EventValidationIssue>[];
    void blocking(int step, String code, String field) {
      if (throughStep == null || step <= throughStep) {
        issues.add(
          EventValidationIssue(code: code, fieldId: field, step: step),
        );
      }
    }

    if (event.schemaVersion > EventDraftData.currentSchemaVersion) {
      blocking(0, 'event_schema_unsupported', 'eventData');
    }
    if (includeClassification && (throughStep == null || throughStep >= 0)) {
      if (event.unsupportedFieldIds.contains('publisherRef')) {
        blocking(0, 'event_publisher_unsupported', 'publisherRef');
      } else if (event.publisherRef?.isValid != true) {
        blocking(0, 'event_publisher_required', 'publisherRef');
      }
      if (event.unsupportedFieldIds.contains('classification')) {
        blocking(0, 'event_classification_unsupported', 'eventArchetype');
      } else {
        issues.addAll(_validateClassification(event.classification));
      }
    }

    if (draft.title.trim().length < 3) {
      blocking(0, 'title_required', 'title');
    }
    if (draft.mainCategory.trim().isEmpty || draft.subcategory.trim().isEmpty) {
      blocking(0, 'taxonomy_required', 'subcategory');
    }
    if (draft.shortDescription.trim().length < 10) {
      blocking(0, 'short_description_required', 'shortDescription');
    }
    if (draft.media.coverImage.trim().isEmpty) {
      blocking(0, 'cover_required', 'coverImage');
    }
    if (event.mediaMetadata.coverAltText.trim().length < 3) {
      blocking(0, 'cover_alt_required', 'coverAltText');
    }
    if (!event.mediaMetadata.rightsConfirmed) {
      blocking(0, 'media_rights_required', 'mediaRights');
    }
    for (final String mediaReference in draft.media.gallery) {
      if ((event.mediaMetadata.galleryAltText[mediaReference] ?? '')
              .trim()
              .length <
          3) {
        blocking(0, 'gallery_alt_required', 'galleryAlt:$mediaReference');
      }
    }

    final bool needsLocation =
        event.format == EventFormat.offline ||
        event.format == EventFormat.hybrid;
    final bool needsOnline =
        event.format == EventFormat.online ||
        event.format == EventFormat.hybrid;
    if (needsLocation && event.location.city.trim().isEmpty) {
      blocking(1, 'city_required', 'city');
    }
    if (needsLocation &&
        (event.location.formattedAddress?.trim().isEmpty ?? true) &&
        (event.location.meetingPoint?.trim().isEmpty ?? true)) {
      blocking(1, 'location_required', 'location');
    }
    if (needsLocation &&
        (!_validLatitude(event.location.latitude) ||
            !_validLongitude(event.location.longitude))) {
      blocking(1, 'location_coordinates_required', 'locationCoordinates');
    } else if (needsLocation && !event.location.pinConfirmed) {
      blocking(1, 'location_pin_unconfirmed', 'locationPin');
    }
    if (needsOnline && event.onlineAccessMode == null) {
      blocking(1, 'online_access_required', 'onlineAccessMode');
    }
    if (event.onlineAccessMode == EventOnlineAccessMode.publicLink &&
        !_isSafeHttps(event.publicOnlineUrl)) {
      blocking(1, 'public_online_url_invalid', 'publicOnlineUrl');
    }
    if (needsOnline &&
        event.onlineAccessMode == EventOnlineAccessMode.externalRegistration &&
        (event.admission?.registrationMode ?? event.registrationMode) !=
            EventRegistrationMode.external) {
      blocking(3, 'online_access_registration_conflict', 'registrationMode');
    }
    if (event.timezoneId.trim().isEmpty) {
      blocking(1, 'timezone_required', 'timezoneId');
    }
    if (event.durationMinutes <= 0) {
      blocking(1, 'duration_invalid', 'durationMinutes');
    }
    if (!_isLocalDate(event.localStartDate)) {
      blocking(1, 'local_start_date_invalid', 'localStartDate');
    }
    if (event.startMinute < 0 || event.startMinute >= 1440) {
      blocking(1, 'start_minute_invalid', 'startMinute');
    }
    if (event.allDay && event.durationMinutes % 1440 != 0) {
      blocking(1, 'all_day_duration_invalid', 'durationMinutes');
    }
    if (event.scheduleMode == EventScheduleMode.multiDate &&
        event.multiDateLocalDates.isEmpty) {
      blocking(1, 'multi_dates_required', 'multiDateLocalDates');
    }
    if (event.scheduleMode == EventScheduleMode.multiDate &&
        event.multiDateLocalDates.any((String value) => !_isLocalDate(value))) {
      blocking(1, 'multi_date_invalid', 'multiDateLocalDates');
    }
    if (event.scheduleMode == EventScheduleMode.recurring) {
      final EventRecurrenceRuleDraft? rule = event.recurrence;
      if (rule == null || rule.interval <= 0) {
        blocking(1, 'recurrence_invalid', 'recurrence');
      } else {
        if (rule.frequency == EventRecurrenceFrequency.weekly &&
            rule.weekdays.any((int day) => day < 1 || day > 7)) {
          blocking(1, 'recurrence_weekday_invalid', 'weekdays');
        }
        if (rule.exceptionLocalDates.any(
          (String value) => !_isLocalDate(value),
        )) {
          blocking(1, 'recurrence_exception_invalid', 'exceptionLocalDates');
        }
        if (rule.endMode == EventRecurrenceEndMode.untilDate &&
            (rule.untilLocalDate?.isEmpty ?? true)) {
          blocking(1, 'recurrence_until_required', 'untilLocalDate');
        } else if (rule.endMode == EventRecurrenceEndMode.untilDate &&
            !_isLocalDate(rule.untilLocalDate!)) {
          blocking(1, 'recurrence_until_invalid', 'untilLocalDate');
        }
        if (rule.endMode == EventRecurrenceEndMode.occurrenceCount &&
            (rule.occurrenceCount ?? 0) <= 0) {
          blocking(1, 'recurrence_count_required', 'occurrenceCount');
        }
      }
    }
    if (event.occurrences.isEmpty) {
      blocking(1, 'occurrences_required', 'occurrences');
    } else if (!event.occurrences.any(
      (EventOccurrenceDraft value) =>
          value.endAtUtc.isAfter(nowUtc ?? DateTime.now().toUtc()),
    )) {
      blocking(1, 'future_occurrence_required', 'occurrences');
    }

    if (event.ageMin != null && event.ageMin! < 0) {
      blocking(2, 'age_min_invalid', 'ageMin');
    }
    if (event.ageMax != null && event.ageMax! < 0) {
      blocking(2, 'age_max_invalid', 'ageMax');
    }
    if (event.ageMin != null &&
        event.ageMax != null &&
        event.ageMin! > event.ageMax!) {
      blocking(2, 'age_range_invalid', 'ageMax');
    }

    if (event.pricingMode == EventPricingMode.free) {
      if (event.price != null ||
          event.paymentCollectionMode != EventPaymentCollectionMode.none) {
        blocking(3, 'free_price_conflict', 'pricingMode');
      }
    } else if (event.pricingMode == EventPricingMode.fixed) {
      if ((event.price?.amountMinor ?? 0) <= 0) {
        blocking(3, 'fixed_price_required', 'price');
      }
      if (event.paymentCollectionMode == EventPaymentCollectionMode.none ||
          event.paymentCollectionMode == EventPaymentCollectionMode.internal) {
        blocking(3, 'payment_mode_unavailable', 'paymentCollectionMode');
      }
    } else {
      blocking(3, 'pricing_capability_unavailable', 'pricingMode');
    }
    if (event.unsupportedFieldIds.contains('admission')) {
      blocking(3, 'event_admission_unsupported', 'admission');
    }
    if (event.unsupportedFieldIds.contains('inventory')) {
      blocking(3, 'event_inventory_unsupported', 'inventory');
    }
    if (includeAccessConfiguration && event.admission == null) {
      blocking(3, 'event_admission_required', 'admission');
    }
    if (includeAccessConfiguration && event.inventory == null) {
      blocking(3, 'event_inventory_authority_required', 'inventoryAuthority');
    }
    if (!event.unsupportedFieldIds.contains('admission') &&
        !event.unsupportedFieldIds.contains('inventory') &&
        (throughStep == null || throughStep >= 3)) {
      issues.addAll(
        _validateAccess(
          admission: event.admission,
          inventory: event.inventory,
          capacityMode: event.capacityMode,
          capacity: event.capacity,
          format: event.format,
          scheduleMode: event.scheduleMode,
          occurrences: event.occurrences,
          externalRegistrationUrl: event.externalBookingUrl,
          readiness: accessReadiness,
        ),
      );
      if (accessReadiness.internalRegistration &&
          event.admission?.registrationMode == EventRegistrationMode.internal) {
        for (final String field
            in const EventContentBodyMapper().map(draft).unsupported) {
          blocking(3, 'internal_registration_v1_unsupported', field);
        }
      }
    }
    if (event.admission == null &&
        event.registrationMode == EventRegistrationMode.external &&
        !_isSafeHttps(event.externalBookingUrl)) {
      blocking(3, 'external_booking_url_invalid', 'externalBookingUrl');
    }
    if (event.admission == null &&
        event.registrationMode == EventRegistrationMode.internal) {
      blocking(3, 'internal_booking_unavailable', 'registrationMode');
    }
    if (event.visibility == EventVisibility.private) {
      blocking(4, 'private_access_unavailable', 'visibility');
    }
    return List<EventValidationIssue>.unmodifiable(issues);
  }

  bool _isSafeHttps(String? raw) {
    final Uri? uri = Uri.tryParse(raw?.trim() ?? '');
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isLocalDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final DateTime? parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null &&
        '${parsed.year.toString().padLeft(4, '0')}-'
                '${parsed.month.toString().padLeft(2, '0')}-'
                '${parsed.day.toString().padLeft(2, '0')}' ==
            value;
  }

  bool _validLatitude(double? value) =>
      value != null && value.isFinite && value >= -90 && value <= 90;

  bool _validLongitude(double? value) =>
      value != null && value.isFinite && value >= -180 && value <= 180;
}
