import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/admin_tools_page.dart';
import 'package:recharge/features/identity/application/identity_workspace_providers.dart';
import 'package:recharge/features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import 'package:recharge/features/identity/domain/entities/workspace_ref.dart';
import '../unit/identity_access_guards_test.dart';

void main() {
  testWidgets(
    'Admin surface is separate from workspace and loses tools on revocation',
    (tester) async {
      await sl.reset();
      final repository = GuardRepository(guardSnapshot())
        ..workspace = WorkspaceRef.page('page-a');
      final controller = guardController(repository);
      sl.registerSingleton<LoadIdentityWorkspaceUseCase>(
        LoadIdentityWorkspaceUseCase(repository),
      );
      await controller.ensureLoaded('alice');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityWorkspaceControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
          child: const MaterialApp(home: AdminToolsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Route moderation'), findsOneWidget);
      expect(controller.state.activeWorkspace, WorkspaceRef.page('page-a'));
      repository.change(guardSnapshot(capabilities: {}));
      await tester.pumpAndSettle();
      expect(find.text('Route moderation'), findsNothing);
      expect(find.text('Admin access unavailable'), findsOneWidget);
      expect(controller.state.activeWorkspace, WorkspaceRef.page('page-a'));
      await tester.pumpWidget(const SizedBox());
      await sl.reset();
    },
  );
}
