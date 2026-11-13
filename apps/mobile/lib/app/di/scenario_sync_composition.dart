import 'package:flutter/foundation.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/data/repositories/scenario_sync_client.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

const scenarioSyncTestEntry = bool.fromEnvironment('RECHARGE_TEST_SCENARIO_I2');
ScenarioInvoke scenarioSyncInvoke({
  required BookingBackendBindingController binding,
  required Future<BookingTransportRuntime> Function() runtime,
}) => (surface, request) async {
  if (!scenarioSyncTestEntry ||
      kReleaseMode ||
      binding.mode != BackendBindingMode.testBackend ||
      !isLoopbackDemoEmulatorBinding(binding) ||
      ![
        'scenarioCommandV1',
        'scenarioQueryV1',
        'quickPlanCommandV1',
        'quickPlanQueryV1',
      ].contains(surface)) {
    throw const ScenarioSyncFailure('test_entry_disabled');
  }
  final transport = await runtime();
  if (!transport.remoteCommandsEnabled || transport.port == null) {
    throw const ScenarioSyncFailure('transport_unavailable');
  }
  return transport.port!.invoke(surface, request);
};
