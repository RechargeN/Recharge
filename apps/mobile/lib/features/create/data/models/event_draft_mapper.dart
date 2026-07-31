import '../../domain/entities/event_draft_data.dart';

class EventDraftMapper {
  const EventDraftMapper._();

  static const Set<String> _knownKeys = <String>{
    'schemaVersion',
    'revision',
    'format',
    'onlineAccessMode',
    'publicOnlineUrl',
    'timezoneId',
    'scheduleMode',
    'allDay',
    'localStartDate',
    'startMinute',
    'durationMinutes',
    'multiDateLocalDates',
    'recurrence',
    'occurrences',
    'occurrenceOverrides',
    'location',
    'amenityIds',
    'requirements',
    'ageMin',
    'ageMax',
    'familyFriendly',
    'kidsAllowed',
    'petFriendly',
    'allowsPartialAttendance',
    'currencyCode',
    'pricingMode',
    'paymentCollectionMode',
    'price',
    'capacityMode',
    'capacity',
    'registrationMode',
    'externalBookingUrl',
    'mediaMetadata',
    'visibility',
    'acceptedWarningCodes',
  };

  static EventDraftData fromJson(
    Map<String, Object?> json, {
    required EventDraftData defaults,
  }) {
    final int version = _int(json['schemaVersion']) ?? 1;
    if (version > EventDraftData.currentSchemaVersion) {
      return defaults.copyWith(unknownFields: Map<String, Object?>.from(json));
    }
    final Map<String, Object?> unknown = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    final Map<String, Object?> location = _map(json['location']);
    final Map<String, Object?> media = _map(json['mediaMetadata']);
    final List<EventOccurrenceDraft> occurrences = _list(json['occurrences'])
        .map(_map)
        .where((Map<String, Object?> value) => value.isNotEmpty)
        .map(_occurrence)
        .whereType<EventOccurrenceDraft>()
        .toList(growable: false);
    final Map<String, EventOccurrenceOverrideDraft> overrides =
        <String, EventOccurrenceOverrideDraft>{};
    for (final MapEntry<String, Object?> entry in _map(
      json['occurrenceOverrides'],
    ).entries) {
      final Map<String, Object?> value = _map(entry.value);
      overrides[entry.key] = EventOccurrenceOverrideDraft(
        occurrenceId: entry.key,
        startAtUtc: _dateTime(value['startAtUtc']),
        endAtUtc: _dateTime(value['endAtUtc']),
        capacity: _int(value['capacity']),
        cancelled: _bool(value['cancelled']) ?? false,
      );
    }
    return EventDraftData(
      schemaVersion: EventDraftData.currentSchemaVersion,
      revision: _int(json['revision']) ?? defaults.revision,
      format: _enumValue(EventFormat.values, json['format']) ?? defaults.format,
      onlineAccessMode: _enumValue(
        EventOnlineAccessMode.values,
        json['onlineAccessMode'],
      ),
      publicOnlineUrl: _nullableString(json['publicOnlineUrl']),
      timezoneId: _string(json['timezoneId'], defaults.timezoneId),
      scheduleMode:
          _enumValue(EventScheduleMode.values, json['scheduleMode']) ??
          defaults.scheduleMode,
      allDay: _bool(json['allDay']) ?? defaults.allDay,
      localStartDate: _string(json['localStartDate'], defaults.localStartDate),
      startMinute: _int(json['startMinute']) ?? defaults.startMinute,
      durationMinutes:
          _int(json['durationMinutes']) ?? defaults.durationMinutes,
      multiDateLocalDates: _stringList(json['multiDateLocalDates']),
      recurrence: _recurrence(json['recurrence']),
      occurrences: occurrences,
      occurrenceOverrides: overrides,
      location: EventLocationDraft(
        marketCityId: _string(
          location['marketCityId'],
          defaults.location.marketCityId,
        ),
        countryCode: _string(
          location['countryCode'],
          defaults.location.countryCode,
        ),
        city: _string(location['city'], defaults.location.city),
        venueName: _nullableString(location['venueName']),
        formattedAddress: _nullableString(location['formattedAddress']),
        meetingPoint: _nullableString(location['meetingPoint']),
        latitude: _double(location['latitude']),
        longitude: _double(location['longitude']),
        pinConfirmed: _bool(location['pinConfirmed']) ?? false,
      ),
      amenityIds: _stringList(json['amenityIds']).toSet(),
      requirements: _string(json['requirements'], ''),
      ageMin: _int(json['ageMin']),
      ageMax: _int(json['ageMax']),
      familyFriendly: _bool(json['familyFriendly']) ?? true,
      kidsAllowed: _bool(json['kidsAllowed']) ?? true,
      petFriendly: _bool(json['petFriendly']) ?? false,
      allowsPartialAttendance: _bool(json['allowsPartialAttendance']) ?? false,
      currencyCode: _string(json['currencyCode'], defaults.currencyCode),
      pricingMode:
          _enumValue(EventPricingMode.values, json['pricingMode']) ??
          defaults.pricingMode,
      paymentCollectionMode:
          _enumValue(
            EventPaymentCollectionMode.values,
            json['paymentCollectionMode'],
          ) ??
          defaults.paymentCollectionMode,
      price: _money(json['price'], defaults.currencyCode),
      capacityMode:
          _enumValue(EventCapacityMode.values, json['capacityMode']) ??
          defaults.capacityMode,
      capacity: _int(json['capacity']),
      registrationMode:
          _enumValue(EventRegistrationMode.values, json['registrationMode']) ??
          defaults.registrationMode,
      externalBookingUrl: _nullableString(json['externalBookingUrl']),
      mediaMetadata: EventMediaMetadataDraft(
        coverAltText: _string(media['coverAltText'], ''),
        rightsConfirmed: _bool(media['rightsConfirmed']) ?? false,
        galleryAltText: <String, String>{
          for (final MapEntry<String, Object?> entry in _map(
            media['galleryAltText'],
          ).entries)
            entry.key: entry.value?.toString() ?? '',
        },
      ),
      visibility:
          _enumValue(EventVisibility.values, json['visibility']) ??
          defaults.visibility,
      acceptedWarningCodes: _stringList(json['acceptedWarningCodes']).toSet(),
      unknownFields: unknown,
    );
  }

