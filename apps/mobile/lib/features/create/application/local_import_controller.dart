import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'local_import_cleanup_policy.dart';
import 'local_import_type_adapters.dart';
import 'publication_media_type.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/local_import.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/local_import_gateway.dart';
import '../domain/repositories/publisher_access_check.dart';
import '../domain/usecases/local_import_hash.dart';

enum LocalImportPhase { loading, ready, working, offline }

/// One inventory line: the dry-run answer, the receipt (if imported) and where
/// its local original stands.
final class LocalImportItemView {
  const LocalImportItemView({
    required this.candidate,
    required this.cleanup,
    this.receipt,
    this.failureCode,
  });

  final LocalImportCandidate candidate;
  final LocalImportReceipt? receipt;
  final LocalImportCleanupStatus cleanup;

  /// The server's refusal of the item's create in this run (no server object
  /// exists for it, so there is no receipt to hold it).
  final String? failureCode;

  /// D4.1 §3.1: only a verified import (or a rollback whose outcome is still
  /// unknown) may be rolled back, and never while a cleanup is under way or
  /// after the original is gone.
  bool get canRollBack {
    final LocalImportReceipt? value = receipt;
    return value != null &&
        (value.state == LocalImportItemState.verified ||
            value.state == LocalImportItemState.rollbackPending) &&
        value.cleanupToken == null &&
        value.localDeletedAtUtc == null;
  }

  /// A cleanup intent whose original is still here can be released.
  bool get canCancelCleanup {
    final LocalImportReceipt? value = receipt;
    return value != null &&
        value.cleanupToken != null &&
        value.localDeletedAtUtc == null;
  }
}

final class LocalImportViewState {
  const LocalImportViewState({
    required this.phase,
    this.items = const <LocalImportItemView>[],
    this.session,
    this.chosenUpdates = const <String>{},
    this.message,
    this.pendingCleanups = 0,
  });

  final LocalImportPhase phase;
  final List<LocalImportItemView> items;
  final LocalImportSession? session;

  /// D4.1: originals already deleted whose server completion is still owed
  /// (the item is no longer in the inventory).
  final int pendingCleanups;

  /// Conflicting items the user chose to import again into their server draft.
  final Set<String> chosenUpdates;

  /// Last refusal or failure code (server code, or a local one).
  final String? message;

  bool get _idle => phase == LocalImportPhase.ready;

  bool get canApprove =>
      _idle &&
      !(session?.open ?? false) &&
      items.any(
        (LocalImportItemView item) =>
            item.candidate.classification == LocalImportClass.create ||
            (item.candidate.classification == LocalImportClass.conflict &&
                chosenUpdates.contains(item.candidate.localDraftId)),
      );

  bool get canRun =>
      (_idle || phase == LocalImportPhase.offline) && (session?.open ?? false);
}

/// Safe local→server import of the user's own Create drafts (D4, BCK-18 §16,
/// §33.5): inventory, dry run without any server mutation, explicit approval,
/// then one item at a time through the owning Content commands with a durable
/// receipt after every step, a checkpoint that advances only after server
/// verification, and resume from it. It never submits or publishes, never
/// imports local publication, moderation or authority state, and never
/// deletes a local original before verification, the user's explicit
/// confirmation and the end of the recovery period.
final class LocalImportController extends ChangeNotifier {
  LocalImportController({
    required String accountId,
    required LocalImportSource source,
    required LocalImportJournal journal,
    required LocalImportExistingPublications existing,
    required LocalImportContentGateway gateway,
    required EventCoverUploader uploader,
    required EventCoverSource mediaSource,
    required PublisherAccessCheck publisherAccess,
    required LocalImportOriginalStore originals,
    required LocalImportCommandGate gate,
    LocalImportCleanupPolicy policy = const LocalImportCleanupPolicy(),
    Map<CreateObjectType, LocalImportTypeAdapter>? adapters,
    String marketId = 'LV',
    DateTime Function()? clock,
    String Function()? newSessionId,
    String Function()? newFencingToken,
    String? installationId,
  }) : _accountId = accountId,
       _source = source,
       _journal = journal,
       _existing = existing,
       _gateway = gateway,
       _uploader = uploader,
       _mediaSource = mediaSource,
       _publisherAccess = publisherAccess,
       _originals = originals,
       _gate = gate,
       _policy = policy,
       _adapters = adapters ?? localImportAdapters,
       _marketId = marketId,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _newSessionId =
           newSessionId ??
           (() => 'imp-${DateTime.now().toUtc().microsecondsSinceEpoch}'),
       _newFencingToken = newFencingToken ?? (() => 'ct-${_randomToken()}'),
       _installationId = installationId ?? 'install-${_randomToken()}';

  /// Upload attempts one run spends on one medium whose sessions keep
  /// expiring; the next run goes on from the saved attempt.
  static const int uploadAttemptsPerRun = 4;

