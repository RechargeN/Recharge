import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_budget_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_logistics_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake.dart';
import 'package:recharge/features/create/domain/usecases/apply_scenario_object_intake_usecase.dart';

void main() {
  late _Ids ids;
  late ApplyScenarioObjectIntakeUseCase apply;

  setUp(() {
    ids = _Ids();
    apply = ApplyScenarioObjectIntakeUseCase(
      idGenerator: ids,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
  });

  test('applies an ordered multi-object batch with one revision', () {
    final target = _target();
    final event = _candidate('event-1', ScenarioCatalogObjectType.event);
    final place = _candidate(
      'place-1',
      ScenarioCatalogObjectType.place,
      location: const ScenarioIntakeLocationSnapshot(
        title: 'Old Riga',
        point: ScenarioGeoPointDraft(latitude: 56.9496, longitude: 24.1052),
        disclosure: ScenarioLocationDisclosure.approximate,
      ),
    );

    final result =
        apply(_request(target, <ScenarioIntakeCandidate>[event, place]))
            as ScenarioIntakeApplied;

    expect(result.targetRevision, 5);
    expect(result.draft.scenarioData!.revision, 5);
    expect(result.createdItemIds, <String>['id-0', 'id-1']);
    expect(result.createdLocationIds, <String>['id-2']);
    expect(result.draft.scenarioData!.days.single.itemIds, <String>[
      'id-0',
      'id-1',
    ]);
    expect(result.draft.scenarioData!.items, hasLength(2));
    expect(result.draft.scenarioData!.locations.single.id, 'id-2');
    expect(result.draft.updatedAtUtc, DateTime.utc(2026, 8, 3, 12));
    expect(result.replayedIdempotentSuccess, isFalse);
  });

  test('adds a batch to Unscheduled without changing day order', () {
    final target = _target();
    final candidate = _candidate('place-1', ScenarioCatalogObjectType.place);
    final request = _request(
      target,
      <ScenarioIntakeCandidate>[candidate],
      dayId: null,
      explicitUnscheduled: true,
    );

    final result = apply(request) as ScenarioIntakeApplied;

    expect(result.draft.scenarioData!.days.single.itemIds, isEmpty);
    expect(result.draft.scenarioData!.unscheduledItemIds, <String>['id-0']);
    expect(result.draft.scenarioData!.items.single.dayId, isNull);
  });

  test('insertion invalidates only an unlocked boundary leg', () {
    final target = _target(withBoundary: true);
    final candidate = _candidate('place-1', ScenarioCatalogObjectType.place);

    final result =
        apply(
              _request(target, <ScenarioIntakeCandidate>[
                candidate,
              ], afterItemId: 'existing-a'),
            )
            as ScenarioIntakeApplied;

    expect(result.draft.scenarioData!.days.single.itemIds, <String>[
      'existing-a',
      'id-0',
      'existing-b',
    ]);
    expect(result.draft.scenarioData!.legs, isEmpty);
  });

  test('locked boundary rejects byte-stably and consumes no ids', () {
    final target = _target(withBoundary: true, lockedBoundary: true);
    final before = ids.count;

    final result =
        apply(
              _request(target, <ScenarioIntakeCandidate>[
                _candidate('place-1', ScenarioCatalogObjectType.place),
              ], afterItemId: 'existing-a'),
            )
            as ScenarioIntakeRejected;

    expect(result.failure, ScenarioIntakeFailure.lockedLegBoundary);
    expect(identical(result.originalDraft, target), isTrue);
    expect(ids.count, before);
  });

  test('stale revision and foreign owner are rejected before mutation', () {
    final target = _target();
    final candidate = _candidate('place-1', ScenarioCatalogObjectType.place);
    final stale =
        apply(
              _request(target, <ScenarioIntakeCandidate>[
                candidate,
              ], revision: 3),
            )
            as ScenarioIntakeRejected;
    final foreignIntent = _intent(<ScenarioIntakeCandidate>[
      candidate,
    ], requesterId: 'user-2');
    final foreign =
        apply(
              _request(target, <ScenarioIntakeCandidate>[
                candidate,
              ], intent: foreignIntent),
            )
            as ScenarioIntakeRejected;

    expect(stale.failure, ScenarioIntakeFailure.revisionConflict);
    expect(foreign.failure, ScenarioIntakeFailure.accessDenied);
    expect(ids.count, 0);
  });

  test('exact catalog object may be added as another occurrence', () {
    final duplicateRef = const ScenarioObjectRef(
      objectId: 'event-existing',
      objectType: ScenarioCatalogObjectType.event,
    );
    final target = _target(existingCatalogRef: duplicateRef);
    final candidate = _candidate(
      duplicateRef.objectId,
      duplicateRef.objectType,
    );
    final accepted =
        apply(_request(target, <ScenarioIntakeCandidate>[candidate]))
            as ScenarioIntakeApplied;
    expect(accepted.draft.scenarioData!.items, hasLength(2));
    expect(
      accepted.draft.scenarioData!.items.map((item) => item.id).toSet(),
      hasLength(2),
    );
  });

  test('fixed Details event needs confirmation before template conversion', () {
    final candidate = _candidate(
      'event-fixed',
      ScenarioCatalogObjectType.event,
      schedule: ScenarioScheduleDraft(
        mode: ScenarioTimeMode.fixed,
        planned: ScenarioDatedPlannedTimeDraft(
          fixedStartAtUtc: DateTime.utc(2026, 8, 8, 17),
        ),
      ),
    );

    final rejected =
        apply(_request(_target(), <ScenarioIntakeCandidate>[candidate]))
            as ScenarioIntakeRejected;
    expect(
      rejected.failure,
      ScenarioIntakeFailure.scheduleConfirmationRequired,
    );

    final accepted =
        apply(
              _request(
                _target(),
                <ScenarioIntakeCandidate>[candidate],
                confirmedScheduleAdjustments: <ScenarioObjectRef>{
                  candidate.ref,
                },
              ),
            )
            as ScenarioIntakeApplied;
    expect(
      accepted.draft.scenarioData!.items.single.schedule.planned,
      isA<ScenarioTemplatePlannedTimeDraft>(),
    );
  });

  test('duplicate refs inside one intent reject the entire batch', () {
    final target = _target();
    final candidate = _candidate('place-1', ScenarioCatalogObjectType.place);
    final intent = _intent(<ScenarioIntakeCandidate>[candidate, candidate]);
    final request = ApplyScenarioObjectIntakeRequest(
      intent: intent,
      targetDraft: target,
      targetCreateDraftId: target.id,
      expectedScenarioRevision: 4,
      placement: ScenarioIntakePlacement(
        dayId: 'day-1',
        orderedRefs: <ScenarioObjectRef>[candidate.ref, candidate.ref],
        roles: <ScenarioObjectRef, ScenarioItemRole>{
          candidate.ref: ScenarioItemRole.mandatory,
        },
      ),
    );

    final result = apply(request) as ScenarioIntakeRejected;

    expect(result.failure, ScenarioIntakeFailure.invalidCandidate);
    expect(identical(result.originalDraft, target), isTrue);
    expect(ids.count, 0);
  });

  test('20 candidates are accepted and 21 are rejected atomically', () {
    final target = _target();
    final twenty = List<ScenarioIntakeCandidate>.generate(
      20,
      (index) => _candidate('place-$index', ScenarioCatalogObjectType.place),
    );

    final accepted = apply(_request(target, twenty));
    expect(accepted, isA<ScenarioIntakeApplied>());
    expect((accepted as ScenarioIntakeApplied).createdItemIds, hasLength(20));

    ids = _Ids();
    apply = ApplyScenarioObjectIntakeUseCase(idGenerator: ids);
    final twentyOne = <ScenarioIntakeCandidate>[
      ...twenty,
      _candidate('place-20', ScenarioCatalogObjectType.place),
    ];
    final rejected =
        apply(_request(target, twentyOne)) as ScenarioIntakeRejected;
    expect(rejected.failure, ScenarioIntakeFailure.batchLimitExceeded);
    expect(ids.count, 0);
  });

  test('invalid late candidate cannot partially add an earlier candidate', () {
    final target = _target();
    final candidates = <ScenarioIntakeCandidate>[
      _candidate('place-1', ScenarioCatalogObjectType.place),
      _candidate('', ScenarioCatalogObjectType.event),
    ];

    final result =
        apply(_request(target, candidates)) as ScenarioIntakeRejected;

    expect(result.failure, ScenarioIntakeFailure.invalidCandidate);
    expect(identical(result.originalDraft, target), isTrue);
    expect(ids.count, 0);
  });

  test('known idempotency receipt returns replay without new ids', () {
    final target = _target();
    final candidate = _candidate('place-1', ScenarioCatalogObjectType.place);
    final request = ApplyScenarioObjectIntakeRequest(
      intent: _intent(<ScenarioIntakeCandidate>[candidate]),
      targetDraft: target,
      targetCreateDraftId: target.id,
      expectedScenarioRevision: 3,
      replayedTargetRevision: 4,
      placement: ScenarioIntakePlacement(
        dayId: 'day-1',
        orderedRefs: <ScenarioObjectRef>[candidate.ref],
        roles: <ScenarioObjectRef, ScenarioItemRole>{
          candidate.ref: ScenarioItemRole.mandatory,
        },
      ),
    );

    final result = apply(request) as ScenarioIntakeApplied;

    expect(result.replayedIdempotentSuccess, isTrue);
    expect(identical(result.draft, target), isTrue);
    expect(result.createdItemIds, isEmpty);
    expect(ids.count, 0);
  });
}

ApplyScenarioObjectIntakeRequest _request(
  CreateDraftEntity target,
  List<ScenarioIntakeCandidate> candidates, {
  ScenarioObjectIntakeIntent? intent,
  String? dayId = 'day-1',
  bool explicitUnscheduled = false,
  String? afterItemId,
  int revision = 4,
  Set<ScenarioObjectRef> confirmedScheduleAdjustments =
      const <ScenarioObjectRef>{},
}) {
  final effectiveIntent = intent ?? _intent(candidates);
  return ApplyScenarioObjectIntakeRequest(
    intent: effectiveIntent,
    targetDraft: target,
    targetCreateDraftId: target.id,
    expectedScenarioRevision: revision,
    placement: ScenarioIntakePlacement(
      dayId: explicitUnscheduled ? null : dayId,
      afterItemId: afterItemId,
      orderedRefs: candidates.map((candidate) => candidate.ref).toList(),
      roles: <ScenarioObjectRef, ScenarioItemRole>{
        for (final candidate in candidates)
          candidate.ref: ScenarioItemRole.mandatory,
      },
      confirmedScheduleAdjustments: confirmedScheduleAdjustments,
    ),
  );
}

ScenarioObjectIntakeIntent _intent(
  List<ScenarioIntakeCandidate> candidates, {
  String requesterId = 'user-1',
}) => ScenarioObjectIntakeIntent(
  contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
  intentId: 'intent-1',
  requesterId: requesterId,
  sourceSurface: ScenarioIntakeSourceSurface.details,
  candidates: candidates,
);

ScenarioIntakeCandidate _candidate(
  String id,
  ScenarioCatalogObjectType type, {
  ScenarioIntakeLocationSnapshot? location,
  ScenarioScheduleDraft? schedule,
}) => ScenarioIntakeCandidate(
  ref: ScenarioObjectRef(objectId: id, objectType: type),
  sourceRevision: 2,
  snapshot: ScenarioObjectSnapshotDraft(
    title: 'Object $id',
    durationMinutes: 60,
    checkedAtUtc: DateTime.utc(2026, 8, 3),
  ),
  sourceStatus: ScenarioSourceStatus.ready,
  location: location,
  schedule: schedule,
);

CreateDraftEntity _target({
  bool withBoundary = false,
  bool lockedBoundary = false,
  ScenarioObjectRef? existingCatalogRef,
}) {
  final existingItems = <ScenarioItemDraft>[];
  final itemIds = <String>[];
  final locations = <ScenarioLocationDraft>[];
  final legs = <ScenarioLegDraft>[];
  if (withBoundary) {
    locations.addAll(const <ScenarioLocationDraft>[
      ScenarioLocationDraft(
        id: 'location-a',
        point: ScenarioGeoPointDraft(latitude: 56.94, longitude: 24.10),
        title: 'A',
        disclosure: ScenarioLocationDisclosure.private,
      ),
      ScenarioLocationDraft(
        id: 'location-b',
        point: ScenarioGeoPointDraft(latitude: 56.95, longitude: 24.11),
        title: 'B',
        disclosure: ScenarioLocationDisclosure.private,
      ),
    ]);
    existingItems.addAll(<ScenarioItemDraft>[
      _existingItem('existing-a', 'location-a'),
      _existingItem('existing-b', 'location-b'),
    ]);
    itemIds.addAll(<String>['existing-a', 'existing-b']);
    legs.add(
      ScenarioLegDraft(
        id: 'leg-a-b',
        dayId: 'day-1',
        fromItemId: 'existing-a',
        toItemId: 'existing-b',
        fromLocationId: 'location-a',
        toLocationId: 'location-b',
        mode: ScenarioTravelMode.car,
        source: ScenarioLegSource.manual,
        status: ScenarioLegStatus.ready,
        cost: const ScenarioCostDraft(),
        lockedByUser: lockedBoundary,
      ),
    );
  } else if (existingCatalogRef != null) {
    existingItems.add(
      _existingItem('existing-catalog', null, catalogRef: existingCatalogRef),
    );
    itemIds.add('existing-catalog');
  }
  final scenario = ScenarioDraftData.defaults().copyWith(
    revision: 4,
    days: <ScenarioDayDraft>[
      ScenarioDayDraft(
        id: 'day-1',
        title: 'Day 1',
        dayIndex: 0,
        itemIds: itemIds,
      ),
    ],
    items: existingItems,
    locations: locations,
    legs: legs,
  );
  return CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'owner@example.test',
    organizerName: 'Owner',
    timezone: 'Europe/Riga',
    currency: 'EUR',
  ).copyWith(
    id: 'scenario-1',
    objectType: CreateObjectType.scenario,
    title: 'Riga day',
    clearEventData: true,
    scenarioData: scenario,
    visibility: VisibilityType.private,
  );
}

ScenarioItemDraft _existingItem(
  String id,
  String? locationId, {
  ScenarioObjectRef? catalogRef,
}) => ScenarioItemDraft(
  id: id,
  dayId: 'day-1',
  startLocationId: locationId,
  endLocationId: locationId,
  kind: ScenarioItemKind.visit,
  source: catalogRef == null
      ? ScenarioTimeBlockSourceDraft(title: id)
      : ScenarioCatalogObjectSourceDraft(
          objectId: catalogRef.objectId,
          objectType: catalogRef.objectType,
          snapshot: const ScenarioObjectSnapshotDraft(title: 'Existing'),
        ),
  sourceStatus: ScenarioSourceStatus.ready,
  schedule: const ScenarioScheduleDraft(
    mode: ScenarioTimeMode.flexible,
    planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
  ),
  durationMinutes: 30,
  cost: const ScenarioCostDraft(),
  orderLocked: false,
  timeLocked: false,
  role: ScenarioItemRole.mandatory,
  selected: true,
  publicNote: '',
);

class _Ids implements IdGenerator {
  int count = 0;

  @override
  String generate() => 'id-${count++}';
}
