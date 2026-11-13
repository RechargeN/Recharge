import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import '../../features/media/domain/repositories/media_upload_gateway.dart';
import 'booking_test_entry_guard.dart';
import 'service_locator.dart';

/// Lets Media use the authenticated Functions transport without the Media
/// feature importing the Booking feature.
final class BookingPortMediaAdapter implements MediaCallablePort {
  const BookingPortMediaAdapter(this._port);

  final BookingCallablePort _port;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    try {
      return await _port.invoke(callableName, data);
    } on BookingCallableFailure catch (error) {
      throw MediaTransportFailure(error.code);
    }
  }
}

/// The same default-off guard as the Booking test entry, applied to Media.
final class BookingGuardMediaGate implements MediaCommandGate {
  const BookingGuardMediaGate(this._guard);

  final BookingTestEntryGuard _guard;

  @override
  void assertAllowed() => _guard.assertAllowed();
}

MediaUploadGateway mediaUploadGatewayFor({
  required BookingCallablePort port,
  required MediaCommandGate gate,
}) => FunctionsMediaUploadGateway(
  port: BookingPortMediaAdapter(port),
  gate: gate,
);

/// Builds the Media upload gateway from the real `testBackend` runtime, or null
/// unless the whole test entry is allowed.
Future<MediaUploadGateway?> createMediaUploadGateway() async {
  if (!sl.isRegistered<BookingTestEntryGuard>()) return null;
  final BookingTestEntryGuard guard = sl<BookingTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  return mediaUploadGatewayFor(port: port, gate: BookingGuardMediaGate(guard));
}
