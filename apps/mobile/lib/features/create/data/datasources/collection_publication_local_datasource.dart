import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../shared/primitives/id/id_generator.dart';
import '../../domain/entities/collection_moderation_request.dart';
import '../../domain/entities/collection_publication_data.dart';
import '../models/collection_publication_model.dart';
import '../models/collection_publication_store_mapper.dart';
import 'collection_publication_store.dart';

/// CLG-PST-01/CLG-PST-02: persisted, staged-write local store for §12/§17's
/// "crash-recoverable staged store" requirement — this class used to be a
/// pure in-memory `Map` (see the CLG-CRT-01 LAUNCH_STATUS entries for that
/// history); it now durably persists through [CollectionPublicationStore],
/// keeping the exact idempotency, removal-only and moderation *contracts*
/// unchanged so `CollectionPublicationRepositoryImpl` and everything above
/// it needed no changes to its own signatures beyond [archive] gaining an
/// actor/request id (§12's audit requirement needs one).
///
/// **On-disk scheme (CLG-PST-02 correction — replaces CLG-PST-01's
/// single-blob-overwrite design after a review found it never verified the
/// write that actually mattered):**
///
/// - `version.<collectionId>.<collectionVersionId>` — an *immutable* record,
///   written once per distinct version id and never overwritten with
///   different content (a retry of the same publish/removal/moderation
///   attempt reuses the same version id with byte-identical content, which
///   is a safe no-op write, not a mutation). Immutability means the risky
///   "overwrite a live blob in place" pattern CLG-PST-01 used for
///   `active.<id>` does not exist here at all.
/// - `pointer.<collectionId>` — a small envelope naming which version id is
///   currently active. This is the *only* thing ever overwritten with
///   different content, and every write to it is read back and
///   byte-compared before being trusted (the actual verified commit marker
///   CLG-PST-01 claimed to have but only applied to a staging key, never to
///   the active key itself).
/// - `pointer.<collectionId>.previous` — a backup of the last pointer value
///   that was itself successfully verified, written immediately before the
///   new pointer replaces it. If the current pointer is unreadable/corrupt,
///   or names a version record that is itself unreadable/corrupt, readers
///   fall back to this — genuine last-known-good recovery, not just hoping
///   the one write that matters was never torn.
/// - `tombstone.<collectionId>` — records that a specific version id was
///   archived (actor, request id, timestamp). Archived-ness is *derived* by
///   comparing the tombstone's `archived_version_id` against the pointer's
///   current version id, not by deleting anything — a later publish moves
///   the pointer to a new version id, which automatically makes an old
///   tombstone stale without this class ever having to remember to clean
///   one up.
/// - `receipt.<commandType>.<actorId>.<requestId>` / `moderation.<requestId>`
///   — unchanged from CLG-PST-01.
/// - `audit.<collectionId>.<commandType>.<actorId>.<requestId>` — §12's
///   "команда и diff попадают в audit" requirement: one immutable record per
///   state-changing command
///   (publish/submit/removal/moderation decision/archive), written before
///   the final visibility marker that closes the command out. Write-only
///   from this class in this pass — no production
///   reader exists yet; tests read it directly through the injected
///   [CollectionPublicationStore].
///
/// A command prepares immutable data first, writes its audit and receipt,
/// and flips the verified visibility marker last. For a publish/removal that
/// marker is `pointer.<collectionId>`; for review submission it is the
/// moderation record; for archive it is the tombstone. Consequently a crash
/// before the final marker leaves the previous visible state intact. A replay
/// that finds a prepared receipt completes only the missing final marker.
///
/// Every stored envelope carries a schema version and a content hash
/// (`CollectionPublicationStoreMapper`); a record that fails either check
/// is corrupt and is isolated to the one lookup that hit it. Every direct
/// call into [CollectionPublicationStore] in this class goes through
/// [_guardStorage], so a raw storage exception (not just a decode failure)
/// always surfaces as a typed [CollectionPublicationException] — CLG-PST-01
/// only did this consistently inside the old commit path.
class CollectionPublicationLocalDatasource {
  CollectionPublicationLocalDatasource({
    required IdGenerator idGenerator,
    required CollectionPublicationStore store,
  }) : _idGenerator = idGenerator,
       _store = store;

  final IdGenerator _idGenerator;
  final CollectionPublicationStore _store;

  static const String _prefix = 'collection_publication_v1';

