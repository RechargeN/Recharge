import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recharge/app/adapters/route_geolocator_adapter.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/controllers/route_recording_controller.dart';
import 'package:recharge/features/create/application/state/route_recording_state.dart';
import 'package:recharge/features/create/data/datasources/route_recording_secure_store.dart';
import 'package:recharge/features/create/data/repositories/route_recording_journal_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/route_location_recording_port.dart';

import '../test/backend_local/support/stand_environment.dart';

/// B1-device, operator-assisted: background Route recording on the phone
/// (B1D-ROUTE-BG-01). The path a person takes: allow location while using
/// the app; Android 11+ grants "all the time" only in Settings, so the start
/// refuses with `gps_background_permission_denied`; the app opens Settings,
/// the operator chooses "Allow all the time"; back in the app the background
/// start must now succeed (before the fix it refused again). The gate then
/// sends the app to the background and checks the location foreground
/// service. Not mocked: geolocator, the permission dialog, Settings.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const String draftId = 'b1-device-route-background';

  testWidgets(
    'B1-device background Route recording',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final RouteGeolocatorAdapter location = RouteGeolocatorAdapter();
      final RouteRecordingController recording = RouteRecordingController(
        idGenerator: UuidV4IdGenerator(),
        location: location,
        journalRepository: RouteRecordingJournalRepositoryImpl(
          store: EncryptedFileRouteRecordingStore(
            secureStorage: const FlutterSecureStorage(),
            supportDirectory: getApplicationSupportDirectory,
          ),
        ),
      );
      addTearDown(recording.dispose);
      await recording.recover(draftId);
      await recording.deleteRecording();

      Future<void> until(bool Function() done, String what) async {
        final DateTime deadline = DateTime.now().add(
          const Duration(minutes: 4),
        );
        while (!done()) {
          if (DateTime.now().isAfter(deadline)) fail('timed out: $what');
          await tester.pump(const Duration(milliseconds: 500));
        }
      }

      final Map<String, Object?> trace = <String, Object?>{
        'initial': (await location.checkPermission()).name,
      };
      await _arrive('foreground-dialog');
      bool started = await recording.start(
        draftId: draftId,
        requestBackground: true,
      );
      trace['firstStart'] = started;
      trace['firstFailure'] = recording.state.failureCode;
      trace['afterFirst'] = (await location.checkPermission()).name;
      if (!started) {
        expect(recording.state.failureCode, 'gps_background_permission_denied');
        await recording.deleteRecording();
        // The person follows the app's hint: Settings → "Allow all the time".
        await _arrive('settings');
        await recording.openAppSettings();
        RouteLocationPermission now = await location.checkPermission();
        final DateTime deadline = DateTime.now().add(
          const Duration(minutes: 5),
        );
        while (now != RouteLocationPermission.always) {
          if (DateTime.now().isAfter(deadline)) {
            fail('"Allow all the time" was not chosen');
          }
          await tester.pump(const Duration(seconds: 1));
          now = await location.checkPermission();
        }
        trace['afterSettings'] = now.name;
        // B1D-ROUTE-BG-01: this start refused with whileInUse before the fix.
        started = await recording.start(
          draftId: draftId,
          requestBackground: true,
        );
      }
      expect(started, isTrue, reason: '${recording.state.failureCode}');
      expect(recording.state.status, RouteRecordingStatus.recording);
      expect(recording.state.backgroundEnabled, isTrue);
      trace['backgroundEnabled'] = recording.state.backgroundEnabled;
      await until(() => recording.state.sampleCount >= 1, 'a first GPS fix');

      // The gate presses Home, checks the location foreground service while
      // the app is in the background, and reopens it.
      await _arrive('background', trace);
      await _gate('foreground');
      expect(
        recording.state.status,
        RouteRecordingStatus.recording,
        reason: 'still recording after the background period',
      );
      expect(recording.state.failureCode, isNull);
      trace['samplesAfterBackground'] = recording.state.sampleCount;
      await recording.deleteRecording();
      await _arrive('done', trace);
    },
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

Future<void> _gate(String name) async {
  final DateTime deadline = DateTime.now().add(const Duration(minutes: 5));
  while (true) {
    final http.Response response = await http.get(_rendezvous('gate', name));
    if (response.statusCode == 200) return;
    if (DateTime.now().isAfter(deadline)) fail('gate never reached $name');
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
