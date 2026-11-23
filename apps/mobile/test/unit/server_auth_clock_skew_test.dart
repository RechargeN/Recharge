import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';

import '../fixtures/auth/server_auth_packet.dart';

// A34/emulator 2026-11-23: a phone clock 4 s behind the server refused every
// sign-in ("server_auth_context_invalid"), because the server's evaluation
// instant was later than the phone's "now". Owner: allow a small clock skew.
void main() {
  ServerAuthContext parseAt(DateTime phoneNow) =>
      ServerAuthContext.fromResponse(
        packet(),
        installationId: 'dev-install',
        now: phoneNow,
      );

  test('a phone clock a few seconds behind the server still signs in', () {
    expect(
      () => parseAt(now.subtract(const Duration(seconds: 4))),
      returnsNormally,
    );
  });

  test('a phone clock within two minutes behind still signs in', () {
    expect(
      () => parseAt(now.subtract(const Duration(seconds: 119))),
      returnsNormally,
    );
  });

  test('a clock far behind the server is still refused', () {
    expect(
      () => parseAt(now.subtract(const Duration(minutes: 10))),
      throwsFormatException,
    );
  });

  test('an answer already expired on the phone is still refused', () {
    expect(
      () => parseAt(now.add(const Duration(hours: 2))),
      throwsFormatException,
    );
  });
}
