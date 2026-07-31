import '../../domain/entities/place_draft_data.dart';

class PlaceDraftMapper {
  const PlaceDraftMapper._();

  static PlaceDraftData fromJson(
    Object? raw, {
    required PlaceDraftData defaults,
  }) {
    if (raw is! Map) return defaults;
    final Map<String, Object?> json = raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final int version = _int(json['schemaVersion']) ?? 1;
    if (version > PlaceDraftData.currentSchemaVersion) {
      throw const FormatException('Unsupported Place draft schema version');
    }
    final Set<String> knownKeys = <String>{
      'schemaVersion',
      'revision',
      'placeKind',
      'relationshipToPlace',
      'publisherRef',
      'contentLocale',
      'languages',
      'location',
      'hours',
      'operationalStatus',
      'visitPlanning',
      'amenityIds',
      'amenityUnknownIds',
      'pricing',
      'contacts',
      'provenance',
      'categoryConfirmed',
      'acceptedWarningCodes',
    };
    final Map<String, Object?> unknownFields = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    return PlaceDraftData(
      schemaVersion: PlaceDraftData.currentSchemaVersion,
      revision: _int(json['revision']) ?? defaults.revision,
      placeKind: _enumValue(PlaceKind.values, json['placeKind']),
      relationshipToPlace: _enumValue(
        PlaceRelationship.values,
        json['relationshipToPlace'],
      ),
      publisherRef:
          _publisherRef(json['publisherRef']) ?? defaults.publisherRef,
      contentLocale: _string(json['contentLocale']) ?? defaults.contentLocale,
      languages: _stringSet(json['languages']),
      location: _location(json['location'], defaults.location),
      hours: _hours(json['hours']),
      operationalStatus: _operationalStatus(json['operationalStatus']),
      visitPlanning: _visitPlanning(json['visitPlanning']),
      amenityIds: _stringSet(json['amenityIds']),
      amenityUnknownIds: _stringSet(json['amenityUnknownIds']),
      pricing: _pricing(json['pricing'], defaults.pricing.currencyCode),
      contacts: _contacts(json['contacts']),
      provenance: _provenance(json['provenance'], defaults.provenance),
      categoryConfirmed: json['categoryConfirmed'] as bool? ?? false,
      acceptedWarningCodes: _stringSet(json['acceptedWarningCodes']),
      unknownFields: unknownFields,
    );
  }