  static Map<String, Object?> toJson(EventDraftData value) => <String, Object?>{
    ...value.unknownFields,
    'schemaVersion': EventDraftData.currentSchemaVersion,
    'revision': value.revision,
    'format': value.format.name,
    'onlineAccessMode': value.onlineAccessMode?.name,
    'publicOnlineUrl': value.publicOnlineUrl,
    'timezoneId': value.timezoneId,
    'scheduleMode': value.scheduleMode.name,
    'allDay': value.allDay,
    'localStartDate': value.localStartDate,
    'startMinute': value.startMinute,
    'durationMinutes': value.durationMinutes,
    'multiDateLocalDates': value.multiDateLocalDates,
    'recurrence': _recurrenceJson(value.recurrence),
    'occurrences': value.occurrences
        .map(
          (EventOccurrenceDraft occurrence) => <String, Object?>{
            'id': occurrence.id,
            'localDate': occurrence.localDate,
            'startAtUtc': occurrence.startAtUtc.toIso8601String(),
            'endAtUtc': occurrence.endAtUtc.toIso8601String(),
            'shiftedForDst': occurrence.shiftedForDst,
          },
        )
        .toList(growable: false),
    'occurrenceOverrides': <String, Object?>{
      for (final MapEntry<String, EventOccurrenceOverrideDraft> entry
          in value.occurrenceOverrides.entries)
        entry.key: <String, Object?>{
          'startAtUtc': entry.value.startAtUtc?.toIso8601String(),
          'endAtUtc': entry.value.endAtUtc?.toIso8601String(),
          'capacity': entry.value.capacity,
          'cancelled': entry.value.cancelled,
        },
    },
    'location': <String, Object?>{
      'marketCityId': value.location.marketCityId,
      'countryCode': value.location.countryCode,
      'city': value.location.city,
      'venueName': value.location.venueName,
      'formattedAddress': value.location.formattedAddress,
      'meetingPoint': value.location.meetingPoint,
      'latitude': value.location.latitude,
      'longitude': value.location.longitude,
      'pinConfirmed': value.location.pinConfirmed,
    },
    'amenityIds': value.amenityIds.toList(growable: false),
    'requirements': value.requirements,
    'ageMin': value.ageMin,
    'ageMax': value.ageMax,
    'familyFriendly': value.familyFriendly,
    'kidsAllowed': value.kidsAllowed,
    'petFriendly': value.petFriendly,
    'allowsPartialAttendance': value.allowsPartialAttendance,
    'currencyCode': value.currencyCode,
    'pricingMode': value.pricingMode.name,
    'paymentCollectionMode': value.paymentCollectionMode.name,
    'price': value.price == null
        ? null
        : <String, Object?>{
            'amountMinor': value.price!.amountMinor,
            'currencyCode': value.price!.currencyCode,
          },
    'capacityMode': value.capacityMode.name,
    'capacity': value.capacity,
    'registrationMode': value.registrationMode.name,
    'externalBookingUrl': value.externalBookingUrl,
    'mediaMetadata': <String, Object?>{
      'coverAltText': value.mediaMetadata.coverAltText,
      'rightsConfirmed': value.mediaMetadata.rightsConfirmed,
      'galleryAltText': value.mediaMetadata.galleryAltText,
    },
    'visibility': value.visibility.name,
    'acceptedWarningCodes': value.acceptedWarningCodes.toList(growable: false),
  };

