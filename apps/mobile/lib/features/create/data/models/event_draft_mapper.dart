import '../../domain/entities/event_admission.dart';
import '../../domain/entities/event_inventory.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/event_classification.dart';
import '../../domain/entities/publisher_ref.dart';

class EventDraftMapper {
  const EventDraftMapper._();

  static const Set<String> _knownKeys = <String>{
    'schemaVersion',
    'revision',
    'publisherRef',
    'classification',
    'admission',
    'inventory',
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
  static const Set<String> _knownPublisherKeys = <String>{'type', 'id'};
  static const Set<String> _knownClassificationKeys = <String>{
    'archetype',
    'primaryParticipationMode',
    'additionalParticipationModes',
    'otherReason',
  };
  static const Set<String> _knownAdmissionKeys = <String>{
    'admissionMode',
    'registrationMode',
    'confirmationMode',
    'eligibilityRules',
    'guestPolicy',
    'onsiteAdmissionPolicy',
    'interestPolicy',
    'registrationWindow',
    'applicationWindow',
    'waitlistPolicy',
  };
  static const Set<String> _knownInventoryKeys = <String>{
    'authority',
    'primaryShape',
    'additionalShapes',
    'pools',
  };

  static EventDraftData fromJson(
    Map<String, Object?> json, {
    required EventDraftData defaults,
  }) {
    final int version = _int(json['schemaVersion']) ?? 1;
    if (version > EventDraftData.currentSchemaVersion) {
      return defaults.copyWith(
        schemaVersion: version,
        clearPublisherRef: true,
        clearClassification: true,
        clearAdmission: true,
        clearInventory: true,
        unknownFields: Map<String, Object?>.from(json),
        unsupportedFieldIds: const <String>{'eventData'},
      );
    }
    final Set<String> unsupportedFieldIds = <String>{};
    final Map<String, Object?> unknown = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    final Map<String, Object?> rawPublisher = _map(json['publisherRef']);
    final PublisherRef? publisher = version >= 2
        ? _publisherRef(rawPublisher)
        : null;
    if (version >= 2 && rawPublisher.isNotEmpty && publisher == null) {
      unknown['publisherRef'] = json['publisherRef'];
      unsupportedFieldIds.add('publisherRef');
    } else if (publisher != null) {
      final Map<String, Object?> nestedUnknown = <String, Object?>{
        for (final MapEntry<String, Object?> entry in rawPublisher.entries)
          if (!_knownPublisherKeys.contains(entry.key)) entry.key: entry.value,
      };
      if (nestedUnknown.isNotEmpty) unknown['publisherRef'] = nestedUnknown;
    }
    final Map<String, Object?> rawClassification = _map(json['classification']);
    final EventClassificationDraft? classification = version >= 2
        ? _classification(rawClassification)
        : null;
    if (version >= 2 &&
        rawClassification.isNotEmpty &&
        classification == null) {
      unknown['classification'] = json['classification'];
      unsupportedFieldIds.add('classification');
    } else if (classification != null) {
      final Map<String, Object?> nestedUnknown = <String, Object?>{
        for (final MapEntry<String, Object?> entry in rawClassification.entries)
          if (!_knownClassificationKeys.contains(entry.key))
            entry.key: entry.value,
      };
      if (nestedUnknown.isNotEmpty) unknown['classification'] = nestedUnknown;
    }
    final Map<String, Object?> location = _map(json['location']);
    final Map<String, Object?> rawAdmission = _map(json['admission']);
    final EventAdmissionDraft? admission = version >= 3
        ? _admission(rawAdmission)
        : null;
    if (rawAdmission.isNotEmpty) {
      unknown['admission'] = json['admission'];
      if (version < 3 ||
          admission == null ||
          _hasUnknownAdmission(rawAdmission)) {
        unsupportedFieldIds.add('admission');
      }
    }
    final Map<String, Object?> rawInventory = _map(json['inventory']);
    final EventInventoryConfiguration? inventory = version >= 3
        ? _inventory(rawInventory)
        : null;
    if (rawInventory.isNotEmpty) {
      unknown['inventory'] = json['inventory'];
      if (version < 3 ||
          inventory == null ||
          _hasUnknownInventory(rawInventory)) {
        unsupportedFieldIds.add('inventory');
      }
    }
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
      schemaVersion: version,
      revision: _int(json['revision']) ?? defaults.revision,
      publisherRef: publisher,
      classification: classification,
      admission: admission,
      inventory: inventory,
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
      unsupportedFieldIds: unsupportedFieldIds,
    );
  }

