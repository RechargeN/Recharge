import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/identity/application/identity_workspace_providers.dart';
import '../application/active_creator_verification_provider.dart';
import '../router/route_names.dart';

class AdminToolsPage extends ConsumerStatefulWidget {
  const AdminToolsPage({super.key});
  @override
  ConsumerState<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends ConsumerState<AdminToolsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(identityWorkspaceControllerProvider).revalidateAccess(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(activeIdentityAccessProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin tools')),
      body: access?.canUseAdminTools != true
          ? const Center(child: Text('Admin access unavailable'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Local/mock administration'),
                const Text(
                  'Verification and quota decisions are not available.',
                ),
                if (access!.hasGlobalCapability('moderate.route') ||
                    access.hasGlobalCapability('manage.route'))
                  ListTile(
                    title: const Text('Route moderation'),
                    onTap: () => context.push(RouteNames.routeModeration),
                  ),
              ],
            ),
    );
  }
}