  final String _accountId;
  final LocalImportSource _source;
  final LocalImportJournal _journal;
  final LocalImportExistingPublications _existing;
  final LocalImportContentGateway _gateway;
  final EventCoverUploader _uploader;
  final EventCoverSource _mediaSource;
  final PublisherAccessCheck _publisherAccess;
  final LocalImportOriginalStore _originals;
  final LocalImportCommandGate _gate;
  final LocalImportCleanupPolicy _policy;
  final Map<CreateObjectType, LocalImportTypeAdapter> _adapters;
  final String _marketId;
  final DateTime Function() _clock;
  final String Function() _newSessionId;
  final String Function() _newFencingToken;

  /// Recorded with every cleanup reservation of this controller; the fencing
  /// token, not this id, is what completes or releases it.
  final String _installationId;

  /// The drafts behind the current dry run, by local id.
  final Map<String, CreateDraftEntity> _drafts = <String, CreateDraftEntity>{};

  /// Create refusals of this controller's runs, by local id.
  final Map<String, String> _createFailures = <String, String>{};

  LocalImportViewState _state = const LocalImportViewState(
    phase: LocalImportPhase.loading,
  );

  LocalImportViewState get state => _state;

  /// Inventory and dry run (no server mutation, no server call).
  Future<void> load() => _run(_dryRun);

  /// The user chooses to import a changed, already imported item again.
  void chooseUpdate(String localDraftId) {
    _state = LocalImportViewState(
      phase: _state.phase,
      items: _state.items,
      session: _state.session,
      chosenUpdates: <String>{..._state.chosenUpdates, localDraftId},
      message: _state.message,
      pendingCleanups: _state.pendingCleanups,
    );
    notifyListeners();
  }

  /// Explicit approval of exactly the current dry run: a new session.
  Future<void> approve() => _run(() async {
    await _dryRun();
    // One open session at a time: it is resumed, never replaced.
    if (_state.session?.open ?? false) {
      throw const _LocalRefusal('session_open');
    }
    if (!_state.canApproveIgnoringPhase) {
      throw const _LocalRefusal('nothing_to_import');
    }
    final List<LocalImportCandidate> planned = <LocalImportCandidate>[
      for (final LocalImportItemView item in _state.items)
        if (item.candidate.classification == LocalImportClass.create ||
            (item.candidate.classification == LocalImportClass.conflict &&
                _state.chosenUpdates.contains(item.candidate.localDraftId)))
          item.candidate,
    ];
    final DateTime now = _clock();
    final LocalImportSession session = LocalImportSession(
      sessionId: _newSessionId(),
      accountId: _accountId,
      inventoryHash: localImportHash(<Object?>[
        for (final LocalImportCandidate item in planned)
          <String, Object?>{
            'localDraftId': item.localDraftId,
            'class': item.classification.name,
            'sourceHash': item.sourceHash,
          },
      ]),
      plannedLocalDraftIds: List<String>.unmodifiable(
        planned.map((LocalImportCandidate item) => item.localDraftId),
      ),
      plannedSourceHashes: List<String>.unmodifiable(
        planned.map((LocalImportCandidate item) => item.sourceHash!),
      ),
      checkpoint: 0,
      status: LocalImportSessionStatus.approved,
      startedAtUtc: now,
      updatedAtUtc: now,
    );
    await _journal.saveSession(session);
    await _dryRun();
  });

  /// Runs, or resumes, the open session from its checkpoint.
  Future<void> run() => _run(() async {
    LocalImportSession? session = await _journal.currentSession(_accountId);
    if (session == null || !session.open) {
      throw const _LocalRefusal('no_open_session');
    }
    // A resume after a restart works from the local data as it is now.
    await _dryRun();
    session = session.copyWith(
      status: LocalImportSessionStatus.running,
      updatedAtUtc: _clock(),
    );
    await _journal.saveSession(session);
    try {
      while (session!.checkpoint < session.plannedLocalDraftIds.length) {
        final String localDraftId =
            session.plannedLocalDraftIds[session.checkpoint];
        await _importItem(
          localDraftId,
          session.plannedSourceHashes[session.checkpoint],
        );
        // Advanced only after the item's receipt is durable (verified or failed).
        session = session.copyWith(
          checkpoint: session.checkpoint + 1,
          updatedAtUtc: _clock(),
        );
        await _journal.saveSession(session);
      }
      await _journal.saveSession(
        session.copyWith(
          status: LocalImportSessionStatus.completed,
          updatedAtUtc: _clock(),
        ),
      );
    } on EventPublicationUnavailable {
      // An unknown outcome: the next run repeats the step with the same key.
      await _journal.saveSession(
        session!.copyWith(
          status: LocalImportSessionStatus.paused,
          updatedAtUtc: _clock(),
        ),
      );
      rethrow;
    } finally {
      await _dryRun();
    }
  });

  /// The user's explicit confirmation that the verified server copy is kept.
  Future<void> confirm(String localDraftId) => _run(() async {
    final LocalImportReceipt receipt = await _requireReceipt(localDraftId);
    if (receipt.state != LocalImportItemState.verified) {
      throw const _LocalRefusal('not_verified');
    }
    await _journal.saveReceipt(
      receipt.copyWith(confirmedAtUtc: _clock(), updatedAtUtc: _clock()),
    );
    await _dryRun();
  });