  static Map<String, Object?> toJson(EventDraftData value) {
    if (value.schemaVersion > EventDraftData.currentSchemaVersion) {
      return Map<String, Object?>.from(value.unknownFields);
    }
    return <String, Object?>{
      ...value.unknownFields,
      'schemaVersion': value.schemaVersion,
      'revision': value.revision,
      if (value.schemaVersion >= 2 && value.publisherRef != null)
        'publisherRef': <String, Object?>{
          ..._map(value.unknownFields['publisherRef']),
          'type': value.publisherRef!.type.wireName,
          'id': value.publisherRef!.id,
        },
      if (value.schemaVersion >= 2 && value.classification != null)
        'classification': _classificationJson(
          value.classification!,
          rawUnknown: _map(value.unknownFields['classification']),
        ),
      if (value.schemaVersion >= 3 &&
          value.admission != null &&
          !value.unsupportedFieldIds.contains('admission'))
        'admission': _admissionJson(
          value.admission!,
          rawUnknown: _map(value.unknownFields['admission']),
        ),
      if (value.schemaVersion >= 3 &&
          value.inventory != null &&
          !value.unsupportedFieldIds.contains('inventory'))
        'inventory': _inventoryJson(
          value.inventory!,
          rawUnknown: _map(value.unknownFields['inventory']),
        ),
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
      if (value.schemaVersion < 3 || value.admission == null)
        'registrationMode': value.registrationMode.name,
      'externalBookingUrl': value.externalBookingUrl,
      'mediaMetadata': <String, Object?>{
        'coverAltText': value.mediaMetadata.coverAltText,
        'rightsConfirmed': value.mediaMetadata.rightsConfirmed,
        'galleryAltText': value.mediaMetadata.galleryAltText,
      },
      'visibility': value.visibility.name,
      'acceptedWarningCodes': value.acceptedWarningCodes.toList(
        growable: false,
      ),
    };
  }

  static PublisherRef? _publisherRef(Map<String, Object?> json) {
    if (json.isEmpty) return null;
    final PublisherType? type = PublisherType.fromWireName(json['type']);
    final String id = _string(json['id'], '').trim();
    if (type == null || id.isEmpty) return null;
    return PublisherRef(type: type, id: id);
  }

  static EventClassificationDraft? _classification(Map<String, Object?> json) {
    if (json.isEmpty) return null;
    final Object? rawArchetype = json['archetype'];
    final EventArchetype? archetype = EventArchetype.fromWireName(rawArchetype);
    if (rawArchetype != null && archetype == null) return null;

    final Object? rawPrimary = json['primaryParticipationMode'];
    final ParticipationMode? primary = ParticipationMode.fromWireName(
      rawPrimary,
    );
    if (rawPrimary != null && primary == null) return null;

    final Set<ParticipationMode> additional = <ParticipationMode>{};
    for (final Object? raw in _list(json['additionalParticipationModes'])) {
      final ParticipationMode? mode = ParticipationMode.fromWireName(raw);
      if (mode == null) return null;
      if (!additional.add(mode)) return null;
    }
    return EventClassificationDraft(
      archetype: archetype,
      primaryParticipationMode: primary,
      additionalParticipationModes: additional,
      otherReason: _nullableString(json['otherReason']),
    );
  }

