import 'dart:convert';
import 'dart:io';

/// The variables a stand gate gives one test client.
///
/// On the PC host they are the process environment, as before. An Android app
/// has no gate-controlled environment, so B1-device passes the same variables
/// in one define, `RECHARGE_DEVICE_ENV` (base64url JSON of string pairs); the
/// host environment still wins where both are set.
final Map<String, String> standEnvironment = Map<String, String>.unmodifiable(
  <String, String>{..._deviceEnvironment(), ...Platform.environment},
);

/// B1-device: the client reaches the stand scripts, fixtures and rendezvous
/// through the gate's loopback bridge (`stand-device-bridge.mjs`, kept on the
/// phone's 127.0.0.1 by `adb reverse`), not through local processes and files.
bool get standOverBridge => standEnvironment['RECHARGE_STAND_BRIDGE'] == '1';

/// The bridge, on the device's loopback (`adb reverse tcp:8765 tcp:8765`).
final Uri standBridgeBase = Uri.parse('http://127.0.0.1:8765');

Map<String, String> _deviceEnvironment() {
  const String encoded = String.fromEnvironment('RECHARGE_DEVICE_ENV');
  if (encoded.isEmpty) return const <String, String>{};
  final Object? decoded = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
  );
  if (decoded is! Map) {
    throw StateError('RECHARGE_DEVICE_ENV is not a JSON object');
  }
  return decoded.map(
    (Object? key, Object? value) =>
        MapEntry<String, String>(key! as String, value! as String),
  );
}
