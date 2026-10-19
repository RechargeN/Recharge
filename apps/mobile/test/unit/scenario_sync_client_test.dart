import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/repositories/scenario_sync_client.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/domain/repositories/create_draft_collection_repository.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = '00000000-0000-4000-8000-000000000001';
  const member = '00000000-0000-4000-8000-000000000002';
  late String id;
  CreateDraftEntity draft() =>
      CreateDraftEntity.defaults(
        organizerId: owner,
        organizerEmail: '',
        organizerName: '',
      ).copyWith(
        id: id,
        objectType: CreateObjectType.scenario,
        title: 'plan',
        scenarioData: ScenarioDraftData.defaults(
          timezoneId: 'Europe/Riga',
          currencyCode: 'EUR',
        ).copyWith(revision: 2),
      );
  Map<String, Object?> entry() => {
    'scenarioId': id,
    'revision': 1,
    'generation': 7,
    'role': 'editor',
    'status': 'active',
    'draft': ScenarioSyncClient.encode(draft()),
  };
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    id = UlidIdGenerator().generate();
  });
  test(
    'ordinary Create save retries one payload but distinguishes competing edits of the same revision',
    () async {
      final remote = _RecordingCreate(),
          repo = CreateRepositoryImpl(
            localDataSource: CreateLocalDataSource(
              const FlutterSecureStorage(),
            ),
            idGenerator: UlidIdGenerator(),
            scenarioSync: remote,
          );
      await repo.saveDraft(owner, draft());
      await repo.saveDraft(owner, draft());
      await repo.saveDraft(owner, draft().copyWith(title: 'another edit'));
      expect(remote.keys[0], remote.keys[1]);
      expect(remote.keys[2], isNot(remote.keys[0]));
      expect(remote.keys.every((k) => k.length <= 128), isTrue);
    },
  );
  test('owner and shared listing consumes all cursor pages', () async {
    var calls = 0;
    final client = ScenarioSyncClient(
      storage: const FlutterSecureStorage(),
      installationId: 'pages',
      currentActor: () => owner,
      invoke: (s, c) async {
        calls++;
        if (calls == 2) expect(c['cursor'], {'page': 1});
        return {
          'kind': 'succeeded',
          'entries': [
            {
              'scenarioId': '$id$calls',
              'title': 'page $calls',
              'revision': 1,
              'updatedAtUtc': '2026-10-18T00:00:00.000Z',
            },
          ],
          'hasMore': calls == 1,
          'cursor': calls == 1 ? {'page': 1} : null,
        };
      },
    );
    expect(
      await client.listDrafts(ownerId: owner, type: CreateObjectType.scenario),
      hasLength(2),
    );
    expect(calls, 2);
  });
  test(
    'historical successful replay cannot roll a newer shared cache backwards',
    () async {
      final client = ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'receipt-order',
        currentActor: () => member,
        invoke: (surface, c) async => {
          'kind': 'succeeded',
          'entry': {
            ...entry(),
            'revision': surface == 'scenarioQueryV1' ? 4 : 2,
          },
        },
      );
      await client.read(id);
      await client.saveIfRevision(
        ownerId: member,
        draft: draft(),
        expectedScenarioRevision: 1,
        idempotencyKey: 'old-receipt',
      );
      expect(client.cached(id)!['revision'], 4);
    },
  );
  test(
    'first shared save loads server generation; transient disable preserves the exact queued command',
    () async {
      final calls = <Map<String, Object?>>[];
      var disabled = true, reads = 0;
      final client = ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'one',
        currentActor: () => member,
        invoke: (surface, c) async {
          if (surface == 'scenarioQueryV1') {
            reads++;
            return {'kind': 'succeeded', 'entry': entry()};
          }
          calls.add(c);
          return disabled
              ? {'kind': 'rejected', 'code': 'feature_disabled'}
              : {'kind': 'succeeded', 'entry': entry()};
        },
      );
      await expectLater(
        client.saveIfRevision(
          ownerId: member,
          draft: draft(),
          expectedScenarioRevision: 1,
          idempotencyKey: 'save-intent',
        ),
        throwsA(
          isA<ScenarioSyncFailure>().having(
            (e) => e.code,
            'code',
            'feature_disabled',
          ),
        ),
      );
      expect(reads, 1);
      expect(calls.single['generation'], 7);
      disabled = false;
      await client.flush();
      expect(calls, hasLength(2));
      expect(calls[1], calls[0]);
    },
  );
  test(
    'journal capacity fails before dispatch and preserves the previous durable journal',
    () async {
      var sent = 0;
      final client = ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'small',
        currentActor: () => owner,
        journalByteLimit: 100,
        invoke: (s, c) async {
          sent++;
          return {'kind': 'succeeded'};
        },
      );
      await expectLater(
        client.saveIfRevision(
          ownerId: owner,
          draft: draft().copyWith(
            scenarioData: draft().scenarioData!.copyWith(revision: 1),
          ),
          expectedScenarioRevision: 0,
          idempotencyKey: 'capacity-intent',
        ),
        throwsA(
          isA<ScenarioSyncFailure>().having(
            (e) => e.code,
            'code',
            'journal_capacity_exceeded',
          ),
        ),
      );
      expect(sent, 0);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
  test(
    'a revoke received while a read is in flight closes cache before the response is published',
    () async {
      final response = Completer<Map<String, Object?>>(),
          started = Completer<void>();
      final client = ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'late',
        currentActor: () => member,
        invoke: (s, c) {
          started.complete();
          return response.future;
        },
      );
      final reading = client.read(id);
      await started.future;
      final revoked = client.receiveRevoke(id);
      expect(client.cached(id), isNull);
      response.complete({'kind': 'succeeded', 'entry': entry()});
      await expectLater(
        reading,
        throwsA(
          isA<ScenarioSyncFailure>().having(
            (e) => e.code,
            'code',
            'access_revoked',
          ),
        ),
      );
      await revoked;
      expect(client.cached(id), isNull);
    },
  );
  test(
    'account switch hides in-flight shared content and another account cannot flush its queue',
    () async {
      var actor = member;
      final response = Completer<Map<String, Object?>>(),
          started = Completer<void>();
      final client = ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'switch',
        currentActor: () => actor,
        invoke: (s, c) {
          started.complete();
          return response.future;
        },
      );
      final reading = client.read(id);
      await started.future;
      actor = owner;
      response.complete({'kind': 'succeeded', 'entry': entry()});
      await expectLater(
        reading,
        throwsA(
          isA<ScenarioSyncFailure>().having(
            (e) => e.code,
            'code',
            'actor_changed',
          ),
        ),
      );
      expect(client.cached(id), isNull);
      await client.restore();
      expect(client.cached(id), isNull);
    },
  );
  test(
    'acknowledged Expand keeps a compact replay receipt instead of another draft payload',
    () async {
      final requests = <Map<String, Object?>>[];
      var generated = 0;
      ScenarioSyncClient client() => ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'compact',
        currentActor: () => owner,
        invoke: (s, c) async {
          requests.add(c);
          return {
            'kind': 'succeeded',
            'entry': {...entry(), 'role': 'owner', 'generation': 0},
          };
        },
      );
      Future<Map<String, Object?>> expand(ScenarioSyncClient c) => c.expand(
        intentId: 'expand-intent',
        sourceId: owner,
        sourceRevision: 1,
        source: const {'id': owner},
        selectedStopIds: {},
        materialize: () async {
          generated++;
          return draft();
        },
      );
      await expand(client());
      final stored =
          jsonDecode(
                (await const FlutterSecureStorage().readAll()).values.single,
              )
              as Map;
      final completed = (stored['completed'] as Map)['expand-intent'] as Map;
      expect(completed.containsKey('draft'), isFalse);
      expect(completed['replayHash'], matches(RegExp(r'^[a-f0-9]{64}$')));
      await expand(client());
      expect(generated, 1);
      expect(requests.last.containsKey('draft'), isFalse);
    },
  );
}

class _RecordingCreate implements CreateDraftCollectionRepository {
  final keys = <String>[];
  @override
  Future<CreateDraftCollectionSaveResult> saveIfRevision({
    required String ownerId,
    required CreateDraftEntity draft,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    return const CreateDraftCollectionSaveResult(
      status: CreateDraftCollectionSaveStatus.saved,
    );
  }

  @override
  Future<CreateDraftEntity?> loadDraftById({
    required String ownerId,
    required String draftId,
  }) async => null;
  @override
  Future<List<CreateDraftSummary>> listDrafts({
    required String ownerId,
    required CreateObjectType type,
  }) async => [];
}
