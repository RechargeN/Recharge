/// Transport to the Emulator-only `discoverQueryV1` read (E2). The
/// implementation lives in `app/di` and reuses the authenticated Functions
/// transport; Discover never sees Firebase, tokens or the Session.
abstract interface class CatalogQueryPort {
  /// Sends one `discoverQuery` v1 envelope and returns the decoded answer.
  Future<Map<String, Object?>> query(Map<String, Object?> request);
}

/// The request did not complete (no connection, refused transport, lost
/// answer). A read is safe to repeat; nothing is assumed about its result.
final class CatalogTransportFailure implements Exception {
  const CatalogTransportFailure(this.code);

  final String code;

  @override
  String toString() => 'CatalogTransportFailure($code)';
}
