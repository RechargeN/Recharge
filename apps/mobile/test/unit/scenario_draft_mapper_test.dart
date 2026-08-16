import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_logistics_draft.dart';

void main() {
  test('Scenario schema v2 survives a typed round-trip', () {
    final ScenarioDraftData source = _fixture();

    final Map<String, Object?> json = ScenarioDraftMapper.toJson(source);
    final ScenarioDraftData restored = ScenarioDraftMapper.fromJson(json);

    expect(json['schemaVersion'], ScenarioDraftData.currentSchemaVersion);
    expect(json['format'], 'weekend');
    expect(json['dateMode'], 'template');
    expect(json['futureRootField'], 'preserved');
    final List<Object?> items = json['items']! as List<Object?>;
    final Map<String, Object?> route = Map<String, Object?>.from(
      items.first as Map,
    );
    expect(route['kind'], 'route');
    expect(route['role'], 'mandatory');
    expect((route['source']! as Map<Object?, Object?>)['type'], 'catalog');
    expect(
      ((route['cost']! as Map<Object?, Object?>)['components']! as List)
          .first['amount']['minorUnits'],
      1200,
    );

    expect(restored.revision, 7);
    expect(restored.format, ScenarioFormat.weekend);
    expect(restored.defaultTimezoneId, 'Europe/Riga');
    expect(restored.displayCurrencyCode, 'EUR');
    expect(restored.party.peopleCount, 2);
    expect(restored.days.single.itemIds, <String>['item-route', 'item-break']);
    expect(restored.locations.length, 2);
    expect(restored.items.length, 2);
    expect(restored.items.first.kind, ScenarioItemKind.route);
    expect(
      restored.items.first.source,
      isA<ScenarioCatalogObjectSourceDraft>(),
    );
    expect(restored.legs.single.mode, ScenarioTravelMode.walking);
    expect(restored.origin!.type, ScenarioOriginType.quickPlanConversion);
    expect(restored.capabilities.multiDay, isTrue);
    expect(restored.unknownFields['futureRootField'], 'preserved');
  });

  test('fractional Scenario minor units fail closed', () {
    final Map<String, Object?> json = ScenarioDraftMapper.toJson(_fixture());
    final List<Object?> items = json['items']! as List<Object?>;
    final Map<String, Object?> firstItem = Map<String, Object?>.from(
      items.first as Map,
    );
    final Map<String, Object?> cost = Map<String, Object?>.from(
      firstItem['cost']! as Map,
    );
    final List<Object?> components = List<Object?>.from(
      cost['components']! as List,
    );
    final Map<String, Object?> component = Map<String, Object?>.from(
      components.first as Map,
    );
    final Map<String, Object?> amount = Map<String, Object?>.from(
      component['amount']! as Map,
    )..['minorUnits'] = 12.5;
    component['amount'] = amount;
    components[0] = component;
    cost['components'] = components;
    firstItem['cost'] = cost;
    items[0] = firstItem;
    json['items'] = items;

    expect(() => ScenarioDraftMapper.fromJson(json), throwsFormatException);
  });

  test('Scenario v1 derives transport defaults without fabricating a car', () {
    final Map<String, Object?> legacy = <String, Object?>{
      'schemaVersion': 1,
      'defaultTimezoneId': 'Europe/Riga',
      'displayCurrencyCode': 'EUR',
      'constraints': <String, Object?>{
        'budgetBasis': 'whole_group',
        'allowedTravelModes': <String>['walking', 'transit'],
        'pace': 'balanced',
      },
    };

    final ScenarioDraftData restored = ScenarioDraftMapper.fromJson(legacy);

    expect(restored.schemaVersion, 2);
    expect(restored.constraints.primaryTravelMode, ScenarioTravelMode.walking);
    expect(restored.constraints.vehicleProfile.enabled, isFalse);
    expect(restored.constraints.allowedTravelModes, <ScenarioTravelMode>{
      ScenarioTravelMode.walking,
      ScenarioTravelMode.transit,
    });
  });

  test('legacy fuel data is readable but removed from normalized output', () {
    final ScenarioDraftData restored = ScenarioDraftMapper.fromJson(
      <String, Object?>{
        'schemaVersion': 2,
        'defaultTimezoneId': 'Europe/Riga',
        'displayCurrencyCode': 'EUR',
        'constraints': <String, Object?>{
          'budgetBasis': 'whole_group',
          'primaryTravelMode': 'car',
          'allowedTravelModes': <String>['car', 'walking'],
          'vehicleProfile': <String, Object?>{
            'enabled': true,
            'includeFuelInBudget': true,
            'litresPer100Km': 8,
            'fuelPricePerLitre': <String, Object?>{
              'minorUnits': 180,
              'currencyCode': 'EUR',
            },
            'passengerSeats': 4,
          },
        },
        'legs': <Object?>[
          <String, Object?>{
            'id': 'legacy-leg',
            'dayId': 'day-1',
            'fromLocationId': 'location-1',
            'toLocationId': 'location-2',
            'mode': 'car',
            'source': 'manual',
            'status': 'ready',
            'cost': <String, Object?>{
              'components': <Object?>[
                <String, Object?>{
                  'componentCode': 'fuel',
                  'knowledge': 'estimated',
                  'amount': <String, Object?>{
                    'minorUnits': 720,
                    'currencyCode': 'EUR',
                  },
                  'source': 'user_override',
                },
                <String, Object?>{
                  'componentCode': 'travel_extra',
                  'knowledge': 'known',
                  'amount': <String, Object?>{
                    'minorUnits': 900,
                    'currencyCode': 'EUR',
                  },
                  'source': 'manual',
                },
              ],
            },
          },
        ],
      },
    );

    expect(restored.constraints.vehicleProfile.enabled, isTrue);
    expect(restored.constraints.vehicleProfile.passengerSeats, 4);
    expect(restored.legs.single.cost.components, hasLength(1));
    expect(
      restored.legs.single.cost.components.single.componentCode,
      'travel_extra',
    );

    final normalized = ScenarioDraftMapper.toJson(restored);
    final constraints = normalized['constraints']! as Map<String, Object?>;
    final profile = constraints['vehicleProfile']! as Map<String, Object?>;
    expect(
      profile.keys,
      isNot(
        containsAll(<String>[
          'includeFuelInBudget',
          'litresPer100Km',
          'fuelPricePerLitre',
        ]),
      ),
    );
    expect(normalized.toString().toLowerCase(), isNot(contains('fuel')));
    expect(normalized.toString(), contains('travel_extra'));
  });

  test('unknown future root payload is retained without guessing fields', () {
    final ScenarioDraftData restored = ScenarioDraftMapper.fromJson(
      <String, Object?>{
        'schemaVersion': 99,
        'revision': 42,
        'futureGraph': <String, Object?>{'opaque': true},
      },
      defaults: ScenarioDraftData.defaults(
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
      ),
    );

    expect(restored.revision, 0);
    expect(restored.items, isEmpty);
    expect(restored.unknownFields['schemaVersion'], 99);
    expect(restored.unknownFields['futureGraph'], <String, Object?>{
      'opaque': true,
    });
    expect(
      ScenarioDraftMapper.toJson(restored)['futureGraph'],
      <String, Object?>{'opaque': true},
    );
  });

  test('mapper uses explicit snake-case ids instead of enum names', () {
    final Map<String, Object?> json = ScenarioDraftMapper.toJson(_fixture());
    final List<Object?> items = json['items']! as List<Object?>;
    final Map<String, Object?> breakItem = Map<String, Object?>.from(
      items.last as Map,
    );

    expect(breakItem['kind'], 'time_block');
    expect(
      (breakItem['schedule']! as Map<Object?, Object?>)['mode'],
      'flexible',
    );
    expect(
      (json['constraints']! as Map<Object?, Object?>)['budgetBasis'],
      'whole_group',
    );
  });

  test('Details intake origin survives a typed round-trip', () {
    final source = ScenarioDraftData.defaults().copyWith(
      origin: const ScenarioOriginDraft(
        type: ScenarioOriginType.details,
        sourceId: 'place-1',
        sourceRevision: 4,
      ),
    );

    final json = ScenarioDraftMapper.toJson(source);
    final restored = ScenarioDraftMapper.fromJson(json);

    expect((json['origin']! as Map<Object?, Object?>)['type'], 'details');
    expect(restored.origin?.type, ScenarioOriginType.details);
    expect(restored.origin?.sourceId, 'place-1');
    expect(restored.origin?.sourceRevision, 4);
  });

  test('official transit snapshot preserves provenance and future fields', () {
    const snapshot = ScenarioScheduleSnapshotDraft(
      freshness: ScenarioScheduleFreshness.current,
      providerCode: 'lv_vivi_train',
      providerDisplayName: 'Vivi',
      licenseName: 'CC0 1.0',
      tripId: 'trip-42',
      routeId: 'route-riga-valga',
      serviceId: 'weekday',
      originStopId: 'riga',
      destinationStopId: 'sigulda',
      feedSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      serviceDate: ScenarioLocalDateDraft(year: 2026, month: 8, day: 3),
      carrierName: 'Vivi',
      serviceLabel: 'Rīga–Valga',
      originLabel: 'Rīga',
      destinationLabel: 'Sigulda',
      plannedDeparture: ScenarioLocalTimeDraft(hour: 23, minute: 59),
      plannedArrival: ScenarioLocalTimeDraft(hour: 0, minute: 50),
      departureSecondsFromServiceDay: 86340,
      arrivalSecondsFromServiceDay: 89400,
      departureDayOffset: 0,
      arrivalDayOffset: 1,
      sourceUrl: 'https://vivi.lv/uploads/GTFS.zip',
      unknownFields: <String, Object?>{
        'futureEvidence': <String, Object?>{'confidence': 'official'},
      },
    );
    final source = ScenarioDraftData.defaults().copyWith(
      items: const <ScenarioItemDraft>[
        ScenarioItemDraft(
          id: 'transport-1',
          kind: ScenarioItemKind.plannedTransport,
          source: ScenarioPlannedTransportSourceDraft(
            kind: ScenarioPlannedTransportKind.train,
            carrierName: 'Vivi',
            publicServiceLabel: 'Rīga–Valga',
            scheduleSnapshot: snapshot,
          ),
          sourceStatus: ScenarioSourceStatus.ready,
          schedule: ScenarioScheduleDraft(
            mode: ScenarioTimeMode.fixed,
            planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
          ),
          durationMinutes: 51,
          cost: ScenarioCostDraft(),
          orderLocked: false,
          timeLocked: true,
          role: ScenarioItemRole.mandatory,
          selected: true,
          publicNote: '',
        ),
      ],
      unscheduledItemIds: <String>['transport-1'],
    );

    final json = ScenarioDraftMapper.toJson(source);
    final restored = ScenarioDraftMapper.fromJson(json);
    final restoredSource =
        restored.items.single.source as ScenarioPlannedTransportSourceDraft;
    final restoredSnapshot = restoredSource.scheduleSnapshot!;

    expect(restoredSnapshot.tripId, 'trip-42');
    expect(restoredSnapshot.routeId, 'route-riga-valga');
    expect(restoredSnapshot.originStopId, 'riga');
    expect(restoredSnapshot.destinationStopId, 'sigulda');
    expect(restoredSnapshot.departureSecondsFromServiceDay, 86340);
    expect(restoredSnapshot.arrivalSecondsFromServiceDay, 89400);
    expect(restoredSnapshot.arrivalDayOffset, 1);
    expect(restoredSnapshot.unknownFields['futureEvidence'], <String, Object?>{
      'confidence': 'official',
    });
    final outputItems = ScenarioDraftMapper.toJson(restored)['items']! as List;
    final outputSource = (outputItems.single as Map)['source'] as Map;
    final outputSnapshot = outputSource['scheduleSnapshot'] as Map;
    expect(outputSnapshot['futureEvidence'], <String, Object?>{
      'confidence': 'official',
    });
  });

  test(
    'legacy manual transit snapshot stays readable without new metadata',
    () {
      final source = ScenarioDraftData.defaults().copyWith(
        items: const <ScenarioItemDraft>[
          ScenarioItemDraft(
            id: 'manual-transport',
            kind: ScenarioItemKind.plannedTransport,
            source: ScenarioPlannedTransportSourceDraft(
              kind: ScenarioPlannedTransportKind.bus,
              publicServiceLabel: '22',
              scheduleSnapshot: ScenarioScheduleSnapshotDraft(
                freshness: ScenarioScheduleFreshness.unknown,
                providerCode: 'manual',
                serviceLabel: '22',
                plannedDeparture: ScenarioLocalTimeDraft(hour: 10, minute: 15),
              ),
            ),
            sourceStatus: ScenarioSourceStatus.ready,
            schedule: ScenarioScheduleDraft(
              mode: ScenarioTimeMode.fixed,
              planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
            ),
            durationMinutes: 30,
            cost: ScenarioCostDraft(),
            orderLocked: false,
            timeLocked: true,
            role: ScenarioItemRole.mandatory,
            selected: true,
            publicNote: '',
          ),
        ],
        unscheduledItemIds: <String>['manual-transport'],
      );

      final restored = ScenarioDraftMapper.fromJson(
        ScenarioDraftMapper.toJson(source),
      );
      final restoredSnapshot =
          (restored.items.single.source as ScenarioPlannedTransportSourceDraft)
              .scheduleSnapshot!;

      expect(restoredSnapshot.providerCode, 'manual');
      expect(restoredSnapshot.serviceLabel, '22');
      expect(restoredSnapshot.tripId, isNull);
      expect(restoredSnapshot.feedSha256, isNull);
      expect(restoredSnapshot.departureDayOffset, isNull);
    },
  );
}

