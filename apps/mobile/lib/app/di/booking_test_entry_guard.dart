import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_command_gate.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';

/// Compile-time switch. `bool.fromEnvironment` only recognises `true`, so the
/// entry is enabled with `--dart-define=RECHARGE_TEST_BOOKING_ENTRY=true`.
const bool bookingTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_BOOKING_ENTRY',
);

/// Default-off test entry for Event Booking. All four conditions must hold at
/// the same time, and the same check protects the route and every command:
///
///  * the define is `true`;
///  * this is not a release build;
///  * the Booking binding is `testBackend`;
///  * the endpoint is the loopback `demo-recharge/europe-west1` Emulator.
final class BookingTestEntryGuard implements BookingCommandGate {
  BookingTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  /// Production wiring: reads the real define and build mode.
  factory BookingTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => BookingTestEntryGuard(
    flag: bookingTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
  );

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

  @override
  bool get allowed {
    if (!flag || releaseMode) return false;
    if (_binding.mode != BackendBindingMode.testBackend) return false;
    return isLoopbackDemoEmulatorBinding(_binding);
  }

  @override
  void assertAllowed() {
    if (!allowed) {
      throw StateError('Booking test entry is not enabled');
    }
  }
}

/// Fails closed: a binding that cannot even form its endpoint is not allowed.
bool isLoopbackDemoEmulatorBinding(BookingBackendBindingController binding) {
  try {
    return isLoopbackDemoEmulator(binding.endpoint);
  } on ArgumentError {
    return false;
  }
}

/// The endpoint is exactly the loopback `demo-recharge/europe-west1` Emulator.
bool isLoopbackDemoEmulator(BookingBackendEndpoint endpoint) {
  if (endpoint.binding != BookingBackendBinding.devEmulator) return false;
  final uri = endpoint.uri;
  if (uri == null || uri.scheme != 'http') return false;
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') return false;
  final path = uri.pathSegments.where((segment) => segment.isNotEmpty);
  return path.length == 2 &&
      path.first == 'demo-recharge' &&
      path.last == 'europe-west1';
}

/// Route guard: where to send a visitor of the Booking test route, or null to
/// let them in. A missing guard (nothing registered) is a refusal.
String? bookingTestEntryRedirect(
  BookingTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;
