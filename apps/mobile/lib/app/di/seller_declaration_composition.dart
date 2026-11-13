import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/identity/data/seller_declaration_gateway.dart';
import '../../features/identity/domain/repositories/seller_declaration_repository.dart';
import 'service_locator.dart';

/// ADR 0023 (2026-11-08): the seller declaration over the bound backend
/// transport, or null when no backend is bound (the page then says the
/// details are unavailable). The dev cloud does not serve this callable yet.
Future<SellerDeclarationRepository?> createSellerDeclarationRepository() async {
  if (!sl.isRegistered<BookingTransportRuntime>()) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.remoteCommandsEnabled
      ? runtime.port
      : null;
  return port == null
      ? null
      : SellerDeclarationGateway(_BookingPortSellerAdapter(port));
}

final class _BookingPortSellerAdapter implements SellerDeclarationPort {
  const _BookingPortSellerAdapter(this._port);

  final BookingCallablePort _port;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    try {
      return await _port.invoke(callableName, command);
    } on BookingCallableFailure catch (error) {
      throw SellerDeclarationFailure(error.code);
    }
  }
}