ScenarioDraftData _fixture() {
  const ScenarioLocationDraft start = ScenarioLocationDraft(
    id: 'location-start',
    point: ScenarioGeoPointDraft(latitude: 56.9496, longitude: 24.1052),
    title: 'Old Riga',
    disclosure: ScenarioLocationDisclosure.public,
    timezoneId: 'Europe/Riga',
    sourceObjectId: 'place-old-riga',
    sourceObjectType: ScenarioCatalogObjectType.place,
  );
  const ScenarioLocationDraft finish = ScenarioLocationDraft(
    id: 'location-finish',
    point: ScenarioGeoPointDraft(latitude: 56.956, longitude: 24.113),
    title: 'Cinema',
    disclosure: ScenarioLocationDisclosure.approximate,
    timezoneId: 'Europe/Riga',
  );
  const ScenarioScheduleDraft routeSchedule = ScenarioScheduleDraft(
    mode: ScenarioTimeMode.fixed,
    planned: ScenarioTemplatePlannedTimeDraft(
      startDayIndex: 0,
      preferredStart: ScenarioLocalTimeDraft(hour: 10, minute: 0),
      endDayIndex: 0,
      preferredEnd: ScenarioLocalTimeDraft(hour: 12, minute: 0),
      startTimezoneId: 'Europe/Riga',
      endTimezoneId: 'Europe/Riga',
    ),
    calculated: ScenarioTemplateCalculatedTimeDraft(
      startDayIndex: 0,
      start: ScenarioLocalTimeDraft(hour: 10, minute: 0),
      endDayIndex: 0,
      end: ScenarioLocalTimeDraft(hour: 12, minute: 0),
    ),
  );
  const ScenarioItemDraft route = ScenarioItemDraft(
    id: 'item-route',
    dayId: 'day-1',
    startLocationId: 'location-start',
    endLocationId: 'location-finish',
    kind: ScenarioItemKind.route,
    source: ScenarioCatalogObjectSourceDraft(
      objectId: 'route-1',
      objectType: ScenarioCatalogObjectType.route,
      snapshot: ScenarioObjectSnapshotDraft(
        title: 'Riga architecture walk',
        durationMinutes: 120,
        distanceM: 5400,
      ),
    ),
    sourceStatus: ScenarioSourceStatus.ready,
    schedule: routeSchedule,
    durationMinutes: 120,
    cost: ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'admission',
          knowledge: ScenarioPriceKnowledge.known,
          amount: ScenarioMoneyDraft(minorUnits: 1200, currencyCode: 'EUR'),
          basis: ScenarioPriceBasis.perPerson,
          source: ScenarioPriceSource.catalog,
        ),
      ],
    ),
    orderLocked: true,
    timeLocked: true,
    role: ScenarioItemRole.mandatory,
    selected: true,
    publicNote: 'Start near the square',
  );
  const ScenarioItemDraft breakItem = ScenarioItemDraft(
    id: 'item-break',
    dayId: 'day-1',
    kind: ScenarioItemKind.timeBlock,
    source: ScenarioTimeBlockSourceDraft(
      title: 'Coffee break',
      categoryId: 'food_drinks',
    ),
    sourceStatus: ScenarioSourceStatus.ready,
    schedule: ScenarioScheduleDraft(
      mode: ScenarioTimeMode.flexible,
      planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
    ),
    durationMinutes: 30,
    cost: ScenarioCostDraft(),
    orderLocked: false,
    timeLocked: false,
    role: ScenarioItemRole.optional,
    selected: true,
    publicNote: '',
  );

  return ScenarioDraftData(
    schemaVersion: ScenarioDraftData.currentSchemaVersion,
    revision: 7,
    format: ScenarioFormat.weekend,
    dateMode: ScenarioDateMode.template,
    defaultTimezoneId: 'Europe/Riga',
    displayCurrencyCode: 'EUR',
    party: const ScenarioPartyDraft(
      peopleCount: 2,
      kind: ScenarioPartyKind.couple,
    ),
    constraints: const ScenarioConstraintsDraft(
      totalBudgetLimit: ScenarioMoneyDraft(
        minorUnits: 10000,
        currencyCode: 'EUR',
      ),
      budgetBasis: ScenarioBudgetBasis.wholeGroup,
      primaryTravelMode: ScenarioTravelMode.walking,
      allowedTravelModes: <ScenarioTravelMode>{ScenarioTravelMode.walking},
      vehicleProfile: ScenarioVehicleProfileDraft.disabled(),
      maxWalkingMinutesPerLeg: 30,
      maxTravelMinutesPerDay: 120,
      pace: ScenarioPace.relaxed,
      interestCategoryIds: <String>{'art_culture'},
      accessibilityRequirementIds: <String>{},
      freeExperienceItemsOnly: false,
    ),
    days: const <ScenarioDayDraft>[
      ScenarioDayDraft(
        id: 'day-1',
        title: 'Saturday',
        dayIndex: 0,
        timezoneId: 'Europe/Riga',
        startLocationId: 'location-start',
        endLocationId: 'location-finish',
        preferredStartTime: ScenarioLocalTimeDraft(hour: 10, minute: 0),
        preferredEndTime: ScenarioLocalTimeDraft(hour: 18, minute: 0),
        itemIds: <String>['item-route', 'item-break'],
      ),
    ],
    locations: const <ScenarioLocationDraft>[start, finish],
    items: const <ScenarioItemDraft>[route, breakItem],
    unscheduledItemIds: const <String>[],
    legs: const <ScenarioLegDraft>[
      ScenarioLegDraft(
        id: 'leg-1',
        dayId: 'day-1',
        fromItemId: 'item-route',
        toItemId: 'item-break',
        fromLocationId: 'location-finish',
        toLocationId: 'location-finish',
        mode: ScenarioTravelMode.walking,
        source: ScenarioLegSource.manual,
        status: ScenarioLegStatus.ready,
        distanceM: 0,
        durationMinutes: 0,
        cost: ScenarioCostDraft(),
      ),
    ],
    totals: const ScenarioTotalsDraft.empty(),
    origin: const ScenarioOriginDraft(
      type: ScenarioOriginType.quickPlanConversion,
      sourceId: 'quick-plan-1',
      sourceRevision: 3,
    ),
    capabilities: const ScenarioCapabilitiesDraft(
      multiDay: true,
      stay: true,
      plannedTransport: true,
      alternatives: true,
      multiCurrency: true,
    ),
    unknownFields: const <String, Object?>{'futureRootField': 'preserved'},
  );
}
