import '../../domain/entities/scenario_budget_draft.dart';
import '../../domain/entities/scenario_draft_data.dart';
import '../../domain/entities/scenario_item_draft.dart';
import '../../domain/entities/scenario_logistics_draft.dart';

class ScenarioDraftMapper {
  const ScenarioDraftMapper._();

  static const Set<String> _knownScheduleSnapshotKeys = <String>{
    'freshness',
    'providerCode',
    'providerDisplayName',
    'licenseName',
    'tripId',
    'routeId',
    'serviceId',
    'originStopId',
    'destinationStopId',
    'feedSha256',
    'serviceDate',
    'feedUpdatedAtUtc',
    'retrievedAtUtc',
    'carrierName',
    'serviceLabel',
    'originLabel',
    'destinationLabel',
    'plannedDeparture',
    'plannedArrival',
    'departureSecondsFromServiceDay',
    'arrivalSecondsFromServiceDay',
    'departureDayOffset',
    'arrivalDayOffset',
    'sourceUrl',
  };

  static const Set<String> _knownRootKeys = <String>{
    'schemaVersion',
    'updatesEnabled',
    'revision',
    'format',
    'dateMode',
    'defaultTimezoneId',
    'displayCurrencyCode',
    'party',
    'constraints',
    'days',
    'locations',
    'items',
    'unscheduledItemIds',
    'legs',
    'totals',
    'origin',
    'capabilities',
  };

  static const Map<String, ScenarioFormat> _formats = <String, ScenarioFormat>{
    'city': ScenarioFormat.city,
    'day': ScenarioFormat.day,
    'weekend': ScenarioFormat.weekend,
    'trip': ScenarioFormat.trip,
  };
  static const Map<String, ScenarioDateMode> _dateModes =
      <String, ScenarioDateMode>{
        'template': ScenarioDateMode.template,
        'dated': ScenarioDateMode.dated,
      };
  static const Map<String, ScenarioPartyKind> _partyKinds =
      <String, ScenarioPartyKind>{
        'solo': ScenarioPartyKind.solo,
        'couple': ScenarioPartyKind.couple,
        'friends': ScenarioPartyKind.friends,
        'family': ScenarioPartyKind.family,
        'group': ScenarioPartyKind.group,
        'mixed': ScenarioPartyKind.mixed,
      };
  static const Map<String, ScenarioBudgetBasis> _budgetBases =
      <String, ScenarioBudgetBasis>{
        'whole_group': ScenarioBudgetBasis.wholeGroup,
        'per_person': ScenarioBudgetBasis.perPerson,
      };
  static const Map<String, ScenarioPace> _paces = <String, ScenarioPace>{
    'relaxed': ScenarioPace.relaxed,
    'balanced': ScenarioPace.balanced,
    'intensive': ScenarioPace.intensive,
  };
  static const Map<String, ScenarioOriginType> _originTypes =
      <String, ScenarioOriginType>{
        'public_scenario': ScenarioOriginType.publicScenario,
        'quick_plan_conversion': ScenarioOriginType.quickPlanConversion,
        'collection': ScenarioOriginType.collection,
        'details': ScenarioOriginType.details,
        'search': ScenarioOriginType.search,
        'smart_search': ScenarioOriginType.smartSearch,
        'map_selection': ScenarioOriginType.mapSelection,
        'manual': ScenarioOriginType.manual,
      };
  static const Map<String, ScenarioItemKind> _itemKinds =
      <String, ScenarioItemKind>{
        'visit': ScenarioItemKind.visit,
        'event': ScenarioItemKind.event,
        'activity': ScenarioItemKind.activity,
        'route': ScenarioItemKind.route,
        'bookable_session': ScenarioItemKind.bookableSession,
        'stay': ScenarioItemKind.stay,
        'planned_transport': ScenarioItemKind.plannedTransport,
        'time_block': ScenarioItemKind.timeBlock,
      };
  static const Map<String, ScenarioItemRole> _itemRoles =
      <String, ScenarioItemRole>{
        'mandatory': ScenarioItemRole.mandatory,
        'optional': ScenarioItemRole.optional,
        'alternative': ScenarioItemRole.alternative,
      };
  static const Map<String, ScenarioSourceStatus> _sourceStatuses =
      <String, ScenarioSourceStatus>{
        'ready': ScenarioSourceStatus.ready,
        'stale': ScenarioSourceStatus.stale,
        'unresolved': ScenarioSourceStatus.unresolved,
        'unavailable': ScenarioSourceStatus.unavailable,
      };
  static const Map<String, ScenarioCatalogObjectType> _catalogTypes =
      <String, ScenarioCatalogObjectType>{
        'event': ScenarioCatalogObjectType.event,
        'place': ScenarioCatalogObjectType.place,
        'activity': ScenarioCatalogObjectType.activity,
        'route': ScenarioCatalogObjectType.route,
        'bookable_session': ScenarioCatalogObjectType.bookableSession,
      };
  static const Map<String, ScenarioLocationDisclosure> _disclosures =
      <String, ScenarioLocationDisclosure>{
        'private': ScenarioLocationDisclosure.private,
        'approximate': ScenarioLocationDisclosure.approximate,
        'public': ScenarioLocationDisclosure.public,
      };
  static const Map<String, ScenarioTimeMode> _timeModes =
      <String, ScenarioTimeMode>{
        'fixed': ScenarioTimeMode.fixed,
        'window': ScenarioTimeMode.window,
        'flexible': ScenarioTimeMode.flexible,
      };
  static const Map<String, ScenarioTravelMode> _travelModes =
      <String, ScenarioTravelMode>{
        'walking': ScenarioTravelMode.walking,
        'bicycle': ScenarioTravelMode.bicycle,
        'car': ScenarioTravelMode.car,
        'taxi': ScenarioTravelMode.taxi,
        'transit': ScenarioTravelMode.transit,
        'other': ScenarioTravelMode.other,
      };
  static const Map<String, ScenarioPlannedTransportKind>
  _plannedTransportKinds = <String, ScenarioPlannedTransportKind>{
    'bus': ScenarioPlannedTransportKind.bus,
    'train': ScenarioPlannedTransportKind.train,
    'tram': ScenarioPlannedTransportKind.tram,
    'trolleybus': ScenarioPlannedTransportKind.trolleybus,
    'ferry': ScenarioPlannedTransportKind.ferry,
    'flight': ScenarioPlannedTransportKind.flight,
    'other': ScenarioPlannedTransportKind.other,
  };
  static const Map<String, ScenarioScheduleFreshness> _scheduleFreshness =
      <String, ScenarioScheduleFreshness>{
        'current': ScenarioScheduleFreshness.current,
        'stale': ScenarioScheduleFreshness.stale,
        'unknown': ScenarioScheduleFreshness.unknown,
        'not_applicable': ScenarioScheduleFreshness.notApplicable,
      };
  static const Map<String, ScenarioLegSource> _legSources =
      <String, ScenarioLegSource>{
        'schedule': ScenarioLegSource.schedule,
        'provider': ScenarioLegSource.provider,
        'manual': ScenarioLegSource.manual,
        'estimate': ScenarioLegSource.estimate,
        'unknown': ScenarioLegSource.unknown,
      };
  static const Map<String, ScenarioLegStatus> _legStatuses =
      <String, ScenarioLegStatus>{
        'ready': ScenarioLegStatus.ready,
        'loading': ScenarioLegStatus.loading,
        'stale': ScenarioLegStatus.stale,
        'failed': ScenarioLegStatus.failed,
        'unavailable': ScenarioLegStatus.unavailable,
      };
  static const Map<String, ScenarioPriceKnowledge> _priceKnowledge =
      <String, ScenarioPriceKnowledge>{
        'free': ScenarioPriceKnowledge.free,
        'known': ScenarioPriceKnowledge.known,
        'estimated': ScenarioPriceKnowledge.estimated,
        'unknown': ScenarioPriceKnowledge.unknown,
      };
  static const Map<String, ScenarioPriceSource> _priceSources =
      <String, ScenarioPriceSource>{
        'catalog': ScenarioPriceSource.catalog,
        'user_override': ScenarioPriceSource.userOverride,
        'provider': ScenarioPriceSource.provider,
        'manual': ScenarioPriceSource.manual,
      };
  static const Map<String, ScenarioPriceBasis> _priceBases =
      <String, ScenarioPriceBasis>{
        'per_person': ScenarioPriceBasis.perPerson,
        'per_adult': ScenarioPriceBasis.perAdult,
        'per_child': ScenarioPriceBasis.perChild,
        'per_group': ScenarioPriceBasis.perGroup,
        'per_night': ScenarioPriceBasis.perNight,
        'per_booking': ScenarioPriceBasis.perBooking,
      };

