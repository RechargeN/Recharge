import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/page_limit_increase_request_entity.dart';
import '../../domain/entities/workspace_ref.dart';
import '../../domain/repositories/identity_workspace_repository.dart';
import '../datasources/identity_workspace_local_datasource.dart';
import '../datasources/mock_identity_fixture.dart';

class IdentityWorkspaceRepositoryImpl implements IdentityWorkspaceRepository {
  const IdentityWorkspaceRepositoryImpl({
    required IdentityWorkspaceLocalDataSource localDataSource,
    required MockIdentityFixture mockFixture,
  }) : _localDataSource = localDataSource,
       _mockFixture = mockFixture;

  final IdentityWorkspaceLocalDataSource _localDataSource;
  final MockIdentityFixture _mockFixture;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    final IdentityAccessSnapshot fixture = _mockFixture.accessForUser(userId);
    final IdentityManagedPageLocalRecord local = await _localDataSource
        .loadManagedPageRecord(userId);
    return IdentityAccessSnapshot(
      userId: fixture.userId,
      globalRole: fixture.globalRole,
      creatorVerificationStatus: fixture.creatorVerificationStatus,
      globalCapabilities: fixture.globalCapabilities,
      pages: <ManagedPageEntity>[...fixture.pages, ...local.pages],
      memberships: <ManagedPageMembershipEntity>[
        ...fixture.memberships,
        ...local.memberships,
      ],
      revision:
          fixture.revision + local.pages.length + local.memberships.length,
    );
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) {
    return _localDataSource.loadActiveWorkspace(userId);
  }

  @override
  Future<void> saveActiveWorkspace(String userId, WorkspaceRef workspace) {
    return _localDataSource.saveActiveWorkspace(userId, workspace);
  }

  @override
  Future<void> saveCreatedPage({
    required String userId,
    required ManagedPageEntity page,
    required ManagedPageMembershipEntity membership,
  }) async {
    if (page.ownerUserId != userId ||
        membership.userId != userId ||
        membership.pageId != page.id ||
        !membership.isOwner) {
      throw StateError('invalid_page_ownership_record');
    }
    final IdentityManagedPageLocalRecord record = await _localDataSource
        .loadManagedPageRecord(userId);
    if (record.pages.any((ManagedPageEntity item) => item.id == page.id) ||
        record.memberships.any(
          (ManagedPageMembershipEntity item) => item.pageId == page.id,
        )) {
      return;
    }
    await _localDataSource.saveManagedPageRecord(
      userId,
      IdentityManagedPageLocalRecord(
        pages: <ManagedPageEntity>[...record.pages, page],
        memberships: <ManagedPageMembershipEntity>[
          ...record.memberships,
          membership,
        ],
        limitRequests: record.limitRequests,
      ),
    );
  }

  @override
  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  ) async {
    final IdentityManagedPageLocalRecord record = await _localDataSource
        .loadManagedPageRecord(userId);
    for (final PageLimitIncreaseRequestEntity request
        in record.limitRequests.reversed) {
      if (request.userId == userId && request.isPending) return request;
    }
    return null;
  }

  @override
  Future<void> savePageLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {
    final IdentityManagedPageLocalRecord record = await _localDataSource
        .loadManagedPageRecord(request.userId);
    if (record.limitRequests.any(
      (PageLimitIncreaseRequestEntity item) => item.id == request.id,
    )) {
      return;
    }
    await _localDataSource.saveManagedPageRecord(
      request.userId,
      IdentityManagedPageLocalRecord(
        pages: record.pages,
        memberships: record.memberships,
        limitRequests: <PageLimitIncreaseRequestEntity>[
          ...record.limitRequests,
          request,
        ],
      ),
    );
  }
}
