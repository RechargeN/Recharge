import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/dev_auth_workspace_composition.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/features/identity/data/repositories/dev_identity_workspace_repository.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import '../fixtures/auth/server_auth_packet.dart';

class Gateway implements DevAuthSessionGateway {
  bool revoked = false;
  int calls = 0;
  @override
  Future<ServerAuthContext?> current() => refresh();
  @override
  Future<ServerAuthContext?> refresh() {
    calls++;
    return revoked
        ? Future.error(StateError('revoked'))
        : Future.value(
            ServerAuthContext.fromResponse(
              packet(),
              installationId: 'dev-install',
              now: now,
            ),
          );
  }

  @override
  Future<ServerAuthContext> signInWithGoogle() async => (await refresh())!;
  @override
  Future<void> clearLocal() async {}
  @override
  Future<void> revokeAndSignOut() async {
    revoked = true;
  }
}

void main() {
  test(
    'dev workspace uses server User and cannot import mock Admin/Creator/Page authority',
    () async {
      final gateway = Gateway();
      final repo = DevServerAuthRepository(gateway: gateway, now: () => now);
      final workspace = createDevIdentityWorkspaceRepository(repo);
      const user = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
      final snapshot = await workspace.loadAccessSnapshot(user);
      expect(snapshot.globalRole, 'user');
      expect(snapshot.isVerifiedCreator, isFalse);
      expect(snapshot.globalCapabilities, {'booking.self_service'});
      expect(snapshot.pages, isEmpty);
      expect(snapshot.memberships, isEmpty);
      expect(
        await workspace.loadActiveWorkspace(user),
        WorkspaceRef.personal(user),
      );
      await expectLater(
        workspace.saveActiveWorkspace(user, WorkspaceRef.page('foreign')),
        throwsStateError,
      );
      await expectLater(
        workspace.loadAccessSnapshot('foreign'),
        throwsStateError,
      );
      gateway.revoked = true;
      await expectLater(workspace.loadAccessSnapshot(user), throwsA(anything));
      expect(gateway.calls, greaterThanOrEqualTo(5));
      expect(
        await const DisabledDevPublicProfessionalPageRepository().findById(
          'local-mock-page',
        ),
        isNull,
      );
    },
  );
}
