import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/discover/data/datasources/content_translation_client.dart';
import '../../features/discover/domain/repositories/content_translation_port.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

/// ADR 0022 stage 1: its own compile-time switch, default off:
/// `--dart-define=RECHARGE_TEST_CONTENT_TRANSLATION=true`.
const bool contentTranslationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_CONTENT_TRANSLATION',
);

bool contentTranslationRemoteAllowed(BookingBackendBindingController binding) =>
    contentTranslationTestEntryDefined &&
    !kReleaseMode &&
    binding.mode == BackendBindingMode.testBackend &&
    isLoopbackDemoEmulatorBinding(binding);

/// Without the guard nothing goes on the wire and Details shows no button.
ContentTranslationInvoke contentTranslationInvoke({
  required BookingBackendBindingController binding,
  required Future<BookingTransportRuntime> Function() runtime,
}) => (surface, request) async {
  if (!contentTranslationRemoteAllowed(binding)) {
    throw const ContentTranslationFailure('test_entry_disabled');
  }
  try {
    final transport = await runtime();
    final port = transport.port;
    if (!transport.remoteCommandsEnabled || port == null) {
      throw const ContentTranslationFailure('transport_unavailable');
    }
    return await port.invoke(surface, request);
  } on BookingCallableFailure catch (error) {
    throw ContentTranslationFailure(error.code);
  } on ContentTranslationFailure {
    rethrow;
  } on Exception {
    // No server answer: the original stays on screen with a message.
    throw const ContentTranslationFailure('transport_unavailable');
  }
};
