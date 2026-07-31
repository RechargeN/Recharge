enum PlaceKind { managedVenue, publicSpace, pointOfInterest }

enum PlaceRelationship { owner, staff, visitor, curator }

enum PublisherType { user, page }

enum PlaceLocationAccuracy { rooftop, interpolated, approximate, manual }

enum PlaceHoursMode { regular, alwaysOpen, seasonal, unknown }

enum PlaceOperationalStatus { operating, temporarilyClosed, permanentlyClosed }

enum PlaceEntryType { free, paid, mixed, notApplicable, unknown }

enum OpeningExceptionKind { closedAllDay, customHours }

enum PlaceSourceType { creatorSubmission, ownerSubmission, staffSubmission }

class PublisherRef {
  const PublisherRef({required this.type, required this.id});

  final PublisherType type;
  final String id;

  bool get isValid => id.trim().isNotEmpty;
}

class PlaceLocationDraft {
  const PlaceLocationDraft({
    required this.marketCityId,
    required this.countryCode,
    required this.city,
    required this.timezoneId,
    this.district,
    this.formattedAddress,
    this.locationLabel,
    this.entranceHint,
    this.latitude,
    this.longitude,
    this.accuracy = PlaceLocationAccuracy.approximate,
    this.pinConfirmed = false,
    this.geocodedAtUtc,
  });

  final String marketCityId;
  final String countryCode;
  final String city;
  final String timezoneId;
  final String? district;
  final String? formattedAddress;
  final String? locationLabel;
  final String? entranceHint;
  final double? latitude;
  final double? longitude;
  final PlaceLocationAccuracy accuracy;
  final bool pinConfirmed;
  final DateTime? geocodedAtUtc;

  PlaceLocationDraft copyWith({
    String? marketCityId,
    String? countryCode,
    String? city,
    String? timezoneId,
    String? district,
    bool clearDistrict = false,
    String? formattedAddress,
    bool clearFormattedAddress = false,
    String? locationLabel,
    bool clearLocationLabel = false,
    String? entranceHint,
    bool clearEntranceHint = false,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    PlaceLocationAccuracy? accuracy,
    bool? pinConfirmed,
    DateTime? geocodedAtUtc,
    bool clearGeocodedAtUtc = false,
  }) {
    return PlaceLocationDraft(
      marketCityId: marketCityId ?? this.marketCityId,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      timezoneId: timezoneId ?? this.timezoneId,
      district: clearDistrict ? null : (district ?? this.district),
      formattedAddress: clearFormattedAddress
          ? null
          : (formattedAddress ?? this.formattedAddress),
      locationLabel: clearLocationLabel
          ? null
          : (locationLabel ?? this.locationLabel),
      entranceHint: clearEntranceHint
          ? null
          : (entranceHint ?? this.entranceHint),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      accuracy: accuracy ?? this.accuracy,
      pinConfirmed: pinConfirmed ?? this.pinConfirmed,
      geocodedAtUtc: clearGeocodedAtUtc
          ? null
          : (geocodedAtUtc ?? this.geocodedAtUtc),
    );
  }
}

class LocalOpeningPeriod {
  const LocalOpeningPeriod({
    required this.id,
    required this.dayOfWeek,
    required this.openMinute,
    required this.closeMinute,
    required this.closesNextDay,
  });

  final String id;
  final int dayOfWeek;
  final int openMinute;
  final int closeMinute;
  final bool closesNextDay;

  int get durationMinutes => closesNextDay
      ? (1440 - openMinute) + closeMinute
      : closeMinute - openMinute;

  LocalOpeningPeriod copyWith({String? id}) => LocalOpeningPeriod(
    id: id ?? this.id,
    dayOfWeek: dayOfWeek,
    openMinute: openMinute,
    closeMinute: closeMinute,
    closesNextDay: closesNextDay,
  );
}

class OpeningException {
  const OpeningException({
    required this.id,
    required this.localDate,
    required this.kind,
    this.periods = const <LocalOpeningPeriod>[],
    this.publicNote,
  });

  final String id;
  final String localDate;
  final OpeningExceptionKind kind;
  final List<LocalOpeningPeriod> periods;
  final String? publicNote;

  OpeningException copyWith({String? id, List<LocalOpeningPeriod>? periods}) =>
      OpeningException(
        id: id ?? this.id,
        localDate: localDate,
        kind: kind,
        periods: periods ?? this.periods,
        publicNote: publicNote,
      );
}

