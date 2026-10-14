import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/domain/entities/create_draft_entity.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/content_server_path.dart';
import '../../features/create/application/rental_publication_controller.dart';
import '../../features/create/presentation/widgets/rental_publication_section.dart';
import '../di/rental_publication_composition.dart';

/// Default-off test page for the Rental publication path (D3.3). It hosts the
/// section for the signed-in user's own Create Rental draft and shows nothing
/// unless the test entry builds a controller.
class RentalPublicationPage extends StatelessWidget {
  const RentalPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: RentalPublicationPanel(),
      ),
    );
  }
}

class RentalPublicationPanel extends ConsumerStatefulWidget {
  const RentalPublicationPanel({super.key});

  @override
  ConsumerState<RentalPublicationPanel> createState() =>
      _RentalPublicationPanelState();
}

class _RentalPublicationPanelState
    extends ConsumerState<RentalPublicationPanel> {
  Future<RentalPublicationController?>? _controller;
  RentalPublicationController? _created;
  String? _userId;

  @override
  void dispose() {
    _created?.removeListener(_captureFeedback);
    _created?.dispose();
    super.dispose();
  }

  /// M1 stage 3: the Create form shows this draft's validation refusal.
  void _captureFeedback() {
    final controller = _created;
    if (mounted && controller != null) {
      ref
          .read(contentValidationFeedbackProvider(CreateObjectType.rental))
          .capture(
            accountId: controller.accountId,
            draft: controller.currentDraft,
            message: controller.state.message,
            violations: controller.state.violations,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = ref.watch(authControllerProvider).state.user?.id;
    if (userId == null) {
      return const Text(
        'Sign in to publish your Rental draft',
        key: Key('rental-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.removeListener(_captureFeedback);
      _created?.dispose();
      _created = null;
      _controller = createRentalPublicationController(userId: userId).then((
        RentalPublicationController? controller,
      ) {
        _created = controller;
        controller?.addListener(_captureFeedback);
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<RentalPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<RentalPublicationController?> snapshot,
          ) {
            final RentalPublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return RentalPublicationSection(controller: controller);
          },
    );
  }
}
