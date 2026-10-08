import 'package:flutter/material.dart';

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
              'Test publication path (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? 'No Event draft in Create',
              key: const Key('event-publication-draft-title'),
            ),
            Text(
              _statusLine(state),
              key: const Key('event-publication-status'),
            ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                'Revision ${status!.currentPublishedRevisionId}',
                key: const Key('event-publication-revision'),
              ),
            if (state.message != null)
              Text(
                state.message!,
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
                  'Save',
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'event-publication-cover',
                  'Upload cover',
                  state.canUploadCover,
                  controller.uploadCover,
                ),
                _action(
                  'event-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'event-publication-refresh',
                  'Refresh',
                  state.phase == EventPublicationPhase.ready ||
                      state.phase == EventPublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'event-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'event-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('My objects', style: Theme.of(context).textTheme.titleSmall),
            for (final EventPublicationObjectView item in state.myObjects)
              ListTile(
                key: Key('event-publication-object-${item.record.contentId}'),
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

  static String _statusLine(EventPublicationViewState state) {
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