class PlaceHoursDraft {
  const PlaceHoursDraft({
    this.mode,
    this.weeklyPeriods = const <LocalOpeningPeriod>[],
    this.exceptions = const <OpeningException>[],
  });

  final PlaceHoursMode? mode;
  final List<LocalOpeningPeriod> weeklyPeriods;
  final List<OpeningException> exceptions;

  PlaceHoursDraft copyWith({
    PlaceHoursMode? mode,
    bool clearMode = false,
    List<LocalOpeningPeriod>? weeklyPeriods,
    List<OpeningException>? exceptions,
  }) {
    return PlaceHoursDraft(
      mode: clearMode ? null : (mode ?? this.mode),
      weeklyPeriods: weeklyPeriods ?? this.weeklyPeriods,
      exceptions: exceptions ?? this.exceptions,
    );
  }

  PlaceHoursDraft replaceLocalIds(String Function() generateId) {
    return copyWith(
      weeklyPeriods: weeklyPeriods
          .map(
            (LocalOpeningPeriod period) => period.id.startsWith('loc_')
                ? period.copyWith(id: generateId())
                : period,
          )
          .toList(growable: false),
      exceptions: exceptions
          .map((OpeningException exception) {
            return exception.copyWith(
              id: exception.id.startsWith('loc_') ? generateId() : exception.id,
              periods: exception.periods
                  .map(
                    (LocalOpeningPeriod period) => period.id.startsWith('loc_')
                        ? period.copyWith(id: generateId())
                        : period,
                  )
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
  }
}

class PlaceOperationalStatusDraft {
  const PlaceOperationalStatusDraft({
    this.status = PlaceOperationalStatus.operating,
    this.closedFromLocalDate,
    this.closedUntilLocalDate,
    this.publicNote,
  });

  final PlaceOperationalStatus status;
  final String? closedFromLocalDate;
  final String? closedUntilLocalDate;
  final String? publicNote;
}

class PlaceVisitPlanningDraft {
  const PlaceVisitPlanningDraft({
    this.recommendedVisitMinutes,
    this.minimumVisitMinutes,
    this.allowsShortVisit = false,
    this.busyTimeNotes,
    this.weatherDependent = false,
    this.arrivalBufferMinutes = 0,
    this.exitBufferMinutes = 0,
  });

  final int? recommendedVisitMinutes;
  final int? minimumVisitMinutes;
  final bool allowsShortVisit;
  final String? busyTimeNotes;
  final bool weatherDependent;
  final int arrivalBufferMinutes;
  final int exitBufferMinutes;

  PlaceVisitPlanningDraft copyWith({
    int? recommendedVisitMinutes,
    bool clearRecommendedVisitMinutes = false,
    int? minimumVisitMinutes,
    bool clearMinimumVisitMinutes = false,
    bool? allowsShortVisit,
    String? busyTimeNotes,
    bool clearBusyTimeNotes = false,
    bool? weatherDependent,
    int? arrivalBufferMinutes,
    int? exitBufferMinutes,
  }) {
    return PlaceVisitPlanningDraft(
      recommendedVisitMinutes: clearRecommendedVisitMinutes
          ? null
          : (recommendedVisitMinutes ?? this.recommendedVisitMinutes),
      minimumVisitMinutes: clearMinimumVisitMinutes
          ? null
          : (minimumVisitMinutes ?? this.minimumVisitMinutes),
      allowsShortVisit: allowsShortVisit ?? this.allowsShortVisit,
      busyTimeNotes: clearBusyTimeNotes
          ? null
          : (busyTimeNotes ?? this.busyTimeNotes),
      weatherDependent: weatherDependent ?? this.weatherDependent,
      arrivalBufferMinutes: arrivalBufferMinutes ?? this.arrivalBufferMinutes,
      exitBufferMinutes: exitBufferMinutes ?? this.exitBufferMinutes,
    );
  }
}

class PlacePricingDraft {
  const PlacePricingDraft({
    required this.currencyCode,
    this.entryType,
    this.entryPriceFrom,
    this.entryPriceTo,
    this.typicalSpendFrom,
    this.typicalSpendTo,
    this.pricingNote,
    this.officialPricingUrl,
  });

  final PlaceEntryType? entryType;
  final double? entryPriceFrom;
  final double? entryPriceTo;
  final double? typicalSpendFrom;
  final double? typicalSpendTo;
  final String currencyCode;
  final String? pricingNote;
  final String? officialPricingUrl;

  PlacePricingDraft copyWith({
    PlaceEntryType? entryType,
    bool clearEntryType = false,
    double? entryPriceFrom,
    bool clearEntryPriceFrom = false,
    double? entryPriceTo,
    bool clearEntryPriceTo = false,
    double? typicalSpendFrom,
    bool clearTypicalSpendFrom = false,
    double? typicalSpendTo,
    bool clearTypicalSpendTo = false,
    String? currencyCode,
    String? pricingNote,
    bool clearPricingNote = false,
    String? officialPricingUrl,
    bool clearOfficialPricingUrl = false,
  }) {
    final PlaceEntryType? nextEntryType = clearEntryType
        ? null
        : (entryType ?? this.entryType);
    final bool clearsEntryPrices =
        nextEntryType == PlaceEntryType.free ||
        nextEntryType == PlaceEntryType.notApplicable ||
        nextEntryType == PlaceEntryType.unknown;
    return PlacePricingDraft(
      entryType: nextEntryType,
      entryPriceFrom: clearsEntryPrices || clearEntryPriceFrom
          ? null
          : (entryPriceFrom ?? this.entryPriceFrom),
      entryPriceTo: clearsEntryPrices || clearEntryPriceTo
          ? null
          : (entryPriceTo ?? this.entryPriceTo),
      typicalSpendFrom: clearTypicalSpendFrom
          ? null
          : (typicalSpendFrom ?? this.typicalSpendFrom),
      typicalSpendTo: clearTypicalSpendTo
          ? null
          : (typicalSpendTo ?? this.typicalSpendTo),
      currencyCode: currencyCode ?? this.currencyCode,
      pricingNote: clearPricingNote ? null : (pricingNote ?? this.pricingNote),
      officialPricingUrl: clearOfficialPricingUrl
          ? null
          : (officialPricingUrl ?? this.officialPricingUrl),
    );
  }
}

class PlaceContactsDraft {
  const PlaceContactsDraft({
    this.websiteUrl,
    this.phone,
    this.email,
    this.bookingUrl,
    this.socialUrls = const <String>[],
  });

  final String? websiteUrl;
  final String? phone;
  final String? email;
  final String? bookingUrl;
  final List<String> socialUrls;

  PlaceContactsDraft copyWith({
    String? websiteUrl,
    bool clearWebsiteUrl = false,
    String? phone,
    bool clearPhone = false,
    String? email,
    bool clearEmail = false,
    String? bookingUrl,
    bool clearBookingUrl = false,
    List<String>? socialUrls,
  }) {
    return PlaceContactsDraft(
      websiteUrl: clearWebsiteUrl ? null : (websiteUrl ?? this.websiteUrl),
      phone: clearPhone ? null : (phone ?? this.phone),
      email: clearEmail ? null : (email ?? this.email),
      bookingUrl: clearBookingUrl ? null : (bookingUrl ?? this.bookingUrl),
      socialUrls: socialUrls ?? this.socialUrls,
    );
  }
}

class PlaceDataProvenance {
  const PlaceDataProvenance({
    required this.sourceType,
    required this.submittedByUserId,
    required this.createdAtUtc,
    required this.lastConfirmedAtUtc,
    this.hoursConfirmedAtUtc,
    this.pricingConfirmedAtUtc,
    this.contactsConfirmedAtUtc,
  });

  final PlaceSourceType sourceType;
  final String submittedByUserId;
  final DateTime createdAtUtc;
  final DateTime lastConfirmedAtUtc;
  final DateTime? hoursConfirmedAtUtc;
  final DateTime? pricingConfirmedAtUtc;
  final DateTime? contactsConfirmedAtUtc;
}

class PlaceDraftData {
  const PlaceDraftData({
    required this.schemaVersion,
    required this.revision,
    required this.publisherRef,
    required this.contentLocale,
    required this.location,
    required this.hours,
    required this.operationalStatus,
    required this.visitPlanning,
    required this.pricing,
    required this.contacts,
    required this.provenance,
    this.placeKind,
    this.relationshipToPlace,
    this.languages = const <String>{},
    this.amenityIds = const <String>{},
    this.amenityUnknownIds = const <String>{},
    this.categoryConfirmed = false,
    this.acceptedWarningCodes = const <String>{},
    this.unknownFields = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final PlaceKind? placeKind;
  final PlaceRelationship? relationshipToPlace;
  final PublisherRef publisherRef;
  final String contentLocale;
  final Set<String> languages;
  final PlaceLocationDraft location;
  final PlaceHoursDraft hours;
  final PlaceOperationalStatusDraft operationalStatus;
  final PlaceVisitPlanningDraft visitPlanning;
  final Set<String> amenityIds;
  final Set<String> amenityUnknownIds;
  final PlacePricingDraft pricing;
  final PlaceContactsDraft contacts;
  final PlaceDataProvenance provenance;
  final bool categoryConfirmed;
  final Set<String> acceptedWarningCodes;
  final Map<String, Object?> unknownFields;

  factory PlaceDraftData.defaults({
    required String userId,
    required String marketCityId,
    required String countryCode,
    required String city,
    required String timezoneId,
    required String currencyCode,
    String contentLocale = 'en',
  }) {
    final DateTime now = DateTime.now().toUtc();
    return PlaceDraftData(
      schemaVersion: currentSchemaVersion,
      revision: 0,
      publisherRef: PublisherRef(type: PublisherType.user, id: userId),
      contentLocale: contentLocale,
      location: PlaceLocationDraft(
        marketCityId: marketCityId,
        countryCode: countryCode,
        city: city,
        timezoneId: timezoneId,
      ),
      hours: const PlaceHoursDraft(),
      operationalStatus: const PlaceOperationalStatusDraft(),
      visitPlanning: const PlaceVisitPlanningDraft(),
      pricing: PlacePricingDraft(currencyCode: currencyCode),
      contacts: const PlaceContactsDraft(),
      provenance: PlaceDataProvenance(
        sourceType: PlaceSourceType.creatorSubmission,
        submittedByUserId: userId,
        createdAtUtc: now,
        lastConfirmedAtUtc: now,
      ),
    );
  }

  PlaceDraftData copyWith({
    int? revision,
    PlaceKind? placeKind,
    bool clearPlaceKind = false,
    PlaceRelationship? relationshipToPlace,
    bool clearRelationshipToPlace = false,
    PublisherRef? publisherRef,
    String? contentLocale,
    Set<String>? languages,
    PlaceLocationDraft? location,
    PlaceHoursDraft? hours,
    PlaceOperationalStatusDraft? operationalStatus,
    PlaceVisitPlanningDraft? visitPlanning,
    Set<String>? amenityIds,
    Set<String>? amenityUnknownIds,
    PlacePricingDraft? pricing,
    PlaceContactsDraft? contacts,
    PlaceDataProvenance? provenance,
    bool? categoryConfirmed,
    Set<String>? acceptedWarningCodes,
    Map<String, Object?>? unknownFields,
  }) {
    return PlaceDraftData(
      schemaVersion: schemaVersion,
      revision: revision ?? this.revision,
      placeKind: clearPlaceKind ? null : (placeKind ?? this.placeKind),
      relationshipToPlace: clearRelationshipToPlace
          ? null
          : (relationshipToPlace ?? this.relationshipToPlace),
      publisherRef: publisherRef ?? this.publisherRef,
      contentLocale: contentLocale ?? this.contentLocale,
      languages: languages ?? this.languages,
      location: location ?? this.location,
      hours: hours ?? this.hours,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      visitPlanning: visitPlanning ?? this.visitPlanning,
      amenityIds: amenityIds ?? this.amenityIds,
      amenityUnknownIds: amenityUnknownIds ?? this.amenityUnknownIds,
      pricing: pricing ?? this.pricing,
      contacts: contacts ?? this.contacts,
      provenance: provenance ?? this.provenance,
      categoryConfirmed: categoryConfirmed ?? this.categoryConfirmed,
      acceptedWarningCodes: acceptedWarningCodes ?? this.acceptedWarningCodes,
      unknownFields: unknownFields ?? this.unknownFields,
    );
  }

  PlaceDraftData nextRevision() => copyWith(revision: revision + 1);

  PlaceDraftData replaceLocalIds(String Function() generateId) {
    return copyWith(hours: hours.replaceLocalIds(generateId));
  }
}
