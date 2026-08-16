import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';
import '../../../../shared/primitives/money/money_parse_result.dart';
import '../../../../shared/primitives/money/money_parser.dart';
import '../../domain/entities/create_availability.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/find_people_draft_data.dart';
import '../../domain/entities/place_draft_data.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/entities/scenario_draft_data.dart';
import '../../domain/usecases/classify_legacy_planning_draft_usecase.dart';
import 'find_people_draft_mapper.dart';
import 'event_draft_mapper.dart';
import 'place_draft_mapper.dart';
import 'route_draft_mapper.dart';
import 'scenario_draft_mapper.dart';

class CreateDraftModel {
  const CreateDraftModel({
    required this.schemaVersion,
    required this.id,
    this.basedOnPublishedVersionId,
    required this.objectType,
    required this.title,
    required this.eventType,
    required this.mainCategory,
    required this.subcategory,
    required this.tags,
    required this.shortDescription,
    required this.fullDescription,
    required this.sectionData,
    required this.startDateTimeUtcIso,
    required this.endDateTimeUtcIso,
    required this.durationMinutes,
    required this.timezone,
    required this.marketCityId,
    required this.availabilityKind,
    required this.scheduleSlots,
    required this.openingHours,
    required this.allowsPartialAttendance,
    required this.minimumVisitDurationMinutes,
    required this.bufferBeforeMinutes,
    required this.bufferAfterMinutes,
    required this.registrationDeadlineUtcIso,
    required this.format,
    required this.country,
    required this.city,
    required this.venueName,
    required this.addressLine1,
    required this.latitude,
    required this.longitude,
    required this.meetingPoint,
    required this.minParticipants,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.ageMin,
    required this.ageMax,
    required this.familyFriendly,
    required this.kidsAllowed,
    required this.petFriendly,
    required this.wheelchairAccessible,
    required this.isFree,
    required this.basePrice,
    required this.currency,
    required this.pricingModel,
    required this.registrationRequired,
    required this.approvalRequired,
    required this.bookingLink,
    required this.waitlistEnabled,
    required this.organizerId,
    required this.organizerName,
    required this.organizerProfileLink,
    required this.organizerPhone,
    required this.organizerEmail,
    required this.coverImage,
    required this.gallery,
    required this.draftStatus,
    required this.moderationStatus,
    required this.publishStatus,
    required this.visibility,
    required this.reportCount,
    required this.createdAtUtcIso,
    required this.updatedAtUtcIso,
    required this.publishedAtUtcIso,
  });

  final int schemaVersion;
  final String id;
  final String? basedOnPublishedVersionId;
  final String objectType;
  final String title;
  final String eventType;
  final String mainCategory;
  final String subcategory;
  final List<String> tags;
  final String shortDescription;
  final String fullDescription;
  final Map<String, dynamic> sectionData;
  final String? startDateTimeUtcIso;
  final String? endDateTimeUtcIso;
  final int? durationMinutes;
  final String timezone;
  final String marketCityId;
  final String availabilityKind;
  final List<Map<String, Object?>> scheduleSlots;
  final List<Map<String, Object?>> openingHours;
  final bool allowsPartialAttendance;
  final int? minimumVisitDurationMinutes;
  final int bufferBeforeMinutes;
  final int bufferAfterMinutes;
  final String? registrationDeadlineUtcIso;
  final String format;
  final String country;
  final String city;
  final String venueName;
  final String addressLine1;
  final double? latitude;
  final double? longitude;
  final String meetingPoint;
  final int? minParticipants;
  final int? maxParticipants;
  final int currentParticipants;
  final int? ageMin;
  final int? ageMax;
  final bool familyFriendly;
  final bool kidsAllowed;
  final bool petFriendly;
  final bool wheelchairAccessible;
  final bool isFree;
  final Money? basePrice;
  final String currency;
  final String pricingModel;
  final bool registrationRequired;
  final bool approvalRequired;
  final String bookingLink;
  final bool waitlistEnabled;
  final String organizerId;
  final String organizerName;
  final String organizerProfileLink;
  final String organizerPhone;
  final String organizerEmail;
  final String coverImage;
  final List<String> gallery;
  final String draftStatus;
  final String moderationStatus;
  final String publishStatus;
  final String visibility;
  final int reportCount;
  final String createdAtUtcIso;
  final String updatedAtUtcIso;
  final String? publishedAtUtcIso;

