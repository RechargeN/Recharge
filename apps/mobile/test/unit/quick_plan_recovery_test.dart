import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/scenarios/data/quick_plan_sync_client.dart';
import 'package:recharge/features/scenarios/application/controllers/scenario_builder_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'one refresh drains later pending work after a terminal conflict',
    () async {
      bool offline = true;
      final sent = <String>[];
      final controller = ScenarioBuilderController();
      addTearDown(controller.dispose);
      final p = controller.state.draft;
      controller.reset();
      final q = controller.state.draft;
      final client = QuickPlanSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'device',
        currentOwner: () => 'A',
        invoke: (surface, request) async {
          if (offline) throw StateError('offline');
          if (surface == 'quickPlanQueryV1') {
            return {'kind': 'succeeded', 'ownerId': 'A', 'entry': null};
          }
          sent.add(request['planId']! as String);
          return request['planId'] == p.id
              ? {'kind': 'rejected', 'code': 'revision_conflict'}
              : {'kind': 'succeeded'};
        },
      );
      await expectLater(client.save(p, expectedRevision: 0), throwsStateError);
      await expectLater(client.save(q, expectedRevision: 0), throwsStateError);
      offline = false;
      await expectLater(client.refresh(p.id), throwsA(isA<QuickPlanFailure>()));
      expect(sent, [p.id, q.id]);
      expect(client.hasPending(p.id), false);
      expect(client.hasPending(q.id), false);
      expect(client.conflicts, hasLength(1));
    },
  );
  test(
    'controller refresh recovers a lost save before the next edit',
    () async {
      Map<String, Object?>? entry;
      final receipts = <String, Map<String, Object?>>{};
      bool lose = true;
      final revisions = <int>[];
      final client = QuickPlanSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'device',
        currentOwner: () => 'A',
        invoke: (surface, request) async {
          if (surface == 'quickPlanQueryV1') {
            return {'kind': 'succeeded', 'ownerId': 'A', 'entry': entry};
          }
          revisions.add(request['expectedRevision']! as int);
          final key = request['idempotencyKey']! as String;
          if (!receipts.containsKey(key)) {
            final rev = entry?['revision'] as int? ?? 0;
            if (request['expectedRevision'] != rev) {
              return {'kind': 'rejected', 'code': 'revision_conflict'};
            }
            entry = {
              'planId': request['planId'],
              'revision': rev + 1,
              'status': 'active',
              'plan': request['plan'],
            };
            receipts[key] = {'kind': 'succeeded'};
          }
          if (lose) {
            lose = false;
            throw StateError('lost response');
          }
          return receipts[key]!;
        },
      );
      final controller = ScenarioBuilderController(repository: client);
      addTearDown(controller.dispose);
      await controller.sync(save: true);
      expect(controller.syncError, isNotNull);
      await controller.sync();
      expect(controller.syncError, null);
      controller.setWalkingOnly(false);
      await controller.sync(save: true);
      expect(controller.syncError, null);
      expect(revisions, [0, 0, 1]);
      expect(entry!['revision'], 2);
    },
  );
}