  static Map<String, Object?> _classificationJson(
    EventClassificationDraft value, {
    Map<String, Object?> rawUnknown = const <String, Object?>{},
  }) {
    final List<ParticipationMode> additional =
        value.additionalParticipationModes.toList(growable: false)..sort(
          (ParticipationMode left, ParticipationMode right) => ParticipationMode
              .values
              .indexOf(left)
              .compareTo(ParticipationMode.values.indexOf(right)),
        );
    return <String, Object?>{
      ...rawUnknown,
      'archetype': value.archetype?.wireName,
      'primaryParticipationMode': value.primaryParticipationMode?.wireName,
      'additionalParticipationModes': additional
          .map((ParticipationMode mode) => mode.wireName)
          .toList(growable: false),
      'otherReason': value.otherReason,
    };
  }

  static EventAdmissionDraft? _admission(Map<String, Object?> json) {
    if (json.isEmpty) return null;
    final AdmissionMode? admissionMode = _nullableEnumValue(
      AdmissionMode.values,
      json['admissionMode'],
    );
    final EventRegistrationMode? registrationMode = _nullableEnumValue(
      EventRegistrationMode.values,
      json['registrationMode'],
    );
    final ConfirmationMode? confirmationMode = _nullableEnumValue(
      ConfirmationMode.values,
      json['confirmationMode'],
    );
    if (_invalidEnum(json, 'admissionMode', admissionMode) ||
        _invalidEnum(json, 'registrationMode', registrationMode) ||
        _invalidEnum(json, 'confirmationMode', confirmationMode)) {
      return null;
    }
    final List<EligibilityRule> eligibility = <EligibilityRule>[];
    for (final Object? raw in _list(json['eligibilityRules'])) {
      final Map<String, Object?> item = _map(raw);
      final EligibilityRuleKind? kind = _enumValue(
        EligibilityRuleKind.values,
        item['kind'],
      );
      final String id = _string(item['id'], '');
      if (kind == null || id.isEmpty) return null;
      eligibility.add(
        EligibilityRule(
          id: id,
          kind: kind,
          publicExplanation: _nullableString(item['publicExplanation']),
          policyRef: _nullableString(item['policyRef']),
        ),
      );
    }
    final GuestPolicy? guest = _guestPolicy(json['guestPolicy']);
    if (_map(json['guestPolicy']).isNotEmpty && guest == null) return null;
    final OnsiteAdmissionPolicy? onsite = _onsitePolicy(
      json['onsiteAdmissionPolicy'],
    );
    if (_map(json['onsiteAdmissionPolicy']).isNotEmpty && onsite == null) {
      return null;
    }
    final InterestPolicy? interest = _interestPolicy(json['interestPolicy']);
    if (_map(json['interestPolicy']).isNotEmpty && interest == null) {
      return null;
    }
    final EventAccessWindow? registrationWindow = _accessWindow(
      json['registrationWindow'],
    );
    if (_map(json['registrationWindow']).isNotEmpty &&
        registrationWindow == null) {
      return null;
    }
    final EventAccessWindow? applicationWindow = _accessWindow(
      json['applicationWindow'],
    );
    if (_map(json['applicationWindow']).isNotEmpty &&
        applicationWindow == null) {
      return null;
    }
    final WaitlistConfiguration? waitlist = _waitlistPolicy(
      json['waitlistPolicy'],
    );
    if (_map(json['waitlistPolicy']).isNotEmpty && waitlist == null) {
      return null;
    }
    return EventAdmissionDraft(
      admissionMode: admissionMode,
      registrationMode: registrationMode,
      confirmationMode: confirmationMode,
      eligibilityRules: List<EligibilityRule>.unmodifiable(eligibility),
      guestPolicy: guest,
      onsiteAdmissionPolicy: onsite,
      interestPolicy: interest,
      registrationWindow: registrationWindow,
      applicationWindow: applicationWindow,
      waitlistPolicy: waitlist,
    );
  }

