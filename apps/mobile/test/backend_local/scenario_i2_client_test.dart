import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/scenario_sync_composition.dart';
import 'package:recharge/app/adapters/legacy_quick_plan_conversion_adapter.dart';
import 'package:recharge/app/application/planning_conversion_facade.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/quick_plan_conversion_coordinator.dart';
import 'package:recharge/features/create/application/scenario_conversion_handoff_store.dart';
import 'package:recharge/features/create/data/datasources/quick_plan_conversion_memory_datasource.dart';
import 'package:recharge/features/create/data/repositories/scenario_sync_client.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/create_draft_collection_repository.dart';
import 'package:recharge/features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart';
import 'package:recharge/features/scenarios/data/quick_plan_codec.dart';
import 'support/stand_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['RECHARGE_I2_LOCAL'] == '1';
  if (enabled) HttpOverrides.global = null;
  test(
    'I2 two real Flutter clients share/revoke and recover one Expand intent',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('i2-client-');
      addTearDown(() => temp.delete(recursive: true));
      Future<(ScenarioInvoke, String)> transport(
        String uid,
        String installation,
      ) async {
        final binding = BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        );
        final http = CountingClient();
        addTearDown(http.close);
        final runtime = await BookingTransportRuntimeFactory(
          endpoint: binding.endpoint,
          client: http,
          tokens: AuthEmulatorTokenProvider(uid),
          sessions: FileSessionStore(File('${temp.path}/$installation.json')),
          installations: FixedInstallationId(installation),
          supportDirectory: () => Directory(
            '${temp.path}/$installation-support',
          ).create(recursive: true),
        ).create();
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
        final invoke = scenarioSyncInvoke(
          binding: binding,
          runtime: () async => runtime,
        );
        final identity = await invoke('quickPlanQueryV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'planId': const Uuid().v4(),
        });
        expect(identity['kind'], 'succeeded', reason: identity.toString());
        return (invoke, identity['ownerId']! as String);
      }

      final (invokeA, owner) = await transport(
        Platform.environment['RECHARGE_I2_OWNER']!,
        'i2-mobile-owner',
      );
      final (invokeB, member) = await transport(
        Platform.environment['RECHARGE_I2_MEMBER']!,
        'i2-mobile-member',
      );
      final a = ScenarioSyncClient(
        invoke: invokeA,
        storage: const FlutterSecureStorage(),
        installationId: 'i2-a',
        currentActor: () => owner,
      );
      final b = ScenarioSyncClient(
        invoke: invokeB,
        storage: const FlutterSecureStorage(),
        installationId: 'i2-b',
        currentActor: () => member,
      );
      await a.restore();
      await b.restore();
      final ids = UlidIdGenerator(), id = ids.generate();
      CreateDraftEntity draft(String title, int rev) =>
          CreateDraftEntity.defaults(
            organizerId: owner,
            organizerEmail: '',
            organizerName: '',
          ).copyWith(
            id: id,
            objectType: CreateObjectType.scenario,
            title: title,
            scenarioData: ScenarioDraftData.defaults(
              timezoneId: 'Europe/Riga',
              currencyCode: 'EUR',
            ).copyWith(revision: rev),
          );
      final createRepository = CreateRepositoryImpl(
        localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
        idGenerator: ids,
        scenarioSync: a,
      );
      final saved = await createRepository.saveIfRevision(
        ownerId: owner,
        draft: draft('shared', 1),
        expectedScenarioRevision: 0,
        idempotencyKey: const Uuid().v4(),
      );
      expect(saved.persistedRevision, 1);
      // Canonical contract boundary through real HTTP and the existing Create port:
      // 30 days, 200 scheduled + 50 unscheduled items, larger than the former 128 KiB cap.
      final dayIds = List.generate(30, (_) => ids.generate());
      final itemIds = List.generate(250, (_) => ids.generate());
      final largeJson = ScenarioDraftMapper.toJson(
        draft('large', 1).scenarioData!,
      );
      largeJson['days'] = List.generate(
        30,
        (day) => {
          'id': dayIds[day],
          'title': 'Day ${day + 1}',
          'dayIndex': day,
          'itemIds': [for (var i = day; i < 200; i += 30) itemIds[i]],
        },
      );
      largeJson['items'] = List.generate(
        250,
        (i) => {
          'id': itemIds[i],
          'dayId': i < 200 ? dayIds[i % 30] : null,
          'kind': 'time_block',
          'source': {
            'type': 'time_block',
            'title': 'Stop $i',
            'categoryId': null,
          },
          'durationMinutes': 30,
          'role': 'mandatory',
          'selected': true,
          'publicNote': 'Stop $i '.padRight(180, 'x'),
        },
      );
      largeJson['unscheduledItemIds'] = itemIds.skip(200).toList();
      final largeDraft = draft('large', 1).copyWith(
        id: ids.generate(),
        scenarioData: ScenarioDraftMapper.fromJson(largeJson),
      );
      final bytes = utf8
          .encode(jsonEncode(ScenarioSyncClient.encode(largeDraft)))
          .length;
      expect(bytes, greaterThan(128 * 1024));
      expect(bytes, lessThan(240 * 1024));
      expect(
        (await createRepository.saveIfRevision(
          ownerId: owner,
          draft: largeDraft,
          expectedScenarioRevision: 0,
          idempotencyKey: const Uuid().v4(),
        )).persistedRevision,
        1,
      );
      final largeEntry = await a.read(largeDraft.id);
      final persisted = (largeEntry['draft'] as Map)['scenario'] as Map;
      expect(persisted['days'], hasLength(30));
      expect(persisted['items'], hasLength(250));
      expect(persisted['unscheduledItemIds'], hasLength(50));
      expect(
        (persisted['items'] as List).last['publicNote'],
        largeDraft.scenarioData!.items.last.publicNote,
      );
      final inviteId = const Uuid().v4();
      expect(
        (await a.membership(
          scenarioId: id,
          commandType: 'invite',
          intentId: const Uuid().v4(),
          expectedRevision: 0,
          recipientId: member,
          role: 'editor',
          inviteId: inviteId,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ))['kind'],
        'succeeded',
      );
      await expectLater(b.read(id), throwsA(isA<ScenarioSyncFailure>()));
      // Pending denial closes cache; accept is an explicit new grant, using a fresh session client.
      final accepted = await invokeB('scenarioCommandV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'actorContext': member,
        'idempotencyKey': const Uuid().v4(),
        'commandType': 'accept',
        'scenarioId': id,
        'expectedRevision': 0,
        'generation': 0,
        'inviteId': inviteId,
      });
      expect(accepted['kind'], 'succeeded', reason: accepted.toString());
      final c = ScenarioSyncClient(
        invoke: invokeB,
        storage: const FlutterSecureStorage(),
        installationId: 'i2-c',
        currentActor: () => member,
      );
      await c.restore();
      expect(c.cached(id), isNull);
      final editKey = const Uuid().v4();
      expect(
        (await c.saveIfRevision(
          ownerId: member,
          draft: draft('member edit', 2),
          expectedScenarioRevision: 1,
          idempotencyKey: editKey,
        )).persistedRevision,
        2,
      );
      expect((await c.read(id))['role'], 'editor');
      expect((await a.read(id))['revision'], 2);
      // One revision, both delivery orders: the first save wins, the other is
      // a conflict whose payload survives a client restart for explicit review.
      final orders = [
        (a, owner, c, invokeB, 'i2-c', member),
        (c, member, a, invokeA, 'i2-a', owner),
      ];
      for (var i = 0; i < orders.length; i++) {
        final (
          first,
          firstActor,
          second,
          secondInvoke,
          secondInstall,
          secondActor,
        ) = orders[i];
        final base = 2 + i, lostKey = const Uuid().v4();
        expect(
          (await first.saveIfRevision(
            ownerId: firstActor,
            draft: draft('winner $i', base + 1),
            expectedScenarioRevision: base,
            idempotencyKey: const Uuid().v4(),
          )).status,
          CreateDraftCollectionSaveStatus.saved,
        );
        expect(
          (await second.saveIfRevision(
            ownerId: secondActor,
            draft: draft('rejected $i', base + 1),
            expectedScenarioRevision: base,
            idempotencyKey: lostKey,
          )).status,
          CreateDraftCollectionSaveStatus.conflict,
        );
        final stored = await a.read(id);
        expect(stored['revision'], base + 1);
        expect((stored['draft'] as Map)['title'], 'winner $i');
        final reopened = ScenarioSyncClient(
          invoke: secondInvoke,
          storage: const FlutterSecureStorage(),
          installationId: secondInstall,
          currentActor: () => secondActor,
        );
        await reopened.restore();
        await reopened.read(id);
        final payload = reopened.conflicts.singleWhere(
          (v) => (v['command'] as Map)['idempotencyKey'] == lostKey,
        );
        expect(payload['code'], 'revision_conflict');
        expect(
          ((payload['command'] as Map)['draft'] as Map)['title'],
          'rejected $i',
        );
      }
      var disconnected = true;
      final queued = ScenarioSyncClient(
        invoke: (surface, command) async {
          if (disconnected) throw const SocketException('offline');
          return invokeB(surface, command);
        },
        storage: const FlutterSecureStorage(),
        installationId: 'i2-c',
        currentActor: () => member,
      );
      await queued.restore();
      await expectLater(
        queued.saveIfRevision(
          ownerId: member,
          draft: draft('queued before revoke', 5),
          expectedScenarioRevision: 4,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(
        (await a.membership(
          scenarioId: id,
          commandType: 'revoke',
          intentId: const Uuid().v4(),
          expectedRevision: 2,
          recipientId: member,
        ))['kind'],
        'succeeded',
      );
      await c.receiveRevoke(id);
      disconnected = false;
      await queued.flush();
      expect(queued.cached(id), isNull);
      expect(queued.conflicts, isEmpty);
      expect(c.cached(id), isNull);
      await expectLater(
        c.saveIfRevision(
          ownerId: member,
          draft: draft('offline', 5),
          expectedScenarioRevision: 4,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ScenarioSyncFailure>()),
      );
      expect((await a.read(id))['revision'], 4);
      await expectLater(c.read(id), throwsA(isA<ScenarioSyncFailure>()));

      // Re-invite has a new membership generation; the prior successful receipt stays fenced.
      final reinvite = const Uuid().v4();
      expect(
        (await a.membership(
          scenarioId: id,
          commandType: 'invite',
          intentId: const Uuid().v4(),
          expectedRevision: 3,
          recipientId: member,
          role: 'viewer',
          inviteId: reinvite,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ))['kind'],
        'succeeded',
      );
      final reaccepted = await invokeB('scenarioCommandV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'actorContext': member,
        'idempotencyKey': const Uuid().v4(),
        'commandType': 'accept',
        'scenarioId': id,
        'expectedRevision': 0,
        'generation': 0,
        'inviteId': reinvite,
      });
      expect(reaccepted['generation'], greaterThan(1));
      expect((await c.read(id))['role'], 'viewer');
      final staleReplay = await invokeB('scenarioCommandV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'actorContext': member,
        'idempotencyKey': editKey,
        'commandType': 'save',
        'scenarioId': id,
        'expectedRevision': 1,
        'generation': 1,
        'draft': ScenarioSyncClient.encode(draft('member edit', 2)),
      });
      expect(staleReplay['code'], 'access_revoked');
      expect(
        (await c.saveIfRevision(
          ownerId: member,
          draft: draft('viewer forbidden', 5),
          expectedScenarioRevision: 4,
          idempotencyKey: const Uuid().v4(),
        )).status,
        CreateDraftCollectionSaveStatus.conflict,
      );
      // Delay an actual authorized HTTP response, commit revoke, then deliver it late.
      final responseReady = Completer<void>(),
          releaseResponse = Completer<void>();
      final late = ScenarioSyncClient(
        invoke: (surface, request) async {
          final response = await invokeB(surface, request);
          expect(response['kind'], 'succeeded');
          responseReady.complete();
          await releaseResponse.future;
          return response;
        },
        storage: const FlutterSecureStorage(),
        installationId: 'i2-late-http',
        currentActor: () => member,
      );
      final inFlight = late.read(id);
      final rejectedLate = expectLater(
        inFlight,
        throwsA(
          isA<ScenarioSyncFailure>().having(
            (e) => e.code,
            'code',
            'access_revoked',
          ),
        ),
      );
      await responseReady.future;
      expect(
        (await a.membership(
          scenarioId: id,
          commandType: 'revoke',
          intentId: const Uuid().v4(),
          expectedRevision: 5,
          recipientId: member,
        ))['kind'],
        'succeeded',
      );
      final clearLate = late.receiveRevoke(id);
      expect(late.cached(id), null);
      releaseResponse.complete();
      await rejectedLate;
      await clearLate;
      expect(late.cached(id), null);
      await expectLater(
        invokeB('scenarioQueryV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'scenarioId': id,
        }).then((r) {
          expect(r['code'], 'not_found_or_forbidden');
        }),
        completes,
      );
      // Actual clients: editor edit / owner delete with a shared revision in both delivery orders.
      for (final deleteFirst in [false, true]) {
        final doomedId = ids.generate(), invitation = const Uuid().v4();
        final doomed = draft('delete race', 1).copyWith(id: doomedId);
        await a.saveIfRevision(
          ownerId: owner,
          draft: doomed,
          expectedScenarioRevision: 0,
          idempotencyKey: const Uuid().v4(),
        );
        await a.membership(
          scenarioId: doomedId,
          commandType: 'invite',
          intentId: const Uuid().v4(),
          expectedRevision: 0,
          recipientId: member,
          role: 'editor',
          inviteId: invitation,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
        await invokeB('scenarioCommandV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'actorContext': member,
          'idempotencyKey': const Uuid().v4(),
          'commandType': 'accept',
          'scenarioId': doomedId,
          'expectedRevision': 0,
          'generation': 0,
          'inviteId': invitation,
        });
        final deletion = {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'actorContext': owner,
          'idempotencyKey': const Uuid().v4(),
          'commandType': 'delete',
          'scenarioId': doomedId,
          'expectedRevision': 1,
          'generation': 0,
        };
        if (deleteFirst) {
          expect(
            (await invokeA('scenarioCommandV1', deletion))['kind'],
            'succeeded',
          );
          await expectLater(
            b.saveIfRevision(
              ownerId: member,
              draft: doomed.copyWith(
                title: 'late edit',
                scenarioData: doomed.scenarioData!.copyWith(revision: 2),
              ),
              expectedScenarioRevision: 1,
              idempotencyKey: const Uuid().v4(),
            ),
            throwsA(isA<ScenarioSyncFailure>()),
          );
        } else {
          expect(
            (await b.saveIfRevision(
              ownerId: member,
              draft: doomed.copyWith(
                title: 'wins CAS',
                scenarioData: doomed.scenarioData!.copyWith(revision: 2),
              ),
              expectedScenarioRevision: 1,
              idempotencyKey: const Uuid().v4(),
            )).status,
            CreateDraftCollectionSaveStatus.saved,
          );
          expect(
            (await invokeA('scenarioCommandV1', deletion))['code'],
            'revision_conflict',
          );
          expect(
            (await invokeA('scenarioCommandV1', {
              ...deletion,
              'requestId': const Uuid().v4(),
              'idempotencyKey': const Uuid().v4(),
              'expectedRevision': 2,
            }))['kind'],
            'succeeded',
          );
        }
        await expectLater(
          b.read(doomedId),
          throwsA(isA<ScenarioSyncFailure>()),
        );
        expect(b.cached(doomedId), null);
      }

      final sourceId = const Uuid().v4(), stopId = const Uuid().v4();
      final source = <String, Object?>{
        'id': sourceId,
        'revision': 0,
        'mood': 'calm',
        'maxDurationMinutes': 150,
        'freeOnly': false,
        'walkingOnly': true,
        'sourcePrompt': 'source',
        'currencyCode': 'EUR',
        'steps': [
          {
            'id': stopId,
            'sourceObjectId': null,
            'sourceObjectType': null,
            'title': 'Riga stop',
            'subtitle': '',
            'category': 'park',
            'durationMinutes': 30,
            'distanceKm': 0.0,
            'priceAmount': {'minorUnits': 0, 'currencyCode': 'EUR'},
            'isFree': true,
            'latitude': 56.95,
            'longitude': 24.1,
          },
        ],
      };
      expect(
        (await invokeA('quickPlanCommandV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'ownerContext': owner,
          'idempotencyKey': const Uuid().v4(),
          'commandType': 'save',
          'planId': sourceId,
          'expectedRevision': 0,
          'plan': source,
        }))['kind'],
        'succeeded',
      );
      // Exercise the existing facade/coordinator/use case, not a second converter.
      final memory = InMemoryQuickPlanConversionSource(),
          handoff = ScenarioConversionHandoffStore();
      const defaults = CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      );
      final facade = PlanningConversionFacade(
        adapter: const LegacyQuickPlanConversionAdapter(),
        source: memory,
        coordinator: QuickPlanConversionCoordinator(
          expand: ExpandQuickPlanToScenarioUseCase(
            source: memory,
            idGenerator: ids,
          ),
          idGenerator: ids,
          runtimeDefaults: defaults,
        ),
        handoffStore: handoff,
        runtimeDefaults: defaults,
      );
      var materializations = 0;
      Future<CreateDraftEntity> materialize([String? requester]) async {
        materializations++;
        final result = await facade.expand(
          ExpandLegacyQuickPlanRequest(
            draft: decodeQuickPlan({...source, 'revision': 1}),
            requesterId: requester ?? owner,
            requesterEmail: '',
            requesterName: '',
            scenarioTitle: 'Expanded',
            selectedStopIds: {stopId},
            copyPrivateNotes: false,
          ),
        );
        final value = handoff.take(result.handoffId!)!;
        return value.copyWith(
          scenarioData: value.scenarioData!.copyWith(revision: 1),
        );
      }

      // I1 invited read is deliberately insufficient for Expand on I2's creation path.
      final quickInvite = const Uuid().v4();
      final quickAccess = <String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'ownerContext': owner,
        'idempotencyKey': const Uuid().v4(),
        'commandType': 'invite',
        'planId': sourceId,
        'expectedRevision': 0,
        'planOwnerId': owner,
        'targetUserId': member,
        'invitationId': quickInvite,
        'generation': 0,
        'previousStatus': 'none',
      };
      expect(
        (await invokeA('quickPlanCommandV1', quickAccess))['kind'],
        'succeeded',
      );
      final quickAccept = Map<String, Object?>.from(quickAccess)
        ..remove('previousStatus');
      quickAccept.addAll({
        'requestId': const Uuid().v4(),
        'ownerContext': member,
        'idempotencyKey': const Uuid().v4(),
        'commandType': 'accept',
        'generation': 1,
      });
      expect(
        (await invokeB('quickPlanCommandV1', quickAccept))['kind'],
        'succeeded',
      );
      expect(
        (await invokeB('quickPlanQueryV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'planId': sourceId,
          'planOwnerId': owner,
          'invitationId': quickInvite,
          'generation': 1,
        }))['kind'],
        'succeeded',
      );
      final deniedExpansion = await b.expand(
        intentId: const Uuid().v4(),
        sourceId: sourceId,
        sourceRevision: 1,
        source: source,
        selectedStopIds: {stopId},
        materialize: () => materialize(member),
      );
      expect(deniedExpansion['code'], 'source_unavailable');
      final beforeOwnerMaterializations = materializations;
      var drop = true;
      final lossy = ScenarioSyncClient(
        invoke: (surface, request) async {
          final r = await invokeA(surface, request);
          if (drop && request['commandType'] == 'expand') {
            drop = false;
            throw const SocketException('lost response');
          }
          return r;
        },
        storage: const FlutterSecureStorage(),
        installationId: 'i2-expand',
        currentActor: () => owner,
      );
      final intent = const Uuid().v4();
      Future<Map<String, Object?>> expand(
        ScenarioSyncClient client,
        String key,
      ) => client.expand(
        intentId: key,
        sourceId: sourceId,
        sourceRevision: 1,
        source: source,
        selectedStopIds: {stopId},
        materialize: materialize,
      );
      await expectLater(expand(lossy, intent), throwsA(isA<SocketException>()));
      var compactReplays = 0;
      final restarted = ScenarioSyncClient(
        invoke: (surface, request) async {
          if (request['replayHash'] != null) {
            compactReplays++;
            expect(request.containsKey('draft'), isFalse);
          }
          return invokeA(surface, request);
        },
        storage: const FlutterSecureStorage(),
        installationId: 'i2-expand',
        currentActor: () => owner,
      );
      final result = await expand(restarted, intent);
      expect(result['kind'], 'succeeded', reason: result.toString());
      expect(materializations, beforeOwnerMaterializations + 1);
      final entry = result['entry'] as Map,
          target = entry['scenarioId'] as String;
      expect(target, matches(RegExp(r'^[0-7][0-9A-HJKMNP-TV-Z]{25}$')));
      expect(target, isNot(sourceId));
      expect((await expand(restarted, intent))['entry'], entry);
      expect(materializations, beforeOwnerMaterializations + 1);
      expect(compactReplays, 1);
      final fresh = await expand(restarted, const Uuid().v4());
      expect((fresh['entry'] as Map)['scenarioId'], isNot(target));
      expect(
        (await invokeA('quickPlanQueryV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'planId': sourceId,
        }))['kind'],
        'succeeded',
      );
      expect(
        (await invokeA('quickPlanCommandV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'ownerContext': owner,
          'idempotencyKey': const Uuid().v4(),
          'commandType': 'delete',
          'planId': sourceId,
          'expectedRevision': 1,
        }))['kind'],
        'succeeded',
      );
      expect((await expand(restarted, intent))['code'], 'source_unavailable');
      // Source authority is rechecked on replay, but its deletion never revokes
      // this independently owned Scenario or closes its valid local cache.
      expect(restarted.cached(target), isNotNull);
      expect((await restarted.read(target))['scenarioId'], target);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