  static EventRecurrenceRuleDraft? _recurrence(Object? raw) {
    final Map<String, Object?> json = _map(raw);
    if (json.isEmpty) return null;
    final EventRecurrenceFrequency? frequency = _enumValue(
      EventRecurrenceFrequency.values,
      json['frequency'],
    );
    if (frequency == null) return null;
    return EventRecurrenceRuleDraft(
      frequency: frequency,
      interval: _int(json['interval']) ?? 1,
      weekdays: _stringList(
        json['weekdays'],
      ).map(int.tryParse).whereType<int>().toSet(),
      monthlyDayPolicy:
          _enumValue(EventMonthlyDayPolicy.values, json['monthlyDayPolicy']) ??
          EventMonthlyDayPolicy.skipInvalidDate,
      endMode:
          _enumValue(EventRecurrenceEndMode.values, json['endMode']) ??
          EventRecurrenceEndMode.never,
      untilLocalDate: _nullableString(json['untilLocalDate']),
      occurrenceCount: _int(json['occurrenceCount']),
      exceptionLocalDates: _stringList(json['exceptionLocalDates']).toSet(),
      dstGapPolicy:
          _enumValue(EventDstGapPolicy.values, json['dstGapPolicy']) ??
          EventDstGapPolicy.shiftForward,
      dstOverlapPolicy:
          _enumValue(EventDstOverlapPolicy.values, json['dstOverlapPolicy']) ??
          EventDstOverlapPolicy.earlierOffset,
    );
  }

  static Map<String, Object?>? _recurrenceJson(
    EventRecurrenceRuleDraft? value,
  ) => value == null
      ? null
      : <String, Object?>{
          'frequency': value.frequency.name,
          'interval': value.interval,
          'weekdays': value.weekdays.map((int value) => '$value').toList(),
          'monthlyDayPolicy': value.monthlyDayPolicy.name,
          'endMode': value.endMode.name,
          'untilLocalDate': value.untilLocalDate,
          'occurrenceCount': value.occurrenceCount,
          'exceptionLocalDates': value.exceptionLocalDates.toList(),
          'dstGapPolicy': value.dstGapPolicy.name,
          'dstOverlapPolicy': value.dstOverlapPolicy.name,
        };

  static EventOccurrenceDraft? _occurrence(Map<String, Object?> json) {
    final String id = _string(json['id'], '');
    final String localDate = _string(json['localDate'], '');
    final DateTime? start = _dateTime(json['startAtUtc']);
    final DateTime? end = _dateTime(json['endAtUtc']);
    if (id.isEmpty || localDate.isEmpty || start == null || end == null) {
      return null;
    }
    return EventOccurrenceDraft(
      id: id,
      localDate: localDate,
      startAtUtc: start,
      endAtUtc: end,
      shiftedForDst: _bool(json['shiftedForDst']) ?? false,
    );
  }

  static EventMoneyDraft? _money(Object? raw, String fallbackCurrency) {
    final Map<String, Object?> json = _map(raw);
    final int? amount = _int(json['amountMinor']);
    if (amount == null) return null;
    return EventMoneyDraft(
      amountMinor: amount,
      currencyCode: _string(json['currencyCode'], fallbackCurrency),
    );
  }

  static T? _enumValue<T extends Enum>(List<T> values, Object? raw) {
    final String name = raw?.toString() ?? '';
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static Map<String, Object?> _map(Object? raw) => raw is Map
      ? raw.map((Object? key, Object? value) => MapEntry('$key', value))
      : <String, Object?>{};

  static List<Object?> _list(Object? raw) =>
      raw is List ? raw.cast<Object?>() : const <Object?>[];

  static List<String> _stringList(Object? raw) =>
      _list(raw).map((Object? value) => '$value').toList(growable: false);

  static String _string(Object? raw, String fallback) {
    final String value = raw?.toString() ?? '';
    return value.isEmpty ? fallback : value;
  }

  static String? _nullableString(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static int? _int(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');

  static double? _double(Object? raw) =>
      raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

  static bool? _bool(Object? raw) => raw is bool
      ? raw
      : switch (raw?.toString().toLowerCase()) {
          'true' => true,
          'false' => false,
          _ => null,
        };

  static DateTime? _dateTime(Object? raw) =>
      DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
}
