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
      // Owner 2026-11-23: identity is the Google (later Apple) sign-in that
      // made this server Session. Paid and booking rules stay on the server.
      creatorVerificationStatus: CreatorVerificationStatus.verified,
      globalCapabilities: Set<String>.unmodifiable(
        context.result.user.capabilities,
      ),
      pages: const [],
      memberships: const [],
      revision: context.accountRevision,
    );
  },
);
