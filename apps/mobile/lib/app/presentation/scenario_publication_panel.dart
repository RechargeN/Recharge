import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/scenario_publication_controller.dart';
import '../../features/create/presentation/widgets/scenario_publication_section.dart';
import '../di/scenario_publication_composition.dart';

/// Default-off test page for the Scenario publication path (I3). It hosts the
/// section for the signed-in user's own Create Scenario and shows nothing
/// unless the test entry builds a controller.
class ScenarioPublicationPage extends StatelessWidget {
  const ScenarioPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scenario publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ScenarioPublicationPanel(),
      ),
    );
  }
}

class ScenarioPublicationPanel extends ConsumerStatefulWidget {
  const ScenarioPublicationPanel({super.key});

  @override
  ConsumerState<ScenarioPublicationPanel> createState() =>
      _ScenarioPublicationPanelState();
}

class _ScenarioPublicationPanelState
    extends ConsumerState<ScenarioPublicationPanel> {
  Future<ScenarioPublicationController?>? _controller;
  ScenarioPublicationController? _created;
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
        'Sign in to publish your Scenario',
        key: Key('scenario-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.dispose();
      _created = null;
      _controller = createScenarioPublicationController(userId: userId).then((
        ScenarioPublicationController? controller,
      ) {
        _created = controller;
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<ScenarioPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<ScenarioPublicationController?> snapshot,
          ) {
            final ScenarioPublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return ScenarioPublicationSection(controller: controller);
          },
    );
  }
}
