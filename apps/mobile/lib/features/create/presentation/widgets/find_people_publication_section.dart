import 'package:flutter/material.dart';

import '../../application/find_people_publication_controller.dart';
import '../../domain/entities/event_publication.dart';
import '../../domain/entities/find_people_publication.dart';

/// Test-path view of the Find People publication (D3.7). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the request itself is the user's Create draft. Consent is a separate,
/// explicit action of the author, never implied by saving or by device location.
class FindPeoplePublicationSection extends StatelessWidget {
  const FindPeoplePublicationSection({super.key, required this.controller});

  final FindPeoplePublicationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final FindPeoplePublicationViewState state = controller.state;
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
              state.draftTitle ?? 'No Find People draft in Create',
              key: const Key('find-people-publication-draft-title'),
            ),
            Text(
              _statusLine(state),
              key: const Key('find-people-publication-status'),
            ),
            Text(
              _consentLine(state.consent),
              key: const Key('find-people-publication-consent'),
            ),
            const Text(
              'Others see only an approximate area (about 1 km). The exact '
              'meeting point stays private to you.',
              key: Key('find-people-publication-privacy-note'),
            ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                'Revision ${status!.currentPublishedRevisionId}',
                key: const Key('find-people-publication-revision'),
              ),
            if (state.message != null)
              Text(
                state.message!,
                key: const Key('find-people-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (state.conflict != null)
              Text(
                'The server has a newer version '
                '(revision ${state.conflict!.serverRevision}). Your edit is '
                'kept here; nothing was overwritten.',
                key: const Key('find-people-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'find-people-publication-save',
                  'Save',
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'find-people-publication-consent-grant',
                  'Consent to publish',
                  state.canGrantConsent,
                  controller.grantConsent,
                ),
                _action(
                  'find-people-publication-consent-revoke',
                  'Withdraw consent',
                  state.canRevokeConsent,
                  controller.revokeConsent,
                ),
                _action(
                  'find-people-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'find-people-publication-refresh',
                  'Refresh',
                  state.phase == FindPeoplePublicationPhase.ready ||
                      state.phase == FindPeoplePublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'find-people-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'find-people-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'find-people-publication-save-over-server',
                    'Save my version',
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'My Find People requests',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final FindPeoplePublicationObjectView item in state.myObjects)
              ListTile(
                key: Key(
                  'find-people-publication-object-${item.record.contentId}',
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

  static String _statusLine(FindPeoplePublicationViewState state) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return 'Not saved to the server';
    if (status == null) return 'Saved as a server draft';
    return _objectLine(status);
  }

  static String _consentLine(FindPeopleConsentView? consent) {
    if (consent == null) return 'consent: not given';
    if (!consent.active) return 'consent: ${consent.state}';
    final String date = consent.expiresAtUtc.toIso8601String().substring(0, 10);
    return 'consent: active until $date';
  }

  static String _objectLine(EventPublicationStatus status) {
    final String review = status.latestSubmissionState ?? 'draft';
    final String visibility = status.visibility ?? 'unpublished';
    return 'review: $review; visibility: $visibility';
  }
}