  /// Removes the local original once the policy allows it, after a fresh
  /// server check and only while the local draft is still exactly the
  /// imported one (same source hash, and the same stored draft at deletion).
  /// D4.1 §1 order: (1) a durable intent with a new fencing token, (2) the
  /// server reservation, (3) the deletion, (4) `completeImportCleanup` with
  /// that exact token. A reservation forbids a rollback on every installation.
  Future<void> deleteLocal(String localDraftId) => _run(() async {
    LocalImportReceipt receipt = await _requireReceipt(localDraftId);
    final LocalImportCleanupStatus status = _policy.statusOf(receipt, _clock());
    final bool reserved =
        status.stage == LocalImportCleanupStage.cleanupReserved;
    if (status.stage != LocalImportCleanupStage.eligible && !reserved) {
      throw _LocalRefusal('cleanup_${status.stage.name}');
    }
    final LocalImportServerDraft server = await _gateway.draft(receipt.draftId);
    if (server.createdByUserId != receipt.serverOwnerUserId ||
        server.contentId != receipt.contentId ||
        server.importSourceKey != receipt.importSourceKey ||
        server.revision < receipt.serverRevision ||
        server.status == 'rolledBack') {
      throw const _LocalRefusal('server_check_failed');
    }
    await _dryRun();
    final CreateDraftEntity? draft = _drafts[localDraftId];
    final LocalImportTypeAdapter? adapter = draft == null
        ? null
        : _adapters[draft.objectType];
    if (draft == null ||
        adapter == null ||
        await _sourceHash(
              draft,
              adapter,
              _scopeOf(draft, receipt.publisherRef),
            ) !=
            receipt.sourceHash) {
      if (receipt.cleanupToken != null) {
        await _releaseCleanup(receipt, 'local_changed_since_import');
      }
      throw const _LocalRefusal('local_changed_since_import');
    }
    if (receipt.cleanupToken == null) {
      receipt = receipt.copyWith(
        cleanupToken: _newFencingToken(),
        cleanupInstallationId: _installationId,
        clearFailure: true,
        updatedAtUtc: _clock(),
      );
      await _journal.saveReceipt(receipt);
    }
    if (receipt.state != LocalImportItemState.cleanupReserved) {
      try {
        await _gateway.reserveImportCleanup(
          importSourceKey: receipt.importSourceKey,
          generation: receipt.generation,
          draftId: receipt.draftId,
          installationId: receipt.cleanupInstallationId!,
          fencingToken: receipt.cleanupToken!,
          idempotencyKey: _cleanupKey(receipt, 'reserve'),
        );
      } on EventPublicationRejected catch (refusal) {
        // Refused (rolled back, held by another installation, gone): nothing
        // is deleted and the intent is dropped.
        await _journal.saveReceipt(
          receipt.copyWith(
            clearCleanup: true,
            failureCode: refusal.code,
            updatedAtUtc: _clock(),
          ),
        );
        await _dryRun();
        rethrow;
      }
      receipt = receipt.copyWith(
        state: LocalImportItemState.cleanupReserved,
        updatedAtUtc: _clock(),
      );
      await _journal.saveReceipt(receipt);
    }
    final bool deleted = await _originals.deleteIfUnchanged(
      accountId: _accountId,
      localDraftId: localDraftId,
      // The stored draft is still the one hashed above.
      unchanged: (CreateDraftEntity stored) =>
          stored.id == draft.id &&
          stored.updatedAtUtc == draft.updatedAtUtc &&
          stored.objectType == draft.objectType,
    );
    if (!deleted) {
      await _releaseCleanup(receipt, 'local_changed_since_import');
      throw const _LocalRefusal('local_changed_since_import');
    }
    receipt = receipt.copyWith(
      localDeletedAtUtc: _clock(),
      updatedAtUtc: _clock(),
    );
    await _journal.saveReceipt(receipt);
    await _completeCleanup(receipt);
    await _dryRun();
  });

  /// Releases this installation's cleanup intent while the original is here.
  Future<void> cancelCleanup(String localDraftId) => _run(() async {
    final LocalImportReceipt receipt = await _requireReceipt(localDraftId);
    if (receipt.cleanupToken == null || receipt.localDeletedAtUtc != null) {
      throw const _LocalRefusal('cleanup_not_reserved');
    }
    await _releaseCleanup(receipt, null);
    await _dryRun();
  });

  /// Completes, with the journaled token, every cleanup whose original was
  /// deleted before the server recorded it (a lost answer or a restart).
  Future<void> finishCleanups() => _run(() async {
    for (final LocalImportReceipt receipt in await _journal.receipts(
      _accountId,
    )) {
      if (_owesCompletion(receipt)) await _completeCleanup(receipt);
    }
    await _dryRun();
  });

