import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/create_draft_collection_repository.dart';

void main() {
  const storage = FlutterSecureStorage();
  late CreateRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    repository = _repository(storage);
  });

  test('lists multiple same-title Scenario drafts by exact id', () async {
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-a', title: 'Weekend', revision: 1),
    );
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-b', title: 'Weekend', revision: 3),
    );

    final summaries = await repository.listDrafts(
      ownerId: 'user-1',
      type: CreateObjectType.scenario,
    );

    expect(summaries.map((value) => value.id).toSet(), <String>{
      'scenario-a',
      'scenario-b',
    });
    expect(summaries.every((value) => value.title == 'Weekend'), isTrue);
    final scenarioB = summaries.singleWhere(
      (value) => value.id == 'scenario-b',
    );
    expect(scenarioB.scenarioRevision, 3);
    expect(scenarioB.scenarioFormat, ScenarioFormat.city);
    expect(scenarioB.scenarioDateMode, ScenarioDateMode.template);
    expect(scenarioB.scenarioDayCount, 1);
    expect(scenarioB.scenarioActiveItemCount, 0);
    expect(
      (await repository.loadDraftById(
        ownerId: 'user-1',
        draftId: 'scenario-a',
      ))?.scenarioData?.revision,
      1,
    );
  });

  test('collection survives repository and data-source restart', () async {
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-a', revision: 2),
    );

    final restarted = _repository(storage);
    final restored = await restarted.loadDraftById(
      ownerId: 'user-1',
      draftId: 'scenario-a',
    );

    expect(restored?.id, 'scenario-a');
    expect(restored?.scenarioData?.revision, 2);
  });

  test('owner namespace prevents foreign draft access', () async {
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-a', revision: 1),
    );

    expect(
      await repository.loadDraftById(ownerId: 'user-2', draftId: 'scenario-a'),
      isNull,
    );
    expect(
      await repository.listDrafts(
        ownerId: 'user-2',
        type: CreateObjectType.scenario,
      ),
      isEmpty,
    );
  });

  test(
    'legacy singleton Scenario migrates idempotently without deletion',
    () async {
      final legacy = _scenarioDraft(id: 'legacy-scenario', revision: 7);
      final legacyRaw = jsonEncode(
        CreateDraftModel.fromEntity(legacy).toJson(),
      );
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'create_draft_user-1': legacyRaw,
      });
      repository = _repository(storage);

      final first = await repository.listDrafts(
        ownerId: 'user-1',
        type: CreateObjectType.scenario,
      );
      final second = await repository.listDrafts(
        ownerId: 'user-1',
        type: CreateObjectType.scenario,
      );

      expect(first.map((value) => value.id), <String>['legacy-scenario']);
      expect(second, hasLength(1));
      expect(await storage.read(key: 'create_draft_user-1'), legacyRaw);
    },
  );

  test('conditional save is revision-safe and retry is idempotent', () async {
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-a', revision: 4),
    );
    final next = _scenarioDraft(id: 'scenario-a', revision: 5);

    final saved = await repository.saveIfRevision(
      ownerId: 'user-1',
      draft: next,
      expectedScenarioRevision: 4,
      idempotencyKey: 'intent-1',
    );
    final replayed = await repository.saveIfRevision(
      ownerId: 'user-1',
      draft: next,
      expectedScenarioRevision: 4,
      idempotencyKey: 'intent-1',
    );

    expect(saved.status, CreateDraftCollectionSaveStatus.saved);
    expect(saved.persistedRevision, 5);
    expect(replayed.status, CreateDraftCollectionSaveStatus.replayed);
    expect(replayed.persistedRevision, 5);
    expect(
      (await repository.loadDraftById(
        ownerId: 'user-1',
        draftId: 'scenario-a',
      ))?.scenarioData?.revision,
      5,
    );
  });

  test('retry recovers a write interrupted before index receipt', () async {
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-a', revision: 4),
    );
    final next = _scenarioDraft(id: 'scenario-a', revision: 5);
    final nextModel = CreateDraftModel.fromEntity(next);
    final safeOwner = base64Url
        .encode(utf8.encode('user-1'))
        .replaceAll('=', '');
    final safeDraft = base64Url
        .encode(utf8.encode('scenario-a'))
        .replaceAll('=', '');
    final prefix = 'create_draft_collection_v1_${safeOwner}_';
    final payloadJson = jsonEncode(nextModel.toJson());
    await storage.write(key: '${prefix}draft_$safeDraft', value: payloadJson);
    await storage.write(
      key: '${prefix}stage_$safeDraft',
      value: jsonEncode(<String, Object?>{
        'idempotencyKey': 'intent-interrupted',
        'draftId': 'scenario-a',
        'expectedRevision': 4,
        'nextRevision': 5,
        'payloadJson': payloadJson,
      }),
    );

    final recovered = await repository.saveIfRevision(
      ownerId: 'user-1',
      draft: next,
      expectedScenarioRevision: 4,
      idempotencyKey: 'intent-interrupted',
    );
    final replayed = await repository.saveIfRevision(
      ownerId: 'user-1',
      draft: next,
      expectedScenarioRevision: 4,
      idempotencyKey: 'intent-interrupted',
    );

    expect(recovered.status, CreateDraftCollectionSaveStatus.replayed);
    expect(recovered.persistedRevision, 5);
    expect(replayed.status, CreateDraftCollectionSaveStatus.replayed);
    expect(await storage.read(key: '${prefix}stage_$safeDraft'), isNull);
  });

  test(
    'stale expected revision cannot overwrite the stored Scenario',
    () async {
      await repository.saveDraft(
        'user-1',
        _scenarioDraft(id: 'scenario-a', revision: 5),
      );

      final result = await repository.saveIfRevision(
        ownerId: 'user-1',
        draft: _scenarioDraft(id: 'scenario-a', revision: 5),
        expectedScenarioRevision: 4,
        idempotencyKey: 'intent-stale',
      );

      expect(result.status, CreateDraftCollectionSaveStatus.conflict);
      expect(result.persistedRevision, 5);
    },
  );

  test(
    'a new draft can be staged with its immediately previous revision',
    () async {
      final result = await repository.saveIfRevision(
        ownerId: 'user-1',
        draft: _scenarioDraft(id: 'scenario-new', revision: 1),
        expectedScenarioRevision: 0,
        idempotencyKey: 'intent-new',
      );

      expect(result.status, CreateDraftCollectionSaveStatus.saved);
      expect(
        (await repository.loadDraftById(
          ownerId: 'user-1',
          draftId: 'scenario-new',
        ))?.scenarioData?.revision,
        1,
      );
    },
  );

  test('corrupt existing target is never silently overwritten', () async {
    await repository.saveDraft(
      'user-1',
      _scenarioDraft(id: 'scenario-a', revision: 2),
    );
    final values = await storage.readAll();
    final draftKey = values.keys.singleWhere(
      (key) =>
          key.contains('create_draft_collection_v1_') &&
          values[key]!.contains('"id":"scenario-a"'),
    );
    await storage.write(key: draftKey, value: '{broken');

    final result = await repository.saveIfRevision(
      ownerId: 'user-1',
      draft: _scenarioDraft(id: 'scenario-a', revision: 3),
      expectedScenarioRevision: 2,
      idempotencyKey: 'intent-corrupt',
    );

    expect(result.status, CreateDraftCollectionSaveStatus.invalidExistingData);
    expect(
      await repository.loadDraftById(ownerId: 'user-1', draftId: 'scenario-a'),
      isNull,
    );
  });

  test(
    'one corrupt collection entry is isolated from valid summaries',
    () async {
      await repository.saveDraft(
        'user-1',
        _scenarioDraft(id: 'scenario-a', revision: 1),
      );
      await repository.saveDraft(
        'user-1',
        _scenarioDraft(id: 'scenario-b', revision: 1),
      );
      final values = await storage.readAll();
      for (final entry in values.entries) {
        if (entry.key.contains('_draft_') &&
            entry.value.contains('"id":"scenario-a"')) {
          await storage.write(key: entry.key, value: '[]');
        }
      }

      final summaries = await repository.listDrafts(
        ownerId: 'user-1',
        type: CreateObjectType.scenario,
      );

      expect(summaries.map((value) => value.id), <String>['scenario-b']);
    },
  );
}

CreateRepositoryImpl _repository(FlutterSecureStorage storage) =>
    CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(storage),
      idGenerator: const _FixedIdGenerator(),
    );

CreateDraftEntity _scenarioDraft({
  required String id,
  int revision = 0,
  String title = 'Scenario',
  String ownerId = 'user-1',
}) {
  final scenario = ScenarioDraftData.defaults().copyWith(
    revision: revision,
    days: const <ScenarioDayDraft>[
      ScenarioDayDraft(
        id: 'day-1',
        title: 'Day 1',
        dayIndex: 0,
        itemIds: <String>[],
      ),
    ],
  );
  return CreateDraftEntity.defaults(
    organizerId: ownerId,
    organizerEmail: '$ownerId@example.test',
    organizerName: 'Owner',
    timezone: 'Europe/Riga',
    currency: 'EUR',
  ).copyWith(
    id: id,
    objectType: CreateObjectType.scenario,
    title: title,
    clearEventData: true,
    scenarioData: scenario,
    visibility: VisibilityType.private,
  );
}

class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator();

  @override
  String generate() => 'fixed-id';
}
