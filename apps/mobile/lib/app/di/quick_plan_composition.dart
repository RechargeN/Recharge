import 'package:flutter/foundation.dart';
import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/scenarios/data/quick_plan_sync_client.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

const quickPlanTestEntry = bool.fromEnvironment('RECHARGE_TEST_QUICK_PLAN');
QuickPlanInvoke quickPlanInvoke({
  required BookingBackendBindingController binding,
  required Future<BookingTransportRuntime> Function() runtime,
}) => (surface, request) async {
  if (!quickPlanTestEntry ||
      kReleaseMode ||
      binding.mode != BackendBindingMode.testBackend ||
      !isLoopbackDemoEmulatorBinding(binding) ||
      !['quickPlanCommandV1', 'quickPlanQueryV1'].contains(surface)) {
    throw const QuickPlanFailure('test_entry_disabled');
  }
  final transport = await runtime();
  if (!transport.remoteCommandsEnabled || transport.port == null) {
    throw const QuickPlanFailure('transport_unavailable');
  }
  try {
    return await transport.port!.invoke(surface, request);
  } on BookingCallableFailure catch (e) {
    throw QuickPlanFailure(e.code);
  }
};
