import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

import '../test/backend_local/event_publication_ui_stand_test.dart' as suite;

/// B1-device: the C3 Create → publication UI suite runs unchanged on the phone,
/// as one app process, against the local stand through
/// `stand-b1-device-gate.mjs` (adb reverse to the PC loopback, stand scripts
/// and fixtures through its bridge). Not a run of the PC host gate.
///
/// The suite reads English UI text, as on the PC, so the phone's system
/// language (Russian on the A34) is replaced by the test locale `en`; the
/// suites that check lv/ru pass those locales themselves.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = const Locale('en');
  binding.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
  suite.main();
}
