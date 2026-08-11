import 'event_admission.dart';
import 'event_inventory.dart';
import 'event_classification.dart';
import 'publisher_ref.dart';
import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';

export 'event_admission.dart' show EventRegistrationMode;
export 'event_inventory.dart' show EventCapacityMode;

enum EventFormat { offline, online, hybrid }

enum EventOnlineAccessMode { publicLink, externalRegistration, internalBooking }

enum EventScheduleMode { oneTime, multiDate, recurring }

enum EventRecurrenceFrequency { daily, weekly, monthly, yearly }

enum EventRecurrenceEndMode { never, untilDate, occurrenceCount }

enum EventMonthlyDayPolicy { skipInvalidDate, useLastDay }

enum EventDstGapPolicy { shiftForward, reject }

enum EventDstOverlapPolicy { earlierOffset, laterOffset }

enum EventPricingMode { free, fixed, ticketTypes, donation }

enum EventPaymentCollectionMode { none, onsite, external, internal }

enum EventVisibility { public, unlisted, private }

class EventMoneyDraft {
  const EventMoneyDraft({
    required this.amountMinor,
    required this.currencyCode,
  });

  factory EventMoneyDraft.fromMoney(Money money) => EventMoneyDraft(
    amountMinor: money.minorUnits,
    currencyCode: money.currency.value,
  );

  final int amountMinor;
  final String currencyCode;

  Money get money => Money(
    minorUnits: amountMinor,
    currency: CurrencyCode.parse(currencyCode),
  );

  EventMoneyDraft copyWith({int? amountMinor, String? currencyCode}) =>
      EventMoneyDraft(
        amountMinor: amountMinor ?? this.amountMinor,
        currencyCode: currencyCode ?? this.currencyCode,
      );
}

class EventLocationDraft {
  const EventLocationDraft({
    required this.marketCityId,
    required this.countryCode,
    required this.city,
    this.venueName,
    this.formattedAddress,
    this.meetingPoint,
    this.latitude,
    this.longitude,
    this.pinConfirmed = false,
  });

  final String marketCityId;
  final String countryCode;
  final String city;
  final String? venueName;
  final String? formattedAddress;
  final String? meetingPoint;
  final double? latitude;
  final double? longitude;
  final bool pinConfirmed;

  EventLocationDraft copyWith({
    String? marketCityId,
    String? countryCode,
    String? city,
    String? venueName,
    bool clearVenueName = false,
    String? formattedAddress,
    bool clearFormattedAddress = false,
    String? meetingPoint,
    bool clearMeetingPoint = false,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    bool? pinConfirmed,
  }) => EventLocationDraft(
    marketCityId: marketCityId ?? this.marketCityId,
    countryCode: countryCode ?? this.countryCode,
    city: city ?? this.city,
    venueName: clearVenueName ? null : (venueName ?? this.venueName),
    formattedAddress: clearFormattedAddress
        ? null
        : (formattedAddress ?? this.formattedAddress),
    meetingPoint: clearMeetingPoint
        ? null
        : (meetingPoint ?? this.meetingPoint),
    latitude: clearLatitude ? null : (latitude ?? this.latitude),
    longitude: clearLongitude ? null : (longitude ?? this.longitude),
    pinConfirmed: pinConfirmed ?? this.pinConfirmed,
  );
}

class EventRecurrenceRuleDraft {
  const EventRecurrenceRuleDraft({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const <int>{},
    this.monthlyDayPolicy = EventMonthlyDayPolicy.skipInvalidDate,
    this.endMode = EventRecurrenceEndMode.never,
    this.untilLocalDate,
    this.occurrenceCount,
    this.exceptionLocalDates = const <String>{},
    this.dstGapPolicy = EventDstGapPolicy.shiftForward,
    this.dstOverlapPolicy = EventDstOverlapPolicy.earlierOffset,
  });

  final EventRecurrenceFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final EventMonthlyDayPolicy monthlyDayPolicy;
  final EventRecurrenceEndMode endMode;
  final String? untilLocalDate;
  final int? occurrenceCount;
  final Set<String> exceptionLocalDates;
  final EventDstGapPolicy dstGapPolicy;
  final EventDstOverlapPolicy dstOverlapPolicy;

