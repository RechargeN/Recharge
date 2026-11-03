import 'package:integration_test/integration_test.dart';

import '../test/backend_local/e2_client_test.dart' as suite;

/// B1-device: E2 client B (Discover → Details → Booking, hide race) runs
/// unchanged on the phone, as one app process, against the local stand through
/// `stand-b1-device-gate.mjs` (adb reverse to the PC loopback, stand scripts
/// and fixtures through its bridge). Not a run of the PC host gate.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  suite.main();
}
