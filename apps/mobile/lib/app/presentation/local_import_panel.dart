import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/local_import_controller.dart';
import '../../features/create/presentation/widgets/local_import_section.dart';
import '../di/local_import_composition.dart';

/// Default-off test page for the local→server import (D4). It hosts the
/// section for the signed-in user's own local data and shows nothing unless
/// the test entry builds a controller.
class LocalImportPage extends StatelessWidget {
  const LocalImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import local data (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: LocalImportPanel(),
      ),
    );
  }
}

class LocalImportPanel extends ConsumerStatefulWidget {
  const LocalImportPanel({super.key});

  @override
  ConsumerState<LocalImportPanel> createState() => _LocalImportPanelState();
}

class _LocalImportPanelState extends ConsumerState<LocalImportPanel> {
  Future<LocalImportController?>? _controller;
  LocalImportController? _created;
  String? _userId;

  @override
  void dispose() {
    _created?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = ref.watch(authControllerProvider).state.user?.id;
    if (userId == null) {
      return const Text(
        'Sign in to import your local data',
        key: Key('local-import-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.dispose();
      _created = null;
      _controller = createLocalImportController(userId: userId).then((
        LocalImportController? controller,
      ) {
        _created = controller;
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<LocalImportController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<LocalImportController?> snapshot,
          ) {
            final LocalImportController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return LocalImportSection(controller: controller);
          },
    );
  }
}
