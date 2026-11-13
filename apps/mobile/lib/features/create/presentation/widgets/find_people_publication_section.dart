import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import 'publication_texts.dart';
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
              context.l10n.publicationTestPath,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.draftTitle ?? context.l10n.publicationNoDraft('findPeople'),
              key: const Key('find-people-publication-draft-title'),
            ),
            Text(
              _statusLine(context.l10n, state),
              key: const Key('find-people-publication-status'),
            ),
            Text(
              _consentLine(context.l10n, state.consent),
              key: const Key('find-people-publication-consent'),
            ),
            Text(
              context.l10n.findPeopleApproxArea,
              key: const Key('find-people-publication-privacy-note'),
            ),
            if (status?.currentPublishedRevisionId != null)
              Text(
                context.l10n.publicationRevision(
                  '${status!.currentPublishedRevisionId}',
                ),
                key: const Key('find-people-publication-revision'),
              ),
            if (state.message != null)
              Text(
                PublicationTexts.message(context.l10n, state.message!),
                key: const Key('find-people-publication-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (state.conflict != null)
              Text(
                context.l10n.publicationConflict(
                  '${state.conflict!.serverRevision}',
                ),
                key: const Key('find-people-publication-conflict'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'find-people-publication-save',
                  context.l10n.publicationSave,
                  state.canSave,
                  controller.save,
                ),
                _action(
                  'find-people-publication-consent-grant',
                  context.l10n.findPeopleConsentToPublish,
                  state.canGrantConsent,
                  controller.grantConsent,
                ),
                _action(
                  'find-people-publication-consent-revoke',
                  context.l10n.findPeopleWithdrawConsent,
                  state.canRevokeConsent,
                  controller.revokeConsent,
                ),
                _action(
                  'find-people-publication-submit',
                  context.l10n.publicationSubmit,
                  state.canSubmit,
                  controller.submit,
                ),
                _action(
                  'find-people-publication-refresh',
                  context.l10n.commonRefresh,
                  state.phase == FindPeoplePublicationPhase.ready ||
                      state.phase == FindPeoplePublicationPhase.offline,
                  controller.refresh,
                ),
                _action(
                  'find-people-publication-publish',
                  context.l10n.publicationPublish,
                  state.canPublish,
                  controller.publish,
                ),
                _action(
                  'find-people-publication-hide',
                  context.l10n.publicationHide,
                  state.canHide,
                  controller.hide,
                ),
                if (state.conflict != null)
                  _action(
                    'find-people-publication-save-over-server',
                    context.l10n.publicationSaveMyVersion,
                    state.canSaveOverServerVersion,
                    controller.saveOverServerVersion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.publicationMyObjects('findPeople'),
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
    FindPeoplePublicationViewState state,
  ) {
    final EventPublicationStatus? status = state.status;
    if (state.record == null) return l10n.publicationNotSaved;
    if (status == null) return l10n.publicationServerDraft;
    return PublicationTexts.objectLine(l10n, status);
  }

  static String _consentLine(
    AppLocalizations l10n,
    FindPeopleConsentView? consent,
  ) {
    if (consent == null) return l10n.findPeopleConsentNone;
    if (!consent.active) return l10n.findPeopleConsentState(consent.state);
    // Consent expiry is no object's local time: shown in the device zone.
    return l10n.findPeopleConsentActiveUntil(
      RechargeFormats.deviceDateTime(consent.expiresAtUtc, l10n.localeName),
    );
  }
}
