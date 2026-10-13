import '../domain/entities/local_import.dart';

/// Where an imported item stands on the way to removing its local original
/// (D4 §6).
enum LocalImportCleanupStage {
  notImported,
  awaitingVerification,
  awaitingConfirmation,
  recoveryPeriod,
  eligible,
  deleted,
}

final class LocalImportCleanupStatus {
  const LocalImportCleanupStatus(this.stage, {this.eligibleAtUtc});

  final LocalImportCleanupStage stage;

  /// When the recovery period ends (set once the user confirmed).
  final DateTime? eligibleAtUtc;
}

/// The local original may be removed only after all three, in this order:
/// the server copy was verified, the user explicitly confirmed it, and the
/// recovery period that starts at that confirmation has ended (D4 §6). The
/// deletion itself re-checks the server and the local draft first; this
/// policy never deletes anything.
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
