import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_command_gate.dart';
import 'package:recharge/features/booking/data/booking_transport_event_booking_gateway.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';

void main() {
  final base = Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1');

  BookingTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => BookingTestEntryGuard(
    flag: flag,
    releaseMode: release,
    binding: BookingBackendBindingController(
      emulatorBase: emulatorBase ?? base,
      releaseMode: release,
      initial: mode,
    ),
  );

  test('allowed only when every condition holds at once', () {
    expect(guard().allowed, isTrue);
    expect(guard(flag: false).allowed, isFalse);
    expect(guard(release: true).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.disabled).allowed, isFalse);
  });

  test('a testBackend binding without an Emulator base is refused', () {
    final withoutBase = BookingTestEntryGuard(
      flag: true,
      releaseMode: false,
      binding: BookingBackendBindingController(
        emulatorBase: null,
        releaseMode: false,
        initial: BackendBindingMode.testBackend,
      ),
    );
    expect(withoutBase.allowed, isFalse);
    expect(withoutBase.assertAllowed, throwsStateError);
  });

  test(
    'the compile-time define is off unless set to true',
    () {
      // The suite runs without the define, so the real default must be off.
      expect(bookingTestEntryDefined, isFalse);
      expect(
        BookingTestEntryGuard.fromEnvironment(
          BookingBackendBindingController(
            emulatorBase: base,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          ),
        ).allowed,
        isFalse,
      );
    },
    skip: bookingTestEntryDefined ? 'run with the define on' : false,
  );

  test('the route redirect refuses unless the guard allows', () {
    expect(bookingTestEntryRedirect(null, fallback: '/x'), '/x');
    expect(bookingTestEntryRedirect(guard(flag: false), fallback: '/x'), '/x');
    expect(bookingTestEntryRedirect(guard(), fallback: '/x'), isNull);
  });

  test(
    'the gateway refuses every read and command when the gate denies',
    () async {
      final port = _CountingPort();
      final gateway = BookingTransportEventBookingGateway(
        adapter: BookingCallableAdapter(
          port: port,
          operations: InMemoryBookingOperationStore(),
        ),
        port: port,
        gate: const DeniedBookingCommandGate(),
      );

      await expectLater(gateway.activeFor('occ'), throwsStateError);
      await expectLater(
        gateway.execute(
          const EventBookingOperation(
            kind: EventBookingOperationKind.create,
            idempotencyKey: 'key-0001',
            occurrenceId: 'occ',
            inventoryPoolId: 'pool',
            channel: 'onsite',
            participantUnits: 1,
            eventRevision: 1,
          ),
        ),
        throwsStateError,
      );
      expect(port.calls, 0, reason: 'nothing may reach the transport');
    },
  );
}

final class _CountingPort implements BookingCallablePort {
  int calls = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    calls += 1;
    return <String, Object?>{};
  }
}
