import '../entities/publisher_ref.dart';

/// Fresh (non-cached) answer to "may [actorUserId] still publish as
/// [publisher]?" — IDP-05A. Create never reads Identity directly; the app
/// layer composes this port. A Page publisher whose access was revoked,
/// suspended or never held must be denied; the draft itself stays untouched.
abstract interface class PublisherAccessCheck {
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
  });
}