  /// D4.1 rollback of a verified import: the durable `rollbackPending` intent
  /// is written first and sent again unchanged until the server's outcome is
  /// known. Only while the local original is still here, no cleanup is under
  /// way, and at exactly the revision the receipt verified.
  Future<void> rollback(String localDraftId) => _run(() async {
    // The local original must still be here: a rollback never leaves the
    // user without both copies (D4.1 §1 invariant).
    await _dryRun();
    final LocalImportItemView? view = _itemOf(localDraftId);
    if (view == null) throw const _LocalRefusal('original_missing');
    LocalImportReceipt receipt = await _requireReceipt(localDraftId);
    if (receipt.state == LocalImportItemState.rolledBack) {
      throw const _LocalRefusal('import_rolled_back');
    }
    if (receipt.localDeletedAtUtc != null) {
      throw const _LocalRefusal('original_removed');
    }
    if (receipt.cleanupToken != null) {
      throw const _LocalRefusal('cleanup_reserved');
    }
    if (!view.canRollBack) throw const _LocalRefusal('rollback_not_allowed');
    if (receipt.state == LocalImportItemState.verified) {
      final int revision = receipt.serverRevision;
      receipt = receipt.copyWith(
        state: LocalImportItemState.rollbackPending,
        rollbackKey: _lifecycleKey(receipt, 'rollback:$revision'),
        rollbackExpectedRevision: revision,
        clearFailure: true,
        updatedAtUtc: _clock(),
      );
      await _journal.saveReceipt(receipt);
    }
    try {
      final LocalImportServerDraft tombstone = await _gateway
          .rollbackImportedDraft(
            draftId: receipt.draftId,
            importSourceKey: receipt.importSourceKey,
            generation: receipt.generation,
            expectedRevision: receipt.rollbackExpectedRevision!,
            idempotencyKey: receipt.rollbackKey!,
          );
      await _rolledBack(receipt, tombstone.revision);
    } on EventPublicationRejected catch (refusal) {
      // A definitive answer to this intent: the binding says whether this
      // generation is rolled back anyway (another installation, or an earlier
      // attempt). Otherwise nothing changed and the receipt is as before.
      if (await _generationRolledBack(receipt)) {
        await _rolledBack(receipt, null);
      } else {
        await _journal.saveReceipt(
          receipt.copyWith(
            state: LocalImportItemState.verified,
            clearRollback: true,
            failureCode: refusal.code,
            updatedAtUtc: _clock(),
          ),
        );
        await _dryRun();
        rethrow;
      }
    }
    await _dryRun();
  });

  // ------------------------------------------------------------------ dry run

  Future<void> _dryRun() async {
    _drafts.clear();
    final List<LocalImportItemView> items = <LocalImportItemView>[];
    final DateTime now = _clock();
    for (final LocalImportSourceItem item in await _source.inventory(
      _accountId,
    )) {
      final LocalImportCandidate candidate = await _classify(item);
      final LocalImportReceipt? receipt = candidate.publisherRef == null
          ? null
          : await _journal.receiptFor(
              accountId: _accountId,
              publisherRef: candidate.publisherRef!,
              localDraftId: candidate.localDraftId,
            );
      items.add(
        LocalImportItemView(
          candidate: candidate,
          receipt: receipt,
          cleanup: _policy.statusOf(receipt, now),
          failureCode: receipt == null
              ? _createFailures[candidate.localDraftId]
              : receipt.failureCode,
        ),
      );
    }
    int pending = 0;
    for (final LocalImportReceipt receipt in await _journal.receipts(
      _accountId,
    )) {
      if (_owesCompletion(receipt)) pending += 1;
    }
    _state = LocalImportViewState(
      phase: _state.phase,
      items: List<LocalImportItemView>.unmodifiable(items),
      session: await _journal.currentSession(_accountId),
      chosenUpdates: _state.chosenUpdates,
      message: _state.message,
      pendingCleanups: pending,
    );
  }

