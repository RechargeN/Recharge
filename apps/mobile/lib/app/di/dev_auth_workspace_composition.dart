import '../../features/auth/data/repositories/dev_server_auth_repository.dart';
import '../../features/identity/data/repositories/dev_identity_workspace_repository.dart';
import '../../features/identity/domain/entities/identity_access_snapshot.dart';

DevIdentityWorkspaceRepository createDevIdentityWorkspaceRepository(
  DevServerAuthRepository auth,
) => DevIdentityWorkspaceRepository(
  revalidate: (userId) async {
    final context = await auth.revalidateContext();
    if (context == null || context.result.user.id != userId) {
      throw StateError('dev_workspace_unauthenticated');
    }
    return IdentityAccessSnapshot(
      userId: userId,
      globalRole: context.result.user.role,
      creatorVerificationStatus: CreatorVerificationStatus.notStarted,
      globalCapabilities: Set<String>.unmodifiable(
        context.result.user.capabilities,
      ),
      pages: const [],
      memberships: const [],
      revision: context.accountRevision,
    );
  },
);
