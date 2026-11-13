import 'package:flutter/material.dart';

import '../../core/localization/l10n_context.dart';
import '../../features/create/presentation/widgets/publication_texts.dart';
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
      appBar: AppBar(
        title: Text(context.l10n.publicationPageTitle('classWorkshop')),
      ),
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
      return Text(
        context.l10n.publicationSignIn('classWorkshop'),
        key: const Key('class-workshop-publication-signed-out'),
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
              context.l10n.publicationTestPath,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ??
                  context.l10n.publicationNoDraft('classWorkshop'),
              key: const Key('class-workshop-publication-draft-title'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('class-workshop-publication-status'),
            ),
            if (state.record != null)
              Text(
                context.l10n.publicationMediaUploaded(
                  state.record!.attachments.length,
                ),
                key: const Key('class-workshop-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                context.l10n.publicationRevision(
                  '${status!.currentPublishedRevisionId}',
                ),
                key: const Key('class-workshop-publication-revision'),
              ),
            if (state.message != null)
              Text(
                PublicationTexts.message(context.l10n, state.message!),
                key: const Key('class-workshop-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            // M1 D2: someone else's newer revision; nothing is overwritten
            // until the user explicitly saves their version.
            if (state.conflict != null)
              Text(
                context.l10n.publicationConflict(
                  '${state.conflict!.serverRevision}',
                ),
                key: const Key('class-workshop-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'class-workshop-publication-save',
                  context.l10n.publicationSave,
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'class-workshop-publication-media-upload',
                  context.l10n.publicationUploadMedia,
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'class-workshop-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'class-workshop-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == ClassWorkshopPublicationPhase.ready ||
                      state.phase == ClassWorkshopPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'class-workshop-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'class-workshop-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'class-workshop-publication-save-over-server',
                    context.l10n.publicationSaveMyVersion,
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.publicationMyObjects('classWorkshop'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
                      ? PublicationTexts.unavailable(
                          context.l10n,
                          item.failureCode,
                        )
                      : PublicationTexts.objectLine(context.l10n, item.status!),
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

  static String _statusLine(
    AppLocalizations l10n,
    ClassWorkshopPublicationViewState state,
  ) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return l10n.publicationNotSaved;
    if (status == null) return l10n.publicationServerDraft;
    return PublicationTexts.objectLine(l10n, status);
  }
}
