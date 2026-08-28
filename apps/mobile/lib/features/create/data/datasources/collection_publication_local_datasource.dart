import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../shared/primitives/id/id_generator.dart';
import '../../domain/entities/collection_moderation_request.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../models/collection_publication_model.dart';

/// In-memory stand-in for the crash-recoverable staged store described in
/// §12 — an actual persisted, staged-write/restart-recovery/corrupt-record-
/// isolation implementation is a tracked follow-up (this class does not yet
/// meet that bar — see the CLG-CRT-01 LAUNCH_STATUS entry); this keeps the
/// exact idempotency, removal-only and moderation *contracts* so the
/// eventual storage backend is a drop-in swap, not an API change.
class CollectionPublicationLocalDatasource {
  CollectionPublicationLocalDatasource({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  final Map<String, PublishedCollectionVersion> _activeByCollectionId =
      <String, PublishedCollectionVersion>{};

  /// Keyed by `'$commandType:$actorId:${bundle.publishAttemptId}'` — §12's
  /// effective `(actorId, commandType, requestId)` key. `publish` and
  /// `submitForReview` each get their own `commandType` prefix so a replay
  /// of one can never be read back as a receipt for the other (a review
  /// receipt replayed through `publish`'s key space, or vice versa, would
  /// otherwise report an activation that never happened).
  final Map<String, _ReceiptRecord> _receiptsByIdempotencyKey =
      <String, _ReceiptRecord>{};

  /// Every moderation request ever created, pending or decided — a decided
  /// request stays here (sealed, immutable `decision`) rather than being
  /// removed, so [decide] can detect and refuse a second decision on the
  /// same request instead of silently re-deciding it.
  final Map<String, CollectionModerationRequest> _moderationRequests =
      <String, CollectionModerationRequest>{};

  Future<CollectionPublishReceipt> publish(
    CollectionPublishBundle bundle, {
    required String actorId,
  }) async {
    final String key = 'publish:$actorId:${bundle.publishAttemptId}';
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

  /// §6/§7 Шаг 5: same idempotency contract as [publish], but its own key
  /// space (see the `_receiptsByIdempotencyKey` doc comment) and the
  /// version only lands in [_moderationRequests] — never
  /// [_activeByCollectionId] — until [decide] accepts it.
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle, {
    required String actorId,
  }) async {
    final String key = 'review:$actorId:${bundle.publishAttemptId}';
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
    _moderationRequests[requestId] = CollectionModerationRequest(
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
    return _moderationRequests.values
        .where((CollectionModerationRequest request) => request.isPending)
        .toList(growable: false);
  }

  /// Returns the decided request (its `decision` now sealed) plus the
  /// newly-active [PublishedCollectionVersion] on acceptance, or `null` on
  /// rejection (nothing to activate). The caller (repository impl) is the
  /// one that talks to the Discover sink — this datasource only owns the
  /// local pending/decided split.
  Future<(CollectionModerationRequest, PublishedCollectionVersion?)> decide({
    required String requestId,
    required bool accept,
    CollectionModerationRejectionReason? rejectionReason,
  }) async {
    if (!accept && rejectionReason == null) {
      throw ArgumentError.notNull('rejectionReason');
    }
    if (accept && rejectionReason != null) {
      throw ArgumentError.value(
        rejectionReason,
        'rejectionReason',
        'Must be null when accepting.',
      );
    }
    final CollectionModerationRequest? request = _moderationRequests[requestId];
    if (request == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.notFound,
        'Moderation request not found.',
      );
    }
    if (!request.isPending) {
      // Sealed (§6): a second decide() on the same request is refused, not
      // silently replayed or overwritten.
      throw const CollectionPublicationException(
        CollectionPublicationFailure.idempotencyConflict,
        'This moderation request was already decided.',
      );
    }
    final DateTime now = DateTime.now().toUtc();
    final CollectionModerationDecision decision = accept
        ? CollectionModerationDecision(
            outcome: CollectionModerationDecisionOutcome.accepted,
            decidedAtUtc: now,
          )
        : CollectionModerationDecision(
            outcome: CollectionModerationDecisionOutcome.rejected,
            decidedAtUtc: now,
            rejectionReason: rejectionReason,
          );
    final CollectionModerationRequest decided = request.copyWith(
      decision: decision,
    );
    _moderationRequests[requestId] = decided;
    if (!accept) return (decided, null);
    final PublishedCollectionVersion version = PublishedCollectionVersion(
      bundle: request.bundle,
      publishedAtUtc: now,
    );
    _activeByCollectionId[request.bundle.collectionId] = version;
    return (decided, version);
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
