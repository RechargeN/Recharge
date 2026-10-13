import 'publication_media_type.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/place_creation_policy.dart';
import '../domain/entities/place_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/place_publication_gateway.dart';
import '../domain/usecases/build_place_content_body.dart';
import 'place_create_config.dart';

enum PlacePublicationPhase { loading, ready, working, noDraft, offline }

/// One entry of "my places": a journaled id and its status as the server
/// reports it now (null with [failureCode] when it could not be read).
final class PlacePublicationObjectView {
  const PlacePublicationObjectView({
    required this.record,
    this.status,
    this.failureCode,
  });

  final PlacePublicationRecord record;
  final EventPublicationStatus? status;
  final String? failureCode;
}

final class PlacePublicationViewState {
  const PlacePublicationViewState({
    required this.phase,
    this.draftTitle,
    this.record,
    this.status,
    this.message,
    this.myObjects = const <PlacePublicationObjectView>[],
    this.conflict,
  });

  final PlacePublicationPhase phase;

  /// Title of the user's Create Place draft, as Create stored it.
  final String? draftTitle;

  /// Server ids of this draft (null until the first save).
  final PlacePublicationRecord? record;
  final EventPublicationStatus? status;

  /// Last refusal or failure code (server code, or a local one).
  final String? message;
  final List<PlacePublicationObjectView> myObjects;

  /// A newer server revision that is not this install's own write (M1 D2);
  /// the local edit waits for the user's explicit choice.
  final DraftConflict? conflict;

  bool get _idle => phase == PlacePublicationPhase.ready;
  bool get canSaveOverServerVersion => _idle && conflict != null;
  bool get canSave => _idle && draftTitle != null;
  bool get canUploadMedia => _idle && record != null;
  bool get canSubmit => _idle && (record?.authorApplied ?? false);
  bool get canPublish => _idle && (status?.approvedForPublication ?? false);
  bool get canHide => _idle && status?.visibility == 'visible';
}

/// Test-path coordinator of one Place publication (D3.1 §5): the user's own
/// Create Place draft -> Content draft (empty, then the full body with the
/// server's author) -> Media cover and gallery -> submit -> (staff review) ->
/// status -> publish or hide, plus "my places". It owns no authority and no
/// business rule: Content, Media and moderation decide on the server, and every
/// call is gated by the default-off Place test entry. Activate and edits after
/// publication are not offered here (§5.1, Q4).
final class PlacePublicationController extends ChangeNotifier {
  PlacePublicationController({
    required String accountId,
    required PlaceDraftSource drafts,
    required EventPublicationGateway gateway,
    required ContentDraftReader reader,
    required EventCoverUploader uploader,
    required EventCoverSource mediaSource,
    required PlacePublicationJournal journal,
    required PlacePublicationCommandGate gate,
    PlaceCreationPolicy Function(String subcategoryId) policyFor =
        placeCreationPolicyFor,
    PlaceContentBodyMapper mapper = const PlaceContentBodyMapper(),
    String marketId = 'LV',
    DateTime Function()? clock,
  }) : _accountId = accountId,
       _drafts = drafts,
       _gateway = gateway,
       _reader = reader,
       _uploader = uploader,
       _mediaSource = mediaSource,
       _journal = journal,
       _gate = gate,
       _policyFor = policyFor,
       _mapper = mapper,
       _marketId = marketId,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const int maxListed = 20;

  final String _accountId;
  final PlaceDraftSource _drafts;
  final EventPublicationGateway _gateway;
  final ContentDraftReader _reader;
  final EventCoverUploader _uploader;
  final EventCoverSource _mediaSource;
  final PlacePublicationJournal _journal;
  final PlacePublicationCommandGate _gate;
  final PlaceCreationPolicy Function(String subcategoryId) _policyFor;
  final PlaceContentBodyMapper _mapper;
  final String _marketId;
  final DateTime Function() _clock;

  /// Records whose server author was checked in this session.
  final Set<String> _verifiedDrafts = <String>{};

  DraftConflict? _conflict;
  CreateDraftEntity? _draft;
  PlacePublicationViewState _state = const PlacePublicationViewState(
    phase: PlacePublicationPhase.loading,
  );

