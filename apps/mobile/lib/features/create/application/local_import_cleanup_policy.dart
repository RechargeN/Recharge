import '../domain/entities/local_import.dart';

/// Where an imported item stands on the way to removing its local original
/// (D4 §6, D4.1 §3.1).
enum LocalImportCleanupStage {
  notImported,
  awaitingVerification,
  awaitingConfirmation,
  recoveryPeriod,
  eligible,

  /// D4.1: the server holds this installation's reservation; the deletion
  /// goes on (or is released) with the same fencing token.
  cleanupReserved,
  deleted,

  /// D4.1: a rollback was sent and its outcome is not known yet: cleanup
  /// waits for the server's final state.
  rollbackPending,

  /// D4.1: the import was rolled back; this original is never cleaned up
  /// under this receipt.
  rolledBack,
}

final class LocalImportCleanupStatus {
  const LocalImportCleanupStatus(this.stage, {this.eligibleAtUtc});

  final LocalImportCleanupStage stage;

  /// When the recovery period ends (set once the user confirmed).
  final DateTime? eligibleAtUtc;
}

/// The local original may be removed only after all three, in this order:
/// the server copy was verified, the user explicitly confirmed it, and the
/// recovery period that starts at that confirmation has ended (D4 §6). A
/// pending or completed rollback forbids it (D4.1 §3.1). The deletion itself
/// re-checks the server and the local draft first and runs under a server
/// reservation; this policy never deletes anything.
final class LocalImportCleanupPolicy {
  const LocalImportCleanupPolicy({this.recoveryPeriod = defaultRecoveryPeriod});

  static const Duration defaultRecoveryPeriod = Duration(days: 30);

  final Duration recoveryPeriod;

  LocalImportCleanupStatus statusOf(
    LocalImportReceipt? receipt,
    DateTime nowUtc,
  ) {
    if (receipt == null) {
      return const LocalImportCleanupStatus(
        LocalImportCleanupStage.notImported,
      );
    }
    if (receipt.localDeletedAtUtc != null) {
      return const LocalImportCleanupStatus(LocalImportCleanupStage.deleted);
    }
    switch (receipt.state) {
      case LocalImportItemState.rolledBack:
        return const LocalImportCleanupStatus(
          LocalImportCleanupStage.rolledBack,
        );
      case LocalImportItemState.rollbackPending:
        return const LocalImportCleanupStatus(
          LocalImportCleanupStage.rollbackPending,
        );
      case LocalImportItemState.cleanupReserved:
        return const LocalImportCleanupStatus(
          LocalImportCleanupStage.cleanupReserved,
        );
      case LocalImportItemState.created:
      case LocalImportItemState.mediaUploaded:
      case LocalImportItemState.bodySaved:
      case LocalImportItemState.verified:
      case LocalImportItemState.failed:
        break;
    }
    if (receipt.state != LocalImportItemState.verified ||
        receipt.verifiedAtUtc == null) {
      return const LocalImportCleanupStatus(
        LocalImportCleanupStage.awaitingVerification,
      );
    }
    final DateTime? confirmed = receipt.confirmedAtUtc;
    if (confirmed == null) {
      return const LocalImportCleanupStatus(
        LocalImportCleanupStage.awaitingConfirmation,
      );
    }
    final DateTime eligibleAt = confirmed.add(recoveryPeriod);
    return LocalImportCleanupStatus(
      nowUtc.isBefore(eligibleAt)
          ? LocalImportCleanupStage.recoveryPeriod
          : LocalImportCleanupStage.eligible,
      eligibleAtUtc: eligibleAt,
    );
  }
}
