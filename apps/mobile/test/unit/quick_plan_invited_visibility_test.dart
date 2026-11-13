import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/scenarios/application/controllers/scenario_builder_controller.dart';
import 'package:recharge/features/scenarios/data/quick_plan_codec.dart';
import 'package:recharge/features/scenarios/data/quick_plan_sync_client.dart';
import 'package:recharge/features/scenarios/domain/repositories/quick_plan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'invited content closes on failed revalidation, background and account switch; late response cannot restore it',
    () async {
      String? actor = 'viewer';
      var offline = false;
      Completer<Map<String, Object?>>? response;
      final seed = ScenarioBuilderController();
      final draft = seed.state.draft;
      seed.dispose();
      final client = QuickPlanSyncClient(
        storage: const FlutterSecureStorage(),
        installationId: 'viewer',
        currentOwner: () => actor,
        invoke: (_, req) async {
          if (offline) throw const SocketException('offline');
          if (response != null) return response.future;
          return {
            'kind': 'succeeded',
            'ownerId': actor,
            'entry': {'status': 'active', 'plan': encodeQuickPlan(draft)},
          };
        },
      );
      final controller = ScenarioBuilderController(repository: client);
      addTearDown(controller.dispose);
      final g = QuickPlanInvitation(
        planId: draft.id,
        ownerId: 'owner',
        inviteeId: 'viewer',
        invitationId: 'invite',
        generation: 1,
        status: 'accepted',
      );
      await controller.openInvited(g);
      expect(controller.invitedPlan, isNotNull);
      expect(client.cached(draft.id), null);
      final own = controller.state.draft;
      controller.setFreeOnly(!own.freeOnly);
      expect(controller.state.draft, own);
      offline = true;
      await controller.sync();
      expect(controller.invitedPlan, null);
      offline = false;
      await controller.sync();
      actor = 'other';
      expect(controller.invitedPlan, null);
      actor = 'viewer';
      response = Completer();
      final pending = controller.openInvited(g);
      await Future<void>.delayed(Duration.zero);
      controller.hideInvitedContent();
      response.complete({
        'kind': 'succeeded',
        'ownerId': 'viewer',
        'entry': {'status': 'active', 'plan': encodeQuickPlan(draft)},
      });
      await pending;
      expect(controller.invitedPlan, null);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
}