  static Map<String, Object?> toJson(PlaceDraftData value) {
    return <String, Object?>{
      ...value.unknownFields,
      'schemaVersion': PlaceDraftData.currentSchemaVersion,
      'revision': value.revision,
      'placeKind': value.placeKind?.name,
      'relationshipToPlace': value.relationshipToPlace?.name,
      'publisherRef': <String, Object?>{
        'type': value.publisherRef.type.name,
        'id': value.publisherRef.id,
      },
      'contentLocale': value.contentLocale,
      'languages': value.languages.toList(growable: false),
      'location': <String, Object?>{
        'marketCityId': value.location.marketCityId,
        'countryCode': value.location.countryCode,
        'city': value.location.city,
        'district': value.location.district,
        'formattedAddress': value.location.formattedAddress,
        'locationLabel': value.location.locationLabel,
        'entranceHint': value.location.entranceHint,
        'latitude': value.location.latitude,
        'longitude': value.location.longitude,
        'timezoneId': value.location.timezoneId,
        'accuracy': value.location.accuracy.name,
        'pinConfirmed': value.location.pinConfirmed,
        'geocodedAtUtc': value.location.geocodedAtUtc?.toIso8601String(),
      },
      'hours': <String, Object?>{
        'mode': value.hours.mode?.name,
        'weeklyPeriods': value.hours.weeklyPeriods
            .map(_periodToJson)
            .toList(growable: false),
        'exceptions': value.hours.exceptions
            .map(
              (OpeningException exception) => <String, Object?>{
                'id': exception.id,
                'localDate': exception.localDate,
                'kind': exception.kind.name,
                'periods': exception.periods
                    .map(_periodToJson)
                    .toList(growable: false),
                'publicNote': exception.publicNote,
              },
            )
            .toList(growable: false),
      },
      'operationalStatus': <String, Object?>{
        'status': value.operationalStatus.status.name,
        'closedFromLocalDate': value.operationalStatus.closedFromLocalDate,
        'closedUntilLocalDate': value.operationalStatus.closedUntilLocalDate,
        'publicNote': value.operationalStatus.publicNote,
      },
      'visitPlanning': <String, Object?>{
        'recommendedVisitMinutes': value.visitPlanning.recommendedVisitMinutes,
        'minimumVisitMinutes': value.visitPlanning.minimumVisitMinutes,
        'allowsShortVisit': value.visitPlanning.allowsShortVisit,
        'busyTimeNotes': value.visitPlanning.busyTimeNotes,
        'weatherDependent': value.visitPlanning.weatherDependent,
        'arrivalBufferMinutes': value.visitPlanning.arrivalBufferMinutes,
        'exitBufferMinutes': value.visitPlanning.exitBufferMinutes,
      },
      'amenityIds': value.amenityIds.toList(growable: false),
      'amenityUnknownIds': value.amenityUnknownIds.toList(growable: false),
      'pricing': <String, Object?>{
        'entryType': value.pricing.entryType?.name,
        'entryPriceFrom': value.pricing.entryPriceFrom,
        'entryPriceTo': value.pricing.entryPriceTo,
        'typicalSpendFrom': value.pricing.typicalSpendFrom,
        'typicalSpendTo': value.pricing.typicalSpendTo,
        'currencyCode': value.pricing.currencyCode,
        'pricingNote': value.pricing.pricingNote,
        'officialPricingUrl': value.pricing.officialPricingUrl,
      },
      'contacts': <String, Object?>{
        'websiteUrl': value.contacts.websiteUrl,
        'phone': value.contacts.phone,
        'email': value.contacts.email,
        'bookingUrl': value.contacts.bookingUrl,
        'socialUrls': value.contacts.socialUrls,
      },
      'provenance': <String, Object?>{
        'sourceType': value.provenance.sourceType.name,
        'submittedByUserId': value.provenance.submittedByUserId,
        'createdAtUtc': value.provenance.createdAtUtc.toIso8601String(),
        'lastConfirmedAtUtc': value.provenance.lastConfirmedAtUtc
            .toIso8601String(),
        'hoursConfirmedAtUtc': value.provenance.hoursConfirmedAtUtc
            ?.toIso8601String(),
        'pricingConfirmedAtUtc': value.provenance.pricingConfirmedAtUtc
            ?.toIso8601String(),
        'contactsConfirmedAtUtc': value.provenance.contactsConfirmedAtUtc
            ?.toIso8601String(),
      },
      'categoryConfirmed': value.categoryConfirmed,
      'acceptedWarningCodes': value.acceptedWarningCodes.toList(
        growable: false,
      ),
    };
  }

  static Map<String, Object?> _periodToJson(LocalOpeningPeriod period) =>
      <String, Object?>{
        'id': period.id,
        'dayOfWeek': period.dayOfWeek,
        'openMinute': period.openMinute,
        'closeMinute': period.closeMinute,
        'closesNextDay': period.closesNextDay,
      };

  static PublisherRef? _publisherRef(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final PublisherType? type = _enumValue(PublisherType.values, json['type']);
    final String? id = _string(json['id']);
    return type == null || id == null ? null : PublisherRef(type: type, id: id);
  }

  static PlaceLocationDraft _location(
    Object? raw,
    PlaceLocationDraft defaults,
  ) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlaceLocationDraft(
      marketCityId: _string(json['marketCityId']) ?? defaults.marketCityId,
      countryCode: _string(json['countryCode']) ?? defaults.countryCode,
      city: _string(json['city']) ?? defaults.city,
      district: _string(json['district']),
      formattedAddress: _string(json['formattedAddress']),
      locationLabel: _string(json['locationLabel']),
      entranceHint: _string(json['entranceHint']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      timezoneId: _string(json['timezoneId']) ?? defaults.timezoneId,
      accuracy:
          _enumValue(PlaceLocationAccuracy.values, json['accuracy']) ??
          defaults.accuracy,
      pinConfirmed: json['pinConfirmed'] as bool? ?? false,
      geocodedAtUtc: _dateTime(json['geocodedAtUtc']),
    );
  }