  static EventInventoryConfiguration? _inventory(Map<String, Object?> json) {
    if (json.isEmpty) return null;
    final InventoryAuthority? authority = _enumValue(
      InventoryAuthority.values,
      json['authority'],
    );
    if (authority == null) return null;
    final InventoryShape? primaryShape = _nullableEnumValue(
      InventoryShape.values,
      json['primaryShape'],
    );
    if (_invalidEnum(json, 'primaryShape', primaryShape)) return null;
    final Set<InventoryShape> additional = <InventoryShape>{};
    for (final Object? raw in _list(json['additionalShapes'])) {
      final InventoryShape? shape = _enumValue(InventoryShape.values, raw);
      if (shape == null || !additional.add(shape)) return null;
    }
    final List<EventInventoryPoolDraft> pools = <EventInventoryPoolDraft>[];
    for (final Object? raw in _list(json['pools'])) {
      final Map<String, Object?> item = _map(raw);
      final InventoryShape? shape = _enumValue(
        InventoryShape.values,
        item['shape'],
      );
      final InventoryChannel? channel = _enumValue(
        InventoryChannel.values,
        item['channel'],
      );
      final EventCapacityMode? capacityMode = _enumValue(
        EventCapacityMode.values,
        item['capacityMode'],
      );
      final String id = _string(item['id'], '');
      if (id.isEmpty ||
          shape == null ||
          channel == null ||
          capacityMode == null) {
        return null;
      }
      pools.add(
        EventInventoryPoolDraft(
          id: id,
          label: _string(item['label'], ''),
          shape: shape,
          channel: channel,
          capacityMode: capacityMode,
          capacity: _int(item['capacity']),
          roleIds: _stringList(item['roleIds']),
          zoneRef: _nullableString(item['zoneRef']),
          providerPoolRef: _nullableString(item['providerPoolRef']),
        ),
      );
    }
    return EventInventoryConfiguration(
      authority: authority,
      primaryShape: primaryShape,
      additionalShapes: additional,
      pools: List<EventInventoryPoolDraft>.unmodifiable(pools),
    );
  }

  static Map<String, Object?> _admissionJson(
    EventAdmissionDraft value, {
    Map<String, Object?> rawUnknown = const <String, Object?>{},
  }) => <String, Object?>{
    ...rawUnknown,
    'admissionMode': value.admissionMode?.name,
    'registrationMode': value.registrationMode?.name,
    'confirmationMode': value.confirmationMode?.name,
    'eligibilityRules': value.eligibilityRules
        .map(
          (rule) => <String, Object?>{
            'id': rule.id,
            'kind': rule.kind.name,
            'publicExplanation': rule.publicExplanation,
            'policyRef': rule.policyRef,
          },
        )
        .toList(growable: false),
    'guestPolicy': value.guestPolicy == null
        ? null
        : <String, Object?>{
            'mode': value.guestPolicy!.mode.name,
            'maxGuests': value.guestPolicy!.maxGuests,
            'countsAgainstCapacity': value.guestPolicy!.countsAgainstCapacity,
          },
    'onsiteAdmissionPolicy': value.onsiteAdmissionPolicy == null
        ? null
        : <String, Object?>{
            'allowed': value.onsiteAdmissionPolicy!.allowed,
            'salesAtDoor': value.onsiteAdmissionPolicy!.salesAtDoor,
            'registrationAtDoor':
                value.onsiteAdmissionPolicy!.registrationAtDoor,
            'subjectToAvailability':
                value.onsiteAdmissionPolicy!.subjectToAvailability,
          },
    'interestPolicy': value.interestPolicy == null
        ? null
        : <String, Object?>{
            'optionalRsvpEnabled': value.interestPolicy!.optionalRsvpEnabled,
            'reminderConsentRequired':
                value.interestPolicy!.reminderConsentRequired,
            'createsBooking': value.interestPolicy!.createsBooking,
            'reservesInventory': value.interestPolicy!.reservesInventory,
            'registrationAtDoorRequired':
                value.interestPolicy!.registrationAtDoorRequired,
          },
    'registrationWindow': _accessWindowJson(value.registrationWindow),
    'applicationWindow': _accessWindowJson(value.applicationWindow),
    'waitlistPolicy': value.waitlistPolicy == null
        ? null
        : <String, Object?>{
            'enabled': value.waitlistPolicy!.enabled,
            'promotionMode': value.waitlistPolicy!.promotionMode.name,
            'offerTtlMinutes': value.waitlistPolicy!.offerTtlMinutes,
            'paymentDeadlineMinutes':
                value.waitlistPolicy!.paymentDeadlineMinutes,
          },
  };