  Future<LocalImportCandidate> _classify(LocalImportSourceItem item) async {
    LocalImportCandidate refused(
      LocalImportClass classification,
      String reason, {
      String? typeId,
      PublisherRef? publisherRef,
    }) => LocalImportCandidate(
      localDraftId: item.localDraftId,
      typeId: typeId ?? item.localType,
      title: item.title,
      classification: classification,
      publisherRef: publisherRef,
      reason: reason,
    );

    final CreateDraftEntity? draft = item.draft;
    final LocalImportTypeAdapter? adapter = draft == null
        ? null
        : _adapters[draft.objectType];
    if (draft == null || adapter == null) {
      return refused(
        LocalImportClass.unsupported,
        'type_not_importable:${item.localType}',
      );
    }
    if (draft.organizerId != _accountId) {
      return refused(
        LocalImportClass.blocked,
        'owner_mismatch',
        typeId: adapter.typeId,
      );
    }
    final PublisherRef? publisher = adapter.publisherOf(draft);
    if (publisher == null || !publisher.isValid) {
      return refused(
        LocalImportClass.blocked,
        'publisher_missing',
        typeId: adapter.typeId,
      );
    }
    if (!await _publisherAccess.canPublishAs(
      actorUserId: _accountId,
      publisher: publisher,
    )) {
      return refused(
        LocalImportClass.blocked,
        'publisher_not_eligible',
        typeId: adapter.typeId,
        publisherRef: publisher,
      );
    }
    if (importSourceKeyOf(draft.id) == null) {
      return refused(
        LocalImportClass.unsupported,
        'local_id',
        typeId: adapter.typeId,
        publisherRef: publisher,
      );
    }
    final LocalImportScope scope = _scopeOf(draft, publisher);
    final List<String> unsupported = adapter.unsupported(draft, scope);
    if (unsupported.isNotEmpty) {
      return refused(
        LocalImportClass.unsupported,
        'unsupported_capability:${unsupported.join(',')}',
        typeId: adapter.typeId,
        publisherRef: publisher,
      );
    }
    final String sourceHash = await _sourceHash(draft, adapter, scope);
    _drafts[draft.id] = draft;
    LocalImportCandidate of(
      LocalImportClass classification, {
      String? reason,
      String? serverContentId,
    }) => LocalImportCandidate(
      localDraftId: draft.id,
      typeId: adapter.typeId,
      title: item.title,
      classification: classification,
      publisherRef: publisher,
      sourceHash: sourceHash,
      reason: reason,
      serverContentId: serverContentId,
    );

    final LocalImportReceipt? receipt = await _journal.receiptFor(
      accountId: _accountId,
      publisherRef: publisher,
      localDraftId: draft.id,
    );
    if (receipt != null) {
      switch (receipt.state) {
        // D4.1: importing again after a rollback is a new, explicit choice.
        case LocalImportItemState.rolledBack:
          return of(
            LocalImportClass.conflict,
            reason: 'rolled_back',
            serverContentId: receipt.contentId,
          );
        case LocalImportItemState.rollbackPending:
          return of(
            LocalImportClass.alreadyMapped,
            reason: 'rollback_pending',
            serverContentId: receipt.contentId,
          );
        case LocalImportItemState.cleanupReserved:
          return of(
            LocalImportClass.alreadyMapped,
            reason: 'cleanup_reserved',
            serverContentId: receipt.contentId,
          );
        case LocalImportItemState.created:
        case LocalImportItemState.mediaUploaded:
        case LocalImportItemState.bodySaved:
        case LocalImportItemState.verified:
        case LocalImportItemState.failed:
          break;
      }
      if (receipt.cleanupToken != null) {
        return of(
          LocalImportClass.alreadyMapped,
          reason: 'cleanup_pending',
          serverContentId: receipt.contentId,
        );
      }
      if (receipt.state != LocalImportItemState.verified) {
        return of(
          LocalImportClass.create,
          reason: 'resume',
          serverContentId: receipt.contentId,
        );
      }
      return receipt.sourceHash == sourceHash
          ? of(
              LocalImportClass.alreadyMapped,
              serverContentId: receipt.contentId,
            )
          : of(
              LocalImportClass.conflict,
              reason: 'local_changed_since_import',
              serverContentId: receipt.contentId,
            );
    }
    final String? published = await _existing.contentIdFor(
      typeId: adapter.typeId,
      accountId: _accountId,
      publisherRef: publisher,
      localDraftId: draft.id,
    );
    if (published != null) {
      return of(
        LocalImportClass.alreadyMapped,
        reason: 'published_by_test_path',
        serverContentId: published,
      );
    }
    return of(LocalImportClass.create);
  }

  // ------------------------------------------------------------- one item

  Future<void> _importItem(String localDraftId, String approvedHash) async {
    final LocalImportItemView? view = _itemOf(localDraftId);
    final CreateDraftEntity? draft = _drafts[localDraftId];
    final LocalImportCandidate? candidate = view?.candidate;
    final LocalImportSession? session = await _journal.currentSession(
      _accountId,
    );
    // The item must still be what the user approved (§5.2): otherwise skip it.
    final bool importable =
        candidate != null &&
        draft != null &&
        (candidate.classification == LocalImportClass.create ||
            candidate.classification == LocalImportClass.conflict);
    final bool approvedSource =
        importable && session != null && candidate.sourceHash == approvedHash;
    if (!approvedSource) return;
    final LocalImportTypeAdapter adapter = _adapters[draft.objectType]!;
    final PublisherRef publisher = candidate.publisherRef!;
    final LocalImportScope scope = _scopeOf(draft, publisher);
    final String importSourceKey = importSourceKeyOf(draft.id)!;

    LocalImportReceipt? receipt = view!.receipt;
    // A pending rollback or cleanup of this item is never mixed with an import.
    if (receipt != null &&
        (receipt.state == LocalImportItemState.rollbackPending ||
            receipt.state == LocalImportItemState.cleanupReserved ||
            receipt.cleanupToken != null)) {
      return;
    }
    if (receipt == null || receipt.state == LocalImportItemState.rolledBack) {
      // §5.3 step 1: the server returns this author's draft for this source
      // if it already has one, whatever key the earlier attempt used. After a
      // rollback (D4.1) the keys name the next generation.
      final int generation = (receipt?.generation ?? 0) + 1;
      final LocalImportServerDraft created;
      try {
        created = await _gateway.createImportDraft(
          typeId: adapter.typeId,
          publisherRef: publisher,
          marketId: _marketId,
          importSourceKey: importSourceKey,
          idempotencyKey: '${_keyBase(scope, generation)}:create',
        );
      } on EventPublicationRejected catch (refusal) {
        // A definitive refusal: nothing exists on the server for this item.
        _createFailures[localDraftId] = refusal.code;
        return;
      }
      _createFailures.remove(localDraftId);
      final String? owner = created.createdByUserId;
      if (owner == null) {
        throw const EventPublicationRejected('invalid_contract');
      }
      receipt = LocalImportReceipt(
        accountId: _accountId,
        publisherRef: publisher,
        localDraftId: draft.id,
        typeId: adapter.typeId,
        importSourceKey: importSourceKey,
        sourceHash: candidate.sourceHash!,
        contentId: created.contentId,
        draftId: created.draftId,
        serverOwnerUserId: owner,
        serverRevision: created.revision,
        state: LocalImportItemState.created,
        updatedAtUtc: _clock(),
        title: candidate.title,
        // The server decides the generation (another installation may have
        // opened it already).
        generation: created.importGeneration ?? 1,
      );
      await _journal.saveReceipt(receipt);
    }
    LocalImportReceipt current = receipt;
    Future<void> failed(String code) async {
      // On top of the latest durable step (media saved after every upload).
      final LocalImportReceipt latest =
          await _journal.receiptFor(
            accountId: _accountId,
            publisherRef: publisher,
            localDraftId: draft.id,
          ) ??
          current;
      await _journal.saveReceipt(
        latest.copyWith(
          // D4.1: the server says this generation is a tombstone; a new
          // import of it is a new, explicit choice.
          state: code == 'import_rolled_back'
              ? LocalImportItemState.rolledBack
              : LocalImportItemState.failed,
          failureCode: code,
          updatedAtUtc: _clock(),
        ),
      );
    }

    try {
      current = await _uploadMedia(draft, adapter, scope, current);
      current = await _saveBody(
        draft,
        adapter,
        scope,
        current,
        candidate.sourceHash!,
      );
      current = await _verify(current);
    } on EventPublicationRejected catch (refusal) {
      await failed(refusal.code);
    } on _LocalRefusal catch (refusal) {
      await failed(refusal.code);
    }
  }