  int? get routeRevision {
    final Object? payload = sectionData['route_details'];
    if (payload is! Map) return null;
    final Object? value = payload['revision'];
    return value is num && value.isFinite ? value.toInt() : null;
  }

  int? get scenarioRevision {
    final Object? payload = sectionData['scenario'];
    if (payload is! Map) return null;
    final Object? value = payload['revision'];
    return value is num && value.isFinite ? value.toInt() : null;
  }

  factory CreateDraftModel.fromEntity(CreateDraftEntity entity) {
    final Map<String, dynamic> serializedSections = Map<String, dynamic>.from(
      entity.sectionData,
    );
    if (entity.eventData != null) {
      serializedSections['event_details'] = EventDraftMapper.toJson(
        entity.eventData!,
      );
    }
    if (entity.placeData != null) {
      serializedSections['place_details'] = PlaceDraftMapper.toJson(
        entity.placeData!,
      );
    }
    if (entity.findPeopleData != null) {
      serializedSections['find_people_details'] = FindPeopleDraftMapper.toJson(
        entity.findPeopleData!,
      );
    }
    if (entity.scenarioData != null) {
      serializedSections['scenario'] = ScenarioDraftMapper.toJson(
        entity.scenarioData!,
      );
    }
    if (entity.routeData != null) {
      serializedSections['route_details'] = RouteDraftMapper.toJson(
        entity.routeData!,
      );
    }
    return CreateDraftModel(
      schemaVersion: 9,
      id: entity.id,
      basedOnPublishedVersionId: entity.basedOnPublishedVersionId,
      objectType: entity.objectType.taxonomyId,
      title: entity.title,
      eventType: entity.eventType,
      mainCategory: entity.mainCategory,
      subcategory: entity.subcategory,
      tags: entity.tags,
      shortDescription: entity.shortDescription,
      fullDescription: entity.fullDescription,
      sectionData: serializedSections,
      startDateTimeUtcIso: entity.startDateTimeUtc?.toIso8601String(),
      endDateTimeUtcIso: entity.endDateTimeUtc?.toIso8601String(),
      durationMinutes: entity.durationMinutes,
      timezone: entity.timezone,
      marketCityId: entity.marketCityId,
      availabilityKind: entity.availabilityKind.name,
      scheduleSlots: entity.scheduleSlots
          .map((CreateTimeSlotDraft slot) => slot.toMap())
          .toList(growable: false),
      openingHours: entity.openingHours
          .map((CreateOpeningHoursDraftRule rule) => rule.toMap())
          .toList(growable: false),
      allowsPartialAttendance: entity.allowsPartialAttendance,
      minimumVisitDurationMinutes: entity.minimumVisitDurationMinutes,
      bufferBeforeMinutes: entity.bufferBeforeMinutes,
      bufferAfterMinutes: entity.bufferAfterMinutes,
      registrationDeadlineUtcIso: entity.registrationDeadlineUtc
          ?.toIso8601String(),
      format: entity.format,
      country: entity.country,
      city: entity.city,
      venueName: entity.venueName,
      addressLine1: entity.addressLine1,
      latitude: entity.latitude,
      longitude: entity.longitude,
      meetingPoint: entity.meetingPoint,
      minParticipants: entity.minParticipants,
      maxParticipants: entity.maxParticipants,
      currentParticipants: entity.currentParticipants,
      ageMin: entity.ageMin,
      ageMax: entity.ageMax,
      familyFriendly: entity.familyFriendly,
      kidsAllowed: entity.kidsAllowed,
      petFriendly: entity.petFriendly,
      wheelchairAccessible: entity.wheelchairAccessible,
      isFree: entity.isFree,
      basePrice: entity.basePrice,
      currency: entity.currency,
      pricingModel: entity.pricingModel,
      registrationRequired: entity.registrationRequired,
      approvalRequired: entity.approvalRequired,
      bookingLink: entity.bookingLink,
      waitlistEnabled: entity.waitlistEnabled,
      organizerId: entity.organizerId,
      organizerName: entity.organizerName,
      organizerProfileLink: entity.organizerProfileLink,
      organizerPhone: entity.organizerPhone,
      organizerEmail: entity.organizerEmail,
      coverImage: entity.media.coverImage,
      gallery: entity.media.gallery,
      draftStatus: entity.draftStatus.name,
      moderationStatus: entity.moderationStatus.name,
      publishStatus: entity.publishStatus.name,
      visibility: entity.visibility.name,
      reportCount: entity.reportCount,
      createdAtUtcIso: entity.createdAtUtc.toIso8601String(),
      updatedAtUtcIso: entity.updatedAtUtc.toIso8601String(),
      publishedAtUtcIso: entity.publishedAtUtc?.toIso8601String(),
    );
  }

