import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/quick_plan_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/scenarios/data/quick_plan_sync_client.dart';
import 'package:recharge/features/scenarios/data/quick_plan_codec.dart';
import 'package:recharge/features/scenarios/domain/entities/scenario_draft_entity.dart';
import 'package:uuid/uuid.dart';
import 'support/stand_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['RECHARGE_I1_LOCAL'] == '1';
  if (enabled) HttpOverrides.global = null;
  test(
    'I1 real Flutter adapters recover queue, conflicts, auth and import',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('i1-client-');
      addTearDown(() => temp.delete(recursive: true));
      Future<(QuickPlanInvoke, String)> transport(
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
        try {
          await runtime.identitySessions!.establish(
            requestId: const Uuid().v4(),
          );
        } on BookingCallableFailure catch (e) {
          fail('Session setup $installation: ${e.code}');
        }
        final invoke = quickPlanInvoke(
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
        Platform.environment['RECHARGE_I1_UID']!,
        'i1-mobile-a',
      );
      final (invokeB, ownerB) = await transport(
        Platform.environment['RECHARGE_I1_UID']!,
        'i1-mobile-b',
      );
      final (invokeOther, other) = await transport(
        Platform.environment['RECHARGE_I1_OTHER_UID']!,
        'i1-mobile-other',
      );
      expect(ownerB, owner);
      String? active = owner;
      var route = invokeA, offline = false, lost = false, expired = false;
      Future<Map<String, Object?>> controlled(
        String surface,
        Map<String, Object?> request,
      ) async {
        if (offline) throw const SocketException('offline');
        if (expired) return {'kind': 'rejected', 'code': 'unauthenticated'};
        final answer = await route(surface, request);
        if (lost && surface == 'quickPlanCommandV1') {
          lost = false;
          throw const SocketException('lost response');
        }
        return answer;
      }

      QuickPlanSyncClient reboot() => QuickPlanSyncClient(
        invoke: controlled,
        storage: const FlutterSecureStorage(),
        installationId: 'i1-device-a',
        currentOwner: () => active,
      );
      var a = reboot();
      final b = QuickPlanSyncClient(
        invoke: invokeB,
        storage: const FlutterSecureStorage(),
        installationId: 'i1-device-b',
        currentOwner: () => owner,
      );
      ScenarioDraftEntity plan([String prompt = 'initial']) =>
          ScenarioDraftEntity(
            id: const Uuid().v4(),
            revision: 0,
            mood: ScenarioMood.calm,
            maxDurationMinutes: 150,
            freeOnly: false,
            walkingOnly: true,
            sourcePrompt: prompt,
            currencyCode: 'EUR',
            steps: const [],
          );
      final failure = throwsA(isA<QuickPlanFailure>());
      // Both delivery orders retain the losing full payload durably.
      for (final reversed in [false, true]) {
        final p = plan();
        await a.save(p, expectedRevision: 0);
        await b.refresh(p.id);
        final first = reversed ? b : a, second = reversed ? a : b;
        await first.save(
          p.copyWith(sourcePrompt: 'winner'),
          expectedRevision: 1,
        );
        await expectLater(
          second.save(p.copyWith(sourcePrompt: 'loser'), expectedRevision: 1),
          failure,
        );
        await second.refresh(p.id);
        expect(second.cached(p.id)!.sourcePrompt, 'winner');
        expect(
          (second.conflicts.last['request'] as Map)['plan'],
          containsPair('sourcePrompt', 'loser'),
        );
      }
      // Persist before dispatch; restart + refresh retries without another action.
      final p = plan();
      offline = true;
      await expectLater(
        a.save(p, expectedRevision: 0),
        throwsA(isA<SocketException>()),
      );
      a = reboot();
      await a.restore();
      expect(a.cached(p.id)!.sourcePrompt, p.sourcePrompt);
      offline = false;
      await a.refresh(p.id);
      expect(a.serverRevision(p.id), 1);
      lost = true;
      await expectLater(
        a.save(p.copyWith(sourcePrompt: 'lost'), expectedRevision: 1),
        throwsA(isA<SocketException>()),
      );
      a = reboot();
      await a.refresh(p.id);
      expect(a.serverRevision(p.id), 2);
      // Session loss retains the exact queued edit. Logout hides it; B cannot send it.
      expired = true;
      await expectLater(
        a.save(p.copyWith(sourcePrompt: 'pending A'), expectedRevision: 2),
        failure,
      );
      active = null;
      a.clearVisible();
      expect(a.cached(p.id), null);
      expect(a.conflicts, isEmpty);
      active = other;
      route = invokeOther;
      expired = false;
      await a.refresh(p.id);
      expect(a.cached(p.id), null);
      await b.refresh(p.id);
      expect(b.cached(p.id)!.sourcePrompt, 'lost');
      active = owner;
      route = invokeA;
      a = reboot();
      await a.refresh(p.id);
      expect(a.cached(p.id)!.sourcePrompt, 'pending A');
      // Edit/delete and delete/offline edit; terminal tombstone on all clients.
      await b.refresh(p.id);
      offline = true;
      await expectLater(
        a.save(p.copyWith(sourcePrompt: 'offline stale'), expectedRevision: 3),
        throwsA(isA<SocketException>()),
      );
      await b.delete(p.id, expectedRevision: 2);
      offline = false;
      await expectLater(a.refresh(p.id), failure);
      await a.refresh(p.id);
      expect(a.cached(p.id), null);
      final q = plan();
      await a.save(q, expectedRevision: 0);
      await b.refresh(q.id);
      await a.save(q.copyWith(sourcePrompt: 'edit'), expectedRevision: 1);
      await b.delete(q.id, expectedRevision: 1);
      await a.refresh(q.id);
      expect(a.cached(q.id), null);
      // Import is one owner command. Lost response + reboot + repeat = one effect.
      final imported = plan('imported');
      final source = jsonEncode({
        'format': 'recharge.quickPlan',
        'schemaVersion': 1,
        'plan': encodeQuickPlan(imported),
      });
      lost = true;
      await expectLater(a.importJson(source), throwsA(isA<SocketException>()));
      a = reboot();
      await a.refresh(imported.id);
      await a.importJson(source);
      expect(a.serverRevision(imported.id), 1);
      final changed = jsonEncode({
        'format': 'recharge.quickPlan',
        'schemaVersion': 1,
        'plan': encodeQuickPlan(imported.copyWith(sourcePrompt: 'collision')),
      });
      await expectLater(a.importJson(changed), failure);
      expect(a.cached(imported.id)!.sourcePrompt, 'imported');
      for (final bad in [
        '{',
        '{}',
        jsonEncode({
          'format': 'recharge.quickPlan',
          'schemaVersion': 2,
          'plan': encodeQuickPlan(imported),
        }),
      ]) {
        expect(() => a.importJson(bad), throwsFormatException);
      }
      await b.delete(imported.id, expectedRevision: 1);
      await a.importJson(source);
      expect(a.cached(imported.id), null);
      // Real callable foreign reads and owner claims disclose nothing.
      final foreign = await invokeOther('quickPlanQueryV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'planId': imported.id,
      });
      expect(foreign['entry'], null);
      final forged = await invokeOther('quickPlanCommandV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'ownerContext': owner,
        'idempotencyKey': const Uuid().v4(),
        'commandType': 'delete',
        'planId': imported.id,
        'expectedRevision': 1,
      });
      expect(forged['code'], 'owner_changed');
    },
    skip: enabled ? false : 'Run the quick-plan Emulator group.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
