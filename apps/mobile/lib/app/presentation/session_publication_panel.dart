import 'package:flutter/material.dart';

import '../../core/localization/l10n_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/domain/entities/create_draft_entity.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/content_server_path.dart';
import '../../features/create/application/session_publication_controller.dart';
import '../../features/create/presentation/widgets/session_publication_section.dart';
import '../di/session_publication_composition.dart';

/// Default-off test page for the Session publication path (D3.5). It hosts the
/// section for the signed-in user's own Create Session draft and shows nothing
/// unless the test entry builds a controller.
class SessionPublicationPage extends StatelessWidget {
  const SessionPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.publicationPageTitle('session'))),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SessionPublicationPanel(),
      ),
    );
  }
}

class SessionPublicationPanel extends ConsumerStatefulWidget {
  const SessionPublicationPanel({super.key});

  @override
  ConsumerState<SessionPublicationPanel> createState() =>
      _SessionPublicationPanelState();
}

class _SessionPublicationPanelState
    extends ConsumerState<SessionPublicationPanel> {
  Future<SessionPublicationController?>? _controller;
  SessionPublicationController? _created;
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
          .read(contentValidationFeedbackProvider(CreateObjectType.session))
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
      return Text(
        context.l10n.publicationSignIn('session'),
        key: const Key('session-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.removeListener(_captureFeedback);
      _created?.dispose();
      _created = null;
      _controller = createSessionPublicationController(userId: userId).then((
        SessionPublicationController? controller,
      ) {
        _created = controller;
        controller?.addListener(_captureFeedback);
        controller?.load();
        return controller;
      });
    }
    return FutureBuilder<SessionPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<SessionPublicationController?> snapshot,
          ) {
            final SessionPublicationController? controller = snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return SessionPublicationSection(controller: controller);
          },
    );
  }
}