  CreateDraftEntity toEntity() {
    final Map<String, Object?> migratedSectionData = _migratedSectionData(
      sectionData,
      legacyObjectType: objectType,
      contentGroupId: mainCategory,
    );
    final CreateObjectType parsedObjectType = _parseObjectType(
      objectType,
      migratedSectionData,
    );
    final EventDraftData eventDefaults =
        EventDraftData.defaults(
          marketCityId: marketCityId,
          countryCode: country,
          city: city,
          timezoneId: timezone,
          currencyCode: currency,
        ).copyWith(
          format: EventFormat.values.firstWhere(
            (EventFormat value) => value.name == format,
            orElse: () => EventFormat.offline,
          ),
          localStartDate:
              startDateTimeUtcIso != null && startDateTimeUtcIso!.length >= 10
              ? startDateTimeUtcIso!.substring(0, 10)
              : null,
          durationMinutes: durationMinutes ?? 120,
          pricingMode: isFree ? EventPricingMode.free : EventPricingMode.fixed,
          paymentCollectionMode: isFree
              ? EventPaymentCollectionMode.none
              : EventPaymentCollectionMode.onsite,
          price: isFree || basePrice == null
              ? null
              : EventMoneyDraft.fromMoney(basePrice!),
          capacityMode: maxParticipants == null
              ? EventCapacityMode.unknown
              : EventCapacityMode.known,
          capacity: maxParticipants,
          registrationMode: bookingLink.trim().isEmpty
              ? EventRegistrationMode.none
              : EventRegistrationMode.external,
          externalBookingUrl: bookingLink.trim().isEmpty ? null : bookingLink,
          mediaMetadata: const EventMediaMetadataDraft(),
        );
    final EventDraftData? eventData = parsedObjectType == CreateObjectType.event
        ? EventDraftMapper.fromJson(
            migratedSectionData['event_details'] is Map
                ? Map<String, Object?>.from(
                    migratedSectionData['event_details']! as Map,
                  )
                : const <String, Object?>{},
            defaults: eventDefaults,
          )
        : null;
    final PlaceDraftData? legacyPlaceDefaults =
        parsedObjectType == CreateObjectType.place
        ? PlaceDraftData.defaults(
            userId: organizerId,
            marketCityId: marketCityId,
            countryCode: country,
            city: city,
            timezoneId: timezone,
            currencyCode: currency,
          ).copyWith(
            location:
                PlaceDraftData.defaults(
                  userId: organizerId,
                  marketCityId: marketCityId,
                  countryCode: country,
                  city: city,
                  timezoneId: timezone,
                  currencyCode: currency,
                ).location.copyWith(
                  formattedAddress: addressLine1.isEmpty ? null : addressLine1,
                  latitude: latitude,
                  longitude: longitude,
                  accuracy: PlaceLocationAccuracy.manual,
                  pinConfirmed: latitude != null && longitude != null,
                ),
            pricing: PlacePricingDraft(
              currency: CurrencyCode.parse(currency),
              entryType: isFree ? PlaceEntryType.free : PlaceEntryType.paid,
              entryPriceFrom: isFree ? null : basePrice,
            ),
            contacts: PlaceContactsDraft(
              phone: organizerPhone.isEmpty ? null : organizerPhone,
              email: organizerEmail.isEmpty ? null : organizerEmail,
              bookingUrl: bookingLink.isEmpty ? null : bookingLink,
            ),
          )
        : null;
    final PlaceDraftData? placeData = parsedObjectType == CreateObjectType.place
        ? PlaceDraftMapper.fromJson(
            migratedSectionData['place_details'],
            defaults: legacyPlaceDefaults!,
          )
        : null;
    final FindPeopleDraftData? findPeopleData =
        parsedObjectType == CreateObjectType.findPeople
        ? FindPeopleDraftMapper.fromJson(
            migratedSectionData['find_people_details'],
            defaults: FindPeopleDraftData.defaults(
              userId: organizerId,
              currencyCode: currency,
            ),
          )
        : null;
    final Object? scenarioPayload =
        migratedSectionData['scenario'] ??
        migratedSectionData['scenario_details'];
    final ScenarioDraftData? scenarioData =
        parsedObjectType == CreateObjectType.scenario
        ? ScenarioDraftMapper.fromJson(
            scenarioPayload is Map
                ? Map<String, Object?>.from(scenarioPayload)
                : const <String, Object?>{},
            defaults: ScenarioDraftData.defaults(
              timezoneId: timezone,
              currencyCode: currency,
            ),
          )
        : null;
    final Object? routePayload = migratedSectionData['route_details'];
    RouteDraftData? routeData;
    final Map<String, Object?> runtimeSectionData = Map<String, Object?>.from(
      migratedSectionData,
    );
    if (parsedObjectType == CreateObjectType.route && routePayload is Map) {
      try {
        routeData = RouteDraftMapper.fromJson(
          Map<String, Object?>.from(routePayload),
        );
        runtimeSectionData.remove('route_details');
      } on UnsupportedRouteSchemaException {
        routeData = null;
      } on RouteDraftFormatException {
        routeData = null;
      }
    }
    return CreateDraftEntity(
      id: id,
      basedOnPublishedVersionId: basedOnPublishedVersionId,
      objectType: parsedObjectType,
      title: title,
      eventType: eventType,
      mainCategory: normalizeRechargeContentGroupId(mainCategory),
      subcategory: normalizeRechargeLegacySubcategoryId(subcategory),
      tags: tags,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      sectionData: runtimeSectionData,
      eventData: eventData,
      placeData: placeData,
      findPeopleData: findPeopleData,
      routeData: routeData,
      scenarioData: scenarioData,
      startDateTimeUtc: startDateTimeUtcIso == null
          ? null
          : DateTime.parse(startDateTimeUtcIso!).toUtc(),
      endDateTimeUtc: endDateTimeUtcIso == null
          ? null
          : DateTime.parse(endDateTimeUtcIso!).toUtc(),
      durationMinutes: durationMinutes,
      timezone: timezone,
      marketCityId: marketCityId,
      availabilityKind: CreateAvailabilityKind.values.firstWhere(
        (CreateAvailabilityKind value) => value.name == availabilityKind,
        orElse: () => CreateAvailabilityKind.none,
      ),
      scheduleSlots: scheduleSlots
          .map(CreateTimeSlotDraft.fromMap)
          .toList(growable: false),
      openingHours: openingHours
          .map(CreateOpeningHoursDraftRule.fromMap)
          .toList(growable: false),
      allowsPartialAttendance: allowsPartialAttendance,
      minimumVisitDurationMinutes: minimumVisitDurationMinutes,
      bufferBeforeMinutes: bufferBeforeMinutes,
      bufferAfterMinutes: bufferAfterMinutes,
      registrationDeadlineUtc: registrationDeadlineUtcIso == null
          ? null
          : DateTime.parse(registrationDeadlineUtcIso!).toUtc(),
      format: format,
      country: country,
      city: city,
      venueName: venueName,
      addressLine1: addressLine1,
      latitude: latitude,
      longitude: longitude,
      meetingPoint: meetingPoint,
      minParticipants: minParticipants,
      maxParticipants: maxParticipants,
      currentParticipants: currentParticipants,
      ageMin: ageMin,
      ageMax: ageMax,
      familyFriendly: familyFriendly,
      kidsAllowed: kidsAllowed,
      petFriendly: petFriendly,
      wheelchairAccessible: wheelchairAccessible,
      isFree: isFree,
      basePrice: basePrice,
      currency: currency,
      pricingModel: pricingModel,
      registrationRequired: registrationRequired,
      approvalRequired: approvalRequired,
      bookingLink: bookingLink,
      waitlistEnabled: waitlistEnabled,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerProfileLink: organizerProfileLink,
      organizerPhone: organizerPhone,
      organizerEmail: organizerEmail,
      media: MediaEntity(coverImage: coverImage, gallery: gallery),
      draftStatus: _parseDraftStatus(draftStatus),
      moderationStatus: _parseModerationStatus(moderationStatus),
      publishStatus: _parsePublishStatus(publishStatus),
      visibility: _parseVisibility(visibility),
      reportCount: reportCount,
      createdAtUtc: DateTime.parse(createdAtUtcIso).toUtc(),
      updatedAtUtc: DateTime.parse(updatedAtUtcIso).toUtc(),
      publishedAtUtc: publishedAtUtcIso == null
          ? null
          : DateTime.parse(publishedAtUtcIso!).toUtc(),
    );
  }

