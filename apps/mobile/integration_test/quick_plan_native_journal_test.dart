import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/features/scenarios/application/controllers/scenario_builder_controller.dart';
import 'package:recharge/features/scenarios/data/quick_plan_sync_client.dart';

/// Two separate installed-app launches, with host adb force-stop between them.
/// No mock secure storage, Firebase credentials, network or shared fixture keys.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = int.fromEnvironment('RECHARGE_I1_NATIVE_PHASE');
  const marker = 'i1_native_test_plan_id';
  const installation = 'i1-native-disposable-avd';
  const owner = 'i1-native-owner';
  const storage = FlutterSecureStorage();
  final journalKey =
      'quick_plan_v1_${base64Url.encode(utf8.encode('$installation:$owner'))}';
  testWidgets('native journal phase $phase', (tester) async {
    expect([1, 2], contains(phase));
    String? activeOwner = owner;
    final client = QuickPlanSyncClient(
      storage: storage,
      installationId: installation,
      currentOwner: () => activeOwner,
      invoke: (_, _) async =>
          throw const SocketException('intentional offline native fixture'),
    );
    if (phase == 1) {
      await storage.delete(key: marker);
      await storage.delete(key: journalKey);
      final controller = ScenarioBuilderController();
      addTearDown(controller.dispose);
      final plan = controller.state.draft.copyWith(
        sourcePrompt: 'native pending survives force-stop',
      );
      await expectLater(
        client.save(plan, expectedRevision: 0),
        throwsA(isA<SocketException>()),
      );
      expect(client.hasPending(plan.id), true);
      await storage.write(key: marker, value: plan.id);
    } else {
      final id = await storage.read(key: marker);
      expect(
        id,
        isNotNull,
        reason: 'Phase 1 must survive process force-stop and APK reinstall',
      );
      await client.restore();
      expect(
        client.cached(id!)!.sourcePrompt,
        'native pending survives force-stop',
      );
      expect(client.hasPending(id), true);
      activeOwner = 'i1-native-other';
      expect(client.cached(id), null);
      await client.restore();
      expect(client.hasPending(id), false);
      activeOwner = owner;
      await client.restore();
      expect(client.hasPending(id), true);
      await storage.delete(key: journalKey);
      await storage.delete(key: marker);
      expect(await storage.read(key: journalKey), null);
      expect(await storage.read(key: marker), null);
    }
  });
}
