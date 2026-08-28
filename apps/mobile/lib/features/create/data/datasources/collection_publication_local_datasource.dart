import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../shared/primitives/id/id_generator.dart';
import '../../domain/entities/collection_moderation_request.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../models/collection_publication_model.dart';
import '../models/collection_publication_store_mapper.dart';
import 'collection_publication_store.dart';

/// CLG-PST-01: persisted, staged-write local store for §12/§17's
/// "crash-recoverable staged store" requirement — this class used to be a
/// pure in-memory `Map` (see the CLG-CRT-01 LAUNCH_STATUS entries for that
/// history); it now durably persists through [CollectionPublicationStore],
/// keeping the exact idempotency, removal-only and moderation *contracts*
/// unchanged so `CollectionPublicationRepositoryImpl` and everything above
/// it needed no changes at all.
///
/// Every write follows one rule: the business effect (an active version, a
/// pending moderation request) is committed durably *before* the
/// idempotency receipt or sealed decision that certifies it — never after.
/// A crash between the two just means a retry redoes idempotent work; the
/// reverse ordering would let a receipt claim something happened that a
/// crash actually prevented, which a retry could never detect or repair.
///
/// Active-version writes specifically go through a three-step staged
/// commit (`_commitActiveVersion`): write to a `staging.<id>` key, read it
/// back and verify the bytes actually landed, only then copy the same
/// bytes into `active.<id>` — the atomic pointer flip. A crash before that
/// last step leaves `active.<id>` exactly as it was (last-known-good); the
/// abandoned staging entry is never read by anything and is simply
/// overwritten by the next attempt.
///
/// Every stored envelope carries a schema version and a content hash
/// (`CollectionPublicationStoreMapper`); a record that fails either check
/// is corrupt and is isolated to the one lookup that hit it — a
/// known-collectionId/requestId lookup surfaces
/// `CollectionPublicationFailure.persistenceUnavailable` (silently
/// returning "not found" would be indistinguishable from real data loss to
/// a caller building a removal-only base revision on top of it), while
/// enumeration (`pendingRequests()`) skips just that one entry and returns
/// the rest.
class CollectionPublicationLocalDatasource {
  CollectionPublicationLocalDatasource({
    required IdGenerator idGenerator,
    required CollectionPublicationStore store,
  }) : _idGenerator = idGenerator,
       _store = store;

  final IdGenerator _idGenerator;
  final CollectionPublicationStore _store;

  static const String _prefix = 'collection_publication_v1';

  String _activeKey(String collectionId) => '$_prefix.active.$collectionId';
  String _stagingKey(String collectionId) => '$_prefix.staging.$collectionId';
  String _receiptKey(String commandType, String actorId, String requestId) =>
      '$_prefix.receipt.$commandType.$actorId.$requestId';
  String _removalReceiptKey(String collectionId, String requestId) =>
      '$_prefix.receipt.removal.$collectionId.$requestId';
  String _moderationKey(String requestId) =>
      '$_prefix.moderation.$requestId';
  static const String _moderationPrefix = '$_prefix.moderation.';

