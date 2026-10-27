import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import 'publication_texts.dart';
import '../../application/place_publication_controller.dart';
import '../../domain/entities/event_publication.dart';

/// Test-path view of the Place publication (D3.1). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the Place itself is the user's Create draft.
class PlacePublicationSection extends StatelessWidget {
  const PlacePublicationSection({super.key, required this.controller});

  final PlacePublicationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final PlacePublicationViewState state = controller.state;
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
              state.draftTitle ?? context.l10n.publicationNoDraft('place'),
              key: const Key('place-publication-draft-title'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('place-publication-status'),
            ),
            if (state.record != null)
              Text(
                context.l10n.publicationMediaUploaded(
                  state.record!.attachments.length,
                ),
                key: const Key('place-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                context.l10n.publicationRevision(
                  '${status!.currentPublishedRevisionId}',
                ),
                key: const Key('place-publication-revision'),
              ),
            if (state.message != null)
              Text(
                PublicationTexts.message(context.l10n, state.message!),
                key: const Key('place-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            // M1 D2: someone else's newer revision; nothing is overwritten
            // until the user explicitly saves their version.
            if (state.conflict != null)
              Text(
                context.l10n.publicationConflict(
                  '${state.conflict!.serverRevision}',
                ),
                key: const Key('place-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'place-publication-save',
                  context.l10n.publicationSave,
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'place-publication-media-upload',
                  context.l10n.publicationUploadMedia,
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'place-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'place-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == PlacePublicationPhase.ready ||
                      state.phase == PlacePublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'place-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'place-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'place-publication-save-over-server',
                    context.l10n.publicationSaveMyVersion,
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.publicationMyObjects('place'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final PlacePublicationObjectView item in state.myObjects)
              ListTile(
                key: Key('place-publication-object-${item.record.contentId}'),
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
    PlacePublicationViewState state,
  ) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return l10n.publicationNotSaved;
    if (status == null) return l10n.publicationServerDraft;
    return PublicationTexts.objectLine(l10n, status);
  }
}
