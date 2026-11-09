import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/publisher_access_check.dart';

/// Explicit authorization for tests of unrelated publishing business rules.
/// Identity authorization itself is covered with the real adapter and snapshots.
class TestPersonalPublisherAccess implements PublisherAccessCheck {
  const TestPersonalPublisherAccess();
  @override
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
    Set<String> requiredCapabilities = const {},
    bool requireAdmin = false,
  }) async =>
      !requireAdmin &&
      publisher.type == PublisherType.user &&
      publisher.id == actorUserId;
}
