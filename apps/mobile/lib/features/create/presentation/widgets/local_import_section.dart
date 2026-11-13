import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../application/local_import_cleanup_policy.dart';
import '../../application/local_import_controller.dart';
import '../../domain/entities/local_import.dart';
import 'publication_texts.dart';

/// Test-path view of the local→server import (D4, D4.1). It renders the dry
/// run, the session and each item's server state, and forwards taps; it holds
/// no rule: what may be imported, rolled back or removed is decided by the
/// controller and the server.
class LocalImportSection extends StatelessWidget {
  const LocalImportSection({super.key, required this.controller});

  final LocalImportController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final LocalImportViewState state = controller.state;
        final LocalImportSession? session = state.session;
        final bool idle = state.phase == LocalImportPhase.ready;
        final AppLocalizations l10n = context.l10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.importSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              session == null
                  ? l10n.importNoSession
                  : l10n.importSessionProgress(
                      l10n.importSessionStatus(session.status.name),
                      session.checkpoint,
                      session.plannedLocalDraftIds.length,
                    ),
              key: const Key('local-import-session'),
            ),
            if (state.message != null)
              Text(
                PublicationTexts.message(l10n, state.message!),
                key: const Key('local-import-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (state.pendingCleanups > 0) ...<Widget>[
              Text(
                l10n.importPendingCleanups(state.pendingCleanups),
                key: const Key('local-import-pending-cleanups'),
              ),
              _action(
                'local-import-finish-cleanup',
                l10n.importFinishCleanup,
                idle || state.phase == LocalImportPhase.offline,
                controller.finishCleanups,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _action(
                  'local-import-dry-run',
                  l10n.importDryRun,
                  idle || state.phase == LocalImportPhase.offline,
                  controller.load,
                ),
                _action(
                  'local-import-approve',
                  l10n.importApprove,
                  state.canApprove,
                  controller.approve,
                ),
                _action(
                  'local-import-run',
                  session?.status == LocalImportSessionStatus.paused
                      ? l10n.importResume
                      : l10n.importRun,
                  state.canRun,
                  controller.run,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final LocalImportItemView item in state.items)
              _ItemTile(
                item: item,
                controller: controller,
                // An unknown outcome is retried from the item itself.
                idle: idle || state.phase == LocalImportPhase.offline,
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
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.controller,
    required this.idle,
  });

  final LocalImportItemView item;
  final LocalImportController controller;
  final bool idle;

  @override
  Widget build(BuildContext context) {
    final LocalImportCandidate candidate = item.candidate;
    final LocalImportReceipt? receipt = item.receipt;
    final String id = candidate.localDraftId;
    final AppLocalizations l10n = context.l10n;
    final String type = l10n.createTypeName(candidate.typeId);
    final String classification = l10n.importClassification(
      candidate.classification.name,
    );
    final String? reason = candidate.reason;
    final String? receiptFailure = receipt?.failureCode;
    final String? itemFailure = item.failureCode;
    final List<String> lines = <String>[
      reason == null
          ? l10n.importCandidateLine(type, classification)
          // A reason may carry a detail after a colon (a type or a
          // capability list); only its stable prefix is shown, localized.
          : l10n.importCandidateLineReason(
              type,
              classification,
              l10n.importReason(reason.split(':').first),
            ),
      if (receipt != null)
        receiptFailure == null
            ? l10n.importServerLine(
                receipt.contentId,
                l10n.importItemState(receipt.state.name),
              )
            : l10n.importServerLineReason(
                receipt.contentId,
                l10n.importItemState(receipt.state.name),
                PublicationTexts.message(l10n, receiptFailure),
              ),
      if (receipt == null && itemFailure != null)
        l10n.importRefused(PublicationTexts.message(l10n, itemFailure)),
      l10n.importLocalCopy(_cleanupLine(l10n, item.cleanup)),
    ];
    return Card(
      key: Key('local-import-item-$id'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              candidate.title.isEmpty ? id : candidate.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final String line in lines) Text(line),
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (candidate.classification == LocalImportClass.conflict)
                  TextButton(
                    key: Key('local-import-choose-$id'),
                    onPressed: idle ? () => controller.chooseUpdate(id) : null,
                    child: Text(l10n.importAgain),
                  ),
                if (item.cleanup.stage ==
                    LocalImportCleanupStage.awaitingConfirmation)
                  TextButton(
                    key: Key('local-import-confirm-$id'),
                    onPressed: idle ? () => controller.confirm(id) : null,
                    child: Text(l10n.importKeepServerCopy),
                  ),
                if (item.cleanup.stage == LocalImportCleanupStage.eligible ||
                    item.cleanup.stage ==
                        LocalImportCleanupStage.cleanupReserved)
                  TextButton(
                    key: Key('local-import-delete-$id'),
                    onPressed: idle ? () => controller.deleteLocal(id) : null,
                    child: Text(
                      item.cleanup.stage ==
                              LocalImportCleanupStage.cleanupReserved
                          ? l10n.importFinishDeleting
                          : l10n.importDeleteLocal,
                    ),
                  ),
                if (item.canCancelCleanup)
                  TextButton(
                    key: Key('local-import-cancel-cleanup-$id'),
                    onPressed: idle ? () => controller.cancelCleanup(id) : null,
                    child: Text(l10n.importKeepLocal),
                  ),
                if (item.canRollBack)
                  TextButton(
                    key: Key('local-import-rollback-$id'),
                    onPressed: idle
                        ? () => _confirmRollback(context, id)
                        : null,
                    child: Text(
                      receipt?.state == LocalImportItemState.rollbackPending
                          ? l10n.importRetryRollback
                          : l10n.importRollBack,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// D4.1 §3.4: the server draft becomes a tombstone; the local copy stays.
  Future<void> _confirmRollback(BuildContext context, String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('local-import-rollback-dialog'),
        title: Text(dialogContext.l10n.importRollbackDialogTitle),
        content: Text(dialogContext.l10n.importRollbackDialogBody),
        actions: <Widget>[
          TextButton(
            key: const Key('local-import-rollback-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('local-import-rollback-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.importRollbackConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.rollback(id);
  }

  static String _cleanupLine(
    AppLocalizations l10n,
    LocalImportCleanupStatus status,
  ) => switch (status.stage) {
    LocalImportCleanupStage.notImported => l10n.importCleanupNotImported,
    LocalImportCleanupStage.awaitingVerification =>
      l10n.importCleanupAwaitingVerification,
    LocalImportCleanupStage.awaitingConfirmation =>
      l10n.importCleanupAwaitingConfirmation,
    // The recovery period ends at an instant of the device's own data, not
    // of any object's local calendar: shown in the device zone.
    LocalImportCleanupStage.recoveryPeriod => l10n.importCleanupRecovery(
      RechargeFormats.deviceDateTime(status.eligibleAtUtc!, l10n.localeName),
    ),
    LocalImportCleanupStage.eligible => l10n.importCleanupEligible,
    LocalImportCleanupStage.cleanupReserved => l10n.importCleanupReserved,
    LocalImportCleanupStage.deleted => l10n.importCleanupDeleted,
    LocalImportCleanupStage.rollbackPending =>
      l10n.importCleanupRollbackPending,
    LocalImportCleanupStage.rolledBack => l10n.importCleanupRolledBack,
  };
}
