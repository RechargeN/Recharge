import 'dart:io';

import 'package:http/http.dart' as http;

import 'booking_callable_adapter.dart';
import 'booking_functions_transport.dart';
import 'booking_persistence_store.dart';

typedef BookingSupportDirectoryProvider = Future<Directory> Function();

final class BookingTransportRuntime {
  const BookingTransportRuntime._({
    required this.binding,
    this.adapter,
    this.port,
    this.identitySessions,
  });

  const BookingTransportRuntime.localMock()
    : this._(binding: BookingBackendBinding.localMock);

  const BookingTransportRuntime.productionDisabled()
    : this._(binding: BookingBackendBinding.productionDisabled);

  const BookingTransportRuntime.devEmulator({
    required BookingCallableAdapter adapter,
    required BookingCallablePort port,
    required FunctionsIdentitySessionClient identitySessions,
  }) : this._(
         binding: BookingBackendBinding.devEmulator,
         adapter: adapter,
         port: port,
         identitySessions: identitySessions,
       );

  final BookingBackendBinding binding;
  final BookingCallableAdapter? adapter;
  final BookingCallablePort? port;
  final FunctionsIdentitySessionClient? identitySessions;

  bool get remoteCommandsEnabled =>
      binding == BookingBackendBinding.devEmulator && adapter != null;
}

/// Lazily creates the mobile Booking transport. Local/mock remains the default
/// and a release build can never activate the Emulator adapter.
final class BookingTransportRuntimeFactory {
  BookingTransportRuntimeFactory({
    required BookingBackendEndpoint endpoint,
    required http.Client client,
    required BookingFirebaseIdTokenProvider tokens,
    required BookingIdentitySessionStore sessions,
    required BookingInstallationIdProvider installations,
    required BookingSupportDirectoryProvider supportDirectory,
  }) : _endpoint = endpoint,
       _client = client,
       _tokens = tokens,
       _sessions = sessions,
       _installations = installations,
       _supportDirectory = supportDirectory;

  final BookingBackendEndpoint _endpoint;
  final http.Client _client;
  final BookingFirebaseIdTokenProvider _tokens;
  final BookingIdentitySessionStore _sessions;
  final BookingInstallationIdProvider _installations;
  final BookingSupportDirectoryProvider _supportDirectory;

  Future<BookingTransportRuntime> create() async {
    switch (_endpoint.binding) {
      case BookingBackendBinding.localMock:
        return const BookingTransportRuntime.localMock();
      case BookingBackendBinding.productionDisabled:
        return const BookingTransportRuntime.productionDisabled();
      case BookingBackendBinding.devEmulator:
        final support = await _supportDirectory();
        final separator = Platform.pathSeparator;
        final persistence = FileBookingPersistenceStore(
          File(
            '${support.path}${separator}booking${separator}transport-v1.json',
          ),
        );
        final identitySessions = FunctionsIdentitySessionClient(
          endpoint: _endpoint,
          client: _client,
          tokens: _tokens,
          installations: _installations,
          sessions: _sessions,
        );
        final port = FunctionsBookingCallablePort(
          endpoint: _endpoint,
          client: _client,
          tokens: _tokens,
          sessions: _sessions,
          identitySessions: identitySessions,
        );
        return BookingTransportRuntime.devEmulator(
          adapter: BookingCallableAdapter(
            port: port,
            operations: persistence.operationStore,
            receipts: persistence.receiptStore,
          ),
          port: port,
          identitySessions: identitySessions,
        );
    }
  }
}