  String _versionKey(String collectionId, String versionId) =>
      '$_prefix.version.$collectionId.$versionId';
  String _pointerKey(String collectionId) => '$_prefix.pointer.$collectionId';
  String _pointerPreviousKey(String collectionId) =>
      '$_prefix.pointer.$collectionId.previous';
  String _tombstoneKey(String collectionId) =>
      '$_prefix.tombstone.$collectionId';
  String _auditKey(
    String collectionId,
    String commandType,
    String actorId,
    String requestId,
  ) => '$_prefix.audit.$collectionId.$commandType.$actorId.$requestId';
  String _receiptKey(String commandType, String actorId, String requestId) =>
      '$_prefix.receipt.$commandType.$actorId.$requestId';
  String _removalReceiptKey(String collectionId, String requestId) =>
      '$_prefix.receipt.removal.$collectionId.$requestId';
  String _moderationKey(String requestId) => '$_prefix.moderation.$requestId';
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
      // The receipt may have landed immediately before a pointer-write crash.
      // Finish that one missing visibility step before reporting replay.
      await _activateReceiptVersion(existing.receipt);
      return existing.receipt.copyWith(
        outcome: CollectionPublishOutcome.replayedIdempotentSuccess,
      );
    }
    final DateTime now = DateTime.now().toUtc();
    final PublishedCollectionVersion version = PublishedCollectionVersion(
      bundle: bundle,
      publishedAtUtc: now,
    );
    final PublishedCollectionVersion staged = await _stageVersion(version);
    await _writeAudit(
      collectionId: bundle.collectionId,
      commandType: 'publish',
      actorId: actorId,
      requestId: bundle.publishAttemptId,
      atUtc: now,
      outcome: 'created',
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: bundle.collectionId,
      collectionVersionId: bundle.collectionVersionId,
      publishedAtUtc: staged.publishedAtUtc,
      outcome: CollectionPublishOutcome.created,
    );
    await _writeReceipt(key, payloadHash, receipt);
    await _activateVersion(staged);
    return receipt;
  }

  /// §6/§7 Шаг 5: same idempotency contract as [publish], but its own key
  /// space (see the key-naming helpers above) and the version only lands
  /// as a moderation request — never [_commitVersion] — until [decide]
  /// accepts it.
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
      final String? moderationRaw = await _guardStorage(
        () => _store.read(_moderationKey(bundle.publishAttemptId)),
      );
      if (moderationRaw == null) {
        // Receipt durable, final moderation marker missing: reconstruct it
        // with the original receipt timestamp instead of minting a new event.
        final DateTime submittedAtUtc = existing.receipt.submittedAtUtc!;
        await _writeAudit(
          collectionId: bundle.collectionId,
          commandType: 'submit',
          actorId: actorId,
          requestId: bundle.publishAttemptId,
          atUtc: submittedAtUtc,
          outcome: 'pendingReview',
        );
        await _writeModerationRequest(
          CollectionModerationRequest(
            requestId: bundle.publishAttemptId,
            bundle: bundle,
            submittedAtUtc: submittedAtUtc,
            submittedByActorId: actorId,
          ),
        );
      } else if (CollectionPublicationStoreMapper.decodeModerationRequest(
            moderationRaw,
          ) ==
          null) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.persistenceUnavailable,
          'Moderation request record is corrupt.',
        );
      }
      // A replay here must NOT be relabelled `replayedIdempotentSuccess` —
      // that outcome reads as "activated" everywhere it is checked, so it
      // would report a still-pending, never-activated submission as a live
      // publish. The stored receipt is already exactly right — return it
      // unchanged.
      return existing.receipt;
    }
    final DateTime now = DateTime.now().toUtc();
    final String requestId = bundle.publishAttemptId;
    final CollectionModerationRequest pending = CollectionModerationRequest(
      requestId: requestId,
      bundle: bundle,
      submittedAtUtc: now,
      submittedByActorId: actorId,
    );
    await _writeAudit(
      collectionId: bundle.collectionId,
      commandType: 'submit',
      actorId: actorId,
      requestId: requestId,
      atUtc: now,
      outcome: 'pendingReview',
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: bundle.collectionId,
      collectionVersionId: bundle.collectionVersionId,
      submittedAtUtc: now,
      outcome: CollectionPublishOutcome.pendingReview,
    );
    await _writeReceipt(key, payloadHash, receipt);
    // Visibility marker last: pendingRequests() cannot expose a request whose
    // audit/receipt did not both land durably.
    await _writeModerationRequest(pending);
    return receipt;
  }

  /// Enumeration, not a keyed lookup — corrupt entries are skipped, not
  /// fatal (see the class doc comment).
  Future<List<CollectionModerationRequest>> pendingRequests() async {
    final Map<String, String> stored = await _guardStorage(
      () => _store.readAllWithPrefix(_moderationPrefix),
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
    final String? raw = await _guardStorage(() => _store.read(key));
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
      final CollectionModerationDecision sealed = request.decision!;
      final CollectionModerationDecisionOutcome requestedOutcome = accept
          ? CollectionModerationDecisionOutcome.accepted
          : CollectionModerationDecisionOutcome.rejected;
      final bool sameDecision =
          sealed.outcome == requestedOutcome &&
          sealed.decidedByActorId == decidedByActorId &&
          sealed.rejectionReason == rejectionReason;
      if (!sameDecision) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.idempotencyConflict,
          'This moderation request was already decided differently.',
        );
      }
      // Idempotent replay of the exact sealed decision. Returning the active
      // version on accept deliberately lets the repository retry a failed
      // Discover sink without mutating the sealed request.
      final PublishedCollectionVersion? active = accept
          ? await activeVersion(request.collectionId)
          : null;
      return (request, active);
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
      await _writeAudit(
        collectionId: request.collectionId,
        commandType: 'moderate_reject',
        actorId: decidedByActorId,
        requestId: requestId,
        atUtc: now,
        outcome: 'rejected',
        diff: <String>[rejectionReason!.name],
      );
      final CollectionModerationRequest decided = request.copyWith(
        decision: decision,
      );
      await _writeModerationRequest(decided);
      return (decided, null);
    }
    // Accept prepares the immutable version and audit before sealing the
    // decision. The pointer may be written first, but activeVersion() hides
    // it while this request is still pending, so the sealed decision remains
    // the externally visible commit marker.
    final PublishedCollectionVersion version = PublishedCollectionVersion(
      bundle: request.bundle,
      publishedAtUtc: now,
    );
    final PublishedCollectionVersion staged = await _stageVersion(version);
    await _writeAudit(
      collectionId: request.collectionId,
      commandType: 'moderate_accept',
      actorId: decidedByActorId,
      requestId: requestId,
      atUtc: now,
      outcome: 'accepted',
    );
    // The pointer is prepared before the sealed decision, but activeVersion()
    // hides it while this request is still pending. The moderation record is
    // therefore the final visibility marker for an accepted review.
    await _activateVersion(staged, moderationRequestId: requestId);
    final CollectionModerationRequest decided = request.copyWith(
      decision: decision,
    );
    await _writeModerationRequest(decided);
    return (decided, staged);
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
      // Receipt can precede the final pointer flip. Exact replay repairs it.
      await _activateReceiptVersion(existing.receipt);
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
    final PublishedCollectionVersion staged = await _stageVersion(
      PublishedCollectionVersion(bundle: nextBundle, publishedAtUtc: now),
    );
    await _writeAudit(
      collectionId: nextBundle.collectionId,
      commandType: 'removal',
      actorId: command.actorId,
      requestId: command.requestId,
      atUtc: now,
      outcome: 'created',
      diff: command.removedItemRefs.toList(growable: false),
    );
    final CollectionPublishReceipt receipt = CollectionPublishReceipt(
      collectionId: nextBundle.collectionId,
      collectionVersionId: nextBundle.collectionVersionId,
      publishedAtUtc: staged.publishedAtUtc,
      outcome: CollectionPublishOutcome.created,
    );
    await _writeReceipt(key, _hashBundle(nextBundle), receipt);
    await _activateVersion(staged);
    return receipt;
  }

  /// §3.11 lifecycle command. Returns `false` only when [collectionId] has
  /// no version history at all (never published, nothing to sync, ever).
  /// Returns `true` both the first time a real active version is archived
  /// *and* on every subsequent retry of an already-archived collection —
  /// the caller (repository impl) uses `true` to decide whether the
  /// Discover sink should be (re)attempted, which must happen on retry too:
  /// CLG-PST-01's version deleted the local record on first archive, so a
  /// retry after a failed sink sync found nothing left to re-attempt
  /// against and silently gave up. This version never deletes anything —
  /// archived-ness is derived by comparing the tombstone's version id
  /// against the pointer's current one, so a later republish automatically
  /// supersedes an old tombstone without this class needing to remember to
  /// clean one up.
  Future<bool> archive(
    String collectionId, {
    required String actorId,
    String? requestId,
  }) async {
    final ({
      String versionId,
      PublishedCollectionVersion version,
      String? moderationRequestId,
    })?
    resolved = await _resolveActive(collectionId);
    if (resolved == null) return false; // never published — nothing, ever.

    final _Tombstone? tombstone = await _readTombstone(collectionId);
    final bool alreadyArchived =
        tombstone != null && tombstone.archivedVersionId == resolved.versionId;
    if (!alreadyArchived) {
      final String effectiveRequestId = requestId ?? _idGenerator.generate();
      final DateTime now = DateTime.now().toUtc();
      await _writeAudit(
        collectionId: collectionId,
        commandType: 'archive',
        actorId: actorId,
        requestId: effectiveRequestId,
        atUtc: now,
        outcome: 'archived',
      );
      // Tombstone is the final visibility marker. If audit persistence fails,
      // the Collection remains active and a retry can safely start over.
      await _writeVerified(
        _tombstoneKey(collectionId),
        CollectionPublicationStoreMapper.encodeTombstone(
          archivedVersionId: resolved.versionId,
          actorId: actorId,
          requestId: effectiveRequestId,
          archivedAtUtc: now,
        ),
      );
    } else {
      // Repair an audit that may have been lost after an older implementation
      // wrote its tombstone first, while keeping the original actor/request.
      await _writeAudit(
        collectionId: collectionId,
        commandType: 'archive',
        actorId: tombstone.actorId,
        requestId: tombstone.requestId,
        atUtc: tombstone.archivedAtUtc,
        outcome: 'archived',
      );
    }
    return true; // has a record either way — sink should be (re)attempted.
  }

  /// A known-collectionId lookup — a corrupt record here throws
  /// `persistenceUnavailable` rather than silently reading as "never
  /// published" (see the class doc comment). Returns `null` both when the
  /// collection was never published and when it is currently archived
  /// (tombstone matches the pointer's current version id).
  Future<PublishedCollectionVersion?> activeVersion(String collectionId) async {
    final ({
      String versionId,
      PublishedCollectionVersion version,
      String? moderationRequestId,
    })?
    resolved = await _resolveActive(collectionId);
    if (resolved == null) return null;
    final _Tombstone? tombstone = await _readTombstone(collectionId);
    if (tombstone != null &&
        tombstone.archivedVersionId == resolved.versionId) {
      return null; // archived, and no republish since.
    }
    final String? requestId = resolved.moderationRequestId;
    if (requestId == null) return resolved.version;
    final String? moderationRaw = await _guardStorage(
      () => _store.read(_moderationKey(requestId)),
    );
    if (moderationRaw != null) {
      final CollectionModerationRequest? moderation =
          CollectionPublicationStoreMapper.decodeModerationRequest(
            moderationRaw,
          );
      if (moderation == null) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.persistenceUnavailable,
          'Moderation request record is corrupt.',
        );
      }
      if (moderation.isPending) return null;
      if (moderation.decision!.outcome ==
          CollectionModerationDecisionOutcome.rejected) {
        return null;
      }
    }
    return resolved.version;
  }

  /// Staged write -> verified commit marker -> small verified pointer flip
  /// with a last-known-good backup (see the class doc comment). The only
  /// mutator of `pointer.<id>` — every caller above (publish/
  /// removeItemsOnly/decide-accept) goes through this, so the discipline
  /// can never be bypassed.
  /// Writes the immutable version record and verifies it, but does not make it
  /// visible. If this exact version id already exists, its original timestamp
  /// and bytes win; the record is never overwritten with different content.
  Future<PublishedCollectionVersion> _stageVersion(
    PublishedCollectionVersion version,
  ) async {
    final String collectionId = version.collectionId;
    final String versionId = version.collectionVersionId;
    final String encodedVersion =
        CollectionPublicationStoreMapper.encodeVersion(version);
    final String versionKey = _versionKey(collectionId, versionId);
    final String? existing = await _guardStorage(() => _store.read(versionKey));
    if (existing != null) {
      final PublishedCollectionVersion? decoded =
          CollectionPublicationStoreMapper.decodeVersion(existing);
      if (decoded == null ||
          _hashBundle(decoded.bundle) != _hashBundle(version.bundle)) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.idempotencyConflict,
          'A version id already exists with different or corrupt content.',
        );
      }
      return decoded;
    }
    await _writeVerified(versionKey, encodedVersion);
    return version;
  }

  /// Final commit marker for a prepared publish/removal/moderation-accept.
  Future<void> _activateVersion(
    PublishedCollectionVersion version, {
    String? moderationRequestId,
  }) async {
    final String collectionId = version.collectionId;
    final String versionId = version.collectionVersionId;

    final String pointerKey = _pointerKey(collectionId);
    final String? currentPointerRaw = await _guardStorage(
      () => _store.read(pointerKey),
    );
    if (currentPointerRaw != null) {
      final current = CollectionPublicationStoreMapper.decodePointerEnvelope(
        currentPointerRaw,
      );
      if (current?.activeVersionId == versionId &&
          current?.moderationRequestId == moderationRequestId) {
        return;
      }
      final currentResolved = await _tryResolvePointer(
        currentPointerRaw,
        collectionId,
      );
      if (currentResolved != null) {
        // Only a pointer whose envelope *and target version* are readable is
        // last-known-good. Never replace `.previous` with corrupt bytes.
        await _writeVerified(
          _pointerPreviousKey(collectionId),
          currentPointerRaw,
        );
      }
    }
    final String newPointer = CollectionPublicationStoreMapper.encodePointer(
      activeVersionId: versionId,
      moderationRequestId: moderationRequestId,
    );
    // The single instant the new version becomes visible to readers. Any
    // failure up to and including this write leaves `pointer.<id>` exactly
    // as it was — last-known-good, no partial state ever observable.
    await _writeVerified(pointerKey, newPointer);
  }

  /// Completes the final pointer flip for a durable publish/removal receipt.
  /// Missing or corrupt prepared data is a typed storage failure: replay must
  /// never claim success when it cannot materialize the receipt's effect.
  Future<void> _activateReceiptVersion(CollectionPublishReceipt receipt) async {
    final String? raw = await _guardStorage(
      () => _store.read(
        _versionKey(receipt.collectionId, receipt.collectionVersionId),
      ),
    );
    final PublishedCollectionVersion? version = raw == null
        ? null
        : CollectionPublicationStoreMapper.decodeVersion(raw);
    if (version == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Prepared version for the durable receipt is missing or corrupt.',
      );
    }
    final ({
      String versionId,
      PublishedCollectionVersion version,
      String? moderationRequestId,
    })?
    current = await _resolveActive(receipt.collectionId);
    if (current != null &&
        current.versionId != receipt.collectionVersionId &&
        !current.version.publishedAtUtc.isBefore(version.publishedAtUtc)) {
      // A later command already advanced the Collection. Replaying an older
      // receipt must never roll the active pointer backwards.
      return;
    }
    await _activateVersion(version);
  }

  /// Resolves `pointer.<collectionId>` to its named version record, falling
  /// back to `pointer.<collectionId>.previous` if the primary pointer or
  /// the version it names is missing/corrupt. Returns `null` only when
  /// there is no pointer at all (never published) — a pointer that exists
  /// but cannot be resolved even through the fallback throws
  /// `persistenceUnavailable`.
  Future<
    ({
      String versionId,
      PublishedCollectionVersion version,
      String? moderationRequestId,
    })?
  >
  _resolveActive(String collectionId) async {
    final String? primaryRaw = await _guardStorage(
      () => _store.read(_pointerKey(collectionId)),
    );
    if (primaryRaw != null) {
      final ({
        String versionId,
        PublishedCollectionVersion version,
        String? moderationRequestId,
      })?
      primary = await _tryResolvePointer(primaryRaw, collectionId);
      if (primary != null) return primary;
    }

    final String? previousRaw = await _guardStorage(
      () => _store.read(_pointerPreviousKey(collectionId)),
    );
    if (previousRaw != null) {
      final ({
        String versionId,
        PublishedCollectionVersion version,
        String? moderationRequestId,
      })?
      fallback = await _tryResolvePointer(previousRaw, collectionId);
      if (fallback != null) return fallback;
    }
    if (primaryRaw == null) return null;
    throw const CollectionPublicationException(
      CollectionPublicationFailure.persistenceUnavailable,
      'Active version record is corrupt and no last-known-good pointer '
      'could be recovered.',
    );
  }

  Future<
    ({
      String versionId,
      PublishedCollectionVersion version,
      String? moderationRequestId,
    })?
  >
  _tryResolvePointer(String raw, String collectionId) async {
    final pointer = CollectionPublicationStoreMapper.decodePointerEnvelope(raw);
    if (pointer == null) return null;
    final String versionId = pointer.activeVersionId;
    final String? versionRaw = await _guardStorage(
      () => _store.read(_versionKey(collectionId, versionId)),
    );
    if (versionRaw == null) return null;
    final PublishedCollectionVersion? version =
        CollectionPublicationStoreMapper.decodeVersion(versionRaw);
    if (version == null) return null;
    return (
      versionId: versionId,
      version: version,
      moderationRequestId: pointer.moderationRequestId,
    );
  }

  Future<_Tombstone?> _readTombstone(String collectionId) async {
    final String? raw = await _guardStorage(
      () => _store.read(_tombstoneKey(collectionId)),
    );
    if (raw == null) return null;
    final decoded = CollectionPublicationStoreMapper.decodeTombstone(raw);
    if (decoded == null) {
      throw const CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Archive tombstone record is corrupt.',
      );
    }
    return _Tombstone(
      archivedVersionId: decoded.archivedVersionId,
      actorId: decoded.actorId,
      requestId: decoded.requestId,
      archivedAtUtc: decoded.archivedAtUtc,
    );
  }

  Future<_StoredReceipt?> _readReceipt(String key) async {
    final String? raw = await _guardStorage(() => _store.read(key));
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
    return _writeVerified(
      key,
      CollectionPublicationStoreMapper.encodeReceipt(
        payloadHash: payloadHash,
        receipt: receipt,
      ),
    );
  }

  Future<void> _writeModerationRequest(CollectionModerationRequest request) {
    return _writeVerified(
      _moderationKey(request.requestId),
      CollectionPublicationStoreMapper.encodeModerationRequest(request),
    );
  }

  Future<void> _writeAudit({
    required String collectionId,
    required String commandType,
    required String actorId,
    required String requestId,
    required DateTime atUtc,
    required String outcome,
    List<String>? diff,
  }) async {
    final String key = _auditKey(collectionId, commandType, actorId, requestId);
    final String? existingRaw = await _guardStorage(() => _store.read(key));
    if (existingRaw != null) {
      final existing = CollectionPublicationStoreMapper.decodeAudit(
        existingRaw,
      );
      if (existing == null) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.persistenceUnavailable,
          'Audit record is corrupt.',
        );
      }
      final bool sameDiff = diff == null
          ? existing.diff == null
          : existing.diff != null &&
                existing.diff!.toSet().containsAll(diff) &&
                diff.toSet().containsAll(existing.diff!);
      if (existing.collectionId != collectionId ||
          existing.commandType != commandType ||
          existing.actorId != actorId ||
          existing.requestId != requestId ||
          existing.outcome != outcome ||
          !sameDiff) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.idempotencyConflict,
          'Audit identity was already used for a different command.',
        );
      }
      return; // immutable exact replay; preserve the original timestamp.
    }
    await _writeVerified(
      key,
      CollectionPublicationStoreMapper.encodeAudit(
        collectionId: collectionId,
        commandType: commandType,
        actorId: actorId,
        requestId: requestId,
        atUtc: atUtc,
        outcome: outcome,
        diff: diff,
      ),
    );
  }

  /// Writes [value] to [key], then reads it back and byte-compares — the
  /// verified commit marker. Any mismatch (or any underlying storage
  /// exception, via [_guardStorage]) surfaces as `persistenceUnavailable`
  /// before the caller can treat [key] as durably, correctly written.
  Future<void> _writeVerified(String key, String value) {
    return _guardStorage(() async {
      await _store.write(key, value);
      final String? verified = await _store.read(key);
      if (verified != value) {
        throw const CollectionPublicationException(
          CollectionPublicationFailure.persistenceUnavailable,
          'Write verification failed for a durable record.',
        );
      }
    });
  }

  /// Every direct call into [_store] in this class goes through this — a
  /// raw storage exception (not just a decode/hash failure, which the
  /// mapper already turns into `null`) always surfaces as a typed
  /// [CollectionPublicationException] instead of propagating unhandled past
  /// `CreateController`, which only ever catches this type.
  Future<T> _guardStorage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CollectionPublicationException {
      rethrow;
    } on Object catch (error) {
      throw CollectionPublicationException(
        CollectionPublicationFailure.persistenceUnavailable,
        'Storage operation failed: $error',
      );
    }
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

class _Tombstone {
  const _Tombstone({
    required this.archivedVersionId,
    required this.actorId,
    required this.requestId,
    required this.archivedAtUtc,
  });

  final String archivedVersionId;
  final String actorId;
  final String requestId;
  final DateTime archivedAtUtc;
}
