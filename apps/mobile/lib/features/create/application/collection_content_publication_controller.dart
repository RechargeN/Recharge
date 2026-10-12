import 'publication_media_type.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/collection_content_publication.dart';
import '../domain/entities/collection_item_draft.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/collection_content_publication_gateway.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/place_publication_gateway.dart'
    show ContentDraftReader;
import '../domain/usecases/build_collection_content_body.dart';

enum CollectionPublicationPhase { loading, ready, working, noDraft, offline }

/// One entry of "my collections": a journaled id and its status as the server
/// reports it now (null with [failureCode] when it could not be read).
final class CollectionPublicationObjectView {
  const CollectionPublicationObjectView({
    required this.record,
    this.status,
    this.failureCode,
  });

  final CollectionPublicationRecord record;
  final EventPublicationStatus? status;
  final String? failureCode;
}

final class CollectionPublicationViewState {
  const CollectionPublicationViewState({
    required this.phase,
    this.draftTitle,
    this.record,
    this.status,
    this.message,
    this.members = const <CollectionMemberStatus>[],
    this.myObjects = const <CollectionPublicationObjectView>[],
  });

  final CollectionPublicationPhase phase;

  /// Title of the user's Create Collection draft, as Create stored it.
  final String? draftTitle;

  /// Server ids of this draft (null until the first save).
  final CollectionPublicationRecord? record;
  final EventPublicationStatus? status;

  /// Last refusal or failure code (server code, or a local one).
  final String? message;

  /// The server's exact-id answer for every item of the draft, in its order.
  final List<CollectionMemberStatus> members;
  final List<CollectionPublicationObjectView> myObjects;

  bool get _idle => phase == CollectionPublicationPhase.ready;
  bool get canSave => _idle && draftTitle != null;
  bool get canUploadMedia => _idle && record != null;
  bool get canSubmit => _idle && (record?.bodySaved ?? false);
  bool get canPublish => _idle && (status?.approvedForPublication ?? false);
  bool get canHide => _idle && status?.visibility == 'visible';
}

/// Test-path coordinator of one Collection publication (D3.4 §5): the user's
/// own Create Collection draft -> Content draft (empty, then the full body) ->
/// Media cover and gallery -> submit -> (staff review) -> status -> publish or
/// hide, plus "my collections" and the server's status of every item. It owns
/// no authority and no business rule: Content (with Catalog-owned membership),
/// Media and moderation decide on the server, and every call is gated by the
/// default-off Collection test entry. Activate and edits after publication are
/// confirmed on the backend only (§3, as Q4 in D3.1).
final class CollectionContentPublicationController extends ChangeNotifier {
  CollectionContentPublicationController({
    required String accountId,
    required CollectionDraftSource drafts,
    required EventPublicationGateway gateway,
    required ContentDraftReader reader,
    required EventCoverUploader uploader,
    required EventCoverSource mediaSource,
    required CollectionPublicationJournal journal,
    required CollectionMembershipReader membership,
    required CollectionPublicationCommandGate gate,
    CollectionContentBodyMapper mapper = const CollectionContentBodyMapper(),
    String marketId = 'LV',
    DateTime Function()? clock,
  }) : _accountId = accountId,
       _drafts = drafts,
       _gateway = gateway,
       _reader = reader,
       _uploader = uploader,
       _mediaSource = mediaSource,
       _journal = journal,
       _membership = membership,
       _gate = gate,
       _mapper = mapper,
       _marketId = marketId,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const int maxListed = 20;

  /// Items whose server status is shown; the server checks every item itself.
  static const int maxMembersShown = 50;

  final String _accountId;
  final CollectionDraftSource _drafts;
  final EventPublicationGateway _gateway;
  final ContentDraftReader _reader;
  final EventCoverUploader _uploader;
  final EventCoverSource _mediaSource;
  final CollectionPublicationJournal _journal;
  final CollectionMembershipReader _membership;
  final CollectionPublicationCommandGate _gate;
  final CollectionContentBodyMapper _mapper;
  final String _marketId;
  final DateTime Function() _clock;

  /// Records whose server author was checked in this session.
  final Set<String> _verifiedDrafts = <String>{};

  CreateDraftEntity? _draft;
  CollectionPublicationViewState _state = const CollectionPublicationViewState(
    phase: CollectionPublicationPhase.loading,
  );

  CollectionPublicationViewState get state => _state;

  Future<void> load() async {
    if (!_gate.allowed) {
      _emit(phase: CollectionPublicationPhase.noDraft, message: 'not_allowed');
      return;
    }
    _emit(phase: CollectionPublicationPhase.loading);
    final CreateDraftEntity? draft = await _drafts.current();
    _draft =
        draft?.objectType == CreateObjectType.collection &&
            draft?.collectionData != null
        ? draft
        : null;
    await _run(
      _refreshAll,
      idle: _draft == null ? CollectionPublicationPhase.noDraft : null,
    );
  }

