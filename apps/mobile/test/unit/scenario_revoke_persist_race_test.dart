import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/repositories/scenario_sync_client.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const actor = '00000000-0000-4000-8000-000000000002';
  final revoked = throwsA(
    isA<ScenarioSyncFailure>().having((e) => e.code, 'code', 'access_revoked'),
  );
  CreateDraftEntity draft(String id) =>
      CreateDraftEntity.defaults(
        organizerId: actor,
        organizerEmail: '',
        organizerName: '',
      ).copyWith(
        id: id,
        objectType: CreateObjectType.scenario,
        title: 'shared',
        scenarioData: ScenarioDraftData.defaults(
          timezoneId: 'Europe/Riga',
          currencyCode: 'EUR',
        ).copyWith(revision: 2),
      );
  for (final operation in ['read', 'save']) {
    test(
      'revoke during $operation journal write prevents returning the already received payload',
      () async {
        final id = UlidIdGenerator().generate(), storage = _BlockedStorage();
        final entry = <String, Object?>{
          'scenarioId': id,
          'revision': 1,
          'generation': 7,
          'role': 'editor',
          'status': 'active',
          'draft': ScenarioSyncClient.encode(draft(id)),
        };
        final client = ScenarioSyncClient(
          storage: storage,
          installationId: 'late-$operation',
          currentActor: () => actor,
          invoke: (surface, request) async {
            if (operation == 'save' && surface == 'scenarioCommandV1') {
              storage.blockNext = true;
            }
            return {'kind': 'succeeded', 'entry': entry};
          },
        );
        if (operation == 'save') {
          await client.read(id);
        } else {
          storage.blockNext = true;
        }
        final future = operation == 'read'
            ? client.read(id)
            : client.saveIfRevision(
                ownerId: actor,
                draft: draft(id),
                expectedScenarioRevision: 1,
                idempotencyKey: 'persist-race',
              );
        final checked = expectLater(future, revoked);
        await storage.started.future;
        final cleanup = client.receiveRevoke(id);
        expect(client.cached(id), null);
        storage.release.complete();
        await checked;
        await cleanup;
        expect(client.cached(id), null);
        final restarted = ScenarioSyncClient(
          storage: storage,
          installationId: 'late-$operation',
          currentActor: () => actor,
          invoke: (_, _) async => throw StateError('offline'),
        );
        await restarted.restore();
        expect(restarted.cached(id), null);
      },
    );
  }
  test(
    'queued Expand does not materialize or store an old-account payload under a changed actor',
    () async {
      var current = actor, generated = 0;
      final entered = Completer<void>(),
          release = Completer<Map<String, Object?>>();
      final client = ScenarioSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'switch-expand',
        currentActor: () => current,
        invoke: (_, _) {
          entered.complete();
          return release.future;
        },
      );
      final id = UlidIdGenerator().generate();
      final read = client.read(id);
      final readCheck = expectLater(read, throwsA(isA<ScenarioSyncFailure>()));
      await entered.future;
      final expansion = client.expand(
        intentId: 'queued-expand',
        sourceId: actor,
        sourceRevision: 1,
        source: const {},
        selectedStopIds: {},
        materialize: () async {
          generated++;
          return draft(id);
        },
      );
      final expandCheck = expectLater(
        expansion,
        throwsA(isA<ScenarioSyncFailure>()),
      );
      current = '00000000-0000-4000-8000-000000000003';
      release.complete({'kind': 'rejected', 'code': 'not_found_or_forbidden'});
      await readCheck;
      await expandCheck;
      expect(generated, 0);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
}

class _BlockedStorage extends FlutterSecureStorage {
  bool blockNext = false;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (blockNext) {
      blockNext = false;
      started.complete();
      await release.future;
    }
    await super.write(key: key, value: value);
  }
}