  EventRecurrenceRuleDraft copyWith({
    EventRecurrenceFrequency? frequency,
    int? interval,
    Set<int>? weekdays,
    EventMonthlyDayPolicy? monthlyDayPolicy,
    EventRecurrenceEndMode? endMode,
    String? untilLocalDate,
    bool clearUntilLocalDate = false,
    int? occurrenceCount,
    bool clearOccurrenceCount = false,
    Set<String>? exceptionLocalDates,
    EventDstGapPolicy? dstGapPolicy,
    EventDstOverlapPolicy? dstOverlapPolicy,
  }) => EventRecurrenceRuleDraft(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    monthlyDayPolicy: monthlyDayPolicy ?? this.monthlyDayPolicy,
    endMode: endMode ?? this.endMode,
    untilLocalDate: clearUntilLocalDate
        ? null
        : (untilLocalDate ?? this.untilLocalDate),
    occurrenceCount: clearOccurrenceCount
        ? null
        : (occurrenceCount ?? this.occurrenceCount),
    exceptionLocalDates: exceptionLocalDates ?? this.exceptionLocalDates,
    dstGapPolicy: dstGapPolicy ?? this.dstGapPolicy,
    dstOverlapPolicy: dstOverlapPolicy ?? this.dstOverlapPolicy,
  );
}

class EventOccurrenceDraft {
  const EventOccurrenceDraft({
    required this.id,
    required this.localDate,
    required this.startAtUtc,
    required this.endAtUtc,
    this.shiftedForDst = false,
  });

  final String id;
  final String localDate;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final bool shiftedForDst;

  EventOccurrenceDraft copyWith({
    String? id,
    String? localDate,
    DateTime? startAtUtc,
    DateTime? endAtUtc,
    bool? shiftedForDst,
  }) => EventOccurrenceDraft(
    id: id ?? this.id,
    localDate: localDate ?? this.localDate,
    startAtUtc: startAtUtc ?? this.startAtUtc,
    endAtUtc: endAtUtc ?? this.endAtUtc,
    shiftedForDst: shiftedForDst ?? this.shiftedForDst,
  );
}

class EventOccurrenceOverrideDraft {
  const EventOccurrenceOverrideDraft({
    required this.occurrenceId,
    this.startAtUtc,
    this.endAtUtc,
    this.capacity,
    this.cancelled = false,
  });

  final String occurrenceId;
  final DateTime? startAtUtc;
  final DateTime? endAtUtc;
  final int? capacity;
  final bool cancelled;
}

class EventMediaMetadataDraft {
  const EventMediaMetadataDraft({
    this.coverAltText = '',
    this.rightsConfirmed = false,
    this.galleryAltText = const <String, String>{},
  });

  final String coverAltText;
  final bool rightsConfirmed;
  final Map<String, String> galleryAltText;

  EventMediaMetadataDraft copyWith({
    String? coverAltText,
    bool? rightsConfirmed,
    Map<String, String>? galleryAltText,
  }) => EventMediaMetadataDraft(
    coverAltText: coverAltText ?? this.coverAltText,
    rightsConfirmed: rightsConfirmed ?? this.rightsConfirmed,
    galleryAltText: galleryAltText ?? this.galleryAltText,
  );
}

class EventDraftData {
  const EventDraftData({
    required this.schemaVersion,
    required this.revision,
    required this.publisherRef,
    required this.classification,
    required this.admission,
    required this.inventory,
    required this.format,
    required this.onlineAccessMode,
    required this.publicOnlineUrl,
    required this.timezoneId,
    required this.scheduleMode,
    required this.allDay,
    required this.localStartDate,
    required this.startMinute,
    required this.durationMinutes,
    required this.multiDateLocalDates,
    required this.recurrence,
    required this.occurrences,
    required this.occurrenceOverrides,
    required this.location,
    required this.amenityIds,
    required this.requirements,
    required this.ageMin,
    required this.ageMax,
    required this.familyFriendly,
    required this.kidsAllowed,
    required this.petFriendly,
    required this.allowsPartialAttendance,
    required this.currencyCode,
    required this.pricingMode,
    required this.paymentCollectionMode,
    required this.price,
    required this.capacityMode,
    required this.capacity,
    required this.registrationMode,
    required this.externalBookingUrl,
    required this.mediaMetadata,
    required this.visibility,
    required this.acceptedWarningCodes,
    required this.unknownFields,
    required this.unsupportedFieldIds,
  });

