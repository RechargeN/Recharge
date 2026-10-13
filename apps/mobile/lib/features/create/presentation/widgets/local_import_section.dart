import 'package:flutter/material.dart';

import '../../application/local_import_cleanup_policy.dart';
import '../../application/local_import_controller.dart';
import '../../domain/entities/local_import.dart';

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Import local data (local Emulator)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              session == null
                  ? 'No import session'
                  : 'Session ${session.status.name}: '
                        '${session.checkpoint}/${session.plannedLocalDraftIds.length}',
              key: const Key('local-import-session'),
            ),
            if (state.message != null)
              Text(
                state.message!,
                key: const Key('local-import-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (state.pendingCleanups > 0) ...<Widget>[
              Text(
                '${state.pendingCleanups} deleted local copies to record '
                'on the server',
                key: const Key('local-import-pending-cleanups'),
              ),
              _action(
                'local-import-finish-cleanup',
                'Finish cleanup',
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
                  'Dry run',
                  idle || state.phase == LocalImportPhase.offline,
                  controller.load,
                ),
                _action(
                  'local-import-approve',
                  'Approve import',
                  state.canApprove,
                  controller.approve,
                ),
                _action(
                  'local-import-run',
                  session?.status == LocalImportSessionStatus.paused
                      ? 'Resume'
                      : 'Run',
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
    final List<String> lines = <String>[
      '${candidate.typeId}: ${candidate.classification.name}'
          '${candidate.reason == null ? '' : ' (${candidate.reason})'}',
      if (receipt != null)
        'server ${receipt.contentId}: ${receipt.state.name}'
            '${receipt.failureCode == null ? '' : ' (${receipt.failureCode})'}',
      if (receipt == null && item.failureCode != null)
        'refused: ${item.failureCode}',
      'local copy: ${_cleanupLine(item.cleanup)}',
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
                    child: const Text('Import again'),
                  ),
                if (item.cleanup.stage ==
                    LocalImportCleanupStage.awaitingConfirmation)
                  TextButton(
                    key: Key('local-import-confirm-$id'),
                    onPressed: idle ? () => controller.confirm(id) : null,
                    child: const Text('Keep the server copy'),
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
                          ? 'Finish deleting local copy'
                          : 'Delete local copy',
                    ),
                  ),
                if (item.canCancelCleanup)
                  TextButton(
                    key: Key('local-import-cancel-cleanup-$id'),
                    onPressed: idle ? () => controller.cancelCleanup(id) : null,
                    child: const Text('Keep local copy'),
                  ),
                if (item.canRollBack)
                  TextButton(
                    key: Key('local-import-rollback-$id'),
                    onPressed: idle
                        ? () => _confirmRollback(context, id)
                        : null,
                    child: Text(
                      receipt?.state == LocalImportItemState.rollbackPending
                          ? 'Retry rollback'
                          : 'Roll back import',
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
        title: const Text('Roll back this import?'),
        content: const Text(
          'The imported server draft is closed for good. Your local copy '
          'stays and can be imported again later.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('local-import-rollback-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('local-import-rollback-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Roll back'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.rollback(id);
  }

  static String _cleanupLine(LocalImportCleanupStatus status) =>
      switch (status.stage) {
        LocalImportCleanupStage.notImported => 'kept (not imported)',
        LocalImportCleanupStage.awaitingVerification =>
          'kept (server copy not verified)',
        LocalImportCleanupStage.awaitingConfirmation =>
          'kept (confirm the server copy)',
        LocalImportCleanupStage.recoveryPeriod =>
          'kept until ${status.eligibleAtUtc!.toIso8601String()}',
        LocalImportCleanupStage.eligible => 'may be deleted',
        LocalImportCleanupStage.cleanupReserved =>
          'being deleted (reserved on the server)',
        LocalImportCleanupStage.deleted => 'deleted',
        LocalImportCleanupStage.rollbackPending =>
          'kept (rollback waiting for the server)',
        LocalImportCleanupStage.rolledBack => 'kept (import rolled back)',
      };
}
