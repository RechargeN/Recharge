import 'package:connectivity_plus/connectivity_plus.dart';

import '../../features/auth/domain/repositories/network_status.dart';

/// The phone's own network status (connectivity_plus). A transport is not a
/// proof of internet; a failed server check covers that case in AuthController.
final class ConnectivityNetworkStatus implements NetworkStatus {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<bool> isOnline() async {
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } on Object {
      return true; // Unknown is never shown as "no network".
    }
  }

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasNetwork);

  static bool _hasNetwork(List<ConnectivityResult> transports) =>
      transports.any((transport) => transport != ConnectivityResult.none);
}