  Future<LocalImportReceipt> _uploadMedia(
    CreateDraftEntity draft,
    LocalImportTypeAdapter adapter,
    LocalImportScope scope,
    LocalImportReceipt start,
  ) async {
    LocalImportReceipt receipt = start;
    final List<LocalImportAttachmentRecord> uploaded =
        <LocalImportAttachmentRecord>[];
    for (final LocalImportAttachment item in adapter.attachments(
      draft,
      scope,
    )) {
      final Uint8List? bytes = await _mediaSource.read(item.localRef);
      if (bytes == null) throw const _LocalRefusal('media_missing');
      final String digest = sha256.convert(bytes).toString();
      final LocalImportAttachmentRecord? known = receipt.attachment(
        item.attachmentId,
      );
      if (known != null && known.sha256 == digest) {
        uploaded.add(known);
        continue;
      }
      int attempt = receipt.uploadAttempts[item.attachmentId] ?? 0;
      String assetId;
      for (int tries = 1; ; tries += 1) {
        try {
          assetId = await _uploader.upload(
            intentId: _uploadIntentId(
              scope,
              receipt.generation,
              item.attachmentId,
              digest,
              attempt,
            ),
            bytes: bytes,
            declaredMediaType: declaredPublicationMediaType(item.localRef),
            publisherRef: scope.publisherRef,
            contentId: receipt.contentId,
          );
          break;
        } on EventPublicationRejected catch (refusal) {
          // The attempt's upload session expired before the server accepted
          // the bytes (an accepted one is reused by the gateway): its intent
          // can never be finished. The next attempt is saved before it is
          // used, so a restart never goes back to the dead one.
          if (refusal.code != 'session_expired') rethrow;
          attempt += 1;
          receipt = receipt.copyWith(
            uploadAttempts: <String, int>{
              ...receipt.uploadAttempts,
              item.attachmentId: attempt,
            },
            updatedAtUtc: _clock(),
          );
          await _journal.saveReceipt(receipt);
          if (tries >= uploadAttemptsPerRun) rethrow;
        }
      }
      uploaded.add(
        LocalImportAttachmentRecord(
          attachmentId: item.attachmentId,
          assetId: assetId,
          sha256: digest,
        ),
      );
      // Saved after every upload, so an interruption keeps what is done.
      receipt = receipt.copyWith(
        attachments: <LocalImportAttachmentRecord>[
          ...receipt.attachments.where(
            (old) => old.attachmentId != item.attachmentId,
          ),
          uploaded.last,
        ],
        updatedAtUtc: _clock(),
      );
      await _journal.saveReceipt(receipt);
    }
    receipt = receipt.copyWith(
      attachments: uploaded,
      state: LocalImportItemState.mediaUploaded,
      updatedAtUtc: _clock(),
    );
    await _journal.saveReceipt(receipt);
    return receipt;
  }

