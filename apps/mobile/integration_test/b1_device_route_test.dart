import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recharge/app/adapters/route_geolocator_adapter.dart';
import 'package:recharge/app/adapters/route_gpx_file_selector_adapter.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/controllers/route_recording_controller.dart';
import 'package:recharge/features/create/application/state/route_recording_state.dart';
import 'package:recharge/features/create/data/datasources/route_gpx_memory_source_store.dart';
import 'package:recharge/features/create/data/datasources/route_recording_secure_store.dart';
import 'package:recharge/features/create/data/repositories/route_recording_journal_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';

import '../test/backend_local/support/stand_environment.dart';

/// B1-device, operator-assisted: Route recording and GPX files on the phone.
///
/// Phase 1: the gate revoked the location permission first, so starting a
/// recording shows the real Android dialog; the operator allows it and walks
/// a few metres until the encrypted journal holds two fixes; then the gate
/// sends the app to the background and ends the process (`am kill`).
/// Phase 2: a cold start recovers that journal as paused (no auto-resume) and
/// deletes it; the operator picks the GPX the gate pushed to Downloads in the
/// system picker (its bytes must match), then completes the export dialog.
///
/// Not mocked: geolocator, the permission dialog, flutter_secure_storage, the
/// encrypted file store, file_selector, share_plus and process death. No
/// stand is needed; the gate's loopback bridge only carries the checkpoints.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final int phase =
      int.tryParse(standEnvironment['RECHARGE_B1_PHASE'] ?? '') ?? 0;
  const String draftId = 'b1-device-route-draft';

  RouteRecordingController controller() => RouteRecordingController(
    idGenerator: UuidV4IdGenerator(),
    location: RouteGeolocatorAdapter(),
    journalRepository: RouteRecordingJournalRepositoryImpl(
      store: EncryptedFileRouteRecordingStore(
        secureStorage: const FlutterSecureStorage(),
        supportDirectory: getApplicationSupportDirectory,
      ),
    ),
  );

  Future<void> until(
    WidgetTester tester,
    bool Function() done,
    String what, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out: $what');
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets(
    'B1-device Route phase $phase',
    (WidgetTester tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(<int>[1, 2], contains(phase));

      if (phase == 1) {
        final RouteRecordingController recording = controller();
        addTearDown(recording.dispose);
        // A journal left by an earlier run would block a new recording.
        await recording.recover(draftId);
        await recording.deleteRecording();
        await _arrive('permission-dialog');
        final bool started = await recording.start(draftId: draftId);
        expect(started, isTrue, reason: '${recording.state.failureCode}');
        expect(recording.state.status, RouteRecordingStatus.recording);
        await _arrive('walk');
        await until(
          tester,
          () => recording.state.sampleCount >= 2,
          'two location fixes in the journal',
        );
        final int recorded = recording.state.sampleCount;
        // Let the journal write of the last fix finish before the process ends.
        await tester.pump(const Duration(seconds: 3));
        await _arrive('kill', <String, Object?>{'samples': recorded});
        await _gate('never', timeout: const Duration(minutes: 10));
        fail('the gate did not end the process');
      }

      final RouteRecordingController recovered = controller();
      addTearDown(recovered.dispose);
      await recovered.recover(draftId);
      expect(recovered.state.recovered, isTrue);
      expect(recovered.state.status, RouteRecordingStatus.paused);
      expect(recovered.state.sampleCount, greaterThanOrEqualTo(1));
      final int recoveredSamples = recovered.state.sampleCount;
      await tester.pump(const Duration(seconds: 5));
      expect(
        recovered.state.status,
        RouteRecordingStatus.paused,
        reason: 'no auto-resume',
      );
      expect(recovered.state.sampleCount, recoveredSamples);
      await recovered.deleteRecording();

      final RouteGpxMemorySourceStore files = RouteGpxMemorySourceStore(
        idGenerator: UuidV4IdGenerator(),
        config: const RouteGpxImportConfig(),
      );
      final RouteGpxFileSelectorAdapter picker = RouteGpxFileSelectorAdapter(
        files,
      );
      await _arrive('gpx-picker');
      final RouteSafeFileRef? picked = await picker.pickForImport();
      expect(picked, isNotNull, reason: 'the operator picked the GPX');
      final String digest = sha256
          .convert(await files.read(picked!))
          .toString();
      await _arrive('gpx-picked', <String, Object?>{
        'name': picked.displayName,
        'size': picked.sizeBytes,
        'sha256': digest,
      });
      await _arrive('gpx-export');
      final bool exported = await picker.saveExport(picked);
      await _arrive('done', <String, Object?>{
        'recoveredSamples': recoveredSamples,
        'exported': exported,
      });
    },
    skip: phase == 0,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Uri _rendezvous(String who, String name) => standBridgeBase.replace(
  path: '/rendezvous',
  queryParameters: <String, String>{'who': who, 'name': name},
);

Future<void> _arrive(
  String name, [
  Map<String, Object?> payload = const <String, Object?>{},
]) async {
  final http.Response response = await http.put(
    _rendezvous('device', name),
    headers: const <String, String>{'content-type': 'application/json'},
    body: jsonEncode(payload),
  );
  expect(response.statusCode, 204, reason: 'bridge refused $name');
}

Future<void> _gate(String name, {required Duration timeout}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (true) {
    final http.Response response = await http.get(_rendezvous('gate', name));
    if (response.statusCode == 200) return;
    if (DateTime.now().isAfter(deadline)) fail('gate never reached $name');
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
