import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/identity/data/seller_declaration_gateway.dart';
import 'service_locator.dart';

/// ADR 0023 (2026-11-08): the seller declaration gateway over the bound
/// backend transport, or null when no backend is bound (the page then says
/// the details are unavailable). The dev cloud does not serve this callable yet.
Future<SellerDeclarationGateway?> createSellerDeclarationGateway() async {
  if (!sl.isRegistered<BookingTransportRuntime>()) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final port = runtime.remoteCommandsEnabled ? runtime.port : null;
  return port == null ? null : SellerDeclarationGateway(port);
}
