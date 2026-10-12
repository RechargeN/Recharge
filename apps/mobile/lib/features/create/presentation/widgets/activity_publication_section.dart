import 'package:flutter/material.dart';

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
              'Test publication path (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? 'No Activity draft in Create',
              key: const Key('activity-publication-draft-title'),
            ),
            Text(
              _statusLine(state),
              key: const Key('activity-publication-status'),
            ),
            if (state.record != null)
              Text(
                'Media uploaded: ${state.record!.attachments.length}',
                key: const Key('activity-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                'Published version: ${status!.currentPublishedRevisionId}',
                key: const Key('activity-publication-revision'),
              ),
            if (state.record != null)
              Text(
                'Draft revision: ${state.record!.draftRevision}${state.record!.editingFromRevisionId != null ? ' — unpublished changes; review required' : ''}',
                key: const Key('activity-publication-editing'),
              ),
            if (state.message != null)
              Text(
                state.message == 'validation_failed'
                    ? 'Check the Activity fields in Create and submit again.'
                    : state.message!,
                key: const Key('activity-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'activity-publication-save',
                  'Save',
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'activity-publication-media-upload',
                  'Upload media',
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'activity-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'activity-publication-refresh',
                  'Refresh',
                  state.phase == ActivityPublicationPhase.ready ||
                      state.phase == ActivityPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'activity-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'activity-publication-activate',
                  'Activate published version',
                  state.canActivate,
                  controller.activate,
                ),
                if (onEdit != null)
                  _action(
                    'activity-publication-edit',
                    'Edit in Create',
                    state.canEdit,
                    onEdit!,
                  ),
                _action(
                  'activity-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'My activities',
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

  static String _statusLine(ActivityPublicationViewState state) {
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