  factory CreateDraftModel.fromJson(
    Map<String, dynamic> json, {
    required String activeCurrency,
    String activeMarketCityId = '',
    String activeTimezone = 'UTC',
    String activeCountry = '',
    String activeCity = '',
  }) {
    final int sourceVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    final String country = json['country'] as String? ?? '';
    final String city = json['city'] as String? ?? '';
    String timezone = json['timezone'] as String? ?? 'UTC';
    String marketCityId = json['marketCityId'] as String? ?? '';
    if (sourceVersion < 2 && marketCityId.isEmpty) {
      final String normalizedCity = city.trim().toLowerCase();
      final String normalizedCountry = country.trim().toLowerCase();
      if (normalizedCity == 'rezekne' || normalizedCity == 'rēzekne') {
        marketCityId = 'rezekne';
      } else if (normalizedCity == activeCity.trim().toLowerCase()) {
        marketCityId = activeMarketCityId;
      } else if ((normalizedCountry == 'latvia' ||
              normalizedCountry == activeCountry.trim().toLowerCase()) &&
          normalizedCity.isEmpty &&
          timezone == 'Europe/Moscow') {
        marketCityId = activeMarketCityId;
      }
      if (marketCityId.isNotEmpty && timezone == 'Europe/Moscow') {
        timezone = marketCityId == 'rezekne' ? 'Europe/Riga' : activeTimezone;
      }
    }
    final String persistedCurrency = (json['currency'] as String? ?? '').trim();
    final String currency = CurrencyCode.parse(
      persistedCurrency.isEmpty ? activeCurrency : persistedCurrency,
    ).value;
    return CreateDraftModel(
      schemaVersion: 9,
      id: json['id'] as String,
      basedOnPublishedVersionId: json['basedOnPublishedVersionId'] as String?,
      objectType: json['objectType'] as String,
      title: json['title'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      mainCategory: json['mainCategory'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      tags: ((json['tags'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      shortDescription: json['shortDescription'] as String? ?? '',
      fullDescription: json['fullDescription'] as String? ?? '',
      sectionData: Map<String, dynamic>.from(
        json['sectionData'] as Map<dynamic, dynamic>? ??
            const <dynamic, dynamic>{},
      ),
      startDateTimeUtcIso: json['startDateTimeUtcIso'] as String?,
      endDateTimeUtcIso: json['endDateTimeUtcIso'] as String?,
      durationMinutes: json['durationMinutes'] as int?,
      timezone: timezone,
      marketCityId: marketCityId,
      availabilityKind:
          json['availabilityKind'] as String? ??
          CreateAvailabilityKind.none.name,
      scheduleSlots: _mapList(json['scheduleSlots']),
      openingHours: _mapList(json['openingHours']),
      allowsPartialAttendance:
          json['allowsPartialAttendance'] as bool? ?? false,
      minimumVisitDurationMinutes: (json['minimumVisitDurationMinutes'] as num?)
          ?.toInt(),
      bufferBeforeMinutes: (json['bufferBeforeMinutes'] as num?)?.toInt() ?? 0,
      bufferAfterMinutes: (json['bufferAfterMinutes'] as num?)?.toInt() ?? 0,
      registrationDeadlineUtcIso: json['registrationDeadlineUtcIso'] as String?,
      format: json['format'] as String? ?? 'offline',
      country: country,
      city: city,
      venueName: json['venueName'] as String? ?? '',
      addressLine1: json['addressLine1'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      meetingPoint: json['meetingPoint'] as String? ?? '',
      minParticipants: json['minParticipants'] as int?,
      maxParticipants: json['maxParticipants'] as int?,
      currentParticipants: json['currentParticipants'] as int? ?? 0,
      ageMin: json['ageMin'] as int?,
      ageMax: json['ageMax'] as int?,
      familyFriendly: json['familyFriendly'] as bool? ?? false,
      kidsAllowed: json['kidsAllowed'] as bool? ?? false,
      petFriendly: json['petFriendly'] as bool? ?? false,
      wheelchairAccessible: json['wheelchairAccessible'] as bool? ?? false,
      isFree: json['isFree'] as bool? ?? true,
      basePrice: _readMoney(
        canonicalMinorUnits: json['basePriceMinorUnits'],
        legacyAmount: json['basePrice'],
        currencyCode: currency,
      ),
      currency: currency,
      pricingModel: json['pricingModel'] as String? ?? 'fixed',
      registrationRequired: json['registrationRequired'] as bool? ?? true,
      approvalRequired: json['approvalRequired'] as bool? ?? false,
      bookingLink: json['bookingLink'] as String? ?? '',
      waitlistEnabled: json['waitlistEnabled'] as bool? ?? false,
      organizerId: json['organizerId'] as String? ?? '',
      organizerName: json['organizerName'] as String? ?? '',
      organizerProfileLink: json['organizerProfileLink'] as String? ?? '',
      organizerPhone: json['organizerPhone'] as String? ?? '',
      organizerEmail: json['organizerEmail'] as String? ?? '',
      coverImage: json['coverImage'] as String? ?? '',
      gallery: ((json['gallery'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      draftStatus: json['draftStatus'] as String? ?? 'draft',
      moderationStatus: json['moderationStatus'] as String? ?? 'none',
      publishStatus: json['publishStatus'] as String? ?? 'draft',
      visibility: json['visibility'] as String? ?? 'public',
      reportCount: json['reportCount'] as int? ?? 0,
      createdAtUtcIso:
          json['createdAtUtcIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      updatedAtUtcIso:
          json['updatedAtUtcIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      publishedAtUtcIso: json['publishedAtUtcIso'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': 9,
      'id': id,
      'basedOnPublishedVersionId': basedOnPublishedVersionId,
      'objectType': objectType,
      'title': title,
      'eventType': eventType,
      'mainCategory': mainCategory,
      'subcategory': subcategory,
      'tags': tags,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'sectionData': sectionData,
      'startDateTimeUtcIso': startDateTimeUtcIso,
      'endDateTimeUtcIso': endDateTimeUtcIso,
      'durationMinutes': durationMinutes,
      'timezone': timezone,
      'marketCityId': marketCityId,
      'availabilityKind': availabilityKind,
      'scheduleSlots': scheduleSlots,
      'openingHours': openingHours,
      'allowsPartialAttendance': allowsPartialAttendance,
      'minimumVisitDurationMinutes': minimumVisitDurationMinutes,
      'bufferBeforeMinutes': bufferBeforeMinutes,
      'bufferAfterMinutes': bufferAfterMinutes,
      'registrationDeadlineUtcIso': registrationDeadlineUtcIso,
      'format': format,
      'country': country,
      'city': city,
      'venueName': venueName,
      'addressLine1': addressLine1,
      'latitude': latitude,
      'longitude': longitude,
      'meetingPoint': meetingPoint,
      'minParticipants': minParticipants,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'familyFriendly': familyFriendly,
      'kidsAllowed': kidsAllowed,
      'petFriendly': petFriendly,
      'wheelchairAccessible': wheelchairAccessible,
      'isFree': isFree,
      'basePriceMinorUnits': basePrice?.minorUnits,
      'currency': currency,
      'pricingModel': pricingModel,
      'registrationRequired': registrationRequired,
      'approvalRequired': approvalRequired,
      'bookingLink': bookingLink,
      'waitlistEnabled': waitlistEnabled,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'organizerProfileLink': organizerProfileLink,
      'organizerPhone': organizerPhone,
      'organizerEmail': organizerEmail,
      'coverImage': coverImage,
      'gallery': gallery,
      'draftStatus': draftStatus,
      'moderationStatus': moderationStatus,
      'publishStatus': publishStatus,
      'visibility': visibility,
      'reportCount': reportCount,
      'createdAtUtcIso': createdAtUtcIso,
      'updatedAtUtcIso': updatedAtUtcIso,
      'publishedAtUtcIso': publishedAtUtcIso,
    };
  }

  static CreateObjectType _parseObjectType(
    String value,
    Map<String, Object?> sectionData,
  ) {
    final String normalized = value.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == 'quick_plan' || normalized == 'quickplan') {
      final LegacyPlanningClassification classification =
          const ClassifyLegacyPlanningDraftUseCase()(<String, Object?>{
            'objectType': value,
            'sectionData': sectionData,
          });
      if (classification.target == LegacyPlanningTarget.scenario) {
        return CreateObjectType.scenario;
      }
    }
    return createObjectTypeFromId(value);
  }

  static List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! List<dynamic>) return const <Map<String, Object?>>[];
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> map) {
          return map.map(
            (dynamic key, dynamic nested) =>
                MapEntry<String, Object?>(key as String, nested as Object?),
          );
        })
        .toList(growable: false);
  }

  static Map<String, Object?> _migratedSectionData(
    Map<String, dynamic> source, {
    required String legacyObjectType,
    required String contentGroupId,
  }) {
    final Map<String, Object?> result = <String, Object?>{...source};
    final String normalizedType = legacyObjectType.trim().toLowerCase();
    if (normalizedType == 'social_request' ||
        normalizedType == 'socialrequest') {
      final Object? legacyDetails = result.remove('social_request_details');
      if (legacyDetails != null && !result.containsKey('find_people_details')) {
        result['find_people_details'] = legacyDetails;
      }
      result['migration'] = <String, Object?>{
        ...?result['migration'] as Map<String, Object?>?,
        'source_type': 'social_request',
        'target_type': 'find_people',
      };
    }
    if (normalizedType != 'offer' ||
        !legacyOfferNeedsRentalReview(contentGroupId)) {
      return result;
    }
    final Map<String, Object?> migration = <String, Object?>{
      ...?result['migration'] as Map<String, Object?>?,
      'review_as_rental': true,
    };
    result['migration'] = migration;
    return result;
  }

  static DraftStatus _parseDraftStatus(String value) {
    return DraftStatus.values.firstWhere(
      (DraftStatus item) => item.name == value,
      orElse: () => DraftStatus.draft,
    );
  }

  static ModerationStatus _parseModerationStatus(String value) {
    return ModerationStatus.values.firstWhere(
      (ModerationStatus item) => item.name == value,
      orElse: () => ModerationStatus.none,
    );
  }

  static PublishStatus _parsePublishStatus(String value) {
    return PublishStatus.values.firstWhere(
      (PublishStatus item) => item.name == value,
      orElse: () => PublishStatus.draft,
    );
  }

  static VisibilityType _parseVisibility(String value) {
    return VisibilityType.values.firstWhere(
      (VisibilityType item) => item.name == value,
      orElse: () => VisibilityType.public,
    );
  }
}

Money? _readMoney({
  required Object? canonicalMinorUnits,
  required Object? legacyAmount,
  required String currencyCode,
}) {
  final CurrencyCode? currency = CurrencyCode.tryParse(currencyCode);
  final bool hasAmount = canonicalMinorUnits != null || legacyAmount != null;
  if (currency == null) {
    if (!hasAmount) return null;
    throw const FormatException('Create draft money currency is invalid.');
  }
  if (canonicalMinorUnits != null) {
    if (canonicalMinorUnits is! int) {
      throw const FormatException(
        'Create draft minor units must be an integer.',
      );
    }
    return Money(minorUnits: canonicalMinorUnits, currency: currency);
  }
  if (legacyAmount == null) return null;
  if (legacyAmount is! num) {
    throw const FormatException('Create draft legacy amount is invalid.');
  }
  final MoneyParseResult result = MoneyParser.parseLegacyNumber(
    legacyAmount,
    currency: currency,
  );
  if (result is MoneyParseSuccess) return result.money;
  throw const FormatException('Create draft amount is invalid or ambiguous.');
}
