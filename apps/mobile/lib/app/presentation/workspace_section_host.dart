import 'package:flutter/material.dart';

import '../../features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import '../../features/identity/presentation/widgets/workspace_section.dart';
import '../di/service_locator.dart';

/// App-shell bridge that keeps Explore presentation independent of Identity.
class WorkspaceSectionHost extends StatelessWidget {
  const WorkspaceSectionHost({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (sl.isRegistered<LoadIdentityWorkspaceUseCase>()) {
      return WorkspaceSection(userId: userId);
    }
    return const ListTile(
      leading: Icon(Icons.account_tree_outlined),
      title: Text('Switch workspace'),
      subtitle: Text('Personal profile, Professional Pages and Admin access'),
    );
  }
}
