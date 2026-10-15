import 'package:flutter/foundation.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/library/data/library_sync_client.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

const libraryTestEntryDefined = bool.fromEnvironment('RECHARGE_TEST_LIBRARY');

bool libraryRemoteAllowed(BookingBackendBindingController binding) =>
    libraryTestEntryDefined &&
    !kReleaseMode &&
    binding.mode == BackendBindingMode.testBackend &&
    isLoopbackDemoEmulatorBinding(binding);

LibraryInvoke libraryInvoke({
  required BookingBackendBindingController binding,
  required Future<BookingTransportRuntime> Function() runtime,
}) => (surface, request) async {
  if (!libraryRemoteAllowed(binding)) {
    throw const LibraryFailure('test_entry_disabled');
  }
  final transport = await runtime();
  final port = transport.port;
  if (!transport.remoteCommandsEnabled || port == null) {
    throw const LibraryFailure('transport_unavailable');
  }
  try {
    return await port.invoke(surface, request);
  } on BookingCallableFailure catch (error) {
    throw LibraryFailure(error.code);
  }
};
