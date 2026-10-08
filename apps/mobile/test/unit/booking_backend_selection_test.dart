import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';

void main() {
  final base = Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1');

  BackendBindingManifest manifest(BackendBindingMode mode) =>
      BackendBindingManifest(
        revision: 1,
        bindings: <String, BackendBindingMode>{
          bookingBackendCapabilityId: mode,
        },
      );

  test('manifest modes map to the existing Booking endpoint selector', () {
    BookingBackendBinding bindingFor(BackendBindingMode mode) =>
        bookingEndpointFor(
          manifest: manifest(mode),
          emulatorBase: base,
          releaseMode: false,
        ).binding;

    expect(
      bindingFor(BackendBindingMode.localOnly),
      BookingBackendBinding.localMock,
    );
    expect(
      bindingFor(BackendBindingMode.testBackend),
      BookingBackendBinding.devEmulator,
    );
    expect(
      bindingFor(BackendBindingMode.disabled),
      BookingBackendBinding.productionDisabled,
    );
  });

  test('a missing capability or release build is never a backend', () {
    expect(
      bookingEndpointFor(
        manifest: BackendBindingManifest.localSafeDefault,
        emulatorBase: base,
        releaseMode: false,
      ).binding,
      BookingBackendBinding.productionDisabled,
    );
    expect(
      bookingEndpointFor(
        manifest: manifest(BackendBindingMode.testBackend),
        emulatorBase: base,
        releaseMode: true,
      ).binding,
      BookingBackendBinding.productionDisabled,
    );
  });

  test('testBackend fails closed without a base and rejects other bases', () {
    expect(
      bookingEndpointFor(
        manifest: manifest(BackendBindingMode.testBackend),
        emulatorBase: null,
        releaseMode: false,
      ).binding,
      BookingBackendBinding.productionDisabled,
    );
    for (final bad in <String>[
      'http://192.168.1.5:5001/demo-recharge/europe-west1',
      'http://127.0.0.1:5001/other-project/europe-west1',
      'https://127.0.0.1:5001/demo-recharge/europe-west1',
    ]) {
      expect(
        () => bookingEndpointFor(
          manifest: manifest(BackendBindingMode.testBackend),
          emulatorBase: Uri.parse(bad),
          releaseMode: false,
        ),
        throwsArgumentError,
        reason: bad,
      );
    }
  });

  test('controller returns to localOnly and can re-enter the test backend', () {
    final controller = BookingBackendBindingController(
      emulatorBase: base,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    expect(controller.endpoint.binding, BookingBackendBinding.devEmulator);

    controller.activate(BackendBindingMode.localOnly);
    expect(controller.endpoint.binding, BookingBackendBinding.localMock);
    expect(controller.manifest.revision, 2);

    controller.rollback();
    expect(controller.mode, BackendBindingMode.testBackend);
    expect(controller.endpoint.binding, BookingBackendBinding.devEmulator);
    expect(controller.rollback, throwsStateError);
  });
}
