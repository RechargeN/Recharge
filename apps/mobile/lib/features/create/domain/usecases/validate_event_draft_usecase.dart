import '../entities/create_draft_entity.dart';
import '../entities/event_draft_data.dart';
import '../entities/event_validation_issue.dart';

class ValidateEventDraftUseCase {
  const ValidateEventDraftUseCase();

  List<EventValidationIssue> call(
    CreateDraftEntity draft, {
    int? throughStep,
    DateTime? nowUtc,
  }) {
    final EventDraftData? event = draft.eventData;
    if (draft.objectType != CreateObjectType.event || event == null) {
      return const <EventValidationIssue>[
        EventValidationIssue(
          code: 'event_data_missing',
          fieldId: 'eventData',
          step: 0,
          message: 'Event details are unavailable. Reopen the draft.',
        ),
      ];
    }
    final List<EventValidationIssue> issues = <EventValidationIssue>[];
    void blocking(int step, String code, String field, String message) {
      if (throughStep == null || step <= throughStep) {
        issues.add(
          EventValidationIssue(
            code: code,
            fieldId: field,
            step: step,
            message: message,
          ),
        );
      }
    }

    if (draft.title.trim().length < 3) {
      blocking(
        0,
        'title_required',
        'title',
        'Add a title of at least 3 characters.',
      );
    }
    if (draft.mainCategory.trim().isEmpty || draft.subcategory.trim().isEmpty) {
      blocking(
        0,
        'taxonomy_required',
        'subcategory',
        'Choose a category and subcategory.',
      );
    }
    if (draft.shortDescription.trim().length < 10) {
      blocking(
        0,
        'short_description_required',
        'shortDescription',
        'Add a short description of at least 10 characters.',
      );
    }
    if (draft.media.coverImage.trim().isEmpty) {
      blocking(0, 'cover_required', 'coverImage', 'Add a cover image.');
    }
    if (event.mediaMetadata.coverAltText.trim().length < 3) {
      blocking(
        0,
        'cover_alt_required',
        'coverAltText',
        'Describe the cover image for accessibility.',
      );
    }
    if (!event.mediaMetadata.rightsConfirmed) {
      blocking(
        0,
        'media_rights_required',
        'mediaRights',
        'Confirm that you may publish this media.',
      );
    }
    for (final String mediaReference in draft.media.gallery) {
      if ((event.mediaMetadata.galleryAltText[mediaReference] ?? '')
              .trim()
              .length <
          3) {
        blocking(
          0,
          'gallery_alt_required',
          'galleryAlt:$mediaReference',
          'Describe every gallery image for accessibility.',
        );
      }
    }

    final bool needsLocation =
        event.format == EventFormat.offline ||
        event.format == EventFormat.hybrid;
    final bool needsOnline =
        event.format == EventFormat.online ||
        event.format == EventFormat.hybrid;
    if (needsLocation && event.location.city.trim().isEmpty) {
      blocking(1, 'city_required', 'city', 'Choose the event city.');
    }
    if (needsLocation &&
        (event.location.formattedAddress?.trim().isEmpty ?? true) &&
        (event.location.meetingPoint?.trim().isEmpty ?? true)) {
      blocking(
        1,
        'location_required',
        'location',
        'Add an address or a clear meeting point.',
      );
    }
    if (needsLocation &&
        (!_validLatitude(event.location.latitude) ||
            !_validLongitude(event.location.longitude))) {
      blocking(
        1,
        'location_coordinates_required',
        'locationCoordinates',
        'Place a valid map pin for the physical location.',
      );
    } else if (needsLocation && !event.location.pinConfirmed) {
      blocking(
        1,
        'location_pin_unconfirmed',
        'locationPin',
        'Confirm the physical location pin.',
      );
    }
    if (needsOnline && event.onlineAccessMode == null) {
      blocking(
        1,
        'online_access_required',
        'onlineAccessMode',
        'Choose how attendees receive online access.',
      );
    }
    if (event.onlineAccessMode == EventOnlineAccessMode.publicLink &&
        !_isSafeHttps(event.publicOnlineUrl)) {
      blocking(
        1,
        'public_online_url_invalid',
        'publicOnlineUrl',
        'Use a valid HTTPS online event URL.',
      );
    }
    if (needsOnline &&
        event.onlineAccessMode == EventOnlineAccessMode.externalRegistration &&
        event.registrationMode != EventRegistrationMode.external) {
      blocking(
        3,
        'online_access_registration_conflict',
        'registrationMode',
        'External online access requires external registration.',
      );
    }
    if (event.timezoneId.trim().isEmpty) {
      blocking(
        1,
        'timezone_required',
        'timezoneId',
        'Choose an IANA timezone.',
      );
    }
    if (event.durationMinutes <= 0) {
      blocking(
        1,
        'duration_invalid',
        'durationMinutes',
        'Duration must be positive.',
      );
    }
    if (!_isLocalDate(event.localStartDate)) {
      blocking(
        1,
        'local_start_date_invalid',
        'localStartDate',
        'Use a valid local date in YYYY-MM-DD format.',
      );
    }
    if (event.startMinute < 0 || event.startMinute >= 1440) {
      blocking(
        1,
        'start_minute_invalid',
        'startMinute',
        'Choose a valid local start time.',
      );
    }
    if (event.allDay && event.durationMinutes % 1440 != 0) {
      blocking(
        1,
        'all_day_duration_invalid',
        'durationMinutes',
        'All-day duration must be a whole number of days.',
      );
    }
    if (event.scheduleMode == EventScheduleMode.multiDate &&
        event.multiDateLocalDates.isEmpty) {
      blocking(
        1,
        'multi_dates_required',
        'multiDateLocalDates',
        'Add at least one date.',
      );
    }
    if (event.scheduleMode == EventScheduleMode.multiDate &&
        event.multiDateLocalDates.any((String value) => !_isLocalDate(value))) {
      blocking(
        1,
        'multi_date_invalid',
        'multiDateLocalDates',
        'Every date must use the YYYY-MM-DD format.',
      );
    }
    if (event.scheduleMode == EventScheduleMode.recurring) {
      final EventRecurrenceRuleDraft? rule = event.recurrence;
      if (rule == null || rule.interval <= 0) {
        blocking(
          1,
          'recurrence_invalid',
          'recurrence',
          'Configure a valid recurrence rule.',
        );
      } else {
        if (rule.frequency == EventRecurrenceFrequency.weekly &&
            rule.weekdays.any((int day) => day < 1 || day > 7)) {
          blocking(
            1,
            'recurrence_weekday_invalid',
            'weekdays',
            'Weekdays must be between 1 and 7.',
          );
        }
        if (rule.exceptionLocalDates.any(
          (String value) => !_isLocalDate(value),
        )) {
          blocking(
            1,
            'recurrence_exception_invalid',
            'exceptionLocalDates',
            'Every excluded date must use the YYYY-MM-DD format.',
          );
        }
        if (rule.endMode == EventRecurrenceEndMode.untilDate &&
            (rule.untilLocalDate?.isEmpty ?? true)) {
          blocking(
            1,
            'recurrence_until_required',
            'untilLocalDate',
            'Choose the final local date.',
          );
        } else if (rule.endMode == EventRecurrenceEndMode.untilDate &&
            !_isLocalDate(rule.untilLocalDate!)) {
          blocking(
            1,
            'recurrence_until_invalid',
            'untilLocalDate',
            'Use a valid final date in YYYY-MM-DD format.',
          );
        }
        if (rule.endMode == EventRecurrenceEndMode.occurrenceCount &&
            (rule.occurrenceCount ?? 0) <= 0) {
          blocking(
            1,
            'recurrence_count_required',
            'occurrenceCount',
            'Occurrence count must be positive.',
          );
        }
      }
    }
    if (event.occurrences.isEmpty) {
      blocking(
        1,
        'occurrences_required',
        'occurrences',
        'The schedule must produce at least one occurrence.',
      );
    } else if (!event.occurrences.any(
      (EventOccurrenceDraft value) =>
          value.endAtUtc.isAfter(nowUtc ?? DateTime.now().toUtc()),
    )) {
      blocking(
        1,
        'future_occurrence_required',
        'occurrences',
        'Add at least one future occurrence.',
      );
    }

    if (event.ageMin != null && event.ageMin! < 0) {
      blocking(
        2,
        'age_min_invalid',
        'ageMin',
        'Minimum age cannot be negative.',
      );
    }
    if (event.ageMax != null && event.ageMax! < 0) {
      blocking(
        2,
        'age_max_invalid',
        'ageMax',
        'Maximum age cannot be negative.',
      );
    }
    if (event.ageMin != null &&
        event.ageMax != null &&
        event.ageMin! > event.ageMax!) {
      blocking(
        2,
        'age_range_invalid',
        'ageMax',
        'Maximum age must not be below minimum age.',
      );
    }

    if (event.pricingMode == EventPricingMode.free) {
      if (event.price != null ||
          event.paymentCollectionMode != EventPaymentCollectionMode.none) {
        blocking(
          3,
          'free_price_conflict',
          'pricingMode',
          'Free events cannot collect a mandatory payment.',
        );
      }
    } else if (event.pricingMode == EventPricingMode.fixed) {
      if ((event.price?.amountMinor ?? 0) <= 0) {
        blocking(
          3,
          'fixed_price_required',
          'price',
          'Enter a positive fixed price.',
        );
      }
      if (event.paymentCollectionMode == EventPaymentCollectionMode.none ||
          event.paymentCollectionMode == EventPaymentCollectionMode.internal) {
        blocking(
          3,
          'payment_mode_unavailable',
          'paymentCollectionMode',
          'Choose onsite or external payment for this slice.',
        );
      }
    } else {
      blocking(
        3,
        'pricing_capability_unavailable',
        'pricingMode',
        'Ticket types and donations require a later capability slice.',
      );
    }
    if (event.capacityMode == EventCapacityMode.known &&
        (event.capacity ?? 0) <= 0) {
      blocking(
        3,
        'capacity_required',
        'capacity',
        'Enter a positive capacity.',
      );
    }
    if (event.capacityMode != EventCapacityMode.known &&
        event.capacity != null) {
      blocking(
        3,
        'capacity_mode_conflict',
        'capacity',
        'Only known capacity stores a numeric limit.',
      );
    }
    if (event.registrationMode == EventRegistrationMode.external &&
        !_isSafeHttps(event.externalBookingUrl)) {
      blocking(
        3,
        'external_booking_url_invalid',
        'externalBookingUrl',
        'Use a valid HTTPS registration URL.',
      );
    }
    if (event.registrationMode == EventRegistrationMode.internal) {
      blocking(
        3,
        'internal_booking_unavailable',
        'registrationMode',
        'Internal Booking is not enabled in this slice.',
      );
    }
    if (event.visibility == EventVisibility.private) {
      blocking(
        4,
        'private_access_unavailable',
        'visibility',
        'Private access requires a later protected-access slice.',
      );
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
