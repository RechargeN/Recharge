import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import 'publication_texts.dart';
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
              context.l10n.publicationTestPath,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? context.l10n.publicationNoDraft('scenario'),
              key: const Key('scenario-publication-draft-title'),
            ),
            Text(
              state.serverRevision == null
                  ? context.l10n.publicationNotSavedYet
                  : context.l10n.publicationServerRevision(
                      '${state.serverRevision}',
                    ),
              key: const Key('scenario-publication-plan'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('scenario-publication-status'),
            ),
            if (share != null)
              SelectableText(
                share.token == null
                    ? context.l10n.scenarioShareLost
                    // The link's expiry is no object's local time: device zone.
                    : context.l10n.scenarioShareUntil(
                        RechargeFormats.deviceDateTime(
                          share.expiresAtUtc,
                          context.l10n.localeName,
                        ),
                        share.token!,
                      ),
                key: const Key('scenario-publication-share'),
              ),
            if (state.message != null)
              Text(
                PublicationTexts.message(context.l10n, state.message!),
                key: const Key('scenario-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            CheckboxListTile(
              key: const Key('scenario-publication-rights'),
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
                  'scenario-publication-prepare',
                  context.l10n.publicationPrepare,
                  state.canPrepare,
                  controller.prepare,
                ),
                _action(
                  'scenario-publication-cover',
                  context.l10n.publicationUploadCover,
                  state.canUploadCover,
                  () => controller.uploadCover(rightsConfirmed: _rights),
                ),
                _action(
                  'scenario-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'scenario-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == ScenarioPublicationPhase.ready,
                  controller.refresh,
                ),
                _action(
                  'scenario-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'scenario-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
                _action(
                  'scenario-publication-share-link',
                  context.l10n.publicationShareLink,
                  state.canShare,
                  controller.share,
                ),
                _action(
                  'scenario-publication-unshare',
                  context.l10n.publicationRevokeLink,
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

  static String _statusLine(
    AppLocalizations l10n,
    ScenarioPublicationViewState state,
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
}
