import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';

import '../test/unit/booking_backend_selection_test.dart' as selection;

/// B1-device: the binding guards in the installed app on the phone.
///
/// The selection suite (release, disabled and localOnly never reach a
/// backend; only the loopback demo-recharge base is accepted) runs unchanged.
/// Then on the phone itself: the stand answers on its own loopback through
/// `adb reverse`, and the Dart guard refuses the emulator, LAN and localhost
/// bases before any request.
///
/// Measured on the A34 (2026-11-03): `dart:io` does not apply the Android
/// network security config, so a Dart request to a LAN address really goes
/// out. The debug config (cleartext only to 127.0.0.1, checked in the APK by
/// the gate) covers the native stacks such as firebase_auth; for the Dart
/// transport the guard below is the boundary.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  selection.main();

  testWidgets(
    'the stand answers on loopback; other bases are refused before a request',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final http.Response loopback = await http.get(
        Uri.parse('http://127.0.0.1:5001/'),
      );
      expect(loopback.statusCode, greaterThan(0));
      expect(
        BookingBackendEndpoint.devEmulator(
          Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1'),
        ).enabled,
        isTrue,
      );
      for (final String base in <String>[
        'http://10.0.2.2:5001/demo-recharge/europe-west1',
        'http://192.168.0.1:5001/demo-recharge/europe-west1',
        'https://127.0.0.1:5001/demo-recharge/europe-west1',
        'http://127.0.0.1:5001/recharge-prod/europe-west1',
      ]) {
        expect(
          () => BookingBackendEndpoint.devEmulator(Uri.parse(base)),
          throwsArgumentError,
          reason: base,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
