import '../entities/create_draft_entity.dart';
import '../entities/local_import.dart';
import '../entities/publisher_ref.dart';

/// One item of the local inventory (D4 §5.1): a Create draft the import may
/// map, or an entry it only lists (its [draft] is null).
final class LocalImportSourceItem {
  const LocalImportSourceItem({
    required this.localDraftId,
    required this.localType,
    required this.title,
    this.draft,
  });

  final String localDraftId;

  /// The local object type name (`CreateObjectType.name`).
  final String localType;
  final String title;
  final CreateDraftEntity? draft;
}

/// Reads the account's local data for the inventory; never writes it.
abstract interface class LocalImportSource {
  Future<List<LocalImportSourceItem>> inventory(String accountId);
}

/// Removes a local original, and only the exact one: the stored draft of the
/// account must still be [localDraftId] and [unchanged] must accept it.
abstract interface class LocalImportOriginalStore {
  Future<bool> deleteIfUnchanged({
    required String accountId,
    required String localDraftId,
    required bool Function(CreateDraftEntity draft) unchanged,
  });
}

/// Durable receipts and sessions on this install (D4 §5.4, §5.5).
abstract interface class LocalImportJournal {
  Future<List<LocalImportReceipt>> receipts(String accountId);

  Future<LocalImportReceipt?> receiptFor({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> saveReceipt(LocalImportReceipt receipt);

  Future<LocalImportSession?> currentSession(String accountId);

  Future<void> saveSession(LocalImportSession session);
}

/// Server objects the test publication paths (C3, D3.1, D3.2, D3.4) already
/// created for a local draft, read from their own journals.
abstract interface class LocalImportExistingPublications {
  Future<String?> contentIdFor({
    required String typeId,
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });
}

/// The owner's Content draft as the server returns it.
final class LocalImportServerDraft {
  const LocalImportServerDraft({
    required this.contentId,
    required this.draftId,
    required this.revision,
    this.typeId,
    this.createdByUserId,
    this.importSourceKey,
    this.body,
    this.status,
    this.importGeneration,
  });

  final String contentId;
  final String draftId;
  final int revision;
  final String? typeId;
  final String? createdByUserId;
  final String? importSourceKey;
  final Map<String, Object?>? body;

  /// Server draft status; `rolledBack` is a D4.1 tombstone.
  final String? status;

  /// D4.1: the binding generation of this draft (absent on D4 drafts: 1).
  final int? importGeneration;
}

/// D4.1: the author's view of a local import binding (`getImportBinding`).
/// It never carries the fencing token of a reservation.
final class LocalImportBindingView {
  const LocalImportBindingView({
    required this.generation,
    required this.rolledBack,
    required this.draftId,
    this.cleanupState,
    this.cleanupInstallationId,
  });

  final int generation;
  final bool rolledBack;
  final String draftId;

  /// `reserved`, `done`, or null without a reservation.
  final String? cleanupState;
  final String? cleanupInstallationId;
}

/// Content owner commands of the import (D4 §5.3). Failures are the same typed
/// `EventPublicationRejected` / `EventPublicationUnavailable` as the
/// publication paths.
abstract interface class LocalImportContentGateway {
  /// `createDraft` with an empty body and the local import source key: the
  /// server returns the draft this author already imported from it, if any.
  Future<LocalImportServerDraft> createImportDraft({
    required String typeId,
    required PublisherRef publisherRef,
    required String marketId,
    required String importSourceKey,
    required String idempotencyKey,
  });

  Future<LocalImportServerDraft> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  });

  Future<LocalImportServerDraft> draft(String draftId);

  /// D4.1: tombstones the author's imported draft of [generation] at exactly
  /// [expectedRevision], together with the binding generation.
  Future<LocalImportServerDraft> rollbackImportedDraft({
    required String draftId,
    required String importSourceKey,
    required int generation,
    required int expectedRevision,
    required String idempotencyKey,
  });

  /// D4.1: the server reservation of the local original's deletion.
  Future<LocalImportBindingView> reserveImportCleanup({
    required String importSourceKey,
    required int generation,
    required String draftId,
    required String installationId,
    required String fencingToken,
    required String idempotencyKey,
  });

  Future<LocalImportBindingView> completeImportCleanup({
    required String importSourceKey,
    required int generation,
    required String fencingToken,
    required String idempotencyKey,
  });

  Future<LocalImportBindingView> releaseImportCleanup({
    required String importSourceKey,
    required int generation,
    required String fencingToken,
    required String idempotencyKey,
  });

  /// D4.1: how an unknown outcome is resolved (`getImportBinding`).
  Future<LocalImportBindingView> importBinding(String importSourceKey);
}

/// Every command asks it first; the default-off import test entry implements it.
abstract interface class LocalImportCommandGate {
  bool get allowed;
  void assertAllowed();
}
