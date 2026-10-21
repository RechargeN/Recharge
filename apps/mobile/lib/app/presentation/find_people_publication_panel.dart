import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/content_server_path.dart';
import '../../features/create/application/find_people_publication_controller.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/presentation/widgets/find_people_publication_section.dart';
import '../di/find_people_publication_composition.dart';

/// Default-off test page for the Find People publication path (D3.7). It hosts
/// the section for the signed-in user's own Create Find People draft and shows
/// nothing unless the test entry builds a controller.
class FindPeoplePublicationPage extends StatelessWidget {
  const FindPeoplePublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find People publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: FindPeoplePublicationPanel(),
      ),
    );
  }
}

class FindPeoplePublicationPanel extends ConsumerStatefulWidget {
  const FindPeoplePublicationPanel({super.key});

  @override
  ConsumerState<FindPeoplePublicationPanel> createState() =>
      _FindPeoplePublicationPanelState();
}

class _FindPeoplePublicationPanelState
    extends ConsumerState<FindPeoplePublicationPanel> {
  Future<FindPeoplePublicationController?>? _controller;
  FindPeoplePublicationController? _created;
  String? _userId;

  @override
  void dispose() {
    _created?.removeListener(_captureFeedback);
    _created?.dispose();
    super.dispose();
  }

  /// The Create form shows this draft's validation refusal (M1 stage 3).
  void _captureFeedback() {
    final FindPeoplePublicationController? controller = _created;
    if (mounted && controller != null) {
      ref
          .read(contentValidationFeedbackProvider(CreateObjectType.findPeople))
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
        'Sign in to publish your Find People draft',
        key: Key('find-people-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.removeListener(_captureFeedback);
      _created?.dispose();
      _created = null;
      _controller = createFindPeoplePublicationController(userId: userId).then((
        FindPeoplePublicationController? controller,
      ) {
        _created = controller;
        controller?.addListener(_captureFeedback);
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<FindPeoplePublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<FindPeoplePublicationController?> snapshot,
          ) {
            final FindPeoplePublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return FindPeoplePublicationSection(controller: controller);
          },
    );
  }
}
