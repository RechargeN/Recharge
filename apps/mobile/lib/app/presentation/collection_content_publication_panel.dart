import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/domain/entities/create_draft_entity.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/content_server_path.dart';
import '../../features/create/application/collection_content_publication_controller.dart';
import '../../features/create/presentation/widgets/collection_content_publication_section.dart';
import '../di/collection_content_publication_composition.dart';

/// Default-off test page for the Collection publication path (D3.4). It hosts
/// the section for the signed-in user's own Create Collection draft and shows
/// nothing unless the test entry builds a controller.
class CollectionContentPublicationPage extends StatelessWidget {
  const CollectionContentPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: CollectionContentPublicationPanel(),
      ),
    );
  }
}

class CollectionContentPublicationPanel extends ConsumerStatefulWidget {
  const CollectionContentPublicationPanel({super.key});

  @override
  ConsumerState<CollectionContentPublicationPanel> createState() =>
      _CollectionContentPublicationPanelState();
}

class _CollectionContentPublicationPanelState
    extends ConsumerState<CollectionContentPublicationPanel> {
  Future<CollectionContentPublicationController?>? _controller;
  CollectionContentPublicationController? _created;
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
          .read(contentValidationFeedbackProvider(CreateObjectType.collection))
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
        'Sign in to publish your Collection draft',
        key: Key('collection-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.removeListener(_captureFeedback);
      _created?.dispose();
      _created = null;
      _controller = createCollectionContentPublicationController(userId: userId)
          .then((CollectionContentPublicationController? controller) {
            _created = controller;
            controller?.addListener(_captureFeedback);
            controller?.load();
            return controller;
          });
    }
    return FutureBuilder<CollectionContentPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<CollectionContentPublicationController?> snapshot,
          ) {
            final CollectionContentPublicationController? controller =
                snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return CollectionContentPublicationSection(controller: controller);
          },
    );
  }
}
