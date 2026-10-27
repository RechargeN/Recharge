import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import 'publication_texts.dart';
import '../../application/activity_publication_controller.dart';
import '../../domain/entities/event_publication.dart';

/// Test-path view of the Recharge Activity publication (D3.2). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the Activity itself is the user's Create draft.
class ActivityPublicationSection extends StatelessWidget {
  const ActivityPublicationSection({
    super.key,
    required this.controller,
    this.onEdit,
  });

  final ActivityPublicationController controller;
  final Future<void> Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final ActivityPublicationViewState state = controller.state;
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
              state.draftTitle ?? context.l10n.publicationNoDraft('activity'),
              key: const Key('activity-publication-draft-title'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('activity-publication-status'),
            ),
            if (state.record != null)
              Text(
                context.l10n.publicationMediaUploaded(
                  state.record!.attachments.length,
                ),
                key: const Key('activity-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                context.l10n.publicationPublishedVersion(
                  '${status!.currentPublishedRevisionId}',
                ),
                key: const Key('activity-publication-revision'),
              ),
            if (state.record != null)
              Text(
                state.record!.editingFromRevisionId != null
                    ? context.l10n.publicationDraftRevisionPending(
                        '${state.record!.draftRevision}',
                      )
                    : context.l10n.publicationDraftRevision(
                        '${state.record!.draftRevision}',
                      ),
                key: const Key('activity-publication-editing'),
              ),
            if (state.message != null)
              Text(
                state.message == 'validation_failed'
                    ? context.l10n.publicationActivityCheckFields
                    : PublicationTexts.message(context.l10n, state.message!),
                key: const Key('activity-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            // M1 D2: someone else's newer revision; nothing is overwritten
            // until the user explicitly saves their version.
            if (state.conflict != null)
              Text(
                context.l10n.publicationConflict(
                  '${state.conflict!.serverRevision}',
                ),
                key: const Key('activity-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'activity-publication-save',
                  context.l10n.publicationSave,
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'activity-publication-media-upload',
                  context.l10n.publicationUploadMedia,
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'activity-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'activity-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == ActivityPublicationPhase.ready ||
                      state.phase == ActivityPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'activity-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'activity-publication-activate',
                  context.l10n.publicationActivatePublished,
                  state.canActivate,
                  controller.activate,
                ),
                if (onEdit != null)
                  _action(
                    'activity-publication-edit',
                    context.l10n.publicationEditInCreate,
                    state.canEdit,
                    onEdit!,
                  ),
                _action(
                  'activity-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'activity-publication-save-over-server',
                    context.l10n.publicationSaveMyVersion,
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.publicationMyObjects('activity'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final ActivityPublicationObjectView item in state.myObjects)
              ListTile(
                key: Key(
                  'activity-publication-object-${item.record.contentId}',
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
    ActivityPublicationViewState state,
  ) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return l10n.publicationNotSaved;
    if (status == null) return l10n.publicationServerDraft;
    return PublicationTexts.objectLine(l10n, status);
  }
}
