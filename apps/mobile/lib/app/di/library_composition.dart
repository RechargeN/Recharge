import 'package:flutter/foundation.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/library/data/library_sync_client.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'dev_content_media_port.dart';

const libraryTestEntryDefined = bool.fromEnvironment('RECHARGE_TEST_LIBRARY');

/// Pilot 2.1 (owner 2026-11-21): the server Library against the dev/stage
/// cloud, through the authenticated Content/Media dev transport. Debug only.
const p2DevLibraryDefined = bool.fromEnvironment('P2_DEV_LIBRARY');

bool libraryCloudAllowed(DevContentMediaPort? devPort) =>
    p2DevLibraryDefined && !kReleaseMode && devPort != null;

bool libraryRemoteAllowed(
  BookingBackendBindingController binding, {
  DevContentMediaPort? devPort,
}) =>
    libraryCloudAllowed(devPort) ||
    (libraryTestEntryDefined &&
        !kReleaseMode &&
        binding.mode == BackendBindingMode.testBackend &&
        isLoopbackDemoEmulatorBinding(binding));

LibraryInvoke libraryInvoke({
  required BookingBackendBindingController binding,
  required Future<BookingTransportRuntime> Function() runtime,
  DevContentMediaPort? devPort,
}) => (surface, request) async {
  if (libraryCloudAllowed(devPort)) {
    try {
      return await devPort!.port.invoke(surface, request);
    } on BookingCallableFailure catch (error) {
      throw LibraryFailure(error.code);
    }
  }
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
