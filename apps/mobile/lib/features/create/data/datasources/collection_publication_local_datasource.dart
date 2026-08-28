import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../shared/primitives/id/id_generator.dart';
import '../../domain/entities/collection_moderation_request.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../models/collection_publication_model.dart';

/// In-memory stand-in for the crash-recoverable staged store described in
/// §12 — an actual persisted/staged implementation is a later gate; this
/// keeps the exact idempotency, removal-only and moderation contracts so
/// callers do not have to change when the storage backend does.
class CollectionPublicationLocalDatasource {
  CollectionPublicationLocalDatasource({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  final Map<String, PublishedCollectionVersion> _activeByCollectionId =
      <String, PublishedCollectionVersion>{};
  final Map<String, _ReceiptRecord> _receiptsByIdempotencyKey =
      <String, _ReceiptRecord>{};
  final Map<String, CollectionModerationRequest> _pendingByRequestId =
      <String, CollectionModerationRequest>{};

  Future<CollectionPublishReceipt> publish(
    CollectionPublishBundle bundle,
  ) async {
    final String key = bundle.publishAttemptId;
    final String payloadHash = _hashBundle(bundle);
    final _ReceiptRecord? existing = _receiptsByIdempotencyKey[key];
    if (existing != null) {
      if (existing.payloadHash != payloadHash) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.idempotencyConflict,
          'This publish attempt id was already used with a different '
          'payload.',
        );
      }
      return existing.receipt.copyWith(
        outcome: CollectionPublishOutcome.replayedIdempotentSuccess,
      );
    }
    final DateTime now = DateTime.now().toUtc();
    final PublishedCollectionVersion version = PublishedCollectionVersion(
      bundle: bundle,
      publishedAtUtc: now,
    );
    // "Staged write": build the record fully before it becomes visible, so
    // a crash mid-write never leaves a half-applied active version.
    _activeByCollectionId[bundle.collectionId] = version;
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: bundle.collectionId,
      collectionVersionId: bundle.collectionVersionId,
      publishedAtUtc: now,
      outcome: CollectionPublishOutcome.created,
    );
    _receiptsByIdempotencyKey[key] = _ReceiptRecord(
      payloadHash: payloadHash,
      receipt: receipt,
    );
    return receipt;
  }

  /// §6/§7 Шаг 5: same idempotency contract as [publish], but the version
  /// only lands in [_pendingByRequestId] — never [_activeByCollectionId] —
  /// until [decide] accepts it.
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle,
  ) async {
    final String key = bundle.publishAttemptId;
    final String payloadHash = _hashBundle(bundle);
    final _ReceiptRecord? existing = _receiptsByIdempotencyKey[key];
    if (existing != null) {
      if (existing.payloadHash != payloadHash) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.idempotencyConflict,
          'This publish attempt id was already used with a different '
          'payload.',
        );
      }
      return existing.receipt.copyWith(
        outcome: CollectionPublishOutcome.replayedIdempotentSuccess,
      );
    }
    final DateTime now = DateTime.now().toUtc();
    final String requestId = bundle.publishAttemptId;
    _pendingByRequestId[requestId] = CollectionModerationRequest(
      requestId: requestId,
      bundle: bundle,
      submittedAtUtc: now,
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: bundle.collectionId,
      collectionVersionId: bundle.collectionVersionId,
      submittedAtUtc: now,
      outcome: CollectionPublishOutcome.pendingReview,
    );
    _receiptsByIdempotencyKey[key] = _ReceiptRecord(
      payloadHash: payloadHash,
      receipt: receipt,
    );
    return receipt;
  }

  Future<List<CollectionModerationRequest>> pendingRequests() async {
    return List<CollectionModerationRequest>.unmodifiable(
      _pendingByRequestId.values,
    );
  }

  /// Returns the newly-active [PublishedCollectionVersion] on acceptance,
  /// or `null` on rejection (nothing to activate). The caller (repository
  /// impl) is the one that talks to the Discover sink — this datasource
  /// only owns the local pending/active split.
  Future<PublishedCollectionVersion?> decide({
    required String requestId,
    required bool accept,
  }) async {
    final CollectionModerationRequest? request = _pendingByRequestId.remove(
      requestId,
    );
    if (request == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.notFound,
        'Moderation request not found.',
      );
    }
    if (!accept) return null;
    final DateTime now = DateTime.now().toUtc();
    final PublishedCollectionVersion version = PublishedCollectionVersion(
      bundle: request.bundle,
      publishedAtUtc: now,
    );
    _activeByCollectionId[request.bundle.collectionId] = version;
    return version;
  }

  Future<CollectionPublishReceipt> removeItemsOnly(
    CollectionRemovalOnlyCommand command,
  ) async {
    final String key = 'removal:${command.collectionId}:${command.requestId}';
    final _ReceiptRecord? existing = _receiptsByIdempotencyKey[key];
    if (existing != null) {
      return existing.receipt.copyWith(
        outcome: CollectionPublishOutcome.replayedIdempotentSuccess,
      );
    }

    final PublishedCollectionVersion? active =
        _activeByCollectionId[command.collectionId];
    if (active == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.notFound,
        'Collection not found.',
      );
    }
    if (active.collectionVersionId != command.expectedBaseRevisionOrHash) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.revisionConflict,
        'The active version has changed since this removal was prepared.',
      );
    }
    final Set<String> activeKeys = active.bundle.items
        .map((item) => item.ref.stableKey)
        .toSet();
    if (!command.removedItemRefs.every(activeKeys.contains)) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.removalOnlyConflict,
        'One or more refs are not part of the active version.',
      );
    }

    final DateTime now = DateTime.now().toUtc();
    final CollectionPublishBundle nextBundle = active.bundle.copyWith(
      collectionVersionId: _idGenerator.generate(),
      items: active.bundle.items
          .where(
            (item) => !command.removedItemRefs.contains(item.ref.stableKey),
          )
          .toList(growable: false),
      publishAttemptId: command.requestId,
    );
    _activeByCollectionId[command.collectionId] = PublishedCollectionVersion(
      bundle: nextBundle,
      publishedAtUtc: now,
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: nextBundle.collectionId,
      collectionVersionId: nextBundle.collectionVersionId,
      publishedAtUtc: now,
      outcome: CollectionPublishOutcome.created,
    );
    _receiptsByIdempotencyKey[key] = _ReceiptRecord(
      payloadHash: _hashBundle(nextBundle),
      receipt: receipt,
    );
    return receipt;
  }

  /// Returns whether an active version existed to deactivate — the caller
  /// only needs to reach the Discover sink when it did.
  Future<bool> archive(String collectionId) async {
    return _activeByCollectionId.remove(collectionId) != null;
  }

  PublishedCollectionVersion? activeVersion(String collectionId) =>
      _activeByCollectionId[collectionId];

  static String _hashBundle(CollectionPublishBundle bundle) {
    final String json = jsonEncode(CollectionPublicationModel.toJson(bundle));
    return sha256.convert(utf8.encode(json)).toString();
  }
}

class _ReceiptRecord {
  const _ReceiptRecord({required this.payloadHash, required this.receipt});

  final String payloadHash;
  final CollectionPublishReceipt receipt;
}