  static const int classificationSchemaVersion = 2;
  static const int accessSchemaVersion = 3;
  static const int currentSchemaVersion = accessSchemaVersion;

  final int schemaVersion;
  final int revision;
  final PublisherRef? publisherRef;
  final EventClassificationDraft? classification;
  final EventAdmissionDraft? admission;
  final EventInventoryConfiguration? inventory;
  final EventFormat format;
  final EventOnlineAccessMode? onlineAccessMode;
  final String? publicOnlineUrl;
  final String timezoneId;
  final EventScheduleMode scheduleMode;
  final bool allDay;
  final String localStartDate;
  final int startMinute;
  final int durationMinutes;
  final List<String> multiDateLocalDates;
  final EventRecurrenceRuleDraft? recurrence;
  final List<EventOccurrenceDraft> occurrences;
  final Map<String, EventOccurrenceOverrideDraft> occurrenceOverrides;
  final EventLocationDraft location;
  final Set<String> amenityIds;
  final String requirements;
  final int? ageMin;
  final int? ageMax;
  final bool familyFriendly;
  final bool kidsAllowed;
  final bool petFriendly;
  final bool allowsPartialAttendance;
  final String currencyCode;
  final EventPricingMode pricingMode;
  final EventPaymentCollectionMode paymentCollectionMode;
  final EventMoneyDraft? price;
  final EventCapacityMode capacityMode;
  final int? capacity;
  final EventRegistrationMode registrationMode;
  final String? externalBookingUrl;
  final EventMediaMetadataDraft mediaMetadata;
  final EventVisibility visibility;
  final Set<String> acceptedWarningCodes;
  final Map<String, Object?> unknownFields;
  final Set<String> unsupportedFieldIds;

  factory EventDraftData.defaults({
    required String marketCityId,
    required String countryCode,
    required String city,
    required String timezoneId,
    required String currencyCode,
    PublisherRef? publisherRef,
  }) {
    final DateTime tomorrow = DateTime.now().toUtc().add(
      const Duration(days: 1),
    );
    final String localDate = _isoDate(tomorrow);
    return EventDraftData(
      schemaVersion: classificationSchemaVersion,
      revision: 0,
      publisherRef: publisherRef,
      classification: null,
      admission: null,
      inventory: null,
      format: EventFormat.offline,
      onlineAccessMode: null,
      publicOnlineUrl: null,
      timezoneId: timezoneId,
      scheduleMode: EventScheduleMode.oneTime,
      allDay: false,
      localStartDate: localDate,
      startMinute: 18 * 60,
      durationMinutes: 120,
      multiDateLocalDates: const <String>[],
      recurrence: null,
      occurrences: const <EventOccurrenceDraft>[],
      occurrenceOverrides: const <String, EventOccurrenceOverrideDraft>{},
      location: EventLocationDraft(
        marketCityId: marketCityId,
        countryCode: countryCode,
        city: city,
      ),
      amenityIds: const <String>{},
      requirements: '',
      ageMin: null,
      ageMax: null,
      familyFriendly: true,
      kidsAllowed: true,
      petFriendly: false,
      allowsPartialAttendance: false,
      currencyCode: currencyCode,
      pricingMode: EventPricingMode.free,
      paymentCollectionMode: EventPaymentCollectionMode.none,
      price: null,
      capacityMode: EventCapacityMode.unknown,
      capacity: null,
      registrationMode: EventRegistrationMode.none,
      externalBookingUrl: null,
      mediaMetadata: const EventMediaMetadataDraft(),
      visibility: EventVisibility.public,
      acceptedWarningCodes: const <String>{},
      unknownFields: const <String, Object?>{},
      unsupportedFieldIds: const <String>{},
    );
  }

