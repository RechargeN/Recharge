import '../entities/identity_access_snapshot.dart';
import '../entities/managed_page_entity.dart';
import '../entities/managed_page_membership_entity.dart';
import '../entities/page_limit_increase_request_entity.dart';
import '../entities/workspace_ref.dart';

abstract class IdentityWorkspaceRepository {
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId);

  Future<WorkspaceRef?> loadActiveWorkspace(String userId);

  Future<void> saveActiveWorkspace(String userId, WorkspaceRef workspace);

  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  });

  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  );

  Future<void> savePageLimitRequest(PageLimitIncreaseRequestEntity request);
}
