import '../entities/identity_access_snapshot.dart';
import '../entities/page_limit_increase_request_entity.dart';
import '../entities/workspace_ref.dart';
import '../repositories/identity_workspace_repository.dart';

class IdentityWorkspaceLoadResult {
  const IdentityWorkspaceLoadResult({
    required this.accessSnapshot,
    required this.activeWorkspace,
    required this.pendingLimitRequest,
    required this.recoveryReasonCode,
  });

  final IdentityAccessSnapshot accessSnapshot;
  final WorkspaceRef activeWorkspace;
  final PageLimitIncreaseRequestEntity? pendingLimitRequest;
  final String? recoveryReasonCode;
}

class LoadIdentityWorkspaceUseCase {
  const LoadIdentityWorkspaceUseCase(this._repository);

  final IdentityWorkspaceRepository _repository;

  Future<IdentityWorkspaceLoadResult> call(String userId) async {
    final IdentityAccessSnapshot snapshot = await _repository
        .loadAccessSnapshot(userId);
    final WorkspaceRef personal = WorkspaceRef.personal(userId);
    final WorkspaceRef? saved = await _repository.loadActiveWorkspace(userId);
    final PageLimitIncreaseRequestEntity? pendingLimitRequest =
        await _repository.loadPendingPageLimitRequest(userId);

    if (saved == null) {
      return IdentityWorkspaceLoadResult(
        accessSnapshot: snapshot,
        activeWorkspace: personal,
        pendingLimitRequest: pendingLimitRequest,
        recoveryReasonCode: null,
      );
    }

    if (saved.isPersonal && saved.id == userId) {
      return IdentityWorkspaceLoadResult(
        accessSnapshot: snapshot,
        activeWorkspace: saved,
        pendingLimitRequest: pendingLimitRequest,
        recoveryReasonCode: null,
      );
    }

    if (saved.isPage && snapshot.canActivatePage(saved.id)) {
      return IdentityWorkspaceLoadResult(
        accessSnapshot: snapshot,
        activeWorkspace: saved,
        pendingLimitRequest: pendingLimitRequest,
        recoveryReasonCode: null,
      );
    }

    await _repository.saveActiveWorkspace(userId, personal);
    return IdentityWorkspaceLoadResult(
      accessSnapshot: snapshot,
      activeWorkspace: personal,
      pendingLimitRequest: pendingLimitRequest,
      recoveryReasonCode: 'workspace_access_unavailable',
    );
  }
}
