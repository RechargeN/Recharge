import '../../features/create/domain/entities/publisher_ref.dart';
import '../../features/create/domain/repositories/publisher_access_check.dart';
import '../../features/identity/domain/entities/identity_access_snapshot.dart';
import '../../features/identity/domain/entities/managed_page_membership_entity.dart';
import '../../features/identity/domain/repositories/identity_workspace_repository.dart';

/// App-level composition of Create's `PublisherAccessCheck` over the local
/// Identity access snapshot (IDP-05A). The snapshot is re-read on every call,
/// so a revoked membership or suspended page is denied at publish time even
/// when the active-workspace preference still points at it.
class IdentityPublisherAccessCheck implements PublisherAccessCheck {
  const IdentityPublisherAccessCheck(this._repository);

  static const String pageSubmitCapability = 'page.content.submit';

  final IdentityWorkspaceRepository _repository;

  @override
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
  }) async {
    if (!publisher.isValid || actorUserId.trim().isEmpty) return false;
    if (publisher.type == PublisherType.user) {
      return publisher.id == actorUserId;
    }
    try {
      final IdentityAccessSnapshot snapshot = await _repository
          .loadAccessSnapshot(actorUserId);
      if (!snapshot.canActivatePage(publisher.id)) return false;
      final ManagedPageMembershipEntity? membership = snapshot.membershipFor(
        publisher.id,
      );
      return membership?.hasCapability(pageSubmitCapability) ?? false;
    } on Object {
      return false;
    }
  }
}
