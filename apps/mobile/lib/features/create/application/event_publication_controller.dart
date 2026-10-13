import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/usecases/build_event_content_body.dart';

enum EventPublicationPhase { loading, ready, working, noDraft, offline }

/// One entry of "my objects": a journaled id and its status as the server
/// reports it now (null with [failureCode] when it could not be read).
final class EventPublicationObjectView {
  const EventPublicationObjectView({
    required this.record,
    this.status,
    this.failureCode,
  });

  final EventPublicationRecord record;
  final EventPublicationStatus? status;
  final String? failureCode;
}

final class EventPublicationViewState {
  const EventPublicationViewState({
    required this.phase,
    this.draftTitle,
    this.record,
    this.status,
    this.message,
    this.myObjects = const <EventPublicationObjectView>[],
  });

  final EventPublicationPhase phase;

  /// Title of the user's Create Event draft, as Create stored it.
  final String? draftTitle;

  /// Server ids of this draft (null until the first save).
  final EventPublicationRecord? record;
  final EventPublicationStatus? status;

  /// Last refusal or failure code (server code, or a local `*_required`).
  final String? message;
  final List<EventPublicationObjectView> myObjects;

  bool get _idle => phase == EventPublicationPhase.ready;
  bool get canSave => _idle && draftTitle != null;
  bool get canUploadCover => _idle && record != null;
  bool get canSubmit => _idle && record != null;
  bool get canPublish => _idle && (status?.approvedForPublication ?? false);
  bool get canHide => _idle && status?.visibility == 'visible';
}

/// Test-path coordinator of one Event publication (C3): the user's own Create
/// draft -> Content draft -> Media cover -> submit -> (staff review) ->
/// publication status -> publish or hide, plus the "my objects" list. It owns
/// no authority and no business rule: Content, Media and moderation decide on
/// the server, and every call is gated by the default-off test entry.
final class EventPublicationController extends ChangeNotifier {
  EventPublicationController({
    required EventDraftSource drafts,
    required EventPublicationGateway gateway,
    required EventCoverUploader covers,
    required EventCoverSource coverSource,
    required EventPublicationJournal journal,
    required EventPublicationCommandGate gate,
    EventContentBodyMapper mapper = const EventContentBodyMapper(),
    String marketId = 'LV',
    DateTime Function()? clock,
  }) : _drafts = drafts,
       _gateway = gateway,
       _covers = covers,
       _coverSource = coverSource,
       _journal = journal,
       _gate = gate,
       _mapper = mapper,
       _marketId = marketId,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const String _namespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
  static const int maxListed = 20;

  final EventDraftSource _drafts;
  final EventPublicationGateway _gateway;
  final EventCoverUploader _covers;
  final EventCoverSource _coverSource;
  final EventPublicationJournal _journal;
  final EventPublicationCommandGate _gate;
  final EventContentBodyMapper _mapper;
  final String _marketId;
  final DateTime Function() _clock;

  CreateDraftEntity? _draft;
  EventPublicationViewState _state = const EventPublicationViewState(
    phase: EventPublicationPhase.loading,
  );

  EventPublicationViewState get state => _state;

  Future<void> load() async {
    if (!_gate.allowed) {
      _emit(phase: EventPublicationPhase.noDraft, message: 'not_allowed');
      return;
    }
    _emit(phase: EventPublicationPhase.loading);
    final CreateDraftEntity? draft = await _drafts.current();
    _draft =
        draft?.objectType == CreateObjectType.event && draft?.eventData != null
        ? draft
        : null;
    await _run(() async {
      await _refreshAll();
    }, idle: _draft == null ? EventPublicationPhase.noDraft : null);
  }

