import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/content_validation_violation.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/find_people_draft_data.dart';
import '../domain/entities/find_people_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/find_people_publication_gateway.dart';
import '../domain/usecases/build_find_people_content_body.dart';

enum FindPeoplePublicationPhase { loading, ready, working, noDraft, offline }

/// One entry of "my Find People requests": a journaled id and its status as
/// the server reports it now (null with [failureCode] when it could not be read).
final class FindPeoplePublicationObjectView {
  const FindPeoplePublicationObjectView({
    required this.record,
    this.status,
    this.failureCode,
  });

  final FindPeoplePublicationRecord record;
  final EventPublicationStatus? status;
  final String? failureCode;
}

final class FindPeoplePublicationViewState {
  const FindPeoplePublicationViewState({
    required this.phase,
    this.draftTitle,
    this.record,
    this.status,
    this.consent,
    this.message,
    this.myObjects = const <FindPeoplePublicationObjectView>[],
    this.conflict,
    this.violations = const <ContentValidationViolation>[],
  });

  final FindPeoplePublicationPhase phase;
  final String? draftTitle;
  final FindPeoplePublicationRecord? record;
  final EventPublicationStatus? status;

  /// The author's BCK-06 consent as the server answers it; null when never given.
  final FindPeopleConsentView? consent;
  final String? message;
  final List<FindPeoplePublicationObjectView> myObjects;
  final DraftConflict? conflict;
  final List<ContentValidationViolation> violations;

  bool get _idle => phase == FindPeoplePublicationPhase.ready;
  bool get _published => status?.currentPublishedRevisionId != null;
  bool get _consented => consent?.active ?? false;
  bool get canSaveOverServerVersion => _idle && conflict != null && !_published;
  bool get canSave => _idle && draftTitle != null && !_published;
  bool get canGrantConsent => _idle && record != null && !_consented;
  bool get canRevokeConsent => _idle && _consented;
  bool get canSubmit =>
      _idle && (record?.authorApplied ?? false) && _consented && !_published;
  bool get canPublish =>
      _idle && (status?.approvedForPublication ?? false) && _consented;
  bool get canHide => _idle && status?.visibility == 'visible';
}

/// Test-path coordinator of one Find People publication (D3.7): the user's own
/// Create Find People draft → Content draft (empty, then the full private
/// source body with the server's author) → the author's explicit BCK-06
/// consent → submit → (staff review) → publish or hide, plus "my requests".
/// It owns no authority and no business rule: Content, Identity (consent and
/// the 18+ attestation) and moderation decide on the server, and every call is
/// gated by the default-off Find People test entry. Device location is never
/// read or sent; the public point is computed by the server. Activate and edits
/// after publication are not offered here.
final class FindPeoplePublicationController extends ChangeNotifier {
  FindPeoplePublicationController({
    required String accountId,
    required String defaultContentLocale,
    required FindPeopleDraftSource drafts,
    required EventPublicationGateway gateway,
    required ContentDraftReader reader,
    required FindPeopleConsentGateway consents,
    required FindPeoplePublicationJournal journal,
    required FindPeoplePublicationCommandGate gate,
    FindPeopleContentBodyMapper mapper = const FindPeopleContentBodyMapper(),
    String marketId = 'LV',
    DateTime Function()? clock,
  }) : _accountId = accountId,
       _defaultContentLocale = defaultContentLocale,
       _drafts = drafts,
       _gateway = gateway,
       _reader = reader,
       _consents = consents,
       _journal = journal,
       _gate = gate,
       _mapper = mapper,
       _marketId = marketId,
       _clock = clock ?? (() => DateTime.now().toUtc());

  static const int maxListed = 20;

  final String _accountId;
  final String _defaultContentLocale;
  final FindPeopleDraftSource _drafts;
  final EventPublicationGateway _gateway;
  final ContentDraftReader _reader;
  final FindPeopleConsentGateway _consents;
  final FindPeoplePublicationJournal _journal;
  final FindPeoplePublicationCommandGate _gate;
  final FindPeopleContentBodyMapper _mapper;
  final String _marketId;
  final DateTime Function() _clock;

  /// Records whose server author was checked in this session.
  final Set<String> _verifiedDrafts = <String>{};

  DraftConflict? _conflict;
  CreateDraftEntity? _draft;
  FindPeoplePublicationViewState _state = const FindPeoplePublicationViewState(
    phase: FindPeoplePublicationPhase.loading,
  );

  FindPeoplePublicationViewState get state => _state;
  String get accountId => _accountId;
  CreateDraftEntity? get currentDraft => _draft;

  Future<void> load() async {
    if (!_gate.allowed) {
      _emit(phase: FindPeoplePublicationPhase.noDraft, message: 'not_allowed');
      return;
    }
    _emit(phase: FindPeoplePublicationPhase.loading);
    final CreateDraftEntity? draft = await _drafts.current();
    _draft =
        draft?.objectType == CreateObjectType.findPeople &&
            draft?.findPeopleData != null
        ? draft
        : null;
    await _run(
      _refreshAll,
      idle: _draft == null ? FindPeoplePublicationPhase.noDraft : null,
    );
  }

