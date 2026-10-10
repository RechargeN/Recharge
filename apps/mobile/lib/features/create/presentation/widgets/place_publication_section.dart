import 'package:flutter/material.dart';

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
              'Test publication path (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? 'No Place draft in Create',
              key: const Key('place-publication-draft-title'),
            ),
            Text(
              _statusLine(state),
              key: const Key('place-publication-status'),
            ),
            if (state.record != null)
              Text(
                'Media uploaded: ${state.record!.attachments.length}',
                key: const Key('place-publication-media'),
              ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                'Revision ${status!.currentPublishedRevisionId}',
                key: const Key('place-publication-revision'),
              ),
            if (state.message != null)
              Text(
                state.message!,
                key: const Key('place-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'place-publication-save',
                  'Save',
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'place-publication-media-upload',
                  'Upload media',
                  state.canUploadMedia,
                  controller.uploadMedia,
                ),
                _action(
                  'place-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'place-publication-refresh',
                  'Refresh',
                  state.phase == PlacePublicationPhase.ready ||
                      state.phase == PlacePublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'place-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'place-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('My places', style: Theme.of(context).textTheme.titleSmall),
            for (final PlacePublicationObjectView item in state.myObjects)
              ListTile(
                key: Key('place-publication-object-${item.record.contentId}'),
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

  static String _statusLine(PlacePublicationViewState state) {
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
