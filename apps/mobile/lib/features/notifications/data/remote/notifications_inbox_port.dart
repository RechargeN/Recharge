/// Transport to the Emulator-only Notifications callables (F1):
/// `notificationsQueryV1` and `notificationsCommandV1`. The implementation
/// lives in `app/di` and reuses the authenticated Functions transport;
/// Notifications never sees Firebase, tokens or the Session.
abstract interface class NotificationsInboxPort {
  /// Sends one `notificationsQuery` v1 envelope and returns the decoded answer.
  Future<Map<String, Object?>> query(Map<String, Object?> request);

  /// Sends one `notificationsCommand` v1 envelope and returns the decoded answer.
  Future<Map<String, Object?>> command(Map<String, Object?> request);
}

/// The call did not produce a usable answer: no connection, refused transport,
/// a typed refusal or an answer that does not parse. Reads are safe to repeat;
/// a repeated `markRead` carries the same idempotency key.
final class NotificationsInboxFailure implements Exception {
  const NotificationsInboxFailure(this.code);

  final String code;

  @override
  String toString() => 'NotificationsInboxFailure($code)';
}
