/// OFFLINE-01 (owner decision 2026-11-21 #6): whether the phone has a network.
/// A hint for the UI only: it never grants or ends server authority.
abstract interface class NetworkStatus {
  Future<bool> isOnline();

  Stream<bool> get changes;
}
