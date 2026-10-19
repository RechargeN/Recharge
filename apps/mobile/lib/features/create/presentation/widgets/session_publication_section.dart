import 'package:flutter/material.dart';

import '../../application/session_publication_controller.dart';
import '../../domain/entities/event_publication.dart';

/// Test-path view of the Session publication (D3.5). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the Session itself is the user's Create draft.
class SessionPublicationSection extends StatelessWidget {
  const SessionPublicationSection({super.key, required this.controller});

  final SessionPublicationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final SessionPublicationViewState state = controller.state;
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
              state.draftTitle ?? 'No Session draft in Create',
              key: const Key('session-publication-draft-title'),
            ),
            Text(
              _statusLine(state),
              key: const Key('session-publication-status'),
            ),
            if (state.record != null)
              Text(
                'Media uploaded: ${state.record!.attachments.length}',
                key: const Key('session-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                'Revision ${status!.currentPublishedRevisionId}',
                key: const Key('session-publication-revision'),
              ),
            if (state.message != null)
              Text(
                state.message!,
                key: const Key('session-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            // M1 D2: someone else's newer revision; nothing is overwritten
            // until the user explicitly saves their version.
            if (state.conflict != null)
              Text(
                'The server has a newer version '
                '(revision ${state.conflict!.serverRevision}). Your edit is '
                'kept here; nothing was overwritten.',
                key: const Key('session-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'session-publication-save',
                  'Save',
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'session-publication-media-upload',
                  'Upload media',
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'session-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'session-publication-refresh',
                  'Refresh',
                  state.phase == SessionPublicationPhase.ready ||
                      state.phase == SessionPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'session-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'session-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'session-publication-save-over-server',
                    'Save my version',
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('My sessions', style: Theme.of(context).textTheme.titleSmall),
            for (final SessionPublicationObjectView item in state.myObjects)
              ListTile(
                key: Key('session-publication-object-${item.record.contentId}'),
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

  static String _statusLine(SessionPublicationViewState state) {
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
