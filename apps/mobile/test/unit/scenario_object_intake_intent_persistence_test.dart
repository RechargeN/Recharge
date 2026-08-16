import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/datasources/scenario_object_intake_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/scenario_object_intake_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake.dart';
import 'package:recharge/features/create/domain/entities/scenario_object_intake_session.dart';

void main() {
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('pending intent survives repository and data-source restart', () async {
    final repository = _repository(storage);
    await repository.put(_session());

    final restarted = _repository(storage);
    final restored = await restarted.load(
      ownerId: 'user-1',
      intentId: 'intent-1',
    );

    expect(restored, isNotNull);
    expect(restored!.status, ScenarioObjectIntakeSessionStatus.pending);
    expect(restored.intent.candidates.single.ref.objectId, 'event-1');
    expect(restored.intent.candidates.single.location!.address, 'GORS');
    expect(restored.expiresAtUtc, DateTime.utc(2026, 8, 3, 12, 30));
  });

  test(
    'consumed receipt is durable and idempotent for the same target',
    () async {
      final repository = _repository(storage);
      await repository.put(_session());
      await repository.markConsumed(
        ownerId: 'user-1',
        intentId: 'intent-1',
        targetDraftId: 'scenario-1',
        targetRevision: 8,
      );
      await repository.markConsumed(
        ownerId: 'user-1',
        intentId: 'intent-1',
        targetDraftId: 'scenario-1',
        targetRevision: 8,
      );

      final restored = await _repository(
        storage,
      ).load(ownerId: 'user-1', intentId: 'intent-1');
      expect(restored!.status, ScenarioObjectIntakeSessionStatus.consumed);
      expect(restored.consumedTargetDraftId, 'scenario-1');
      expect(restored.consumedTargetRevision, 8);
    },
  );

  test(
    'foreign owner payload fails closed instead of being filtered',
    () async {
      final repository = _repository(storage);
      await repository.put(_session());
      final values = await storage.readAll();
      final key = values.keys.single;
      final payload = jsonDecode(values[key]!) as Map<String, dynamic>;
      final sessions = payload['sessions'] as List<dynamic>;
      final session = sessions.single as Map<String, dynamic>;
      final intent = session['intent'] as Map<String, dynamic>;
      intent['requesterId'] = 'user-2';
      await storage.write(key: key, value: jsonEncode(payload));

      expect(
        () =>
            _repository(storage).load(ownerId: 'user-1', intentId: 'intent-1'),
        throwsFormatException,
      );
    },
  );
}

ScenarioObjectIntakeRepositoryImpl _repository(FlutterSecureStorage storage) =>
    ScenarioObjectIntakeRepositoryImpl(
      ScenarioObjectIntakeLocalDataSource(storage),
    );

ScenarioObjectIntakeSession _session() => ScenarioObjectIntakeSession(
  schemaVersion: ScenarioObjectIntakeSession.currentSchemaVersion,
  intent: ScenarioObjectIntakeIntent(
    contractVersion: ScenarioObjectIntakeIntent.currentContractVersion,
    intentId: 'intent-1',
    requesterId: 'user-1',
    sourceSurface: ScenarioIntakeSourceSurface.details,
    candidates: <ScenarioIntakeCandidate>[
      ScenarioIntakeCandidate(
        ref: const ScenarioObjectRef(
          objectId: 'event-1',
          objectType: ScenarioCatalogObjectType.event,
        ),
        snapshot: ScenarioObjectSnapshotDraft(
          title: 'Concert',
          checkedAtUtc: DateTime.utc(2026, 8, 3, 12),
        ),
        sourceStatus: ScenarioSourceStatus.ready,
        location: const ScenarioIntakeLocationSnapshot(
          title: 'GORS',
          point: ScenarioGeoPointDraft(latitude: 56.5099, longitude: 27.3332),
          address: 'GORS',
          timezoneId: 'Europe/Riga',
          disclosure: ScenarioLocationDisclosure.public,
        ),
      ),
    ],
  ),
  createdAtUtc: DateTime.utc(2026, 8, 3, 12),
  expiresAtUtc: DateTime.utc(2026, 8, 3, 12, 30),
  status: ScenarioObjectIntakeSessionStatus.pending,
);