  /// §5.3 step 3: the full body, at exactly the revision the receipt holds
  /// (the Collection review belongs to the revision the save produces). A lost
  /// answer is repeated under the same key. A revision the server moved past
  /// is someone else's edit: it is kept, and the item fails with
  /// `revision_conflict` instead of being written over (D4.1 §3.3).
  Future<LocalImportReceipt> _saveBody(
    CreateDraftEntity draft,
    LocalImportTypeAdapter adapter,
    LocalImportScope scope,
    LocalImportReceipt receipt,
    String sourceHash,
  ) async {
    final Map<String, String> assets = <String, String>{
      for (final LocalImportAttachmentRecord item in receipt.attachments)
        item.attachmentId: item.assetId,
    };
    Map<String, Object?> bodyFor(int revision) => adapter.body(
      draft,
      scope: scope,
      serverOwnerUserId: receipt.serverOwnerUserId,
      reviewedRevision: revision + 1,
      assetIds: assets,
    );
    Future<(LocalImportServerDraft, String)> update(int revision) async {
      final Map<String, Object?> body = bodyFor(revision);
      final String bodyHash = localImportHash(body);
      final LocalImportServerDraft saved = await _gateway.updateDraft(
        draftId: receipt.draftId,
        expectedRevision: revision,
        body: body,
        idempotencyKey:
            '${_keyBase(scope, receipt.generation)}:update:$revision:'
            '${bodyHash.substring(0, 16)}',
      );
      return (saved, bodyHash);
    }

    final (LocalImportServerDraft, String) result = await update(
      receipt.serverRevision,
    );
    final LocalImportReceipt saved = receipt.copyWith(
      serverRevision: result.$1.revision,
      sentBodyHash: result.$2,
      sourceHash: sourceHash,
      state: LocalImportItemState.bodySaved,
      updatedAtUtc: _clock(),
      clearFailure: true,
    );
    await _journal.saveReceipt(saved);
    return saved;
  }

  /// §5.3 step 4: the server's own copy is read back and compared.
  Future<LocalImportReceipt> _verify(LocalImportReceipt receipt) async {
    final LocalImportServerDraft server = await _gateway.draft(receipt.draftId);
    final Map<String, Object?>? body = server.body;
    final bool same =
        server.contentId == receipt.contentId &&
        server.createdByUserId == receipt.serverOwnerUserId &&
        server.importSourceKey == receipt.importSourceKey &&
        (server.importGeneration ?? 1) == receipt.generation &&
        server.status != 'rolledBack' &&
        // A replayed save may answer with the revision it stored first; the
        // server copy is what counts: exactly the body that was sent.
        server.revision >= receipt.serverRevision &&
        body != null &&
        localImportHash(body) == receipt.sentBodyHash;
    if (!same) throw const _LocalRefusal('verification_mismatch');
    final LocalImportReceipt verified = receipt.copyWith(
      serverRevision: server.revision,
      state: LocalImportItemState.verified,
      verifiedAtUtc: _clock(),
      // A new import of a changed draft needs a new confirmation.
      clearConfirmed: true,
      updatedAtUtc: _clock(),
    );
    await _journal.saveReceipt(verified);
    return verified;
  }

  // --------------------------------------------------------------- helpers

  LocalImportScope _scopeOf(CreateDraftEntity draft, PublisherRef publisher) =>
      LocalImportScope(
        accountId: _accountId,
        publisherRef: publisher,
        localDraftId: draft.id,
      );

  /// D4.1 §3.2: generation 1 keeps the D4 keys; a later one names itself.
  static String _keyBase(LocalImportScope scope, int generation) =>
      generation <= 1 ? scope.keyBase : '${scope.keyBase}:g$generation';

  static String _uploadIntentId(
    LocalImportScope scope,
    int generation,
    String attachmentId,
    String digest,
    int attempt,
  ) => generation <= 1
      ? scope.uploadIntentId(attachmentId, digest, attempt: attempt)
      : scope.id(
          'g$generation:upload:$attachmentId:$digest'
          '${attempt == 0 ? '' : ':$attempt'}',
        );

  /// Keys of the rollback and cleanup commands always name the generation.
  String _lifecycleKey(LocalImportReceipt receipt, String step) {
    final LocalImportScope scope = LocalImportScope(
      accountId: _accountId,
      publisherRef: receipt.publisherRef,
      localDraftId: receipt.localDraftId,
    );
    return '${scope.keyBase}:g${receipt.generation}:$step';
  }

  String _cleanupKey(LocalImportReceipt receipt, String step) =>
      _lifecycleKey(receipt, 'cleanup:${receipt.cleanupToken}:$step');

  static bool _owesCompletion(LocalImportReceipt receipt) =>
      receipt.localDeletedAtUtc != null &&
      receipt.cleanupToken != null &&
      receipt.cleanupCompletedAtUtc == null;

  Future<void> _completeCleanup(LocalImportReceipt receipt) async {
    // A lost answer is repeated with the same token under the same key.
    await _gateway.completeImportCleanup(
      importSourceKey: receipt.importSourceKey,
      generation: receipt.generation,
      fencingToken: receipt.cleanupToken!,
      idempotencyKey: _cleanupKey(receipt, 'complete'),
    );
    await _journal.saveReceipt(
      receipt.copyWith(cleanupCompletedAtUtc: _clock(), updatedAtUtc: _clock()),
    );
  }