  /// Creates the Content draft if needed (empty body) and saves the full
  /// private source body with the server's author.
  Future<void> save() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final FindPeoplePublicationScope scope = _scope(draft);
    // Nothing is sent, not even the empty draft, for a draft that cannot map.
    _assertSupported(draft, scope);
    final FindPeoplePublicationRecord record =
        await _usableRecord(scope) ?? await _create(draft, scope);
    await _assertNotPreviouslyPublished(record);
    await _saveBody(draft, scope, record);
    await _refreshAll();
  });

  /// The author's explicit consent to this exact publication (FP-OD-03).
  Future<void> grantConsent() => _run(() async {
    final FindPeoplePublicationScope scope = _scope(_requireDraft());
    final FindPeoplePublicationRecord record = await _requireRecord(scope);
    final FindPeopleConsentView? current = await _consents.consent(
      record.contentId,
    );
    final int expected = current?.revision ?? 0;
    await _consents.grant(
      contentId: record.contentId,
      expectedRevision: expected,
      idempotencyKey: '${scope.keyBase}:consent:grant:$expected',
    );
    await _refreshAll();
  });

  /// Withdraws consent; the server removes the request from every new answer.
  Future<void> revokeConsent() => _run(() async {
    final FindPeoplePublicationScope scope = _scope(_requireDraft());
    final FindPeoplePublicationRecord record = await _requireRecord(scope);
    final FindPeopleConsentView? current = await _consents.consent(
      record.contentId,
    );
    if (current == null) throw const _LocalRefusal('consent_missing');
    await _consents.revoke(
      contentId: record.contentId,
      expectedRevision: current.revision,
      idempotencyKey: '${scope.keyBase}:consent:revoke:${current.revision}',
    );
    await _refreshAll();
  });

  Future<void> submit() => _run(() async {
    final CreateDraftEntity draft = _requireDraft();
    final FindPeoplePublicationScope scope = _scope(draft);
    final FindPeoplePublicationRecord record = await _requireRecord(scope);
    await _assertNotPreviouslyPublished(record);
    if (!record.authorApplied) throw const _LocalRefusal('save_required');
    _assertSupported(draft, scope);
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
    final FindPeoplePublicationScope scope = _scope(draft);
    final FindPeoplePublicationRecord record = await _requireRecord(scope);
    await _assertNotPreviouslyPublished(record);
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
    final FindPeoplePublicationRecord record = await _requireRecord(
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

  /// The owner's own hide of the published request (`withdrawPublication`).
  Future<void> hide() => _run(() async {
    final FindPeoplePublicationRecord record = await _requireRecord(
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

  /// An empty draft under a stable key (a replay returns the same draft),
  /// recorded with the author the server stored.
  Future<FindPeoplePublicationRecord> _create(
    CreateDraftEntity draft,
    FindPeoplePublicationScope scope,
  ) async {
    final EventServerDraftRef created = await _gateway.createDraft(
      publisherRef: scope.publisherRef,
      marketId: _marketId,
      body: const <String, Object?>{},
      idempotencyKey: '${scope.keyBase}:create',
    );
    final String? owner = created.createdByUserId;
    if (owner == null) throw const EventPublicationRejected('invalid_contract');
    final FindPeoplePublicationRecord record = FindPeoplePublicationRecord(
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

  Future<void> _assertNotPreviouslyPublished(
    FindPeoplePublicationRecord record,
  ) async {
    final EventPublicationStatus status = await _gateway.status(
      record.contentId,
    );
    if (status.currentPublishedRevisionId != null) {
      throw const _LocalRefusal('editing_after_publication_not_supported');
    }
  }

  /// M1 D2: every write is journaled with its exact payload before the call.
  /// A write whose answer never came is replayed first, unchanged; a revision
  /// the server holds for any other reason is someone else's edit and stops
  /// the save with `revision_conflict` until [saveOverServerVersion].
  Future<void> _saveBody(
    CreateDraftEntity draft,
    FindPeoplePublicationScope scope,
    FindPeoplePublicationRecord record, {
    int? overServerRevision,
  }) async {
    final FindPeopleContentBody mapped = _mapper.map(
      draft,
      scope: scope,
      serverOwnerUserId: record.serverOwnerUserId,
      defaultContentLocale: _defaultContentLocale,
    );
    _refuseUnsupported(mapped);
    final String bodyDigest = sha256
        .convert(utf8.encode(jsonEncode(mapped.body)))
        .toString()
        .substring(0, 16);
    FindPeoplePublicationRecord current = record;
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
    final FindPeoplePublicationRecord sending = current.copyWith(
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
      final FindPeoplePublicationRecord refused = sending.copyWith(
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

  Future<void> _conflictOn(FindPeoplePublicationRecord record) async {
    final EventServerDraftRef server = await _reader.draft(record.draftId);
    if (server.createdByUserId != record.serverOwnerUserId) {
      throw const _LocalRefusal('foreign_record');
    }
    _conflict = DraftConflict(serverRevision: server.revision);
  }

  void _assertSupported(
    CreateDraftEntity draft,
    FindPeoplePublicationScope scope,
  ) => _refuseUnsupported(
    _mapper.map(
      draft,
      scope: scope,
      // Only the unsupported list is read here; no body is sent.
      serverOwnerUserId: '',
      defaultContentLocale: _defaultContentLocale,
    ),
  );

  static void _refuseUnsupported(FindPeopleContentBody mapped) {
    if (mapped.unsupported.isNotEmpty) {
      throw _LocalRefusal(
        'unsupported_capability:${mapped.unsupported.join(',')}',
      );
    }
  }

  /// The journal record of this account, publisher and draft, used only while
  /// the server confirms it is this owner's draft. A foreign or unreadable
  /// record is ignored, never deleted.
  Future<FindPeoplePublicationRecord?> _usableRecord(
    FindPeoplePublicationScope scope,
  ) async {
    final FindPeoplePublicationRecord? record = await _journal.forLocalDraft(
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

  Future<FindPeoplePublicationRecord> _requireRecord(
    FindPeoplePublicationScope scope,
  ) async {
    final FindPeoplePublicationRecord? record = await _usableRecord(scope);
    if (record == null) throw const _LocalRefusal('save_required');
    return record;
  }

  Future<void> _refreshAll() async {
    final CreateDraftEntity? draft = _draft;
    final FindPeoplePublicationRecord? record = draft == null
        ? null
        : await _usableRecord(_scope(draft));
    final EventPublicationStatus? status = record == null
        ? null
        : await _gateway.status(record.contentId);
    final FindPeopleConsentView? consent = record == null
        ? null
        : await _consents.consent(record.contentId);
    if (_conflict != null && record != null) await _conflictOn(record);
    final List<FindPeoplePublicationObjectView> objects =
        <FindPeoplePublicationObjectView>[];
    for (final FindPeoplePublicationRecord item in (await _journal.list(
      _accountId,
    )).take(maxListed)) {
      try {
        objects.add(
          FindPeoplePublicationObjectView(
            record: item,
            status: await _gateway.status(item.contentId),
          ),
        );
      } on EventPublicationRejected catch (refusal) {
        objects.add(
          FindPeoplePublicationObjectView(
            record: item,
            failureCode: refusal.code,
          ),
        );
      }
    }
    _state = FindPeoplePublicationViewState(
      phase: _state.phase,
      draftTitle: draft?.title,
      record: record,
      status: status,
      consent: consent,
      message: _state.message,
      myObjects: List<FindPeoplePublicationObjectView>.unmodifiable(objects),
      conflict: _conflict,
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    FindPeoplePublicationPhase? idle,
  }) async {
    if (_state.phase == FindPeoplePublicationPhase.working) return;
    if (!_gate.allowed) {
      _emit(phase: _state.phase, message: 'not_allowed');
      return;
    }
    final FindPeoplePublicationPhase done =
        idle ?? FindPeoplePublicationPhase.ready;
    _emit(phase: FindPeoplePublicationPhase.working, message: null);
    try {
      await action();
      _emit(phase: done, message: null);
    } on EventPublicationRejected catch (refusal) {
      _emit(phase: done, message: refusal.code, violations: refusal.violations);
    } on _LocalRefusal catch (refusal) {
      _emit(phase: done, message: refusal.code);
    } on EventPublicationUnavailable catch (failure) {
      _emit(phase: FindPeoplePublicationPhase.offline, message: failure.code);
    } on StateError {
      // The gate closed between the check and the call: nothing was sent.
      _emit(phase: done, message: 'not_allowed');
    }
  }

  void _emit({
    required FindPeoplePublicationPhase phase,
    String? message,
    List<ContentValidationViolation> violations =
        const <ContentValidationViolation>[],
  }) {
    _state = FindPeoplePublicationViewState(
      phase: phase,
      draftTitle: _state.draftTitle ?? _draft?.title,
      record: _state.record,
      status: _state.status,
      consent: _state.consent,
      message: message,
      myObjects: _state.myObjects,
      conflict: _conflict,
      violations: violations,
    );
    notifyListeners();
  }

  CreateDraftEntity _requireDraft() {
    final CreateDraftEntity? draft = _draft;
    if (draft == null) throw const _LocalRefusal('find_people_draft_required');
    return draft;
  }

  /// The publisher captured in the Create draft (active workspace, IDP-04A):
  /// a personal request belongs to this account; a Page request names its
  /// Page, and the server re-checks access to it on every command.
  FindPeoplePublicationScope _scope(CreateDraftEntity draft) {
    final FindPeopleDraftData data = draft.findPeopleData!;
    final PublisherRef? ref = switch (data.publisherType) {
      FindPeoplePublisherType.user
          when data.publisherId == _accountId &&
              draft.organizerId == _accountId =>
        PublisherRef(type: PublisherType.user, id: _accountId),
      FindPeoplePublisherType.page when draft.organizerId == _accountId =>
        PublisherRef(type: PublisherType.page, id: data.publisherId),
      _ => null,
    };
    if (ref == null || !ref.isValid) {
      throw const _LocalRefusal('publisher_required');
    }
    return FindPeoplePublicationScope(
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