  /// Creates the Content draft if needed (empty body, §5.4) and saves the full
  /// body with the uploaded media.
  Future<void> save() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final CollectionPublicationScope scope = _scope(draft);
    // Nothing is sent, not even the empty draft, for a draft that cannot map.
    _refuseUnsupported(_mapper.map(draft, scope: scope, reviewedRevision: 0));
    final CollectionPublicationRecord record =
        await _usableRecord(scope) ?? await _create(draft, scope);
    await _saveBody(draft, scope, record);
    await _refreshAll();
  });

  /// Uploads the cover and every gallery photo that changed, then binds them.
  Future<void> uploadMedia() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final CollectionPublicationScope scope = _scope(draft);
    CollectionPublicationRecord record = await _requireRecord(scope);
    final List<CollectionAttachmentRecord> uploaded =
        <CollectionAttachmentRecord>[];
    for (final CollectionMediaAttachment item in _mapper.attachmentsOf(
      draft,
      scope,
    )) {
      final Uint8List? bytes = await _mediaSource.read(item.localRef);
      if (bytes == null) throw const _LocalRefusal('media_missing');
      final String digest = sha256.convert(bytes).toString();
      final CollectionAttachmentRecord? known = record.attachment(
        item.attachmentId,
      );
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
        CollectionAttachmentRecord(
          attachmentId: item.attachmentId,
          assetId: assetId,
          sha256: digest,
        ),
      );
      // Saved after every upload, so an interruption keeps what is done.
      record = record.copyWith(
        attachments: <CollectionAttachmentRecord>[
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
    final CollectionPublicationScope scope = _scope(draft);
    final CollectionPublicationRecord record = await _requireRecord(scope);
    if (!record.bodySaved) throw const _LocalRefusal('save_required');
    final String submissionId = await _gateway.submit(
      draftId: record.draftId,
      expectedDraftRevision: record.draftRevision,
      idempotencyKey: '${scope.keyBase}:submit:${record.draftRevision}',
    );
    await _journal.save(record.copyWith(submissionId: submissionId));
    await _refreshAll();
  });

  Future<void> refresh() => _run(_refreshAll);

  /// Publishes the revision staff approved (the owner's own command).
  Future<void> publish() => _run(() async {
    final CollectionPublicationRecord record = await _requireRecord(
      _scope(_requireDraft()),
    );
    final EventPublicationStatus status = await _gateway.status(
      record.contentId,
    );
    final String? submissionId =
        status.latestSubmissionId ?? record.submissionId;
    if (submissionId == null) throw const _LocalRefusal('submission_required');
    await _gateway.publishApproved(
      submissionId: submissionId,
      expectedPointerRevision: status.pointerRevision ?? 0,
      idempotencyKey: '$submissionId:publish',
    );
    await _refreshAll();
  });

  /// The owner's own hide of the published Collection (`withdrawPublication`).
  Future<void> hide() => _run(() async {
    final CollectionPublicationRecord record = await _requireRecord(
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

  /// §5.4: an empty draft under a stable key (a replay returns the same
  /// draft), recorded with the author the server stored.
  Future<CollectionPublicationRecord> _create(
    CreateDraftEntity draft,
    CollectionPublicationScope scope,
  ) async {
    final EventServerDraftRef created = await _gateway.createDraft(
      publisherRef: scope.publisherRef,
      marketId: _marketId,
      body: const <String, Object?>{},
      idempotencyKey: '${scope.keyBase}:create',
    );
    final String? owner = created.createdByUserId;
    if (owner == null) throw const EventPublicationRejected('invalid_contract');
    final CollectionPublicationRecord record = CollectionPublicationRecord(
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

  /// §5.4: the full body. Its composition review belongs to the revision this
  /// update produces, so a revision the server already moved past is read
  /// back once and the body mapped and saved again for it.
  Future<void> _saveBody(
    CreateDraftEntity draft,
    CollectionPublicationScope scope,
    CollectionPublicationRecord record,
  ) async {
    final Map<String, String> assets = await _currentAssets(
      draft,
      scope,
      record,
    );
    Future<EventServerDraftRef> update(int revision) {
      final CollectionContentBody mapped = _mapper.map(
        draft,
        scope: scope,
        reviewedRevision: revision + 1,
        assetIds: assets,
      );
      _refuseUnsupported(mapped);
      final String bodyDigest = sha256
          .convert(utf8.encode(jsonEncode(mapped.body)))
          .toString()
          .substring(0, 16);
      return _gateway.updateDraft(
        draftId: record.draftId,
        expectedRevision: revision,
        body: mapped.body,
        idempotencyKey: '${scope.keyBase}:update:$revision:$bodyDigest',
      );
    }

    EventServerDraftRef updated;
    try {
      updated = await update(record.draftRevision);
    } on EventPublicationRejected catch (refusal) {
      if (refusal.code != 'revision_conflict') rethrow;
      final EventServerDraftRef server = await _reader.draft(record.draftId);
      if (server.createdByUserId != record.serverOwnerUserId) {
        throw const _LocalRefusal('foreign_record');
      }
      updated = await update(server.revision);
    }
    await _journal.save(
      record.copyWith(
        draftRevision: updated.revision,
        bodySaved: true,
        title: draft.title,
      ),
    );
  }

  static void _refuseUnsupported(CollectionContentBody mapped) {
    if (mapped.unsupported.isNotEmpty) {
      throw _LocalRefusal(
        'unsupported_capability:${mapped.unsupported.join(',')}',
      );
    }
  }

  /// Uploaded assets whose photo still has the same bytes in the draft.
  Future<Map<String, String>> _currentAssets(
    CreateDraftEntity draft,
    CollectionPublicationScope scope,
    CollectionPublicationRecord record,
  ) async {
    final Map<String, String> assets = <String, String>{};
    for (final CollectionMediaAttachment item in _mapper.attachmentsOf(
      draft,
      scope,
    )) {
      final CollectionAttachmentRecord? known = record.attachment(
        item.attachmentId,
      );
      if (known == null) continue;
      final Uint8List? bytes = await _mediaSource.read(item.localRef);
      if (bytes != null && sha256.convert(bytes).toString() == known.sha256) {
        assets[item.attachmentId] = known.assetId;
      }
    }
    return assets;
  }

  /// §5.6: the journal record of this account, publisher and draft, used only
  /// while the server confirms it is this owner's draft. A foreign or
  /// unreadable record is ignored, never deleted.
  Future<CollectionPublicationRecord?> _usableRecord(
    CollectionPublicationScope scope,
  ) async {
    final CollectionPublicationRecord? record = await _journal.forLocalDraft(
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

  Future<CollectionPublicationRecord> _requireRecord(
    CollectionPublicationScope scope,
  ) async {
    final CollectionPublicationRecord? record = await _usableRecord(scope);
    if (record == null) throw const _LocalRefusal('save_required');
    return record;
  }

  Future<void> _refreshAll() async {
    final CreateDraftEntity? draft = _draft;
    final CollectionPublicationRecord? record = draft == null
        ? null
        : await _usableRecord(_scope(draft));
    final EventPublicationStatus? status = record == null
        ? null
        : await _gateway.status(record.contentId);
    final List<CollectionMemberStatus> members = <CollectionMemberStatus>[];
    for (final CollectionItemDraft item
        in (draft?.collectionData?.items ?? const <CollectionItemDraft>[]).take(
          maxMembersShown,
        )) {
      members.add(await _membership.statusOf(item.ref));
    }
    final List<CollectionPublicationObjectView> objects =
        <CollectionPublicationObjectView>[];
    for (final CollectionPublicationRecord item in (await _journal.list(
      _accountId,
    )).take(maxListed)) {
      try {
        objects.add(
          CollectionPublicationObjectView(
            record: item,
            status: await _gateway.status(item.contentId),
          ),
        );
      } on EventPublicationRejected catch (refusal) {
        objects.add(
          CollectionPublicationObjectView(
            record: item,
            failureCode: refusal.code,
          ),
        );
      }
    }
    _state = CollectionPublicationViewState(
      phase: _state.phase,
      draftTitle: draft?.title,
      record: record,
      status: status,
      message: _state.message,
      members: List<CollectionMemberStatus>.unmodifiable(members),
      myObjects: List<CollectionPublicationObjectView>.unmodifiable(objects),
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    CollectionPublicationPhase? idle,
  }) async {
    if (_state.phase == CollectionPublicationPhase.working) return;
    if (!_gate.allowed) {
      _emit(phase: _state.phase, message: 'not_allowed');
      return;
    }
    final CollectionPublicationPhase done =
        idle ?? CollectionPublicationPhase.ready;
    _emit(phase: CollectionPublicationPhase.working, message: null);
    try {
      await action();
      _emit(phase: done, message: null);
    } on EventPublicationRejected catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on _LocalRefusal catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on EventPublicationUnavailable catch (failure) {
      _emit(phase: CollectionPublicationPhase.offline, message: failure.code);
    } on StateError {
      // The gate closed between the check and the call: nothing was sent.
      _emit(phase: done, message: 'not_allowed');
    }
  }

  void _emit({required CollectionPublicationPhase phase, String? message}) {
    _state = CollectionPublicationViewState(
      phase: phase,
      draftTitle: _state.draftTitle ?? _draft?.title,
      record: _state.record,
      status: _state.status,
      message: message,
      members: _state.members,
      myObjects: _state.myObjects,
    );
    notifyListeners();
  }

  CreateDraftEntity _requireDraft() {
    final CreateDraftEntity? draft = _draft;
    if (draft == null) throw const _LocalRefusal('collection_draft_required');
    return draft;
  }

  CollectionPublicationScope _scope(CreateDraftEntity draft) {
    final PublisherRef? ref = draft.collectionData?.publisherRef;
    if (ref == null || !ref.isValid) {
      throw const _LocalRefusal('publisher_required');
    }
    return CollectionPublicationScope(
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