  Future<CollectionPublishReceipt> publish(
    CollectionPublishBundle bundle, {
    required String actorId,
  }) async {
    final String key = _receiptKey('publish', actorId, bundle.publishAttemptId);
    final String payloadHash = _hashBundle(bundle);
    final _StoredReceipt? existing = await _readReceipt(key);
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
    await _commitActiveVersion(bundle.collectionId, version);
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: bundle.collectionId,
      collectionVersionId: bundle.collectionVersionId,
      publishedAtUtc: now,
      outcome: CollectionPublishOutcome.created,
    );
    await _writeReceipt(key, payloadHash, receipt);
    return receipt;
  }

  /// §6/§7 Шаг 5: same idempotency contract as [publish], but its own key
  /// space (see the key-naming helpers above) and the version only lands
  /// as a moderation request — never [_commitActiveVersion] — until
  /// [decide] accepts it.
  Future<CollectionPublishReceipt> submitForReview(
    CollectionPublishBundle bundle, {
    required String actorId,
  }) async {
    final String key = _receiptKey('review', actorId, bundle.publishAttemptId);
    final String payloadHash = _hashBundle(bundle);
    final _StoredReceipt? existing = await _readReceipt(key);
    if (existing != null) {
      if (existing.payloadHash != payloadHash) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.idempotencyConflict,
          'This publish attempt id was already used with a different '
          'payload.',
        );
      }
      // Review finding: unlike `publish()`, a replay here must NOT be
      // relabelled `replayedIdempotentSuccess` — that outcome reads as
      // "activated" everywhere it is checked, so it would report a
      // still-pending, never-activated submission as a live publish. The
      // stored receipt is already exactly right — return it unchanged.
      return existing.receipt;
    }
    final DateTime now = DateTime.now().toUtc();
    final String requestId = bundle.publishAttemptId;
    await _writeModerationRequest(
      CollectionModerationRequest(
        requestId: requestId,
        bundle: bundle,
        submittedAtUtc: now,
        submittedByActorId: actorId,
      ),
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: bundle.collectionId,
      collectionVersionId: bundle.collectionVersionId,
      submittedAtUtc: now,
      outcome: CollectionPublishOutcome.pendingReview,
    );
    await _writeReceipt(key, payloadHash, receipt);
    return receipt;
  }

  /// Enumeration, not a keyed lookup — corrupt entries are skipped, not
  /// fatal (see the class doc comment).
  Future<List<CollectionModerationRequest>> pendingRequests() async {
    final Map<String, String> stored = await _store.readAllWithPrefix(
      _moderationPrefix,
    );
    final List<CollectionModerationRequest> result =
        <CollectionModerationRequest>[];
    for (final String raw in stored.values) {
      final CollectionModerationRequest? request =
          CollectionPublicationStoreMapper.decodeModerationRequest(raw);
      if (request != null && request.isPending) result.add(request);
    }
    return List<CollectionModerationRequest>.unmodifiable(result);
  }

  /// Returns the decided request (its `decision` now sealed) plus the
  /// newly-active [PublishedCollectionVersion] on acceptance, or `null` on
  /// rejection (nothing to activate). The caller (repository impl) is the
  /// one that talks to the Discover sink — this datasource only owns the
  /// local pending/decided split.
  Future<(CollectionModerationRequest, PublishedCollectionVersion?)> decide({
    required String requestId,
    required bool accept,
    required String decidedByActorId,
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
    final String key = _moderationKey(requestId);
    final String? raw = await _store.read(key);
    if (raw == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.notFound,
        'Moderation request not found.',
      );
    }
    final CollectionModerationRequest? request =
        CollectionPublicationStoreMapper.decodeModerationRequest(raw);
    if (request == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Moderation request record is corrupt.',
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
            decidedByActorId: decidedByActorId,
          )
        : CollectionModerationDecision(
            outcome: CollectionModerationDecisionOutcome.rejected,
            decidedAtUtc: now,
            decidedByActorId: decidedByActorId,
            rejectionReason: rejectionReason,
          );
    if (!accept) {
      final CollectionModerationRequest decided = request.copyWith(
        decision: decision,
      );
      await _writeModerationRequest(decided);
      return (decided, null);
    }
    // Accept: commit the version first (the business effect), seal the
    // decision second — same effect-before-receipt ordering as everywhere
    // else in this class.
    final PublishedCollectionVersion version = PublishedCollectionVersion(
      bundle: request.bundle,
      publishedAtUtc: now,
    );
    await _commitActiveVersion(request.bundle.collectionId, version);
    final CollectionModerationRequest decided = request.copyWith(
      decision: decision,
    );
    await _writeModerationRequest(decided);
    return (decided, version);
  }

  Future<CollectionPublishReceipt> removeItemsOnly(
    CollectionRemovalOnlyCommand command,
  ) async {
    final String key = _removalReceiptKey(
      command.collectionId,
      command.requestId,
    );
    final _StoredReceipt? existing = await _readReceipt(key);
    if (existing != null) {
      return existing.receipt.copyWith(
        outcome: CollectionPublishOutcome.replayedIdempotentSuccess,
      );
    }

    final PublishedCollectionVersion? active = await activeVersion(
      command.collectionId,
    );
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
    await _commitActiveVersion(
      command.collectionId,
      PublishedCollectionVersion(bundle: nextBundle, publishedAtUtc: now),
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: nextBundle.collectionId,
      collectionVersionId: nextBundle.collectionVersionId,
      publishedAtUtc: now,
      outcome: CollectionPublishOutcome.created,
    );
    await _writeReceipt(key, _hashBundle(nextBundle), receipt);
    return receipt;
  }

  /// Returns whether an active version existed to deactivate — the caller
  /// only needs to reach the Discover sink when it did. Deletes whatever
  /// is under the key regardless of whether it still decodes cleanly —
  /// archiving corrupt garbage under an active-version key is still a
  /// meaningful, safe action.
  Future<bool> archive(String collectionId) async {
    final String key = _activeKey(collectionId);
    final String? existing = await _store.read(key);
    if (existing == null) return false;
    await _store.delete(key);
    return true;
  }

  /// A known-collectionId lookup — a corrupt record here throws
  /// `persistenceUnavailable` rather than silently reading as "never
  /// published" (see the class doc comment).
  Future<PublishedCollectionVersion?> activeVersion(String collectionId) async {
    final String? raw = await _store.read(_activeKey(collectionId));
    if (raw == null) return null;
    final PublishedCollectionVersion? version =
        CollectionPublicationStoreMapper.decodeVersion(raw);
    if (version == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Active version record is corrupt.',
      );
    }
    return version;
  }

  /// Staged write -> verified commit marker -> atomic active pointer (see
  /// the class doc comment). The only mutator of `active.<id>` — every
  /// caller above (publish/removeItemsOnly/decide-accept) goes through
  /// this, so the three-step discipline can never be bypassed.
  Future<void> _commitActiveVersion(
    String collectionId,
    PublishedCollectionVersion version,
  ) async {
    final String encoded = CollectionPublicationStoreMapper.encodeVersion(
      version,
    );
    final String stagingKey = _stagingKey(collectionId);
    try {
      await _store.write(stagingKey, encoded);
      final String? verified = await _store.read(stagingKey);
      if (verified != encoded) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.persistenceUnavailable,
          'Staged write verification failed.',
        );
      }
      // Atomic pointer flip: readers only ever consult `active.<id>`,
      // never `staging.<id>` — this is the single instant the new version
      // becomes visible. Any failure up to and including this write means
      // `active.<id>` is left exactly as it was — last-known-good, no
      // partial state ever observable.
      await _store.write(_activeKey(collectionId), encoded);
    } on CollectionPublicationException {
      rethrow;
    } on Object catch (error) {
      throw CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Staged commit failed: $error',
      );
    }
    try {
      await _store.delete(stagingKey);
    } on Object {
      // Best-effort cleanup — the commit above already landed durably; a
      // leftover staging entry is inert (never read) and simply gets
      // overwritten by the next attempt for this collectionId.
    }
  }

  Future<_StoredReceipt?> _readReceipt(String key) async {
    final String? raw = await _store.read(key);
    if (raw == null) return null;
    final ({String payloadHash, CollectionPublishReceipt receipt})? decoded =
        CollectionPublicationStoreMapper.decodeReceipt(raw);
    if (decoded == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Idempotency receipt record is corrupt.',
      );
    }
    return _StoredReceipt(
      payloadHash: decoded.payloadHash,
      receipt: decoded.receipt,
    );
  }

  Future<void> _writeReceipt(
    String key,
    String payloadHash,
    CollectionPublishReceipt receipt,
  ) {
    return _store.write(
      key,
      CollectionPublicationStoreMapper.encodeReceipt(
        payloadHash: payloadHash,
        receipt: receipt,
      ),
    );
  }

  Future<void> _writeModerationRequest(CollectionModerationRequest request) {
    return _store.write(
      _moderationKey(request.requestId),
      CollectionPublicationStoreMapper.encodeModerationRequest(request),
    );
  }

  static String _hashBundle(CollectionPublishBundle bundle) {
    final String json = jsonEncode(CollectionPublicationModel.toJson(bundle));
    return sha256.convert(utf8.encode(json)).toString();
  }
}

class _StoredReceipt {
  const _StoredReceipt({required this.payloadHash, required this.receipt});

  final String payloadHash;
  final CollectionPublishReceipt receipt;
}
