import 'package:flutter/material.dart';

import '../../application/route_content_publication_controller.dart';

/// Test-path view of the Route publication (J2). It renders the controller's
/// state and forwards taps; it holds no rule and no second form: the Route
/// itself is the user's Create draft, saved through the J1 owner sync.
class RouteContentPublicationSection extends StatefulWidget {
  const RouteContentPublicationSection({super.key, required this.controller});

  final RouteContentPublicationController controller;

  @override
  State<RouteContentPublicationSection> createState() =>
      _RouteContentPublicationSectionState();
}

class _RouteContentPublicationSectionState
    extends State<RouteContentPublicationSection> {
  bool _rights = false;

  @override
  Widget build(BuildContext context) {
    final RouteContentPublicationController controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final RouteContentPublicationViewState state = controller.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Test publication path (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? 'No Route draft in Create',
              key: const Key('route-publication-draft-title'),
            ),
            Text(
              state.serverRevision == null
                  ? 'Not saved to the server yet'
                  : 'Server revision ${state.serverRevision}',
              key: const Key('route-publication-route'),
            ),
            Text(_trimLine(state), key: const Key('route-publication-trim')),
            Text(
              _statusLine(state),
              key: const Key('route-publication-status'),
            ),
            if (state.message != null)
              Text(
                _messageLine(state.message!),
                key: const Key('route-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            CheckboxListTile(
              key: const Key('route-publication-rights'),
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
                  'route-publication-sync',
                  'Save to server',
                  state.canSync,
                  controller.syncRoute,
                ),
                _action(
                  'route-publication-hide-ends',
                  'Hide 200 m at both ends',
                  state.canHideEnds,
                  controller.hidePrivateEnds,
                ),
                _action(
                  'route-publication-prepare',
                  'Prepare',
                  state.canPrepare,
                  controller.prepare,
                ),
                _action(
                  'route-publication-cover',
                  'Upload cover',
                  state.canUploadCover,
                  () => controller.uploadCover(rightsConfirmed: _rights),
                ),
                _action(
                  'route-publication-submit',
                  'Submit',
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'route-publication-refresh',
                  'Refresh',
                  state.phase == RouteContentPublicationPhase.ready,
                  controller.refresh,
                ),
                _action(
                  'route-publication-publish',
                  'Publish',
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'route-publication-hide',
                  'Hide',
                  state.canHide,
                  controller.hide,
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

  static String _trimLine(RouteContentPublicationViewState state) {
    final trim = state.trim;
    if (trim == null) return 'Hidden ends: unknown';
    return 'Hidden ends: start ${trim.startMeters} m, end ${trim.endMeters} m';
  }

  static String _statusLine(RouteContentPublicationViewState state) {
    if (state.record?.contentDraftId == null) return 'Not prepared';
    final String review = state.status?.latestSubmissionState ?? 'draft';
    final String visibility = state.status?.visibility ?? 'unpublished';
    return 'review: $review; visibility: $visibility';
  }

  /// RP-02: the recorded-GPS refusals get a plain explanation.
  static String _messageLine(String code) => switch (code) {
    'privacy_trim_required' =>
      'Recorded GPS: hide at least 200 m at both ends before publishing',
    'privacy_trim_empty' =>
      'Too short to publish: nothing is left after hiding the ends',
    _ => code,
  };
}
