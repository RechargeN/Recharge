import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import '../test/unit/booking_backend_selection_test.dart' as selection;

/// B1-device: the binding guards and the debug network policy on the phone.
///
/// The selection suite (release, disabled and localOnly never reach a
/// backend; only the loopback demo-recharge base is accepted) runs unchanged
/// in the installed app. Then the Android policy of the debug build itself:
/// cleartext to the phone's loopback (the stand through `adb reverse`) works,
/// cleartext to any other host is refused by the platform before a socket is
/// opened, so a test binding cannot silently reach a LAN or emulator address.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  selection.main();

  testWidgets(
    'debug cleartext is allowed only to 127.0.0.1',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      // The Functions Emulator through adb reverse answers (any status).
      final http.Response loopback = await http.get(
        Uri.parse('http://127.0.0.1:5001/'),
      );
      expect(loopback.statusCode, greaterThan(0));
      for (final String host in <String>[
        '10.0.2.2',
        '192.168.0.1',
        'localhost',
      ]) {
        await expectLater(
          http.get(Uri.parse('http://$host:5001/')),
          throwsA(
            predicate(
              (Object error) =>
                  '$error'.contains('Insecure HTTP is not allowed'),
              'refused by the platform cleartext policy',
            ),
          ),
          reason: host,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