  static Map<String, Object?> _inventoryJson(
    EventInventoryConfiguration value, {
    Map<String, Object?> rawUnknown = const <String, Object?>{},
  }) {
    final List<InventoryShape> additional =
        value.additionalShapes.toList(growable: false)..sort(
          (left, right) => InventoryShape.values
              .indexOf(left)
              .compareTo(InventoryShape.values.indexOf(right)),
        );
    return <String, Object?>{
      ...rawUnknown,
      'authority': value.authority.name,
      'primaryShape': value.primaryShape?.name,
      'additionalShapes': additional.map((shape) => shape.name).toList(),
      'pools': value.pools
          .map(
            (pool) => <String, Object?>{
              'id': pool.id,
              'label': pool.label,
              'shape': pool.shape.name,
              'channel': pool.channel.name,
              'capacityMode': pool.capacityMode.name,
              'capacity': pool.capacity,
              'roleIds': pool.roleIds,
              'zoneRef': pool.zoneRef,
              'providerPoolRef': pool.providerPoolRef,
            },
          )
          .toList(growable: false),
    };
  }

  static GuestPolicy? _guestPolicy(Object? raw) {
    final Map<String, Object?> json = _map(raw);
    if (json.isEmpty) return null;
    final GuestPolicyMode? mode = _enumValue(
      GuestPolicyMode.values,
      json['mode'],
    );
    if (mode == null) return null;
    return GuestPolicy(
      mode: mode,
      maxGuests: _int(json['maxGuests']),
      countsAgainstCapacity: _bool(json['countsAgainstCapacity']) ?? true,
    );
  }

  static OnsiteAdmissionPolicy? _onsitePolicy(Object? raw) {
    final Map<String, Object?> json = _map(raw);
    if (json.isEmpty) return null;
    if (json['allowed'] is! bool) return null;
    return OnsiteAdmissionPolicy(
      allowed: _bool(json['allowed'])!,
      salesAtDoor: _bool(json['salesAtDoor']) ?? false,
      registrationAtDoor: _bool(json['registrationAtDoor']) ?? false,
      subjectToAvailability: _bool(json['subjectToAvailability']) ?? true,
    );
  }

  static InterestPolicy? _interestPolicy(Object? raw) {
    final Map<String, Object?> json = _map(raw);
    if (json.isEmpty || json['optionalRsvpEnabled'] is! bool) return null;
    return InterestPolicy(
      optionalRsvpEnabled: _bool(json['optionalRsvpEnabled'])!,
      reminderConsentRequired: _bool(json['reminderConsentRequired']) ?? true,
      createsBooking: _bool(json['createsBooking']) ?? false,
      reservesInventory: _bool(json['reservesInventory']) ?? false,
      registrationAtDoorRequired:
          _bool(json['registrationAtDoorRequired']) ?? false,
    );
  }

  static EventAccessWindow? _accessWindow(Object? raw) {
    final Map<String, Object?> json = _map(raw);
    if (json.isEmpty) return null;
    final EventAccessWindowKind? kind = _enumValue(
      EventAccessWindowKind.values,
      json['kind'],
    );
    if (kind == null) return null;
    return EventAccessWindow(
      kind: kind,
      opensAtUtc: _dateTime(json['opensAtUtc']),
      closesAtUtc: _dateTime(json['closesAtUtc']),
      opensBeforeOccurrenceMinutes: _int(json['opensBeforeOccurrenceMinutes']),
      closesBeforeOccurrenceMinutes: _int(
        json['closesBeforeOccurrenceMinutes'],
      ),
    );
  }

