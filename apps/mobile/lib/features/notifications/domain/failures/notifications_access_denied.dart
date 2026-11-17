/// The server refused this account access to the inbox (for example an
/// account outside the staging allowlist). Not a transport or load failure:
/// retrying does not help, so the UI says so instead of "could not load".
final class NotificationsAccessDenied implements Exception {
  const NotificationsAccessDenied();

  @override
  String toString() => 'NotificationsAccessDenied';
}