  /// Creates or updates the Content draft from the user's Create draft.
  Future<void> save() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    await _saveDraft(draft, await _journal.forLocalDraft(draft.id));
    await _refreshAll();
  });

  /// Uploads the draft's cover through Media and binds that exact asset.
  Future<void> uploadCover() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    EventPublicationRecord record = await _requireRecord(draft);
    final Uint8List? bytes = await _coverSource.read(draft.media.coverImage);
    if (bytes == null) throw const _LocalRefusal('cover_required');
    final String digest = sha256.convert(bytes).toString();
    if (record.coverAssetId == null || record.coverDigest != digest) {
      final String assetId = await _covers.upload(
        // The same bytes for the same draft always replay the same upload.
        intentId: const Uuid().v5(_namespace, '${draft.id}:cover:$digest'),
        bytes: bytes,
        declaredMediaType: _declaredMediaType(draft.media.coverImage),
        publisherRef: _publisherRef(draft),
        contentId: record.contentId,
      );
      record = record.copyWith(coverAssetId: assetId, coverDigest: digest);
      await _journal.save(record);
    }
    await _saveDraft(draft, record);
    await _refreshAll();
  });

  Future<void> submit() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final EventPublicationRecord record = await _requireRecord(draft);
    final String submissionId = await _gateway.submit(
      draftId: record.draftId,
      expectedDraftRevision: record.draftRevision,
      idempotencyKey: '${_keyBase(draft.id)}:submit:${record.draftRevision}',
    );
    await _journal.save(record.copyWith(submissionId: submissionId));
    await _refreshAll();
  });

  Future<void> refresh() => _run(_refreshAll);

  /// Publishes the revision staff approved (the owner's own command).
  Future<void> publish() => _run(() async {
    final EventPublicationRecord record = await _requireRecord(_requireDraft());
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

  /// The owner's own hide of the published Event (`withdrawPublication`).
  Future<void> hide() => _run(() async {
    final EventPublicationRecord record = await _requireRecord(_requireDraft());
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

  Future<EventPublicationRecord> _saveDraft(
    CreateDraftEntity draft,
    EventPublicationRecord? record,
  ) async {
    final EventContentBody mapped = _mapper.map(
      draft,
      coverMediaId: await _currentCoverAsset(draft, record),
    );
    if (mapped.unsupported.isNotEmpty) {
      throw _LocalRefusal(
        'unsupported_capability:${mapped.unsupported.join(',')}',
      );
    }
    final String base = _keyBase(draft.id);
    if (record == null) {
      final EventServerDraftRef created = await _gateway.createDraft(
        publisherRef: _publisherRef(draft),
        marketId: _marketId,
        body: mapped.body,
        idempotencyKey: '$base:create',
      );
      final EventPublicationRecord fresh = EventPublicationRecord(
        localDraftId: draft.id,
        contentId: created.contentId,
        draftId: created.draftId,
        draftRevision: created.revision,
        title: draft.title,
        createdAtUtc: _clock(),
      );
      await _journal.save(fresh);
      return fresh;
    }
    final String bodyDigest = sha256
        .convert(utf8.encode(jsonEncode(mapped.body)))
        .toString()
        .substring(0, 16);
    final EventServerDraftRef updated = await _gateway.updateDraft(
      draftId: record.draftId,
      expectedRevision: record.draftRevision,
      body: mapped.body,
      idempotencyKey: '$base:update:${record.draftRevision}:$bodyDigest',
    );
    final EventPublicationRecord saved = record.copyWith(
      draftRevision: updated.revision,
      title: draft.title,
    );
    await _journal.save(saved);
    return saved;
  }

  /// The uploaded asset, but only while the draft still points at the same bytes.
  Future<String?> _currentCoverAsset(
    CreateDraftEntity draft,
    EventPublicationRecord? record,
  ) async {
    if (record?.coverAssetId == null) return null;
    final Uint8List? bytes = await _coverSource.read(draft.media.coverImage);
    if (bytes == null) return null;
    return sha256.convert(bytes).toString() == record!.coverDigest
        ? record.coverAssetId
        : null;
  }

  Future<void> _refreshAll() async {
    final CreateDraftEntity? draft = _draft;
    final EventPublicationRecord? record = draft == null
        ? null
        : await _journal.forLocalDraft(draft.id);
    final EventPublicationStatus? status = record == null
        ? null
        : await _gateway.status(record.contentId);
    final List<EventPublicationObjectView> objects =
        <EventPublicationObjectView>[];
    for (final EventPublicationRecord item in (await _journal.list()).take(
      maxListed,
    )) {
      try {
        objects.add(
          EventPublicationObjectView(
            record: item,
            status: await _gateway.status(item.contentId),
          ),
        );
      } on EventPublicationRejected catch (refusal) {
        objects.add(
          EventPublicationObjectView(record: item, failureCode: refusal.code),
        );
      }
    }
    _state = EventPublicationViewState(
      phase: _state.phase,
      draftTitle: draft?.title,
      record: record,
      status: status,
      message: _state.message,
      myObjects: List<EventPublicationObjectView>.unmodifiable(objects),
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    EventPublicationPhase? idle,
  }) async {
    if (_state.phase == EventPublicationPhase.working) return;
    if (!_gate.allowed) {
      _emit(phase: _state.phase, message: 'not_allowed');
      return;
    }
    final EventPublicationPhase done = idle ?? EventPublicationPhase.ready;
    _emit(phase: EventPublicationPhase.working, message: null);
    try {
      await action();
      _emit(phase: done, message: null);
    } on EventPublicationRejected catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on _LocalRefusal catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on EventPublicationUnavailable catch (failure) {
      _emit(phase: EventPublicationPhase.offline, message: failure.code);
    } on StateError {
      // The gate closed between the check and the call: nothing was sent.
      _emit(phase: done, message: 'not_allowed');
    }
  }

  void _emit({required EventPublicationPhase phase, String? message}) {
    _state = EventPublicationViewState(
      phase: phase,
      draftTitle: _state.draftTitle ?? _draft?.title,
      record: _state.record,
      status: _state.status,
      message: message,
      myObjects: _state.myObjects,
    );
    notifyListeners();
  }

  CreateDraftEntity _requireDraft() {
    final CreateDraftEntity? draft = _draft;
    if (draft == null) throw const _LocalRefusal('event_draft_required');
    return draft;
  }

  Future<EventPublicationRecord> _requireRecord(CreateDraftEntity draft) async {
    final EventPublicationRecord? record = await _journal.forLocalDraft(
      draft.id,
    );
    if (record == null) throw const _LocalRefusal('save_required');
    return record;
  }

  static PublisherRef _publisherRef(CreateDraftEntity draft) {
    final PublisherRef? ref = draft.eventData?.publisherRef;
    if (ref == null || !ref.isValid) {
      throw const _LocalRefusal('publisher_required');
    }
    return ref;
  }

  static String _keyBase(String localDraftId) =>
      'evp-${sha256.convert(utf8.encode(localDraftId)).toString().substring(0, 24)}';

  /// What the client claims; the server detects the real type from the bytes.
  static String _declaredMediaType(String reference) {
    final String lower = reference.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}

/// A precondition the client checks before sending anything.
final class _LocalRefusal implements Exception {
  const _LocalRefusal(this.code);

  final String code;
}
