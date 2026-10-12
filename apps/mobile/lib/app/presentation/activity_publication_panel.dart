import '../../features/create/application/activity_validation_feedback_provider.dart';
import '../../features/create/application/create_providers.dart';
import '../../features/create/application/state/create_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/route_names.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/activity_publication_controller.dart';
import '../../features/create/presentation/widgets/activity_publication_section.dart';
import '../di/activity_publication_composition.dart';

/// Default-off test page for the Recharge Activity publication path (D3.2). It
/// hosts the section for the signed-in user's own Create Activity draft and
/// shows nothing unless the test entry builds a controller.
class ActivityPublicationPage extends StatelessWidget {
  const ActivityPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ActivityPublicationPanel(),
      ),
    );
  }
}

class ActivityPublicationPanel extends ConsumerStatefulWidget {
  const ActivityPublicationPanel({super.key});

  @override
  ConsumerState<ActivityPublicationPanel> createState() =>
      _ActivityPublicationPanelState();
}

class _ActivityPublicationPanelState
    extends ConsumerState<ActivityPublicationPanel> {
  Future<ActivityPublicationController?>? _controller;
  ActivityPublicationController? _created;
  String? _userId;

  @override
  void dispose() {
    _created?.removeListener(_captureFeedback);
    _created?.dispose();
    super.dispose();
  }

  void _captureFeedback() {
    final controller = _created;
    if (mounted && controller != null) {
      ref.read(activityValidationFeedbackProvider).capture(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = ref.watch(authControllerProvider).state.user?.id;
    if (userId == null) {
      return const Text(
        'Sign in to publish your Activity draft',
        key: Key('activity-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.removeListener(_captureFeedback);
      _created?.dispose();
      _created = null;
      _controller = createActivityPublicationController(userId: userId).then((
        ActivityPublicationController? controller,
      ) {
        _created = controller;
        controller?.addListener(_captureFeedback);
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<ActivityPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<ActivityPublicationController?> snapshot,
          ) {
            final ActivityPublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return ActivityPublicationSection(
              controller: controller,
              onEdit: () async {
                // Flush existing Create work before replacing its cached
                // controller. A different current draft is then refused by
                // beginEditing, rather than overwritten or discarded.
                final create = ref.read(createControllerProvider);
                if (create.state.isLoaded) {
                  await create.saveDraft();
                  if (!context.mounted) {
                    return;
                  }
                  if (create.state.saveStatus != CreateSaveStatus.saved) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Save your Create draft before editing this publication.',
                        ),
                      ),
                    );
                    return;
                  }
                }
                await controller.beginEditing();
                if (!context.mounted || controller.state.message != null) {
                  return;
                }
                ref.invalidate(createControllerProvider);
                await context.push<void>(
                  '${RouteNames.createObjectFor('activity')}?publicationEdit=activity',
                );
                if (context.mounted) await controller.refresh();
              },
            );
          },
    );
  }
}
