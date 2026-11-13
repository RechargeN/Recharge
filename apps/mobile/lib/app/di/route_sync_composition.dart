import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/data/repositories/route_sync_client.dart';
import '../../features/create/domain/repositories/route_sync_repository.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

/// J1 default-off entry: `--dart-define=RECHARGE_TEST_ROUTE_SYNC=true`.
const routeSyncTestEntry = bool.fromEnvironment('RECHARGE_TEST_ROUTE_SYNC');

/// The same four conditions as every other test entry: the define, a
/// non-release build, the test binding and the loopback demo Emulator.
RouteInvoke routeSyncInvoke({
  required BookingBackendBindingController binding,
  required Future<BookingTransportRuntime> Function() runtime,
}) => (surface, request) async {
  if (!routeSyncTestEntry ||
      kReleaseMode ||
      binding.mode != BackendBindingMode.testBackend ||
      !isLoopbackDemoEmulatorBinding(binding) ||
      !const <String>['routeCommandV1', 'routeQueryV1'].contains(surface)) {
    throw const RouteSyncFailure('test_entry_disabled');
  }
  final transport = await runtime();
  if (!transport.remoteCommandsEnabled || transport.port == null) {
    throw const RouteSyncFailure('transport_unavailable');
  }
  try {
    return await transport.port!.invoke(surface, request);
  } on BookingCallableFailure catch (error) {
    throw RouteSyncFailure(error.code);
  }
};
