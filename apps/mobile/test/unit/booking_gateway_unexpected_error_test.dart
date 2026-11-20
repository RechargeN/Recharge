import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_command_gate.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';

/// N4c follow-up (2026-11-18): an unexpected transport error (here an
/// ArgumentError, as the A34 allowlist bug threw) never escapes the gateway,
/// so the Booking panel cannot stay on its loading state. Reads become
/// offline (retryable); a command becomes an unknown outcome (reconciled,
/// never sent twice blindly).
void main() {
  BookingTransportEventBookingGateway gateway() {
    final _ThrowingPort port = _ThrowingPort();
    return BookingTransportEventBookingGateway(
      adapter: BookingCallableAdapter(
        port: port,
        operations: InMemoryBookingOperationStore(),
      ),
      port: port,
      gate: _OpenGate(),
    );
  }

  test('reads answer offline instead of throwing', () async {
    final g = gateway();
    expect((await g.activeFor('occ_1')).outcome, EventBookingOutcome.offline);
    expect((await g.booking('bkg_1')).outcome, EventBookingOutcome.offline);
    expect(
      (await g.termsFor(eventId: 'evt_1', occurrenceId: 'occ_1')).outcome,
      EventBookingTermsOutcome.offline,
    );
  });

  test('a command answers unknown outcome instead of throwing', () async {
    final result = await gateway().execute(
      const EventBookingOperation(
        kind: EventBookingOperationKind.create,
        idempotencyKey: 'idem_unexpected_1',
        occurrenceId: 'occ_1',
        participantUnits: 1,
        eventRevision: 1,
      ),
    );
    expect(result.outcome, EventBookingOutcome.unknownOutcome);
  });
}

class _ThrowingPort implements BookingCallablePort {
  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async => throw ArgumentError.value(callableName, 'callableName');
}

class _OpenGate implements BookingCommandGate {
  @override
  bool get allowed => true;

  @override
  void assertAllowed() {}
}
