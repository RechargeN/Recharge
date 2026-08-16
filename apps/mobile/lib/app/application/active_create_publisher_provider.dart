import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/domain/entities/publisher_ref.dart';
import '../../features/identity/application/identity_workspace_providers.dart';
import '../../features/identity/domain/entities/workspace_ref.dart';
import '../../features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import '../di/service_locator.dart';

/// App-level composition bridge between Identity workspace and Create.
final activeCreatePublisherProvider = Provider<PublisherRef?>((ref) {
  if (!sl.isRegistered<LoadIdentityWorkspaceUseCase>()) return null;
  final WorkspaceRef? workspace = ref
      .watch(identityWorkspaceControllerProvider)
      .state
      .activeWorkspace;
  if (workspace == null || workspace.id.trim().isEmpty) return null;
  return PublisherRef(
    type: workspace.isPage ? PublisherType.page : PublisherType.user,
    id: workspace.id,
  );
});
