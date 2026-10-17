import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/scenarios/data/quick_plan_sync_client.dart';
import 'package:recharge/features/scenarios/domain/entities/scenario_draft_entity.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ScenarioDraftEntity plan() => ScenarioDraftEntity(
    id: const Uuid().v4(),
    revision: 0,
    mood: ScenarioMood.calm,
    maxDurationMinutes: 120,
    freeOnly: true,
    walkingOnly: true,
    sourcePrompt: 'owner A private draft',
    currencyCode: 'EUR',
    steps: const [],
  );
  test(
    'save waiting behind an in-flight request retains its initiating owner',
    () async {
      String? owner = 'A';
      final entered = Completer<void>(), release = Completer<void>();
      int commands = 0;
      final client = QuickPlanSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'device',
        currentOwner: () => owner,
        invoke: (surface, request) async {
          if (surface == 'quickPlanCommandV1') {
            commands++;
            return {'kind': 'succeeded'};
          }
          if (!entered.isCompleted) entered.complete();
          await release.future;
          return {'kind': 'succeeded', 'ownerId': 'A', 'entry': null};
        },
      );
      final p = plan(), q = plan();
      final first = client.save(p, expectedRevision: 0);
      final firstCheck = expectLater(first, throwsA(isA<QuickPlanFailure>()));
      await entered.future;
      final queued = client.save(q, expectedRevision: 0);
      final queuedCheck = expectLater(queued, throwsA(isA<QuickPlanFailure>()));
      owner = 'B';
      release.complete();
      await Future.wait([firstCheck, queuedCheck]);
      expect(commands, 0);
      owner = 'A';
      await client.restore();
      expect(client.cached(p.id)!.sourcePrompt, p.sourcePrompt);
      expect(
        client.cached(q.id),
        null,
      ); // Never persisted or dispatched under B.
    },
  );
  test(
    'server account mismatch preserves pending and reveals no other cache',
    () async {
      String? owner = 'A';
      int commands = 0;
      final client = QuickPlanSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'device',
        currentOwner: () => owner,
        invoke: (surface, request) async {
          if (surface == 'quickPlanCommandV1') commands++;
          return {'kind': 'succeeded', 'ownerId': 'B', 'entry': null};
        },
      );
      final p = plan();
      await expectLater(
        client.save(p, expectedRevision: 0),
        throwsA(isA<QuickPlanFailure>()),
      );
      expect(commands, 0);
      owner = null;
      expect(client.cached(p.id), null);
      owner = 'A';
      await client.restore();
      expect(client.cached(p.id), isNotNull);
    },
  );
}
