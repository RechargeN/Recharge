import '../../core/layout/page_list_padding.dart';
import '../../core/localization/l10n_context.dart';
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
      appBar: AppBar(title: Text(context.l10n.identityAdminTools)),
      body: access?.canUseAdminTools != true
          ? Center(child: Text(context.l10n.adminToolsUnavailable))
          : ListView(
              padding: pageListPadding(context, const EdgeInsets.all(20)),
              children: [
                Text(context.l10n.adminToolsLocalMock),
                Text(context.l10n.adminToolsNoDecisions),
                if (access!.hasGlobalCapability('moderate.route') ||
                    access.hasGlobalCapability('manage.route'))
                  ListTile(
                    title: Text(context.l10n.createRouteRouteModeration),
                    onTap: () => context.push(RouteNames.routeModeration),
                  ),
              ],
            ),
    );
  }
}
