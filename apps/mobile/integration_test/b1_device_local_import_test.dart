import 'package:integration_test/integration_test.dart';

import '../test/backend_local/local_import_stand_test.dart' as suite;

/// B1-device: the D4 local import and rollback suite runs unchanged on the
/// phone, as one app process, against the local stand through
/// `stand-b1-device-gate.mjs` (adb reverse to the PC loopback, stand scripts
/// and fixtures through its bridge). Not a run of the PC host gate.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  suite.main();
}
