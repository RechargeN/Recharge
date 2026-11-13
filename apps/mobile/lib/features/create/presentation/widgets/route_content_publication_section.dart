import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../application/route_content_publication_controller.dart';
import 'publication_texts.dart';

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
              context.l10n.publicationTestPath,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? context.l10n.publicationNoDraft('route'),
              key: const Key('route-publication-draft-title'),
            ),
            Text(
              state.serverRevision == null
                  ? context.l10n.publicationNotSavedYet
                  : context.l10n.publicationServerRevision(
                      '${state.serverRevision}',
                    ),
              key: const Key('route-publication-route'),
            ),
            Text(
              _trimLine(context.l10n, state),
              key: const Key('route-publication-trim'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('route-publication-status'),
            ),
            if (state.message != null)
              Text(
                _messageLine(context.l10n, state.message!),
                key: const Key('route-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            CheckboxListTile(
              key: const Key('route-publication-rights'),
              value: _rights,
              title: Text(context.l10n.publicationCoverPermission),
              onChanged: (bool? value) =>
                  setState(() => _rights = value ?? false),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'route-publication-sync',
                  context.l10n.publicationSaveToServer,
                  state.canSync,
                  controller.syncRoute,
                ),
                _action(
                  'route-publication-hide-ends',
                  context.l10n.routeHideEnds(
                    RouteContentPublicationController
                        .recommendedTrim
                        .startMeters,
                  ),
                  state.canHideEnds,
                  controller.hidePrivateEnds,
                ),
                _action(
                  'route-publication-prepare',
                  context.l10n.publicationPrepare,
                  state.canPrepare,
                  controller.prepare,
                ),
                _action(
                  'route-publication-cover',
                  context.l10n.publicationUploadCover,
                  state.canUploadCover,
                  () => controller.uploadCover(rightsConfirmed: _rights),
                ),
                _action(
                  'route-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'route-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == RouteContentPublicationPhase.ready,
                  controller.refresh,
                ),
                _action(
                  'route-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'route-publication-hide',
                  context.l10n.publicationHide,
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

  static String _trimLine(
    AppLocalizations l10n,
    RouteContentPublicationViewState state,
  ) {
    final trim = state.trim;
    if (trim == null) return l10n.routeHiddenEndsUnknown;
    return l10n.routeHiddenEnds(
      RechargeFormats.decimal(trim.startMeters, l10n.localeName),
      RechargeFormats.decimal(trim.endMeters, l10n.localeName),
    );
  }

  static String _statusLine(
    AppLocalizations l10n,
    RouteContentPublicationViewState state,
  ) {
    if (state.record?.contentDraftId == null) {
      return l10n.publicationNotPrepared;
    }
    return PublicationTexts.statusLine(
      l10n,
      state.status?.latestSubmissionState,
      state.status?.visibility,
    );
  }

  /// RP-02: every code, the recorded-GPS refusals too, goes through the
  /// shared catalog, never shown as is.
  static String _messageLine(AppLocalizations l10n, String code) =>
      PublicationTexts.message(l10n, code);
}
