import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import 'publication_texts.dart';
import '../../application/event_publication_controller.dart';
import '../../domain/entities/event_publication.dart';

/// Test-path view of the Event publication (C3). It renders the controller's
/// state and forwards taps; it holds no rule and no second form: the Event
/// itself is the user's Create draft.
class EventPublicationSection extends StatelessWidget {
  const EventPublicationSection({super.key, required this.controller});

  final EventPublicationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final EventPublicationViewState state = controller.state;
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
              state.draftTitle ?? context.l10n.publicationNoDraft('event'),
              key: const Key('event-publication-draft-title'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('event-publication-status'),
            ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                context.l10n.publicationRevision(
                  '${status!.currentPublishedRevisionId}',
                ),
                key: const Key('event-publication-revision'),
              ),
            if (state.message != null)
              Text(
                PublicationTexts.message(context.l10n, state.message!),
                key: const Key('event-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'event-publication-save',
                  context.l10n.publicationSave,
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'event-publication-cover',
                  context.l10n.publicationUploadCover,
                  state.canUploadCover,
                  controller.uploadCover,
                ),
                _action(
                  'event-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'event-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == EventPublicationPhase.ready ||
                      state.phase == EventPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'event-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'event-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.publicationMyObjects('event'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final EventPublicationObjectView item in state.myObjects)
              ListTile(
                key: Key('event-publication-object-${item.record.contentId}'),
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
    EventPublicationViewState state,
  ) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return l10n.publicationNotSaved;
    if (status == null) return l10n.publicationServerDraft;
    return PublicationTexts.objectLine(l10n, status);
  }
}
