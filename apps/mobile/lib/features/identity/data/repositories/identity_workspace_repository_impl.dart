import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/page_limit_increase_request_entity.dart';
import '../../domain/entities/workspace_ref.dart';
import '../../domain/repositories/identity_workspace_repository.dart';
import '../datasources/identity_workspace_local_datasource.dart';
import '../datasources/mock_identity_fixture.dart';
import '../datasources/public_professional_page_local_datasource.dart';

class IdentityWorkspaceRepositoryImpl implements IdentityWorkspaceRepository {
  const IdentityWorkspaceRepositoryImpl({
    required IdentityWorkspaceLocalDataSource localDataSource,
    required MockIdentityFixture mockFixture,
    PublicProfessionalPageLocalDataSource? publicPageLocalDataSource,
    Future<String?> Function()? currentActor,
  }) : _localDataSource = localDataSource,
       _mockFixture = mockFixture,
       _currentActor = currentActor,
       _publicPageLocalDataSource = publicPageLocalDataSource;

  final Future<String?> Function()? _currentActor;
  Future<void> _requireActor(String userId) async {
    if (userId.trim().isEmpty ||
        (_currentActor != null && await _currentActor() != userId)) {
      throw StateError('identity_actor_changed');
    }
  }

  IdentityAccessSnapshot _access(
    String userId,
    IdentityManagedPageLocalRecord local,
  ) {
    final fixture = _mockFixture.accessForUser(userId);
    return IdentityAccessSnapshot(
      userId: fixture.userId,
      globalRole: fixture.globalRole,
      creatorVerificationStatus: fixture.creatorVerificationStatus,
      globalCapabilities: fixture.globalCapabilities,
      pages: [...fixture.pages, ...local.pages],
      memberships: [...fixture.memberships, ...local.memberships],
      revision:
          fixture.revision + local.pages.length + local.memberships.length,
    );
  }

  final IdentityWorkspaceLocalDataSource _localDataSource;
  final MockIdentityFixture _mockFixture;
  final PublicProfessionalPageLocalDataSource? _publicPageLocalDataSource;

  @override
  Future<IdentityAccessSnapshot> loadAccessSnapshot(String userId) async {
    await _requireActor(userId);
    final local = await _localDataSource.loadManagedPageRecord(userId);
    await _requireActor(userId);
    return _access(userId, local);
  }

  @override
  Future<WorkspaceRef?> loadActiveWorkspace(String userId) async {
    await _requireActor(userId);
    return _localDataSource.loadActiveWorkspace(userId);
  }

  @override
  Future<void> saveActiveWorkspace(
    String userId,
    WorkspaceRef workspace,
  ) async {
    await _requireActor(userId);
    if (workspace.isPersonal && workspace.id != userId) {
      throw StateError('personal_workspace_user_mismatch');
    }
    await _requireActor(userId);
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
    await _localDataSource.updateManagedPageRecord(userId, (record) async {
      await _requireActor(userId);
      final access = _access(userId, record);
      if (!access.belongsTo(userId) || !access.canCreatePage) {
        throw StateError('page_creation_not_authorized');
      }
      if (record.pages.any((item) => item.id == page.id)) return record;
      if (access.ownedPages.length >=
          IdentityAccessSnapshot.selfServiceOwnedPageLimit) {
        throw StateError('self_service_page_limit_reached');
      }
      if (record.memberships.any((item) => item.pageId == page.id)) {
        throw StateError('invalid_page_ownership_record');
      }
      return IdentityManagedPageLocalRecord(
        pages: [...record.pages, page],
        memberships: [...record.memberships, membership],
        limitRequests: record.limitRequests,
      );
    });
    await _requireActor(userId);
    await _publicPageLocalDataSource?.upsertPage(page);
  }

  @override
  Future<PageLimitIncreaseRequestEntity?> loadPendingPageLimitRequest(
    String userId,
  ) async {
    await _requireActor(userId);
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
    await _localDataSource.updateManagedPageRecord(request.userId, (
      record,
    ) async {
      await _requireActor(request.userId);
      if (record.limitRequests.any(
        (item) =>
            item.id == request.id ||
            (item.userId == request.userId && item.isPending),
      )) {
        return record;
      }
      return IdentityManagedPageLocalRecord(
        pages: record.pages,
        memberships: record.memberships,
        limitRequests: [...record.limitRequests, request],
      );
    });
  }
}