  EventDraftData copyWith({
    int? schemaVersion,
    int? revision,
    PublisherRef? publisherRef,
    bool clearPublisherRef = false,
    EventClassificationDraft? classification,
    bool clearClassification = false,
    EventAdmissionDraft? admission,
    bool clearAdmission = false,
    EventInventoryConfiguration? inventory,
    bool clearInventory = false,
    EventFormat? format,
    EventOnlineAccessMode? onlineAccessMode,
    bool clearOnlineAccessMode = false,
    String? publicOnlineUrl,
    bool clearPublicOnlineUrl = false,
    String? timezoneId,
    EventScheduleMode? scheduleMode,
    bool? allDay,
    String? localStartDate,
    int? startMinute,
    int? durationMinutes,
    List<String>? multiDateLocalDates,
    EventRecurrenceRuleDraft? recurrence,
    bool clearRecurrence = false,
    List<EventOccurrenceDraft>? occurrences,
    Map<String, EventOccurrenceOverrideDraft>? occurrenceOverrides,
    EventLocationDraft? location,
    Set<String>? amenityIds,
    String? requirements,
    int? ageMin,
    bool clearAgeMin = false,
    int? ageMax,
    bool clearAgeMax = false,
    bool? familyFriendly,
    bool? kidsAllowed,
    bool? petFriendly,
    bool? allowsPartialAttendance,
    String? currencyCode,
    EventPricingMode? pricingMode,
    EventPaymentCollectionMode? paymentCollectionMode,
    EventMoneyDraft? price,
    bool clearPrice = false,
    EventCapacityMode? capacityMode,
    int? capacity,
    bool clearCapacity = false,
    EventRegistrationMode? registrationMode,
    String? externalBookingUrl,
    bool clearExternalBookingUrl = false,
    EventMediaMetadataDraft? mediaMetadata,
    EventVisibility? visibility,
    Set<String>? acceptedWarningCodes,
    Map<String, Object?>? unknownFields,
    Set<String>? unsupportedFieldIds,
  }) => EventDraftData(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    revision: revision ?? this.revision,
    publisherRef: clearPublisherRef
        ? null
        : (publisherRef ?? this.publisherRef),
    classification: clearClassification
        ? null
        : (classification ?? this.classification),
    admission: clearAdmission ? null : (admission ?? this.admission),
    inventory: clearInventory ? null : (inventory ?? this.inventory),
    format: format ?? this.format,
    onlineAccessMode: clearOnlineAccessMode
        ? null
        : (onlineAccessMode ?? this.onlineAccessMode),
    publicOnlineUrl: clearPublicOnlineUrl
        ? null
        : (publicOnlineUrl ?? this.publicOnlineUrl),
    timezoneId: timezoneId ?? this.timezoneId,
    scheduleMode: scheduleMode ?? this.scheduleMode,
    allDay: allDay ?? this.allDay,
    localStartDate: localStartDate ?? this.localStartDate,
    startMinute: startMinute ?? this.startMinute,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    multiDateLocalDates: multiDateLocalDates ?? this.multiDateLocalDates,
    recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
    occurrences: occurrences ?? this.occurrences,
    occurrenceOverrides: occurrenceOverrides ?? this.occurrenceOverrides,
    location: location ?? this.location,
    amenityIds: amenityIds ?? this.amenityIds,
    requirements: requirements ?? this.requirements,
    ageMin: clearAgeMin ? null : (ageMin ?? this.ageMin),
    ageMax: clearAgeMax ? null : (ageMax ?? this.ageMax),
    familyFriendly: familyFriendly ?? this.familyFriendly,
    kidsAllowed: kidsAllowed ?? this.kidsAllowed,
    petFriendly: petFriendly ?? this.petFriendly,
    allowsPartialAttendance:
        allowsPartialAttendance ?? this.allowsPartialAttendance,
    currencyCode: currencyCode ?? this.currencyCode,
    pricingMode: pricingMode ?? this.pricingMode,
    paymentCollectionMode: paymentCollectionMode ?? this.paymentCollectionMode,
    price: clearPrice ? null : (price ?? this.price),
    capacityMode: capacityMode ?? this.capacityMode,
    capacity: clearCapacity ? null : (capacity ?? this.capacity),
    registrationMode: registrationMode ?? this.registrationMode,
    externalBookingUrl: clearExternalBookingUrl
        ? null
        : (externalBookingUrl ?? this.externalBookingUrl),
    mediaMetadata: mediaMetadata ?? this.mediaMetadata,
    visibility: visibility ?? this.visibility,
    acceptedWarningCodes: acceptedWarningCodes ?? this.acceptedWarningCodes,
    unknownFields: unknownFields ?? this.unknownFields,
    unsupportedFieldIds: unsupportedFieldIds ?? this.unsupportedFieldIds,
  );

  EventDraftData nextRevision() => copyWith(revision: revision + 1);
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
