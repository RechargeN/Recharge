import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/scenario_object_intake_facade.dart';
import 'package:recharge/app/application/scenario_object_intake_config.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/scenario_object_intake_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/scenario_object_intake_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
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
    ids = _Ids(<String>['day-new', 'scenario-new', 'item-new', 'location-new']);
    collection = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(storage, activeCurrency: 'EUR'),
      idGenerator: ids,
    );
    intents = ScenarioObjectIntakeRepositoryImpl(
      ScenarioObjectIntakeLocalDataSource(storage),
    );
    facade = ScenarioObjectIntakeFacade(
      intentRepository: intents,
      collectionRepository: collection,
      scenarioCoordinator: ScenarioCreateCoordinator(idGenerator: ids),
      runtimeDefaults: _defaults,
      idGenerator: ids,
      clock: () => now,
    );
  });

  test('new Scenario is persisted only by successful atomic Apply', () async {
    final intent = _intent();
    expect(await facade.begin(intent), isEmpty);
    final target = facade.materializeNewTarget(
      intent: intent,
      organizerEmail: 'user@example.test',
      organizerName: 'User',
      title: 'Latgale day',
    );

    expect(target.id, 'scenario-new');
    expect(target.visibility, VisibilityType.private);
    expect(
      await collection.loadDraftById(ownerId: 'user-1', draftId: target.id),
      isNull,
    );

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

  test('expired intent cannot create an otherwise valid new target', () async {
    final intent = _intent();
    await facade.begin(intent);
    final target = facade.materializeNewTarget(
      intent: intent,
      organizerEmail: 'user@example.test',
      organizerName: 'User',
      title: 'Expired plan',
    );
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
    expect(await facade.listTargets('user-1'), isEmpty);
  });

  test(
    'kill switch blocks a pending intent without changing target data',
    () async {
      final intent = _intent();
      await facade.begin(intent);
      final target = facade.materializeNewTarget(
        intent: intent,
        organizerEmail: 'user@example.test',
        organizerName: 'User',
        title: 'Retained plan',
      );
      final disabled = ScenarioObjectIntakeFacade(
        intentRepository: intents,
        collectionRepository: collection,
        scenarioCoordinator: ScenarioCreateCoordinator(idGenerator: ids),
        runtimeDefaults: _defaults,
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
        isEmpty,
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

const CreateRuntimeDefaults _defaults = CreateRuntimeDefaults(
  marketCityId: 'latvia',
  timezone: 'Europe/Riga',
  country: 'LV',
  city: 'Riga',
  currency: 'EUR',
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
