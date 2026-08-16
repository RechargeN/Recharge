import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/scenario_object_intake_facade.dart';
import 'package:recharge/app/application/scenario_object_intake_config.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/scenario_object_intake_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/scenario_object_intake_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake_session.dart';

void main() {
  const storage = FlutterSecureStorage();
  late DateTime now;
  late _Ids ids;
  late CreateRepositoryImpl collection;
  late ScenarioObjectIntakeRepositoryImpl intents;
  late ScenarioObjectIntakeFacade facade;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    now = DateTime.utc(2026, 8, 3, 12);
    ids = _Ids(<String>['item-new', 'location-new']);
    collection = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(storage),
      idGenerator: ids,
    );
    intents = ScenarioObjectIntakeRepositoryImpl(
      ScenarioObjectIntakeLocalDataSource(storage),
    );
    facade = ScenarioObjectIntakeFacade(
      intentRepository: intents,
      collectionRepository: collection,
      scenarioCoordinator: ScenarioCreateCoordinator(idGenerator: ids),
      idGenerator: ids,
      clock: () => now,
    );
  });

  test('object is added only to an existing Scenario', () async {
    final intent = _intent();
    final target = _target();
    await collection.saveDraft('user-1', target);
    expect(await facade.begin(intent), hasLength(1));

    final outcome = await facade.apply(
      ownerId: 'user-1',
      intentId: intent.intentId,
      targetDraft: target,
      dayId: 'day-new',
      afterItemId: null,
      orderedRefs: <ScenarioObjectRef>[intent.candidates.single.ref],
      roles: <ScenarioObjectRef, ScenarioItemRole>{
        intent.candidates.single.ref: ScenarioItemRole.mandatory,
      },
      confirmedDuplicates: const <ScenarioObjectRef>{},
      confirmedUnavailable: const <ScenarioObjectRef>{},
      confirmedScheduleAdjustments: const <ScenarioObjectRef>{},
    );

    expect(outcome.status, ScenarioObjectIntakeApplyStatus.applied);
    expect(outcome.createdItemCount, 1);
    expect(outcome.targetRevision, 1);
    final persisted = await collection.loadDraftById(
      ownerId: 'user-1',
      draftId: target.id,
    );
    expect(persisted!.scenarioData!.days.single.itemIds, <String>['item-new']);
    expect(persisted.scenarioData!.locations.single.id, 'location-new');

    final retry = await facade.apply(
      ownerId: 'user-1',
      intentId: intent.intentId,
      targetDraft: target,
      dayId: 'day-new',
      afterItemId: null,
      orderedRefs: <ScenarioObjectRef>[intent.candidates.single.ref],
      roles: <ScenarioObjectRef, ScenarioItemRole>{
        intent.candidates.single.ref: ScenarioItemRole.mandatory,
      },
      confirmedDuplicates: const <ScenarioObjectRef>{},
      confirmedUnavailable: const <ScenarioObjectRef>{},
      confirmedScheduleAdjustments: const <ScenarioObjectRef>{},
    );
    expect(retry.succeeded, isTrue);
    expect(retry.replayed, isTrue);
    expect((await facade.listTargets('user-1')), hasLength(1));
  });

  test('expired intent cannot mutate an existing target', () async {
    final intent = _intent();
    final target = _target();
    await collection.saveDraft('user-1', target);
    await facade.begin(intent);
    now = now.add(const Duration(minutes: 31));

    final outcome = await facade.apply(
      ownerId: 'user-1',
      intentId: intent.intentId,
      targetDraft: target,
      dayId: 'day-new',
      afterItemId: null,
      orderedRefs: <ScenarioObjectRef>[intent.candidates.single.ref],
      roles: <ScenarioObjectRef, ScenarioItemRole>{
        intent.candidates.single.ref: ScenarioItemRole.mandatory,
      },
      confirmedDuplicates: const <ScenarioObjectRef>{},
      confirmedUnavailable: const <ScenarioObjectRef>{},
      confirmedScheduleAdjustments: const <ScenarioObjectRef>{},
    );

    expect(outcome.failure, ScenarioIntakeFailure.intentExpired);
    expect((await facade.listTargets('user-1')).single.scenarioRevision, 0);
  });

  test(
    'kill switch blocks a pending intent without changing target data',
    () async {
      final intent = _intent();
      final target = _target();
      await collection.saveDraft('user-1', target);
      await facade.begin(intent);
      final disabled = ScenarioObjectIntakeFacade(
        intentRepository: intents,
        collectionRepository: collection,
        scenarioCoordinator: ScenarioCreateCoordinator(idGenerator: ids),
        idGenerator: ids,
        clock: () => now,
        config: const ScenarioObjectIntakeConfig(enabled: false),
      );

      final outcome = await disabled.apply(
        ownerId: 'user-1',
        intentId: intent.intentId,
        targetDraft: target,
        dayId: 'day-new',
        afterItemId: null,
        orderedRefs: <ScenarioObjectRef>[intent.candidates.single.ref],
        roles: <ScenarioObjectRef, ScenarioItemRole>{
          intent.candidates.single.ref: ScenarioItemRole.mandatory,
        },
        confirmedDuplicates: const <ScenarioObjectRef>{},
        confirmedUnavailable: const <ScenarioObjectRef>{},
        confirmedScheduleAdjustments: const <ScenarioObjectRef>{},
      );

      expect(outcome.status, ScenarioObjectIntakeApplyStatus.rejected);
      expect(
        await collection.listDrafts(
          ownerId: 'user-1',
          type: CreateObjectType.scenario,
        ),
        hasLength(1),
      );
      expect(
        (await intents.load(
          ownerId: 'user-1',
          intentId: intent.intentId,
        ))!.status,
        ScenarioObjectIntakeSessionStatus.pending,
      );
    },
  );
}

CreateDraftEntity _target() =>
    CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.test',
      organizerName: 'User',
      marketCityId: 'latvia',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ).copyWith(
      id: 'scenario-existing',
      objectType: CreateObjectType.scenario,
      title: 'Latgale day',
      clearEventData: true,
      scenarioData: ScenarioDraftData.defaults().copyWith(
        days: const <ScenarioDayDraft>[
          ScenarioDayDraft(
            id: 'day-new',
            title: 'Day 1',
            dayIndex: 0,
            itemIds: <String>[],
          ),
        ],
      ),
    );

ScenarioObjectIntakeIntent _intent() => ScenarioObjectIntakeIntent(
  contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
  intentId: 'intent-1',
  requesterId: 'user-1',
  sourceSurface: ScenarioIntakeSourceSurface.details,
  candidates: <ScenarioIntakeCandidate>[
    ScenarioIntakeCandidate(
      ref: const ScenarioObjectRef(
        objectId: 'place-1',
        objectType: ScenarioCatalogObjectType.place,
      ),
      snapshot: ScenarioObjectSnapshotDraft(
        title: 'GORS',
        checkedAtUtc: DateTime.utc(2026, 8, 3, 12),
      ),
      sourceStatus: ScenarioSourceStatus.ready,
      location: const ScenarioIntakeLocationSnapshot(
        title: 'GORS',
        point: ScenarioGeoPointDraft(latitude: 56.5099, longitude: 27.3332),
        disclosure: ScenarioLocationDisclosure.public,
      ),
    ),
  ],
);

class _Ids implements IdGenerator {
  _Ids(this._values);

  final List<String> _values;

  @override
  String generate() {
    if (_values.isEmpty) throw StateError('No test ids left.');
    return _values.removeAt(0);
  }
}
