import '../../features/booking/data/booking_callable_adapter.dart';
import 'backend_binding_manifest.dart';

/// Capability id under which the Booking backend binding is recorded in a
/// [BackendBindingManifest].
const String bookingBackendCapabilityId = 'booking.backend';

/// Maps the binding manifest to the existing Booking endpoint selector.
///
/// This is the only link between the two: `localOnly` is the local mock,
/// `testBackend` is the loopback demo-recharge Emulator, and everything else
/// (including any release build) is disabled. No Auth or Session mechanism
/// lives here; those stay in the Booking Functions transport.
BookingBackendEndpoint bookingEndpointFor({
  required BackendBindingManifest manifest,
  required Uri? emulatorBase,
  required bool releaseMode,
}) {
  if (releaseMode) return const BookingBackendEndpoint.productionDisabled();
  switch (manifest.modeFor(bookingBackendCapabilityId)) {
    case BackendBindingMode.localOnly:
      return const BookingBackendEndpoint.localMock();
    case BackendBindingMode.disabled:
      return const BookingBackendEndpoint.productionDisabled();
    case BackendBindingMode.testBackend:
      // Fail closed: a test binding without an Emulator base never falls back
      // to local data or to any other address.
      if (emulatorBase == null) {
        return const BookingBackendEndpoint.productionDisabled();
      }
      // Validates loopback host and demo-recharge/europe-west1.
      return BookingBackendEndpoint.devEmulator(emulatorBase);
  }
}

/// Reversible Booking binding. Switching never touches local Booking data:
/// each endpoint only decides where commands go.
final class BookingBackendBindingController {
  BookingBackendBindingController({
    required Uri? emulatorBase,
    required bool releaseMode,
    BackendBindingMode initial = BackendBindingMode.localOnly,
  }) : _emulatorBase = emulatorBase,
       _releaseMode = releaseMode,
       _manifest = _manifestFor(1, initial);

  final Uri? _emulatorBase;
  final bool _releaseMode;
  final List<BackendBindingManifest> _history = <BackendBindingManifest>[];
  BackendBindingManifest _manifest;

  BackendBindingManifest get manifest => _manifest;

  BackendBindingMode get mode => _manifest.modeFor(bookingBackendCapabilityId);

  BookingBackendEndpoint get endpoint => bookingEndpointFor(
    manifest: _manifest,
    emulatorBase: _emulatorBase,
    releaseMode: _releaseMode,
  );

  /// Records a new manifest revision. The previous revision stays available
  /// for [rollback].
  void activate(BackendBindingMode next) {
    if (next == mode) return;
    _history.add(_manifest);
    _manifest = _manifestFor(_manifest.revision + 1, next);
  }

  /// Returns to the previous manifest revision, for example back to
  /// `localOnly` after a test backend session.
  void rollback() {
    if (_history.isEmpty) {
      throw StateError('No earlier Booking binding revision to roll back to');
    }
    _manifest = _manifest.rollbackTo(_history.removeLast());
  }

  static BackendBindingManifest _manifestFor(
    int revision,
    BackendBindingMode mode,
  ) => BackendBindingManifest(
    revision: revision,
    bindings: <String, BackendBindingMode>{bookingBackendCapabilityId: mode},
  );
}