  static PlaceHoursDraft _hours(Object? raw) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlaceHoursDraft(
      mode: _enumValue(PlaceHoursMode.values, json['mode']),
      weeklyPeriods: _list(
        json['weeklyPeriods'],
      ).map(_period).whereType<LocalOpeningPeriod>().toList(growable: false),
      exceptions: _list(
        json['exceptions'],
      ).map(_exception).whereType<OpeningException>().toList(growable: false),
    );
  }

  static LocalOpeningPeriod? _period(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final String? id = _string(json['id']);
    final int? day = _int(json['dayOfWeek']);
    final int? open = _int(json['openMinute']);
    final int? close = _int(json['closeMinute']);
    if (id == null || day == null || open == null || close == null) return null;
    return LocalOpeningPeriod(
      id: id,
      dayOfWeek: day,
      openMinute: open,
      closeMinute: close,
      closesNextDay: json['closesNextDay'] as bool? ?? false,
    );
  }

  static OpeningException? _exception(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final String? id = _string(json['id']);
    final String? localDate = _string(json['localDate']);
    final OpeningExceptionKind? kind = _enumValue(
      OpeningExceptionKind.values,
      json['kind'],
    );
    if (id == null || localDate == null || kind == null) return null;
    return OpeningException(
      id: id,
      localDate: localDate,
      kind: kind,
      periods: _list(
        json['periods'],
      ).map(_period).whereType<LocalOpeningPeriod>().toList(growable: false),
      publicNote: _string(json['publicNote']),
    );
  }

  static PlaceOperationalStatusDraft _operationalStatus(Object? raw) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlaceOperationalStatusDraft(
      status:
          _enumValue(PlaceOperationalStatus.values, json['status']) ??
          PlaceOperationalStatus.operating,
      closedFromLocalDate: _string(json['closedFromLocalDate']),
      closedUntilLocalDate: _string(json['closedUntilLocalDate']),
      publicNote: _string(json['publicNote']),
    );
  }

  static PlaceVisitPlanningDraft _visitPlanning(Object? raw) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlaceVisitPlanningDraft(
      recommendedVisitMinutes: _int(json['recommendedVisitMinutes']),
      minimumVisitMinutes: _int(json['minimumVisitMinutes']),
      allowsShortVisit: json['allowsShortVisit'] as bool? ?? false,
      busyTimeNotes: _string(json['busyTimeNotes']),
      weatherDependent: json['weatherDependent'] as bool? ?? false,
      arrivalBufferMinutes: _int(json['arrivalBufferMinutes']) ?? 0,
      exitBufferMinutes: _int(json['exitBufferMinutes']) ?? 0,
    );
  }

  static PlacePricingDraft _pricing(Object? raw, String defaultCurrency) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlacePricingDraft(
      entryType: _enumValue(PlaceEntryType.values, json['entryType']),
      entryPriceFrom: _double(json['entryPriceFrom']),
      entryPriceTo: _double(json['entryPriceTo']),
      typicalSpendFrom: _double(json['typicalSpendFrom']),
      typicalSpendTo: _double(json['typicalSpendTo']),
      currencyCode: _string(json['currencyCode']) ?? defaultCurrency,
      pricingNote: _string(json['pricingNote']),
      officialPricingUrl: _string(json['officialPricingUrl']),
    );
  }

  static PlaceContactsDraft _contacts(Object? raw) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlaceContactsDraft(
      websiteUrl: _string(json['websiteUrl']),
      phone: _string(json['phone']),
      email: _string(json['email']),
      bookingUrl: _string(json['bookingUrl']),
      socialUrls: _list(json['socialUrls'])
          .map((Object? value) => _string(value))
          .whereType<String>()
          .toList(growable: false),
    );
  }

  static PlaceDataProvenance _provenance(
    Object? raw,
    PlaceDataProvenance defaults,
  ) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return PlaceDataProvenance(
      sourceType:
          _enumValue(PlaceSourceType.values, json['sourceType']) ??
          defaults.sourceType,
      submittedByUserId:
          _string(json['submittedByUserId']) ?? defaults.submittedByUserId,
      createdAtUtc: _dateTime(json['createdAtUtc']) ?? defaults.createdAtUtc,
      lastConfirmedAtUtc:
          _dateTime(json['lastConfirmedAtUtc']) ?? defaults.lastConfirmedAtUtc,
      hoursConfirmedAtUtc: _dateTime(json['hoursConfirmedAtUtc']),
      pricingConfirmedAtUtc: _dateTime(json['pricingConfirmedAtUtc']),
      contactsConfirmedAtUtc: _dateTime(json['contactsConfirmedAtUtc']),
    );
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is! Map) return null;
    return raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  static List<Object?> _list(Object? raw) {
    return raw is List ? raw.cast<Object?>() : const <Object?>[];
  }

  static String? _string(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  static int? _int(Object? raw) => raw is num ? raw.toInt() : null;
  static double? _double(Object? raw) => raw is num ? raw.toDouble() : null;
  static DateTime? _dateTime(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  static T? _enumValue<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  static Set<String> _stringSet(Object? raw) =>
      _list(raw).map(_string).whereType<String>().toSet();
}
