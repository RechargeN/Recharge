import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/domain/entities/create_draft_entity.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/create/application/content_server_path.dart';
import '../../features/create/application/class_workshop_publication_controller.dart';
import '../../features/create/domain/entities/event_publication.dart';
import '../di/class_workshop_publication_composition.dart';

/// Default-off test page for the Class / Workshop publication path (D3.6). It hosts the
/// section for the signed-in user's own Create Class / Workshop draft and shows nothing
/// unless the test entry builds a controller.
class ClassWorkshopPublicationPage extends StatelessWidget {
  const ClassWorkshopPublicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class / Workshop publication (test)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: ClassWorkshopPublicationPanel(),
      ),
    );
  }
}

class ClassWorkshopPublicationPanel extends ConsumerStatefulWidget {
  const ClassWorkshopPublicationPanel({super.key});

  @override
  ConsumerState<ClassWorkshopPublicationPanel> createState() =>
      _ClassWorkshopPublicationPanelState();
}

class _ClassWorkshopPublicationPanelState
    extends ConsumerState<ClassWorkshopPublicationPanel> {
  Future<ClassWorkshopPublicationController?>? _controller;
  ClassWorkshopPublicationController? _created;
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
          .read(
            contentValidationFeedbackProvider(CreateObjectType.classWorkshop),
          )
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
        'Sign in to publish your Class draft',
        key: Key('class-workshop-publication-signed-out'),
      );
    }
    // A change of account builds a new controller bound to that account.
    if (_controller == null || _userId != userId) {
      _userId = userId;
      _created?.removeListener(_captureFeedback);
      _created?.dispose();
      _created = null;
      _controller = createClassWorkshopPublicationController(userId: userId)
          .then((ClassWorkshopPublicationController? controller) {
            _created = controller;
            controller?.addListener(_captureFeedback);
            controller?.load();
            return controller;
          });
    }
    return FutureBuilder<ClassWorkshopPublicationController?>(
      future: _controller,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<ClassWorkshopPublicationController?> snapshot,
          ) {
            final ClassWorkshopPublicationController? controller =
                snapshot.data;
            if (controller == null) return const SizedBox.shrink();
            return ClassWorkshopPublicationSection(controller: controller);
          },
    );
  }
}

/// Test-path view of the Class / Workshop publication (D3.6). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the Class itself is the user's Create draft.
class ClassWorkshopPublicationSection extends StatelessWidget {
  const ClassWorkshopPublicationSection({super.key, required this.controller});

  final ClassWorkshopPublicationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final ClassWorkshopPublicationViewState state = controller.state;
        final EventPublicationStatus? status = state.status;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Test publication path (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? 'No Class / Workshop draft in Create',
              key: const Key('class-workshop-publication-draft-title'),
            ),
            Text(
              _statusLine(state),
              key: const Key('class-workshop-publication-status'),
            ),
            if (state.record != null)
              Text(
                'Media uploaded: ${state.record!.attachments.length}',
                key: const Key('class-workshop-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                'Revision ${status!.currentPublishedRevisionId}',
                key: const Key('class-workshop-publication-revision'),
              ),
            if (state.message != null)
              Text(
                state.message!,
                key: const Key('class-workshop-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            // M1 D2: someone else's newer revision; nothing is overwritten
            // until the user explicitly saves their version.
            if (state.conflict != null)
              Text(
                'The server has a newer version '
                '(revision ${state.conflict!.serverRevision}). Your edit is '
                'kept here; nothing was overwritten.',
                key: const Key('class-workshop-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'class-workshop-publication-save',
                  'Save',
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'class-workshop-publication-media-upload',
                  'Upload media',
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'class-workshop-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'class-workshop-publication-refresh',
                  'Refresh',
                  state.phase == ClassWorkshopPublicationPhase.ready ||
                      state.phase == ClassWorkshopPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'class-workshop-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'class-workshop-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'class-workshop-publication-save-over-server',
                    'Save my version',
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('My classes', style: Theme.of(context).textTheme.titleSmall),
            for (final ClassWorkshopPublicationObjectView item
                in state.myObjects)
              ListTile(
                key: Key(
                  'class-workshop-publication-object-${item.record.contentId}',
                ),
                dense: true,
                title: Text(item.record.title),
                subtitle: Text(
                  item.status == null
                      ? 'unavailable: ${item.failureCode}'
                      : _objectLine(item.status!),
                ),
              ),
          ],
        );
      },
    );
  }

  static Widget _action(
    String key,
    String label,
    bool enabled,
    Future<void> Function() onTap,
  ) => FilledButton(
    key: Key(key),
    onPressed: enabled ? onTap : null,
    child: Text(label),
  );

  static String _statusLine(ClassWorkshopPublicationViewState state) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return 'Not saved to the server';
    if (status == null) return 'Saved as a server draft';
    return _objectLine(status);
  }

  static String _objectLine(EventPublicationStatus status) {
    final String review = status.latestSubmissionState ?? 'draft';
    final String visibility = status.visibility ?? 'unpublished';
    return 'review: $review; visibility: $visibility';
  }
}