  static ScenarioDraftData fromJson(
    Map<String, Object?> json, {
    ScenarioDraftData? defaults,
  }) {
    final ScenarioDraftData fallback = defaults ?? ScenarioDraftData.defaults();
    final int sourceVersion = _int(json['schemaVersion']) ?? 1;
    if (sourceVersion > ScenarioDraftData.currentSchemaVersion) {
      return fallback.copyWith(unknownFields: Map<String, Object?>.from(json));
    }
    final Map<String, Object?> unknown = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!_knownRootKeys.contains(entry.key)) entry.key: entry.value,
    };
    return ScenarioDraftData(
      schemaVersion: ScenarioDraftData.currentSchemaVersion,
      revision: _int(json['revision']) ?? fallback.revision,
      format: _enum(_formats, json['format']) ?? fallback.format,
      dateMode: _enum(_dateModes, json['dateMode']) ?? fallback.dateMode,
      defaultTimezoneId: _string(
        json['defaultTimezoneId'],
        fallback.defaultTimezoneId,
      ),
      displayCurrencyCode: _string(
        json['displayCurrencyCode'],
        fallback.displayCurrencyCode,
      ).toUpperCase(),
      party: _party(json['party'], fallback.party),
      constraints: _constraints(json['constraints'], fallback.constraints),
      days: _list(json['days']).map(_day).toList(growable: false),
      locations: _list(
        json['locations'],
      ).map(_location).toList(growable: false),
      items: _list(json['items']).map(_item).toList(growable: false),
      unscheduledItemIds: _stringList(json['unscheduledItemIds']),
      legs: _list(json['legs']).map(_leg).toList(growable: false),
      totals: _totals(json['totals']),
      origin: _origin(json['origin']),
      capabilities: _capabilities(json['capabilities']),
      unknownFields: unknown,
      updatesEnabled: _bool(json['updatesEnabled']) ?? fallback.updatesEnabled,
    );
  }

  static Map<String, Object?> toJson(ScenarioDraftData value) {
    return <String, Object?>{
      ...value.unknownFields,
      'schemaVersion': ScenarioDraftData.currentSchemaVersion,
      'updatesEnabled': value.updatesEnabled,
      'revision': value.revision,
      'format': _id(_formats, value.format),
      'dateMode': _id(_dateModes, value.dateMode),
      'defaultTimezoneId': value.defaultTimezoneId,
      'displayCurrencyCode': value.displayCurrencyCode,
      'party': _partyToJson(value.party),
      'constraints': _constraintsToJson(value.constraints),
      'days': value.days.map(_dayToJson).toList(growable: false),
      'locations': value.locations.map(_locationToJson).toList(growable: false),
      'items': value.items.map(_itemToJson).toList(growable: false),
      'unscheduledItemIds': value.unscheduledItemIds,
      'legs': value.legs.map(_legToJson).toList(growable: false),
      'totals': _totalsToJson(value.totals),
      'origin': value.origin == null ? null : _originToJson(value.origin!),
      'capabilities': _capabilitiesToJson(value.capabilities),
    };
  }

  static ScenarioPartyDraft _party(Object? value, ScenarioPartyDraft fallback) {
    final Map<String, Object?> json = _map(value);
    return ScenarioPartyDraft(
      peopleCount: _int(json['peopleCount']) ?? fallback.peopleCount,
      kind: _enum(_partyKinds, json['kind']) ?? fallback.kind,
      childrenCount: _int(json['childrenCount']),
    );
  }

  static Map<String, Object?> _partyToJson(ScenarioPartyDraft value) =>
      <String, Object?>{
        'peopleCount': value.peopleCount,
        'kind': _id(_partyKinds, value.kind),
        'childrenCount': value.childrenCount,
      };

  static ScenarioConstraintsDraft _constraints(
    Object? value,
    ScenarioConstraintsDraft fallback,
  ) {
    final Map<String, Object?> json = _map(value);
    final Set<ScenarioTravelMode> allowed =
        _stringList(json['allowedTravelModes'])
            .map((String id) => _enum(_travelModes, id))
            .whereType<ScenarioTravelMode>()
            .toSet();
    final Set<ScenarioTravelMode> normalizedAllowed = allowed.isEmpty
        ? <ScenarioTravelMode>{...fallback.allowedTravelModes}
        : allowed;
    final ScenarioTravelMode primary =
        _enum(_travelModes, json['primaryTravelMode']) ??
        _derivePrimaryTravelMode(normalizedAllowed);
    return ScenarioConstraintsDraft(
      totalBudgetLimit: _money(json['totalBudgetLimit']),
      budgetBasis:
          _enum(_budgetBases, json['budgetBasis']) ?? fallback.budgetBasis,
      primaryTravelMode: primary,
      allowedTravelModes: <ScenarioTravelMode>{...normalizedAllowed, primary},
      vehicleProfile: _vehicleProfile(
        json['vehicleProfile'],
        fallback: fallback.vehicleProfile,
        carIsPrimary: primary == ScenarioTravelMode.car,
      ),
      maxWalkingMinutesPerLeg: _int(json['maxWalkingMinutesPerLeg']),
      maxTravelMinutesPerDay: _int(json['maxTravelMinutesPerDay']),
      pace: _enum(_paces, json['pace']) ?? fallback.pace,
      interestCategoryIds: _stringList(json['interestCategoryIds']).toSet(),
      accessibilityRequirementIds: _stringList(
        json['accessibilityRequirementIds'],
      ).toSet(),
      freeExperienceItemsOnly:
          _bool(json['freeExperienceItemsOnly']) ??
          fallback.freeExperienceItemsOnly,
    );
  }

  static Map<String, Object?> _constraintsToJson(
    ScenarioConstraintsDraft value,
  ) => <String, Object?>{
    'totalBudgetLimit': value.totalBudgetLimit == null
        ? null
        : _moneyToJson(value.totalBudgetLimit!),
    'budgetBasis': _id(_budgetBases, value.budgetBasis),
    'primaryTravelMode': _id(_travelModes, value.primaryTravelMode),
    'allowedTravelModes': value.allowedTravelModes
        .map((ScenarioTravelMode mode) => _id(_travelModes, mode))
        .toList(growable: false),
    'vehicleProfile': _vehicleProfileToJson(value.vehicleProfile),
    'maxWalkingMinutesPerLeg': value.maxWalkingMinutesPerLeg,
    'maxTravelMinutesPerDay': value.maxTravelMinutesPerDay,
    'pace': _id(_paces, value.pace),
    'interestCategoryIds': value.interestCategoryIds.toList(growable: false),
    'accessibilityRequirementIds': value.accessibilityRequirementIds.toList(
      growable: false,
    ),
    'freeExperienceItemsOnly': value.freeExperienceItemsOnly,
  };

  static ScenarioTravelMode _derivePrimaryTravelMode(
    Set<ScenarioTravelMode> allowed,
  ) {
    if (allowed.contains(ScenarioTravelMode.car)) {
      return ScenarioTravelMode.car;
    }
    for (final ScenarioTravelMode mode in ScenarioTravelMode.values) {
      if (allowed.contains(mode)) {
        return mode;
      }
    }
    return ScenarioTravelMode.walking;
  }

  static ScenarioVehicleProfileDraft _vehicleProfile(
    Object? value, {
    required ScenarioVehicleProfileDraft fallback,
    required bool carIsPrimary,
  }) {
    final Map<String, Object?> json = _map(value);
    return ScenarioVehicleProfileDraft(
      enabled:
          _bool(json['enabled']) ??
          (json.isEmpty ? carIsPrimary : fallback.enabled),
      label: _nullableString(json['label']),
      passengerSeats: _int(json['passengerSeats']),
    );
  }

  static Map<String, Object?> _vehicleProfileToJson(
    ScenarioVehicleProfileDraft value,
  ) => <String, Object?>{
    'enabled': value.enabled,
    'label': value.label,
    'passengerSeats': value.passengerSeats,
  };

  static ScenarioDayDraft _day(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioDayDraft(
      id: _string(json['id'], ''),
      title: _string(json['title'], ''),
      dayIndex: _int(json['dayIndex']) ?? -1,
      timezoneId: _nullableString(json['timezoneId']),
      localDate: _localDate(json['localDate']),
      startLocationId: _nullableString(json['startLocationId']),
      endLocationId: _nullableString(json['endLocationId']),
      preferredStartTime: _localTime(json['preferredStartTime']),
      preferredEndTime: _localTime(json['preferredEndTime']),
      itemIds: _stringList(json['itemIds']),
    );
  }

  static Map<String, Object?> _dayToJson(ScenarioDayDraft value) =>
      <String, Object?>{
        'id': value.id,
        'title': value.title,
        'dayIndex': value.dayIndex,
        'timezoneId': value.timezoneId,
        'localDate': _localDateToJson(value.localDate),
        'startLocationId': value.startLocationId,
        'endLocationId': value.endLocationId,
        'preferredStartTime': _localTimeToJson(value.preferredStartTime),
        'preferredEndTime': _localTimeToJson(value.preferredEndTime),
        'itemIds': value.itemIds,
      };

  static ScenarioLocationDraft _location(Object? value) {
    final Map<String, Object?> json = _map(value);
    final Map<String, Object?> point = _map(json['point']);
    return ScenarioLocationDraft(
      id: _string(json['id'], ''),
      point: ScenarioGeoPointDraft(
        latitude: _double(point['latitude']) ?? double.nan,
        longitude: _double(point['longitude']) ?? double.nan,
      ),
      title: _string(json['title'], ''),
      address: _nullableString(json['address']),
      marketId: _nullableString(json['marketId']),
      regionId: _nullableString(json['regionId']),
      timezoneId: _nullableString(json['timezoneId']),
      disclosure:
          _enum(_disclosures, json['disclosure']) ??
          ScenarioLocationDisclosure.private,
      sourceObjectId: _nullableString(json['sourceObjectId']),
      sourceObjectType: _enum(_catalogTypes, json['sourceObjectType']),
    );
  }

  static Map<String, Object?> _locationToJson(ScenarioLocationDraft value) =>
      <String, Object?>{
        'id': value.id,
        'point': _pointToJson(value.point),
        'title': value.title,
        'address': value.address,
        'marketId': value.marketId,
        'regionId': value.regionId,
        'timezoneId': value.timezoneId,
        'disclosure': _id(_disclosures, value.disclosure),
        'sourceObjectId': value.sourceObjectId,
        'sourceObjectType': value.sourceObjectType == null
            ? null
            : _id(_catalogTypes, value.sourceObjectType!),
      };

  static ScenarioItemDraft _item(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioItemDraft(
      id: _string(json['id'], ''),
      dayId: _nullableString(json['dayId']),
      startLocationId: _nullableString(json['startLocationId']),
      endLocationId: _nullableString(json['endLocationId']),
      kind: _enum(_itemKinds, json['kind']) ?? ScenarioItemKind.timeBlock,
      source: _source(json['source']),
      sourceStatus:
          _enum(_sourceStatuses, json['sourceStatus']) ??
          ScenarioSourceStatus.unresolved,
      schedule: _schedule(json['schedule']),
      durationMinutes: _int(json['durationMinutes']),
      cost: _cost(json['cost']),
      orderLocked: _bool(json['orderLocked']) ?? false,
      timeLocked: _bool(json['timeLocked']) ?? false,
      role: _enum(_itemRoles, json['role']) ?? ScenarioItemRole.optional,
      alternativeGroupId: _nullableString(json['alternativeGroupId']),
      selected: _bool(json['selected']) ?? false,
      publicNote: _string(json['publicNote'], ''),
    );
  }

  static Map<String, Object?> _itemToJson(ScenarioItemDraft value) =>
      <String, Object?>{
        'id': value.id,
        'dayId': value.dayId,
        'startLocationId': value.startLocationId,
        'endLocationId': value.endLocationId,
        'kind': _id(_itemKinds, value.kind),
        'source': _sourceToJson(value.source),
        'sourceStatus': _id(_sourceStatuses, value.sourceStatus),
        'schedule': _scheduleToJson(value.schedule),
        'durationMinutes': value.durationMinutes,
        'cost': _costToJson(value.cost),
        'orderLocked': value.orderLocked,
        'timeLocked': value.timeLocked,
        'role': _id(_itemRoles, value.role),
        'alternativeGroupId': value.alternativeGroupId,
        'selected': value.selected,
        'publicNote': value.publicNote,
      };

  static ScenarioItemSourceDraft _source(Object? value) {
    final Map<String, Object?> json = _map(value);
    return switch (_string(json['type'], '')) {
      'catalog' => ScenarioCatalogObjectSourceDraft(
        objectId: _string(json['objectId'], ''),
        objectType:
            _enum(_catalogTypes, json['objectType']) ??
            ScenarioCatalogObjectType.place,
        snapshot: _snapshot(json['snapshot']),
      ),
      'custom_location' => ScenarioCustomLocationSourceDraft(
        locationId: _string(json['locationId'], ''),
      ),
      'planned_transport' => ScenarioPlannedTransportSourceDraft(
        kind:
            _enum(_plannedTransportKinds, json['kind']) ??
            ScenarioPlannedTransportKind.other,
        carrierName: _nullableString(json['carrierName']),
        publicServiceLabel: _nullableString(json['publicServiceLabel']),
        scheduleSnapshot: _scheduleSnapshot(json['scheduleSnapshot']),
      ),
      'time_block' || _ => ScenarioTimeBlockSourceDraft(
        title: _string(json['title'], ''),
        categoryId: _nullableString(json['categoryId']),
      ),
    };
  }

  static Map<String, Object?> _sourceToJson(ScenarioItemSourceDraft value) {
    return switch (value) {
      ScenarioCatalogObjectSourceDraft source => <String, Object?>{
        'type': 'catalog',
        'objectId': source.objectId,
        'objectType': _id(_catalogTypes, source.objectType),
        'snapshot': _snapshotToJson(source.snapshot),
      },
      ScenarioCustomLocationSourceDraft source => <String, Object?>{
        'type': 'custom_location',
        'locationId': source.locationId,
      },
      ScenarioPlannedTransportSourceDraft source => <String, Object?>{
        'type': 'planned_transport',
        'kind': _id(_plannedTransportKinds, source.kind),
        'carrierName': source.carrierName,
        'publicServiceLabel': source.publicServiceLabel,
        'scheduleSnapshot': source.scheduleSnapshot == null
            ? null
            : _scheduleSnapshotToJson(source.scheduleSnapshot!),
      },
      ScenarioTimeBlockSourceDraft source => <String, Object?>{
        'type': 'time_block',
        'title': source.title,
        'categoryId': source.categoryId,
      },
    };
  }

  static ScenarioScheduleSnapshotDraft? _scheduleSnapshot(Object? value) {
    final Map<String, Object?> json = _map(value);
    if (json.isEmpty) {
      return null;
    }
    return ScenarioScheduleSnapshotDraft(
      freshness:
          _enum(_scheduleFreshness, json['freshness']) ??
          ScenarioScheduleFreshness.unknown,
      providerCode: _nullableString(json['providerCode']),
      providerDisplayName: _nullableString(json['providerDisplayName']),
      licenseName: _nullableString(json['licenseName']),
      tripId: _nullableString(json['tripId']),
      routeId: _nullableString(json['routeId']),
      serviceId: _nullableString(json['serviceId']),
      originStopId: _nullableString(json['originStopId']),
      destinationStopId: _nullableString(json['destinationStopId']),
      feedSha256: _nullableString(json['feedSha256']),
      serviceDate: _localDate(json['serviceDate']),
      feedUpdatedAtUtc: _dateTime(json['feedUpdatedAtUtc']),
      retrievedAtUtc: _dateTime(json['retrievedAtUtc']),
      carrierName: _nullableString(json['carrierName']),
      serviceLabel: _nullableString(json['serviceLabel']),
      originLabel: _nullableString(json['originLabel']),
      destinationLabel: _nullableString(json['destinationLabel']),
      plannedDeparture: _localTime(json['plannedDeparture']),
      plannedArrival: _localTime(json['plannedArrival']),
      departureSecondsFromServiceDay: _int(
        json['departureSecondsFromServiceDay'],
      ),
      arrivalSecondsFromServiceDay: _int(json['arrivalSecondsFromServiceDay']),
      departureDayOffset: _int(json['departureDayOffset']),
      arrivalDayOffset: _int(json['arrivalDayOffset']),
      sourceUrl: _nullableString(json['sourceUrl']),
      unknownFields: Map<String, Object?>.unmodifiable(
        Map<String, Object?>.fromEntries(
          json.entries.where(
            (MapEntry<String, Object?> entry) =>
                !_knownScheduleSnapshotKeys.contains(entry.key),
          ),
        ),
      ),
    );
  }

  static Map<String, Object?> _scheduleSnapshotToJson(
    ScenarioScheduleSnapshotDraft value,
  ) => <String, Object?>{
    ...value.unknownFields,
    'freshness': _id(_scheduleFreshness, value.freshness),
    'providerCode': value.providerCode,
    'providerDisplayName': value.providerDisplayName,
    'licenseName': value.licenseName,
    'tripId': value.tripId,
    'routeId': value.routeId,
    'serviceId': value.serviceId,
    'originStopId': value.originStopId,
    'destinationStopId': value.destinationStopId,
    'feedSha256': value.feedSha256,
    'serviceDate': _localDateToJson(value.serviceDate),
    'feedUpdatedAtUtc': value.feedUpdatedAtUtc?.toUtc().toIso8601String(),
    'retrievedAtUtc': value.retrievedAtUtc?.toUtc().toIso8601String(),
    'carrierName': value.carrierName,
    'serviceLabel': value.serviceLabel,
    'originLabel': value.originLabel,
    'destinationLabel': value.destinationLabel,
    'plannedDeparture': _localTimeToJson(value.plannedDeparture),
    'plannedArrival': _localTimeToJson(value.plannedArrival),
    'departureSecondsFromServiceDay': value.departureSecondsFromServiceDay,
    'arrivalSecondsFromServiceDay': value.arrivalSecondsFromServiceDay,
    'departureDayOffset': value.departureDayOffset,
    'arrivalDayOffset': value.arrivalDayOffset,
    'sourceUrl': value.sourceUrl,
  };

  static ScenarioObjectSnapshotDraft _snapshot(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioObjectSnapshotDraft(
      title: _string(json['title'], ''),
      coverMediaId: _nullableString(json['coverMediaId']),
      publisherId: _nullableString(json['publisherId']),
      sourceLocationVersion: _int(json['sourceLocationVersion']),
      durationMinutes: _int(json['durationMinutes']),
      distanceM: _double(json['distanceM']),
      checkedAtUtc: _dateTime(json['checkedAtUtc']),
    );
  }

  static Map<String, Object?> _snapshotToJson(
    ScenarioObjectSnapshotDraft value,
  ) => <String, Object?>{
    'title': value.title,
    'coverMediaId': value.coverMediaId,
    'publisherId': value.publisherId,
    'sourceLocationVersion': value.sourceLocationVersion,
    'durationMinutes': value.durationMinutes,
    'distanceM': value.distanceM,
    'checkedAtUtc': value.checkedAtUtc?.toUtc().toIso8601String(),
  };

  static ScenarioScheduleDraft _schedule(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioScheduleDraft(
      mode: _enum(_timeModes, json['mode']) ?? ScenarioTimeMode.flexible,
      planned: _plannedTime(json['planned']),
      calculated: _calculatedTime(json['calculated']),
    );
  }

  static Map<String, Object?> _scheduleToJson(ScenarioScheduleDraft value) =>
      <String, Object?>{
        'mode': _id(_timeModes, value.mode),
        'planned': _plannedTimeToJson(value.planned),
        'calculated': value.calculated == null
            ? null
            : _calculatedTimeToJson(value.calculated!),
      };

  static ScenarioPlannedTimeDraft _plannedTime(Object? value) {
    final Map<String, Object?> json = _map(value);
    if (_string(json['type'], 'template') == 'dated') {
      return ScenarioDatedPlannedTimeDraft(
        fixedStartAtUtc: _dateTime(json['fixedStartAtUtc']),
        fixedEndAtUtc: _dateTime(json['fixedEndAtUtc']),
        windowStart: _localTime(json['windowStart']),
        windowEnd: _localTime(json['windowEnd']),
        windowEndDayOffset: _int(json['windowEndDayOffset']) ?? 0,
        startTimezoneId: _nullableString(json['startTimezoneId']),
        endTimezoneId: _nullableString(json['endTimezoneId']),
      );
    }
    return ScenarioTemplatePlannedTimeDraft(
      startDayIndex: _int(json['startDayIndex']) ?? 0,
      preferredStart: _localTime(json['preferredStart']),
      windowStart: _localTime(json['windowStart']),
      windowEnd: _localTime(json['windowEnd']),
      windowEndDayOffset: _int(json['windowEndDayOffset']) ?? 0,
      endDayIndex: _int(json['endDayIndex']),
      preferredEnd: _localTime(json['preferredEnd']),
      startTimezoneId: _nullableString(json['startTimezoneId']),
      endTimezoneId: _nullableString(json['endTimezoneId']),
    );
  }

  static Map<String, Object?> _plannedTimeToJson(
    ScenarioPlannedTimeDraft value,
  ) {
    return switch (value) {
      ScenarioTemplatePlannedTimeDraft time => <String, Object?>{
        'type': 'template',
        'startDayIndex': time.startDayIndex,
        'preferredStart': _localTimeToJson(time.preferredStart),
        'windowStart': _localTimeToJson(time.windowStart),
        'windowEnd': _localTimeToJson(time.windowEnd),
        'windowEndDayOffset': time.windowEndDayOffset,
        'endDayIndex': time.endDayIndex,
        'preferredEnd': _localTimeToJson(time.preferredEnd),
        'startTimezoneId': time.startTimezoneId,
        'endTimezoneId': time.endTimezoneId,
      },
      ScenarioDatedPlannedTimeDraft time => <String, Object?>{
        'type': 'dated',
        'fixedStartAtUtc': time.fixedStartAtUtc?.toUtc().toIso8601String(),
        'fixedEndAtUtc': time.fixedEndAtUtc?.toUtc().toIso8601String(),
        'windowStart': _localTimeToJson(time.windowStart),
        'windowEnd': _localTimeToJson(time.windowEnd),
        'windowEndDayOffset': time.windowEndDayOffset,
        'startTimezoneId': time.startTimezoneId,
        'endTimezoneId': time.endTimezoneId,
      },
    };
  }

  static ScenarioCalculatedTimeDraft? _calculatedTime(Object? value) {
    final Map<String, Object?> json = _map(value);
    if (json.isEmpty) {
      return null;
    }
    if (_string(json['type'], '') == 'dated') {
      final DateTime? start = _dateTime(json['startAtUtc']);
      final DateTime? end = _dateTime(json['endAtUtc']);
      return start == null || end == null
          ? null
          : ScenarioDatedCalculatedTimeDraft(startAtUtc: start, endAtUtc: end);
    }
    final ScenarioLocalTimeDraft? start = _localTime(json['start']);
    final ScenarioLocalTimeDraft? end = _localTime(json['end']);
    return start == null || end == null
        ? null
        : ScenarioTemplateCalculatedTimeDraft(
            startDayIndex: _int(json['startDayIndex']) ?? 0,
            start: start,
            endDayIndex: _int(json['endDayIndex']) ?? 0,
            end: end,
          );
  }

  static Map<String, Object?> _calculatedTimeToJson(
    ScenarioCalculatedTimeDraft value,
  ) {
    return switch (value) {
      ScenarioTemplateCalculatedTimeDraft time => <String, Object?>{
        'type': 'template',
        'startDayIndex': time.startDayIndex,
        'start': _localTimeToJson(time.start),
        'endDayIndex': time.endDayIndex,
        'end': _localTimeToJson(time.end),
      },
      ScenarioDatedCalculatedTimeDraft time => <String, Object?>{
        'type': 'dated',
        'startAtUtc': time.startAtUtc.toUtc().toIso8601String(),
        'endAtUtc': time.endAtUtc.toUtc().toIso8601String(),
      },
    };
  }

  static ScenarioLegDraft _leg(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioLegDraft(
      id: _string(json['id'], ''),
      dayId: _string(json['dayId'], ''),
      fromItemId: _nullableString(json['fromItemId']),
      toItemId: _nullableString(json['toItemId']),
      fromLocationId: _string(json['fromLocationId'], ''),
      toLocationId: _string(json['toLocationId'], ''),
      mode: _enum(_travelModes, json['mode']) ?? ScenarioTravelMode.other,
      source: _enum(_legSources, json['source']) ?? ScenarioLegSource.unknown,
      status:
          _enum(_legStatuses, json['status']) ?? ScenarioLegStatus.unavailable,
      distanceM: _double(json['distanceM']),
      durationMinutes: _int(json['durationMinutes']),
      cost: _cost(json['cost']),
      displayPolyline: _list(
        json['displayPolyline'],
      ).map(_point).toList(growable: false),
      providerCode: _nullableString(json['providerCode']),
      warningCode: _nullableString(json['warningCode']),
      updatedAtUtc: _dateTime(json['updatedAtUtc']),
      scheduleSnapshot: _scheduleSnapshot(json['scheduleSnapshot']),
      lockedByUser: _bool(json['lockedByUser']) ?? false,
    );
  }

  static Map<String, Object?> _legToJson(ScenarioLegDraft value) =>
      <String, Object?>{
        'id': value.id,
        'dayId': value.dayId,
        'fromItemId': value.fromItemId,
        'toItemId': value.toItemId,
        'fromLocationId': value.fromLocationId,
        'toLocationId': value.toLocationId,
        'mode': _id(_travelModes, value.mode),
        'source': _id(_legSources, value.source),
        'status': _id(_legStatuses, value.status),
        'distanceM': value.distanceM,
        'durationMinutes': value.durationMinutes,
        'cost': _costToJson(value.cost),
        'displayPolyline': value.displayPolyline
            .map(_pointToJson)
            .toList(growable: false),
        'providerCode': value.providerCode,
        'warningCode': value.warningCode,
        'updatedAtUtc': value.updatedAtUtc?.toUtc().toIso8601String(),
        'scheduleSnapshot': value.scheduleSnapshot == null
            ? null
            : _scheduleSnapshotToJson(value.scheduleSnapshot!),
        'lockedByUser': value.lockedByUser,
      };

  static ScenarioCostDraft _cost(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioCostDraft(
      components: _list(json['components'])
          .map(_estimate)
          .where((component) => !_isLegacyFuelComponent(component))
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _costToJson(ScenarioCostDraft value) =>
      <String, Object?>{
        'components': value.components
            .where((component) => !_isLegacyFuelComponent(component))
            .map(_estimateToJson)
            .toList(growable: false),
      };

  static bool _isLegacyFuelComponent(ScenarioMoneyEstimateDraft component) =>
      component.componentCode.trim().toLowerCase() == 'fuel';

  static ScenarioMoneyEstimateDraft _estimate(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioMoneyEstimateDraft(
      componentCode: _string(json['componentCode'], ''),
      knowledge:
          _enum(_priceKnowledge, json['knowledge']) ??
          ScenarioPriceKnowledge.unknown,
      amount: _money(json['amount']),
      basis: _enum(_priceBases, json['basis']),
      source:
          _enum(_priceSources, json['source']) ?? ScenarioPriceSource.manual,
      observedAtUtc: _dateTime(json['observedAtUtc']),
      confidence: _double(json['confidence']),
    );
  }

  static Map<String, Object?> _estimateToJson(
    ScenarioMoneyEstimateDraft value,
  ) => <String, Object?>{
    'componentCode': value.componentCode,
    'knowledge': _id(_priceKnowledge, value.knowledge),
    'amount': value.amount == null ? null : _moneyToJson(value.amount!),
    'basis': value.basis == null ? null : _id(_priceBases, value.basis!),
    'source': _id(_priceSources, value.source),
    'observedAtUtc': value.observedAtUtc?.toUtc().toIso8601String(),
    'confidence': value.confidence,
  };

  static ScenarioMoneyDraft? _money(Object? value) {
    final Map<String, Object?> json = _map(value);
    final int? minorUnits = _int(json['minorUnits']);
    final String currencyCode = _string(json['currencyCode'], '').toUpperCase();
    return minorUnits == null || currencyCode.isEmpty
        ? null
        : ScenarioMoneyDraft(
            minorUnits: minorUnits,
            currencyCode: currencyCode,
          );
  }

  static Map<String, Object?> _moneyToJson(ScenarioMoneyDraft value) =>
      <String, Object?>{
        'minorUnits': value.minorUnits,
        'currencyCode': value.currencyCode,
      };

  static ScenarioTotalsDraft _totals(Object? value) {
    final Map<String, Object?> json = _map(value);
    if (json.isEmpty) {
      return const ScenarioTotalsDraft.empty();
    }
    return ScenarioTotalsDraft(
      activityMinutes: _int(json['activityMinutes']) ?? 0,
      plannedBlockMinutes: _int(json['plannedBlockMinutes']) ?? 0,
      localTravelMinutes: _int(json['localTravelMinutes']) ?? 0,
      plannedTransportMinutes: _int(json['plannedTransportMinutes']) ?? 0,
      implicitWaitingMinutes: _int(json['implicitWaitingMinutes']) ?? 0,
      stayNights: _int(json['stayNights']) ?? 0,
      dayTotals: _list(
        json['dayTotals'],
      ).map(_dayTotals).toList(growable: false),
      displayIncludedExperienceCost: _money(
        json['displayIncludedExperienceCost'],
      ),
      displayIncludedStayCost: _money(json['displayIncludedStayCost']),
      displayIncludedLocalTravelCost: _money(
        json['displayIncludedLocalTravelCost'],
      ),
      displayIncludedPlannedTransportCost: _money(
        json['displayIncludedPlannedTransportCost'],
      ),
      displayFromTotalCost: _money(json['displayFromTotalCost']),
      originalCurrencySubtotals: _list(
        json['originalCurrencySubtotals'],
      ).map(_currencySubtotal).toList(growable: false),
      exchangeRateSnapshotId: _nullableString(json['exchangeRateSnapshotId']),
      estimatedCostCount: _int(json['estimatedCostCount']) ?? 0,
      unknownCostCount: _int(json['unknownCostCount']) ?? 0,
      knownLocalTravelDistanceM:
          _double(json['knownLocalTravelDistanceM']) ?? 0,
      knownEmbeddedRouteDistanceM:
          _double(json['knownEmbeddedRouteDistanceM']) ?? 0,
      activeItemCount: _int(json['activeItemCount']) ?? 0,
      dayCount: _int(json['dayCount']) ?? 0,
      unresolvedLegCount: _int(json['unresolvedLegCount']) ?? 0,
      warningCount: _int(json['warningCount']) ?? 0,
    );
  }

  static Map<String, Object?> _totalsToJson(
    ScenarioTotalsDraft value,
  ) => <String, Object?>{
    'activityMinutes': value.activityMinutes,
    'plannedBlockMinutes': value.plannedBlockMinutes,
    'localTravelMinutes': value.localTravelMinutes,
    'plannedTransportMinutes': value.plannedTransportMinutes,
    'implicitWaitingMinutes': value.implicitWaitingMinutes,
    'stayNights': value.stayNights,
    'dayTotals': value.dayTotals.map(_dayTotalsToJson).toList(growable: false),
    'displayIncludedExperienceCost': value.displayIncludedExperienceCost == null
        ? null
        : _moneyToJson(value.displayIncludedExperienceCost!),
    'displayIncludedStayCost': value.displayIncludedStayCost == null
        ? null
        : _moneyToJson(value.displayIncludedStayCost!),
    'displayIncludedLocalTravelCost':
        value.displayIncludedLocalTravelCost == null
        ? null
        : _moneyToJson(value.displayIncludedLocalTravelCost!),
    'displayIncludedPlannedTransportCost':
        value.displayIncludedPlannedTransportCost == null
        ? null
        : _moneyToJson(value.displayIncludedPlannedTransportCost!),
    'displayFromTotalCost': value.displayFromTotalCost == null
        ? null
        : _moneyToJson(value.displayFromTotalCost!),
    'originalCurrencySubtotals': value.originalCurrencySubtotals
        .map(_currencySubtotalToJson)
        .toList(growable: false),
    'exchangeRateSnapshotId': value.exchangeRateSnapshotId,
    'estimatedCostCount': value.estimatedCostCount,
    'unknownCostCount': value.unknownCostCount,
    'knownLocalTravelDistanceM': value.knownLocalTravelDistanceM,
    'knownEmbeddedRouteDistanceM': value.knownEmbeddedRouteDistanceM,
    'activeItemCount': value.activeItemCount,
    'dayCount': value.dayCount,
    'unresolvedLegCount': value.unresolvedLegCount,
    'warningCount': value.warningCount,
  };

  static ScenarioDayTotalsDraft _dayTotals(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioDayTotalsDraft(
      dayId: _string(json['dayId'], ''),
      activityMinutes: _int(json['activityMinutes']) ?? 0,
      plannedBlockMinutes: _int(json['plannedBlockMinutes']) ?? 0,
      localTravelMinutes: _int(json['localTravelMinutes']) ?? 0,
      plannedTransportMinutes: _int(json['plannedTransportMinutes']) ?? 0,
      implicitWaitingMinutes: _int(json['implicitWaitingMinutes']) ?? 0,
      elapsedMinutes: _int(json['elapsedMinutes']),
      unresolvedValueCount: _int(json['unresolvedValueCount']) ?? 0,
    );
  }

  static Map<String, Object?> _dayTotalsToJson(ScenarioDayTotalsDraft value) =>
      <String, Object?>{
        'dayId': value.dayId,
        'activityMinutes': value.activityMinutes,
        'plannedBlockMinutes': value.plannedBlockMinutes,
        'localTravelMinutes': value.localTravelMinutes,
        'plannedTransportMinutes': value.plannedTransportMinutes,
        'implicitWaitingMinutes': value.implicitWaitingMinutes,
        'elapsedMinutes': value.elapsedMinutes,
        'unresolvedValueCount': value.unresolvedValueCount,
      };

  static ScenarioCurrencySubtotalDraft _currencySubtotal(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioCurrencySubtotalDraft(
      currencyCode: _string(json['currencyCode'], '').toUpperCase(),
      knownMinorUnits: _int(json['knownMinorUnits']) ?? 0,
      estimatedMinorUnits: _int(json['estimatedMinorUnits']) ?? 0,
    );
  }

  static Map<String, Object?> _currencySubtotalToJson(
    ScenarioCurrencySubtotalDraft value,
  ) => <String, Object?>{
    'currencyCode': value.currencyCode,
    'knownMinorUnits': value.knownMinorUnits,
    'estimatedMinorUnits': value.estimatedMinorUnits,
  };

  static ScenarioOriginDraft? _origin(Object? value) {
    final Map<String, Object?> json = _map(value);
    final ScenarioOriginType? type = _enum(_originTypes, json['type']);
    return type == null
        ? null
        : ScenarioOriginDraft(
            type: type,
            sourceId: _nullableString(json['sourceId']),
            sourceRevision: _int(json['sourceRevision']),
          );
  }

  static Map<String, Object?> _originToJson(ScenarioOriginDraft value) =>
      <String, Object?>{
        'type': _id(_originTypes, value.type),
        'sourceId': value.sourceId,
        'sourceRevision': value.sourceRevision,
      };

  static ScenarioCapabilitiesDraft _capabilities(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioCapabilitiesDraft(
      multiDay: _bool(json['multiDay']) ?? false,
      stay: _bool(json['stay']) ?? false,
      plannedTransport: _bool(json['plannedTransport']) ?? false,
      alternatives: _bool(json['alternatives']) ?? false,
      multiCurrency: _bool(json['multiCurrency']) ?? false,
      optimizer: _bool(json['optimizer']) ?? false,
      unlistedShare: _bool(json['unlistedShare']) ?? false,
      publicPublish: _bool(json['publicPublish']) ?? false,
      liveLogistics: _bool(json['liveLogistics']) ?? false,
    );
  }

  static Map<String, Object?> _capabilitiesToJson(
    ScenarioCapabilitiesDraft value,
  ) => <String, Object?>{
    'multiDay': value.multiDay,
    'stay': value.stay,
    'plannedTransport': value.plannedTransport,
    'alternatives': value.alternatives,
    'multiCurrency': value.multiCurrency,
    'optimizer': value.optimizer,
    'unlistedShare': value.unlistedShare,
    'publicPublish': value.publicPublish,
    'liveLogistics': value.liveLogistics,
  };

  static ScenarioLocalDateDraft? _localDate(Object? value) {
    final Map<String, Object?> json = _map(value);
    final int? year = _int(json['year']);
    final int? month = _int(json['month']);
    final int? day = _int(json['day']);
    return year == null || month == null || day == null
        ? null
        : ScenarioLocalDateDraft(year: year, month: month, day: day);
  }

  static Map<String, Object?>? _localDateToJson(
    ScenarioLocalDateDraft? value,
  ) => value == null
      ? null
      : <String, Object?>{
          'year': value.year,
          'month': value.month,
          'day': value.day,
        };

  static ScenarioLocalTimeDraft? _localTime(Object? value) {
    final Map<String, Object?> json = _map(value);
    final int? hour = _int(json['hour']);
    final int? minute = _int(json['minute']);
    return hour == null || minute == null
        ? null
        : ScenarioLocalTimeDraft(hour: hour, minute: minute);
  }

  static Map<String, Object?>? _localTimeToJson(
    ScenarioLocalTimeDraft? value,
  ) => value == null
      ? null
      : <String, Object?>{'hour': value.hour, 'minute': value.minute};

  static ScenarioGeoPointDraft _point(Object? value) {
    final Map<String, Object?> json = _map(value);
    return ScenarioGeoPointDraft(
      latitude: _double(json['latitude']) ?? double.nan,
      longitude: _double(json['longitude']) ?? double.nan,
    );
  }

  static Map<String, Object?> _pointToJson(ScenarioGeoPointDraft value) =>
      <String, Object?>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };

  static T? _enum<T>(Map<String, T> values, Object? value) {
    final String id = value?.toString().trim().toLowerCase() ?? '';
    return values[id];
  }

  static String _id<T>(Map<String, T> values, T value) {
    return values.entries
        .firstWhere((MapEntry<String, T> e) => e.value == value)
        .key;
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) {
      return <String, Object?>{};
    }
    return value.map<String, Object?>((dynamic key, dynamic item) {
      return MapEntry<String, Object?>(key.toString(), item as Object?);
    });
  }

  static List<Object?> _list(Object? value) =>
      value is List ? value.cast<Object?>() : const <Object?>[];

  static List<String> _stringList(Object? value) => _list(value)
      .map((Object? item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);

  static String _string(Object? value, String fallback) {
    final String result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  static String? _nullableString(Object? value) {
    final String result = value?.toString().trim() ?? '';
    return result.isEmpty ? null : result;
  }

  static int? _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };

  static double? _double(Object? value) => switch (value) {
    double number => number,
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };

  static bool? _bool(Object? value) => switch (value) {
    bool result => result,
    String text when text.toLowerCase() == 'true' => true,
    String text when text.toLowerCase() == 'false' => false,
    _ => null,
  };

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }
}