  /// Gives the reservation back while the original is still here; a server
  /// that holds nothing for this token leaves only the local intent to drop.
  Future<void> _releaseCleanup(LocalImportReceipt receipt, String? code) async {
    try {
      await _gateway.releaseImportCleanup(
        importSourceKey: receipt.importSourceKey,
        generation: receipt.generation,
        fencingToken: receipt.cleanupToken!,
        idempotencyKey: _cleanupKey(receipt, 'release'),
      );
    } on EventPublicationRejected catch (refusal) {
      if (refusal.code != 'cleanup_not_reserved') rethrow;
    }
    await _journal.saveReceipt(
      receipt.copyWith(
        state: LocalImportItemState.verified,
        clearCleanup: true,
        failureCode: code,
        clearFailure: code == null,
        updatedAtUtc: _clock(),
      ),
    );
    await _dryRun();
  }

  Future<void> _rolledBack(LocalImportReceipt receipt, int? revision) =>
      _journal.saveReceipt(
        receipt.copyWith(
          state: LocalImportItemState.rolledBack,
          serverRevision: revision,
          rolledBackAtUtc: _clock(),
          clearRollback: true,
          clearFailure: true,
          updatedAtUtc: _clock(),
        ),
      );

  /// Whether the server's binding shows this receipt's generation rolled back.
  Future<bool> _generationRolledBack(LocalImportReceipt receipt) async {
    final LocalImportBindingView binding;
    try {
      binding = await _gateway.importBinding(receipt.importSourceKey);
    } on EventPublicationRejected {
      return false;
    }
    // A later generation exists only after this one was rolled back.
    return binding.generation > receipt.generation ||
        (binding.generation == receipt.generation &&
            binding.rolledBack &&
            binding.draftId == receipt.draftId);
  }

  /// The canonical local source: the mapped body as the dry run sees it (no
  /// server author, no server media) and the SHA-256 of every medium's bytes.
  Future<String> _sourceHash(
    CreateDraftEntity draft,
    LocalImportTypeAdapter adapter,
    LocalImportScope scope,
  ) async {
    final Map<String, Object?> media = <String, Object?>{};
    for (final LocalImportAttachment item in adapter.attachments(
      draft,
      scope,
    )) {
      final Uint8List? bytes = await _mediaSource.read(item.localRef);
      media[item.attachmentId] = bytes == null
          ? 'missing'
          : sha256.convert(bytes).toString();
    }
    return localImportHash(<String, Object?>{
      'schema': 'recharge-local-import-source-v1',
      'typeId': adapter.typeId,
      'localDraftId': draft.id,
      'publisherRef': <String, Object?>{
        'type': scope.publisherRef.type.wireName,
        'id': scope.publisherRef.id,
      },
      'body': adapter.body(
        draft,
        scope: scope,
        serverOwnerUserId: '',
        reviewedRevision: 0,
        assetIds: const <String, String>{},
      ),
      'media': media,
    });
  }

  LocalImportItemView? _itemOf(String localDraftId) {
    for (final LocalImportItemView item in _state.items) {
      if (item.candidate.localDraftId == localDraftId) return item;
    }
    return null;
  }

  Future<LocalImportReceipt> _requireReceipt(String localDraftId) async {
    final LocalImportItemView? view = _itemOf(localDraftId);
    final LocalImportReceipt? receipt = view?.receipt;
    if (receipt == null) throw const _LocalRefusal('not_imported');
    return receipt;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_state.phase == LocalImportPhase.working) return;
    if (!_gate.allowed) {
      _emit(phase: _state.phase, message: 'not_allowed');
      return;
    }
    _emit(phase: LocalImportPhase.working, message: null);
    try {
      await action();
      _emit(phase: LocalImportPhase.ready, message: null);
    } on EventPublicationRejected catch (refusal) {
      _emit(phase: LocalImportPhase.ready, message: refusal.code);
    } on _LocalRefusal catch (refusal) {
      _emit(phase: LocalImportPhase.ready, message: refusal.code);
    } on EventPublicationUnavailable catch (failure) {
      // An unknown outcome: the view shows the journal as it now stands.
      await _refresh();
      _emit(phase: LocalImportPhase.offline, message: failure.code);
    } on StateError {
      // The gate closed between the check and the call: nothing was sent.
      _emit(phase: LocalImportPhase.ready, message: 'not_allowed');
    }
  }

  Future<void> _refresh() async {
    try {
      await _dryRun();
    } on Exception {
      // The previous view stays; the journal is what the next action reads.
    }
  }

  void _emit({required LocalImportPhase phase, String? message}) {
    _state = LocalImportViewState(
      phase: phase,
      items: _state.items,
      session: _state.session,
      chosenUpdates: _state.chosenUpdates,
      message: message,
      pendingCleanups: _state.pendingCleanups,
    );
    notifyListeners();
  }
}

/// 128 random bits, URL-safe and unpadded.
String _randomToken() {
  final Random random = Random.secure();
  return base64Url
      .encode(List<int>.generate(16, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

extension on LocalImportViewState {
  bool get canApproveIgnoringPhase =>
      !(session?.open ?? false) &&
      items.any(
        (LocalImportItemView item) =>
            item.candidate.classification == LocalImportClass.create ||
            (item.candidate.classification == LocalImportClass.conflict &&
                chosenUpdates.contains(item.candidate.localDraftId)),
      );
}

/// A precondition the client checks before sending anything.
final class _LocalRefusal implements Exception {
  const _LocalRefusal(this.code);

  final String code;
}
