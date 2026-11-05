import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/page_limit_increase_request_entity.dart';
import '../../domain/entities/workspace_ref.dart';
import '../../domain/repositories/identity_workspace_repository.dart';
import '../../domain/repositories/public_professional_page_repository.dart';

/// Only server revalidation supplies authority. No Local fixtures or page writers.
final class DevIdentityWorkspaceRepository
    implements IdentityWorkspaceRepository {
  DevIdentityWorkspaceRepository({required this.revalidate});
  final Future<IdentityAccessSnapshot> Function(String userId) revalidate;
  Future<IdentityAccessSnapshot> _read(String userId) async {
    final snapshot = await revalidate(userId);
    if (snapshot.userId != userId ||
        snapshot.pages.isNotEmpty ||
        snapshot.memberships.isNotEmpty ||
        snapshot.isVerifiedCreator) {
      throw StateError('dev_workspace_authority_invalid');
    }
    return snapshot;
  }

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) =>
      _read(userId);
  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async {
    await _read(userId);
    return WorkspaceRef.personal(userId);
  }

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    await _read(userId);
    if (!workspace.isPersonal || workspace.id != userId) {
      throw StateError('dev_workspace_page_disabled');
    }
  }

  @override
  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  }) async {
    throw StateError('dev_workspace_page_disabled');
  }

  @override
  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  ) async {
    await _read(userId);
    return null;
  }

  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {
    throw StateError('dev_workspace_page_disabled');
  }
}

final class DisabledDevPublicProfessionalPageRepository
    implements PublicProfessionalPageRepository {
  const DisabledDevPublicProfessionalPageRepository();
  @override
  Future<ManagedPageEntity?> findById(String pageId) async => null;
  @override
  Future<ManagedPageEntity?> findBySlug(String slug) async => null;
}