  static WaitlistConfiguration? _waitlistPolicy(Object? raw) {
    final Map<String, Object?> json = _map(raw);
    if (json.isEmpty || json['enabled'] is! bool) return null;
    final WaitlistPromotionMode? mode = _enumValue(
      WaitlistPromotionMode.values,
      json['promotionMode'],
    );
    if (mode == null) return null;
    return WaitlistConfiguration(
      enabled: _bool(json['enabled'])!,
      promotionMode: mode,
      offerTtlMinutes: _int(json['offerTtlMinutes']),
      paymentDeadlineMinutes: _int(json['paymentDeadlineMinutes']),
    );
  }

  static Map<String, Object?>? _accessWindowJson(EventAccessWindow? value) =>
      value == null
      ? null
      : <String, Object?>{
          'kind': value.kind.name,
          'opensAtUtc': value.opensAtUtc?.toIso8601String(),
          'closesAtUtc': value.closesAtUtc?.toIso8601String(),
          'opensBeforeOccurrenceMinutes': value.opensBeforeOccurrenceMinutes,
          'closesBeforeOccurrenceMinutes': value.closesBeforeOccurrenceMinutes,
        };

  static T? _nullableEnumValue<T extends Enum>(List<T> values, Object? raw) =>
      raw == null ? null : _enumValue(values, raw);

  static bool _invalidEnum<T>(
    Map<String, Object?> json,
    String key,
    T? parsed,
  ) => json[key] != null && parsed == null;

  static bool _hasUnknownAdmission(Map<String, Object?> json) {
    if (json.keys.any((key) => !_knownAdmissionKeys.contains(key))) return true;
    const Map<String, Set<String>> nestedKeys = <String, Set<String>>{
      'guestPolicy': <String>{'mode', 'maxGuests', 'countsAgainstCapacity'},
      'onsiteAdmissionPolicy': <String>{
        'allowed',
        'salesAtDoor',
        'registrationAtDoor',
        'subjectToAvailability',
      },
      'interestPolicy': <String>{
        'optionalRsvpEnabled',
        'reminderConsentRequired',
        'createsBooking',
        'reservesInventory',
        'registrationAtDoorRequired',
      },
      'registrationWindow': <String>{
        'kind',
        'opensAtUtc',
        'closesAtUtc',
        'opensBeforeOccurrenceMinutes',
        'closesBeforeOccurrenceMinutes',
      },
      'applicationWindow': <String>{
        'kind',
        'opensAtUtc',
        'closesAtUtc',
        'opensBeforeOccurrenceMinutes',
        'closesBeforeOccurrenceMinutes',
      },
      'waitlistPolicy': <String>{
        'enabled',
        'promotionMode',
        'offerTtlMinutes',
        'paymentDeadlineMinutes',
      },
    };
    for (final MapEntry<String, Set<String>> entry in nestedKeys.entries) {
      if (_map(json[entry.key]).keys.any((key) => !entry.value.contains(key))) {
        return true;
      }
    }
    const Set<String> eligibilityKeys = <String>{
      'id',
      'kind',
      'publicExplanation',
      'policyRef',
    };
    return _list(json['eligibilityRules'])
        .map(_map)
        .any((item) => item.keys.any((key) => !eligibilityKeys.contains(key)));
  }

  static bool _hasUnknownInventory(Map<String, Object?> json) {
    if (json.keys.any((key) => !_knownInventoryKeys.contains(key))) return true;
    const Set<String> poolKeys = <String>{
      'id',
      'label',
      'shape',
      'channel',
      'capacityMode',
      'capacity',
      'roleIds',
      'zoneRef',
      'providerPoolRef',
    };
    return _list(
      json['pools'],
    ).map(_map).any((item) => item.keys.any((key) => !poolKeys.contains(key)));
  }

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