  PlacePublicationViewState get state => _state;

  Future<void> load() async {
    if (!_gate.allowed) {
      _emit(phase: PlacePublicationPhase.noDraft, message: 'not_allowed');
      return;
    }
    _emit(phase: PlacePublicationPhase.loading);
    final CreateDraftEntity? draft = await _drafts.current();
    _draft =
        draft?.objectType == CreateObjectType.place && draft?.placeData != null
        ? draft
        : null;
    await _run(
      _refreshAll,
      idle: _draft == null ? PlacePublicationPhase.noDraft : null,
    );
  }

  /// Creates the Content draft if needed (empty body, §5.4) and saves the full
  /// body with the server's author and the uploaded media.
  Future<void> save() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final PlacePublicationScope scope = _scope(draft);
    // Nothing is sent, not even the empty draft, for a draft that cannot map.
    _assertSupported(draft, scope);
    final PlacePublicationRecord record =
        await _usableRecord(scope) ?? await _create(draft, scope);
    await _saveBody(draft, scope, record);
    await _refreshAll();
  });

  /// Uploads the cover and every gallery photo that changed, then binds them.
  Future<void> uploadMedia() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final PlacePublicationScope scope = _scope(draft);
    PlacePublicationRecord record = await _requireRecord(scope);
    final List<PlaceAttachmentRecord> uploaded = <PlaceAttachmentRecord>[];
    for (final PlaceMediaAttachment item in _attachments(draft, scope)) {
      final Uint8List? bytes = await _mediaSource.read(item.localRef);
      if (bytes == null) throw const _LocalRefusal('media_missing');
      final String digest = sha256.convert(bytes).toString();
      final PlaceAttachmentRecord? known = record.attachment(item.attachmentId);
      if (known != null && known.sha256 == digest) {
        uploaded.add(known);
        continue;
      }
      final String assetId = await _uploader.upload(
        // The same bytes of the same photo always replay the same upload.
        intentId: scope.uploadIntentId(item.attachmentId, digest),
        bytes: bytes,
        declaredMediaType: declaredPublicationMediaType(item.localRef),
        publisherRef: scope.publisherRef,
        contentId: record.contentId,
      );
      uploaded.add(
        PlaceAttachmentRecord(
          attachmentId: item.attachmentId,
          assetId: assetId,
          sha256: digest,
        ),
      );
      // Saved after every upload, so an interruption keeps what is done.
      record = record.copyWith(
        attachments: <PlaceAttachmentRecord>[
          ...record.attachments.where(
            (old) => old.attachmentId != item.attachmentId,
          ),
          uploaded.last,
        ],
      );
      await _journal.save(record);
    }
    // Only the draft's current photos stay, in its order.
    record = record.copyWith(attachments: uploaded);
    await _journal.save(record);
    await _saveBody(draft, scope, record);
    await _refreshAll();
  });

  Future<void> submit() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final PlacePublicationScope scope = _scope(draft);
    final PlacePublicationRecord record = await _requireRecord(scope);
    if (!record.authorApplied) throw const _LocalRefusal('save_required');
    final String submissionId = await _gateway.submit(
      draftId: record.draftId,
      expectedDraftRevision: record.draftRevision,
      idempotencyKey: '${scope.keyBase}:submit:${record.draftRevision}',
    );
    await _journal.save(record.copyWith(submissionId: submissionId));
    await _refreshAll();
  });

  Future<void> refresh() => _run(_refreshAll);

  /// M1 D2: the user's explicit choice to save the local version on top of the
  /// newer server revision a conflict reported. Nothing else saves over it.
  Future<void> saveOverServerVersion() => _run(() async {
    final DraftConflict? conflict = _conflict;
    if (conflict == null) throw const _LocalRefusal('no_conflict');
    final CreateDraftEntity draft = _requireDraft();
    final PlacePublicationScope scope = _scope(draft);
    final PlacePublicationRecord record = await _requireRecord(scope);
    await _saveBody(
      draft,
      scope,
      record,
      overServerRevision: conflict.serverRevision,
    );
    await _refreshAll();
  });

  /// Publishes the revision staff approved (the owner's own command).
  Future<void> publish() => _run(() async {
    final PlacePublicationRecord record = await _requireRecord(
      _scope(_requireDraft()),
    );
    final EventPublicationStatus status = await _gateway.status(
      record.contentId,
    );
    final String? submissionId =
        status.latestSubmissionId ?? record.submissionId;
    if (submissionId == null) throw const _LocalRefusal('submission_required');
    // M1 D1: the first attempt is journaled before the call; a retry after an
    // unknown outcome sends that same payload, never a fresh pointer revision.
    PublishIntent? intent = record.publishIntent;
    if (intent == null || intent.submissionId != submissionId) {
      intent = PublishIntent(
        submissionId: submissionId,
        expectedPointerRevision: status.pointerRevision ?? 0,
      );
      await _journal.save(record.copyWith(publishIntent: intent));
    }
    await _gateway.publishApproved(
      submissionId: intent.submissionId,
      expectedPointerRevision: intent.expectedPointerRevision,
      idempotencyKey: intent.idempotencyKey,
    );
    await _refreshAll();
  });

  /// The owner's own hide of the published Place (`withdrawPublication`).
  Future<void> hide() => _run(() async {
    final PlacePublicationRecord record = await _requireRecord(
      _scope(_requireDraft()),
    );
    final EventPublicationStatus status = await _gateway.status(
      record.contentId,
    );
    final int pointerRevision = status.pointerRevision ?? 0;
    await _gateway.withdraw(
      contentId: record.contentId,
      expectedPointerRevision: pointerRevision,
      idempotencyKey: '${record.contentId}:withdraw:$pointerRevision',
    );
    await _refreshAll();
  });

  /// §5.4 steps 1–2: an empty draft under a stable key (a replay returns the
  /// same draft), recorded with the author the server stored.
  Future<PlacePublicationRecord> _create(
    CreateDraftEntity draft,
    PlacePublicationScope scope,
  ) async {
    final EventServerDraftRef created = await _gateway.createDraft(
      publisherRef: scope.publisherRef,
      marketId: _marketId,
      body: const <String, Object?>{},
      idempotencyKey: '${scope.keyBase}:create',
    );
    final String? owner = created.createdByUserId;
    if (owner == null) throw const EventPublicationRejected('invalid_contract');
    final PlacePublicationRecord record = PlacePublicationRecord(
      accountId: _accountId,
      publisherRef: scope.publisherRef,
      localDraftId: draft.id,
      contentId: created.contentId,
      draftId: created.draftId,
      draftRevision: created.revision,
      serverOwnerUserId: owner,
      title: draft.title,
      createdAtUtc: _clock(),
    );
    await _journal.save(record);
    _verifiedDrafts.add(record.draftId);
    return record;
  }

  /// §5.4 step 3: the full body with the server's author.
  ///
  /// M1 D2: every write is journaled with its exact payload before the call.
  /// A write whose answer never came is replayed first, unchanged: the server
  /// answers a write it applied from its stored result, so that newer revision
  /// is this install's own. A revision the server holds for any other reason
  /// is someone else's edit: the save stops with `revision_conflict` and the
  /// local edit waits for [saveOverServerVersion]; nothing overwrites it here.
  Future<void> _saveBody(
    CreateDraftEntity draft,
    PlacePublicationScope scope,
    PlacePublicationRecord record, {
    int? overServerRevision,
  }) async {
    final PlaceContentBody mapped = _mapper.map(
      draft,
      scope: scope,
      policy: _policyFor(draft.subcategory),
      serverOwnerUserId: record.serverOwnerUserId,
      assetIds: await _currentAssets(draft, scope, record),
    );
    _refuseUnsupported(mapped);
    final String bodyDigest = sha256
        .convert(utf8.encode(jsonEncode(mapped.body)))
        .toString()
        .substring(0, 16);
    PlacePublicationRecord current = record;
    final PendingDraftUpdate? pending = current.pendingUpdate;
    if (pending != null) {
      final EventServerDraftRef replayed;
      try {
        replayed = await _gateway.updateDraft(
          draftId: current.draftId,
          expectedRevision: pending.baseRevision,
          body: pending.body,
          idempotencyKey: pending.idempotencyKey,
        );
      } on EventPublicationRejected catch (refusal) {
        // A refused write was never applied: it is no longer pending.
        current = current.copyWith(clearPendingUpdate: true);
        await _journal.save(current);
        if (refusal.code == 'revision_conflict') await _conflictOn(current);
        rethrow;
      }
      current = current.copyWith(
        draftRevision: replayed.revision,
        clearPendingUpdate: true,
      );
      await _journal.save(current);
      if (overServerRevision == null && pending.bodyDigest == bodyDigest) {
        await _journal.save(
          current.copyWith(authorApplied: true, title: draft.title),
        );
        _conflict = null;
        return;
      }
    }
    final int base = overServerRevision ?? current.draftRevision;
    final String key = '${scope.keyBase}:update:$base:$bodyDigest';
    final PlacePublicationRecord sending = current.copyWith(
      pendingUpdate: PendingDraftUpdate(
        baseRevision: base,
        idempotencyKey: key,
        bodyDigest: bodyDigest,
        body: mapped.body,
      ),
    );
    await _journal.save(sending);
    final EventServerDraftRef updated;
    try {
      updated = await _gateway.updateDraft(
        draftId: current.draftId,
        expectedRevision: base,
        body: mapped.body,
        idempotencyKey: key,
      );
    } on EventPublicationRejected catch (refusal) {
      final PlacePublicationRecord refused = sending.copyWith(
        clearPendingUpdate: true,
      );
      await _journal.save(refused);
      if (refusal.code == 'revision_conflict') await _conflictOn(refused);
      rethrow;
    }
    // A lost answer (EventPublicationUnavailable) leaves the write pending.
    await _journal.save(
      sending.copyWith(
        draftRevision: updated.revision,
        authorApplied: true,
        title: draft.title,
        clearPendingUpdate: true,
      ),
    );
    _conflict = null;
  }

  /// Reads the server revision that won, so the user sees what they would
  /// save over; a draft of another author is never touched.
  Future<void> _conflictOn(PlacePublicationRecord record) async {
    final EventServerDraftRef server = await _reader.draft(record.draftId);
    if (server.createdByUserId != record.serverOwnerUserId) {
      throw const _LocalRefusal('foreign_record');
    }
    _conflict = DraftConflict(serverRevision: server.revision);
  }

  void _assertSupported(CreateDraftEntity draft, PlacePublicationScope scope) =>
      _refuseUnsupported(
        _mapper.map(
          draft,
          scope: scope,
          policy: _policyFor(draft.subcategory),
          // Only the unsupported list is read here; no body is sent.
          serverOwnerUserId: '',
        ),
      );

  static void _refuseUnsupported(PlaceContentBody mapped) {
    if (mapped.unsupported.isNotEmpty) {
      throw _LocalRefusal(
        'unsupported_capability:${mapped.unsupported.join(',')}',
      );
    }
  }

  /// Uploaded assets whose photo still has the same bytes in the draft.
  Future<Map<String, String>> _currentAssets(
    CreateDraftEntity draft,
    PlacePublicationScope scope,
    PlacePublicationRecord record,
  ) async {
    final Map<String, String> assets = <String, String>{};
    for (final PlaceMediaAttachment item in _attachments(draft, scope)) {
      final PlaceAttachmentRecord? known = record.attachment(item.attachmentId);
      if (known == null) continue;
      final Uint8List? bytes = await _mediaSource.read(item.localRef);
      if (bytes != null && sha256.convert(bytes).toString() == known.sha256) {
        assets[item.attachmentId] = known.assetId;
      }
    }
    return assets;
  }

  List<PlaceMediaAttachment> _attachments(
    CreateDraftEntity draft,
    PlacePublicationScope scope,
  ) => _mapper.attachmentsOf(draft, scope);

  /// §5.6: the journal record of this account, publisher and draft, used only
  /// while the server confirms it is this owner's draft. A foreign or
  /// unreadable record is ignored, never deleted.
  Future<PlacePublicationRecord?> _usableRecord(
    PlacePublicationScope scope,
  ) async {
    final PlacePublicationRecord? record = await _journal.forLocalDraft(
      accountId: _accountId,
      publisherRef: scope.publisherRef,
      localDraftId: scope.localDraftId,
    );
    if (record == null) return null;
    if (_verifiedDrafts.contains(record.draftId)) return record;
    try {
      final EventServerDraftRef server = await _reader.draft(record.draftId);
      if (server.createdByUserId != record.serverOwnerUserId ||
          server.contentId != record.contentId) {
        return null;
      }
    } on EventPublicationRejected {
      return null;
    }
    _verifiedDrafts.add(record.draftId);
    return record;
  }

  Future<PlacePublicationRecord> _requireRecord(
    PlacePublicationScope scope,
  ) async {
    final PlacePublicationRecord? record = await _usableRecord(scope);
    if (record == null) throw const _LocalRefusal('save_required');
    return record;
  }

  Future<void> _refreshAll() async {
    final CreateDraftEntity? draft = _draft;
    final PlacePublicationRecord? record = draft == null
        ? null
        : await _usableRecord(_scope(draft));
    final EventPublicationStatus? status = record == null
        ? null
        : await _gateway.status(record.contentId);
    // M1 D2: a refresh fetches the revision the user would save over now.
    if (_conflict != null && record != null) await _conflictOn(record);
    final List<PlacePublicationObjectView> objects =
        <PlacePublicationObjectView>[];
    for (final PlacePublicationRecord item in (await _journal.list(
      _accountId,
    )).take(maxListed)) {
      try {
        objects.add(
          PlacePublicationObjectView(
            record: item,
            status: await _gateway.status(item.contentId),
          ),
        );
      } on EventPublicationRejected catch (refusal) {
        objects.add(
          PlacePublicationObjectView(record: item, failureCode: refusal.code),
        );
      }
    }
    _state = PlacePublicationViewState(
      phase: _state.phase,
      draftTitle: draft?.title,
      record: record,
      status: status,
      message: _state.message,
      myObjects: List<PlacePublicationObjectView>.unmodifiable(objects),
      conflict: _conflict,
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    PlacePublicationPhase? idle,
  }) async {
    if (_state.phase == PlacePublicationPhase.working) return;
    if (!_gate.allowed) {
      _emit(phase: _state.phase, message: 'not_allowed');
      return;
    }
    final PlacePublicationPhase done = idle ?? PlacePublicationPhase.ready;
    _emit(phase: PlacePublicationPhase.working, message: null);
    try {
      await action();
      _emit(phase: done, message: null);
    } on EventPublicationRejected catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on _LocalRefusal catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on EventPublicationUnavailable catch (failure) {
      _emit(phase: PlacePublicationPhase.offline, message: failure.code);
    } on StateError {
      // The gate closed between the check and the call: nothing was sent.
      _emit(phase: done, message: 'not_allowed');
    }
  }

  void _emit({required PlacePublicationPhase phase, String? message}) {
    _state = PlacePublicationViewState(
      phase: phase,
      draftTitle: _state.draftTitle ?? _draft?.title,
      record: _state.record,
      status: _state.status,
      message: message,
      myObjects: _state.myObjects,
      conflict: _conflict,
    );
    notifyListeners();
  }

  CreateDraftEntity _requireDraft() {
    final CreateDraftEntity? draft = _draft;
    if (draft == null) throw const _LocalRefusal('place_draft_required');
    return draft;
  }

  PlacePublicationScope _scope(CreateDraftEntity draft) {
    final PublisherRef? ref = draft.placeData?.publisherRef;
    if (ref == null || !ref.isValid) {
      throw const _LocalRefusal('publisher_required');
    }
    return PlacePublicationScope(
      accountId: _accountId,
      publisherRef: ref,
      localDraftId: draft.id,
    );
  }
}

/// A precondition the client checks before sending anything.
final class _LocalRefusal implements Exception {
  const _LocalRefusal(this.code);

  final String code;
}
