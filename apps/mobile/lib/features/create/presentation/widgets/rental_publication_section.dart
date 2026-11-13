import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import 'publication_texts.dart';
import '../../application/rental_publication_controller.dart';
import '../../domain/entities/event_publication.dart';

/// Test-path view of the Rental publication (D3.3). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the Rental itself is the user's Create draft.
class RentalPublicationSection extends StatelessWidget {
  const RentalPublicationSection({super.key, required this.controller});

  final RentalPublicationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final RentalPublicationViewState state = controller.state;
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
              state.draftTitle ?? context.l10n.publicationNoDraft('rental'),
              key: const Key('rental-publication-draft-title'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('rental-publication-status'),
            ),
            if (state.record != null)
              Text(
                context.l10n.publicationMediaUploaded(
                  state.record!.attachments.length,
                ),
                key: const Key('rental-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                context.l10n.publicationRevision(
                  '${status!.currentPublishedRevisionId}',
                ),
                key: const Key('rental-publication-revision'),
              ),
            if (state.message != null)
              Text(
                PublicationTexts.message(context.l10n, state.message!),
                key: const Key('rental-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            // M1 D2: someone else's newer revision; nothing is overwritten
            // until the user explicitly saves their version.
            if (state.conflict != null)
              Text(
                context.l10n.publicationConflict(
                  '${state.conflict!.serverRevision}',
                ),
                key: const Key('rental-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'rental-publication-save',
                  context.l10n.publicationSave,
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'rental-publication-media-upload',
                  context.l10n.publicationUploadMedia,
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'rental-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'rental-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == RentalPublicationPhase.ready ||
                      state.phase == RentalPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'rental-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'rental-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'rental-publication-save-over-server',
                    context.l10n.publicationSaveMyVersion,
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.publicationMyObjects('rental'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final RentalPublicationObjectView item in state.myObjects)
              ListTile(
                key: Key('rental-publication-object-${item.record.contentId}'),
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
    RentalPublicationViewState state,
  ) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return l10n.publicationNotSaved;
    if (status == null) return l10n.publicationServerDraft;
    return PublicationTexts.objectLine(l10n, status);
  }
}
