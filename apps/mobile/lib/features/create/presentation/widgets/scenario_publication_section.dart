import 'package:flutter/material.dart';

import '../../application/scenario_publication_controller.dart';
import '../../domain/entities/scenario_publication.dart';

/// Test-path view of the Scenario publication (I3). It renders the
/// controller's state and forwards taps; it holds no rule and no second form:
/// the Scenario itself is the user's Create draft, saved through I2.
class ScenarioPublicationSection extends StatefulWidget {
  const ScenarioPublicationSection({super.key, required this.controller});

  final ScenarioPublicationController controller;

  @override
  State<ScenarioPublicationSection> createState() =>
      _ScenarioPublicationSectionState();
}

class _ScenarioPublicationSectionState
    extends State<ScenarioPublicationSection> {
  bool _rights = false;

  @override
  Widget build(BuildContext context) {
    final ScenarioPublicationController controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final ScenarioPublicationViewState state = controller.state;
        final ScenarioShareLink? share = state.share;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Test publication path (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? 'No Scenario draft in Create',
              key: const Key('scenario-publication-draft-title'),
            ),
            Text(
              state.serverRevision == null
                  ? 'Not saved to the server yet'
                  : 'Server revision ${state.serverRevision}',
              key: const Key('scenario-publication-plan'),
            ),
            Text(
              _statusLine(state),
              key: const Key('scenario-publication-status'),
            ),
            if (share != null)
              SelectableText(
                share.token == null
                    ? 'Link issued, answer lost: issue a new link'
                    : 'Unlisted link until ${share.expiresAtUtc.toIso8601String()}: '
                          '${share.token}',
                key: const Key('scenario-publication-share'),
              ),
            if (state.message != null)
              Text(
                state.message!,
                key: const Key('scenario-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            CheckboxListTile(
              key: const Key('scenario-publication-rights'),
              value: _rights,
              title: const Text('I have permission to use the cover image'),
              onChanged: (bool? value) =>
                  setState(() => _rights = value ?? false),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'scenario-publication-prepare',
                  'Prepare',
                  state.canPrepare,
                  controller.prepare,
                ),
                _action(
                  'scenario-publication-cover',
                  'Upload cover',
                  state.canUploadCover,
                  () => controller.uploadCover(rightsConfirmed: _rights),
                ),
                _action(
                  'scenario-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'scenario-publication-refresh',
                  'Refresh',
                  state.phase == ScenarioPublicationPhase.ready,
                  controller.refresh,
                ),
                _action(
                  'scenario-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'scenario-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
                ),
                _action(
                  'scenario-publication-share-link',
                  'Share link',
                  state.canShare,
                  controller.share,
                ),
                _action(
                  'scenario-publication-unshare',
                  'Revoke link',
                  state.canUnshare,
                  controller.unshare,
                ),
              ],
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

  static String _statusLine(ScenarioPublicationViewState state) {
    if (state.record?.contentDraftId == null) return 'Not prepared';
    final String review = state.status?.latestSubmissionState ?? 'draft';
    final String visibility = state.status?.visibility ?? 'unpublished';
    return 'review: $review; visibility: $visibility';
  }
}
