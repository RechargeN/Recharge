import '../entities/identity_access_snapshot.dart';
import '../entities/workspace_ref.dart';
import '../repositories/identity_workspace_repository.dart';

class WorkspaceSelectionException implements Exception {
  const WorkspaceSelectionException(this.code);

  final String code;
}

class SelectWorkspaceUseCase {
  const SelectWorkspaceUseCase(this._repository);

  final IdentityWorkspaceRepository _repository;

  Future<WorkspaceRef> call({
    required String userId,
    required WorkspaceRef workspace,
  }) async {
    if (workspace.isPersonal) {
      if (workspace.id != userId) {
        throw const WorkspaceSelectionException(
          'personal_workspace_user_mismatch',
        );
      }
    } else {
      final IdentityAccessSnapshot snapshot = await _repository
          .loadAccessSnapshot(userId);
      if (!snapshot.canActivatePage(workspace.id)) {
        throw const WorkspaceSelectionException('workspace_access_unavailable');
      }
    }

    await _repository.saveActiveWorkspace(userId, workspace);
    return workspace;
  }
}
