import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/entities/scenario_publication.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/scenario_publication_gateway.dart';

enum ScenarioPublicationPhase { loading, ready, working, noDraft }

final class ScenarioPublicationViewState {
  const ScenarioPublicationViewState({
    required this.phase,
    this.draftTitle,
    this.serverRevision,
    this.record,
    this.status,
    this.share,
    this.message,
  });

  final ScenarioPublicationPhase phase;
  final String? draftTitle;

  /// The plan revision the server holds (I2); null until it was saved there.
  final int? serverRevision;
  final ScenarioPublicationRecord? record;
  final EventPublicationStatus? status;
  final ScenarioShareLink? share;

  /// Last refusal or failure code (server code, or a local one).
  final String? message;

  bool get _idle => phase == ScenarioPublicationPhase.ready;
  bool get _unpublished => status?.currentPublishedRevisionId == null;
  bool get _reviewing => status?.latestSubmissionState == 'under_review';
  bool get canPrepare =>
      _idle && serverRevision != null && !_reviewing && !_approved;
  bool get canUploadCover =>
      _idle && record?.contentDraftId != null && !_reviewing && !_approved;
  bool get canSubmit =>
      _idle && record?.contentRevision != null && !_reviewing && !_approved;
  bool get _approved =>
      status?.latestSubmissionState == 'approved_for_publication';
  bool get canPublish => _idle && _approved;
  bool get canHide => _idle && status?.visibility == 'visible';
  bool get canShare => _idle && serverRevision != null;
  bool get canUnshare => _idle && serverRevision != null;
  bool get published => !_unpublished && status?.visibility == 'visible';
}

/// Test-path coordinator of one Scenario publication (I3 / SCN-PUB-01): the
/// user's Create Scenario, already saved on the server through I2, is pinned
/// to an immutable public revision, bound to its one Content draft with the
/// shared public fields and cover, submitted, reviewed by staff and published
/// or hidden by the owner; an unlisted link is issued or revoked separately.
/// It owns no rule: Planning, Content, Media and moderation decide on the
/// server, and every call passes the default-off Scenario test entry.
final class ScenarioPublicationController extends ChangeNotifier {
  ScenarioPublicationController({
    required String accountId,
    required String defaultContentLocale,
    required ScenarioDraftSource drafts,
    required ScenarioPlanningGateway planning,
    required EventPublicationGateway content,
    required EventCoverUploader uploader,
    required EventCoverSource mediaSource,
    required ScenarioPublicationJournal journal,
    required EventPublicationCommandGate gate,
    String marketId = 'LV',
  }) : _accountId = accountId,
       _locale = defaultContentLocale,
       _drafts = drafts,
       _planning = planning,
       _content = content,
       _uploader = uploader,
       _mediaSource = mediaSource,
       _journal = journal,
       _gate = gate,
       _marketId = marketId;

  final String _accountId;
  final String _locale;
  final ScenarioDraftSource _drafts;
  final ScenarioPlanningGateway _planning;
  final EventPublicationGateway _content;
  final EventCoverUploader _uploader;
  final EventCoverSource _mediaSource;
  final ScenarioPublicationJournal _journal;
  final EventPublicationCommandGate _gate;
  final String _marketId;

  CreateDraftEntity? _draft;
  ScenarioPublicationViewState _state = const ScenarioPublicationViewState(
    phase: ScenarioPublicationPhase.loading,
  );

  ScenarioPublicationViewState get state => _state;
  PublisherRef get _publisher =>
      PublisherRef(type: PublisherType.user, id: _accountId);

  Future<void> load() async {
    if (!_gate.allowed) {
      _state = const ScenarioPublicationViewState(
        phase: ScenarioPublicationPhase.noDraft,
        message: 'not_allowed',
      );
      notifyListeners();
      return;
    }
    final CreateDraftEntity? draft = await _drafts.current();
    _draft =
        draft?.objectType == CreateObjectType.scenario &&
            draft?.scenarioData != null
        ? draft
        : null;
    if (_draft == null) {
      _state = const ScenarioPublicationViewState(
        phase: ScenarioPublicationPhase.noDraft,
      );
      notifyListeners();
      return;
    }
    await _run(() async {});
  }

  Future<void> refresh() => _run(() async {});

  /// Pins the server plan to a new immutable public revision and binds it to
  /// the Scenario's one Content draft (created on first use).
  Future<void> prepare() => _run(() async {
    final CreateDraftEntity draft = _draft!;
    final int revision = await _planning.serverRevision(draft.id);
    final ScenarioDistributionRef pinned = await _planning.distribute(
      scenarioId: draft.id,
      expectedRevision: revision,
      idempotencyKey: 'scn-dist:${draft.id}:$revision',
    );
    ScenarioPublicationRecord record =
        (_state.record ??
                ScenarioPublicationRecord(
                  accountId: _accountId,
                  scenarioId: draft.id,
                  scenarioRevisionId: pinned.scenarioRevisionId,
                  contentHash: pinned.contentHash,
                  distribution: pinned.distribution,
                ))
            .copyWith(
              scenarioRevisionId: pinned.scenarioRevisionId,
              contentHash: pinned.contentHash,
              distribution: pinned.distribution,
            );
    await _journal.save(record);
    final Map<String, Object?> body = _body(draft, record);
    final EventServerDraftRef ref;
    if (record.contentDraftId == null) {
      ref = await _content.createDraft(
        publisherRef: _publisher,
        marketId: _marketId,
        body: body,
        idempotencyKey: 'scn-content:${draft.id}',
      );
    } else {
      ref = await _content.updateDraft(
        draftId: record.contentDraftId!,
        expectedRevision: record.contentRevision!,
        body: body,
        idempotencyKey: _key('scn-bind', record, body),
      );
    }
    record = record.copyWith(
      contentDraftId: ref.draftId,
      contentRevision: ref.revision,
    );
    await _journal.save(record);
  });

  /// Uploads the Create cover once per content and binds it with the rights
  /// confirmation the user gave.
  Future<void> uploadCover({required bool rightsConfirmed}) => _run(() async {
    final CreateDraftEntity draft = _draft!;
    if (!rightsConfirmed) throw const _LocalRefusal('media_rights_required');
    ScenarioPublicationRecord record = _state.record!;
    final Uint8List? bytes = await _mediaSource.read(draft.media.coverImage);
    if (bytes == null) throw const _LocalRefusal('media_missing');
    final String digest = sha256.convert(bytes).toString();
    final String assetId =
        record.coverSha256 == digest && record.coverAssetId != null
        ? record.coverAssetId!
        : await _uploader.upload(
            intentId: 'scn-cover:${draft.id}:${digest.substring(0, 16)}',
            bytes: bytes,
            declaredMediaType: _mediaType(bytes),
            publisherRef: _publisher,
            contentId: record.scenarioId,
          );
    record = record.copyWith(coverAssetId: assetId, coverSha256: digest);
    final Map<String, Object?> body = _body(draft, record);
    final EventServerDraftRef ref = await _content.updateDraft(
      draftId: record.contentDraftId!,
      expectedRevision: record.contentRevision!,
      body: body,
      idempotencyKey: _key('scn-cover', record, body),
    );
    await _journal.save(record.copyWith(contentRevision: ref.revision));
  });

  Future<void> submit() => _run(() async {
    final ScenarioPublicationRecord record = _state.record!;
    await _content.submit(
      draftId: record.contentDraftId!,
      expectedDraftRevision: record.contentRevision!,
      idempotencyKey:
          'scn-submit:${record.contentDraftId}:${record.contentRevision}',
    );
  });

  Future<void> publish() => _run(() async {
    final EventPublicationStatus status = _state.status!;
    await _content.publishApproved(
      submissionId: status.latestSubmissionId!,
      expectedPointerRevision: status.pointerRevision ?? 0,
      idempotencyKey: 'scn-publish:${status.latestSubmissionId}',
    );
  });

  Future<void> hide() => _run(() async {
    final EventPublicationStatus status = _state.status!;
    await _content.withdraw(
      contentId: status.contentId,
      expectedPointerRevision: status.pointerRevision!,
      idempotencyKey: 'scn-hide:${status.contentId}:${status.pointerRevision}',
    );
  });

  /// Issues a new unlisted link (the previous one stops working at once).
  Future<void> share({int? ttlDays}) => _run(() async {
    final ScenarioShareLink link = await _planning.share(
      scenarioId: _draft!.id,
      expectedRevision: _state.serverRevision!,
      ttlDays: ttlDays,
      idempotencyKey: 'scn-share:${const Uuid().v4()}',
    );
    _share = link;
    if (link.token == null) {
      throw const _LocalRefusal('share_token_unavailable');
    }
  });

  Future<void> unshare() => _run(() async {
    await _planning.unshare(
      scenarioId: _draft!.id,
      expectedRevision: _state.serverRevision!,
      idempotencyKey: 'scn-unshare:${const Uuid().v4()}',
    );
    _share = null;
  });

  ScenarioShareLink? _share;

  Map<String, Object?> _body(
    CreateDraftEntity draft,
    ScenarioPublicationRecord record,
  ) => <String, Object?>{
    'title': record.distribution['title'],
    'shortDescription': draft.shortDescription,
    'fullDescription': draft.fullDescription,
    'contentLocale': _locale,
    'media': <String, Object?>{
      if (record.coverAssetId != null)
        'coverImage': <String, Object?>{
          'mediaId': record.coverAssetId,
          'altText': <String, Object?>{_locale: draft.title},
        },
      'rightsConfirmed': record.coverAssetId != null,
    },
    'scenario': <String, Object?>{
      'ref': <String, Object?>{
        'scenarioId': record.scenarioId,
        'scenarioRevisionId': record.scenarioRevisionId,
        'contentHash': record.contentHash,
      },
      'distribution': record.distribution,
    },
  };

  /// The same body always replays the same command; a new body gets a new key.
  static String _key(
    String prefix,
    ScenarioPublicationRecord record,
    Map<String, Object?> body,
  ) {
    final String digest = sha256
        .convert(
          utf8.encode(
            '${record.contentDraftId}:${record.contentRevision}:'
            '${jsonEncode(body)}',
          ),
        )
        .toString();
    return '$prefix:${digest.substring(0, 40)}';
  }

  static String _mediaType(Uint8List bytes) =>
      bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50
      ? 'image/png'
      : 'image/jpeg';

  Future<void> _run(Future<void> Function() action) async {
    if (_draft == null) return;
    _state = ScenarioPublicationViewState(
      phase: ScenarioPublicationPhase.working,
      draftTitle: _state.draftTitle,
      serverRevision: _state.serverRevision,
      record: _state.record,
      status: _state.status,
      share: _share,
    );
    notifyListeners();
    String? message;
    try {
      _gate.assertAllowed();
      await action();
    } on EventPublicationRejected catch (error) {
      message = error.code;
    } on EventPublicationUnavailable catch (error) {
      message = error.code;
    } on _LocalRefusal catch (error) {
      message = error.code;
    }
    final CreateDraftEntity draft = _draft!;
    int? revision;
    EventPublicationStatus? status;
    try {
      revision = await _planning.serverRevision(draft.id);
    } on Exception {
      message ??= 'plan_not_synced';
    }
    final ScenarioPublicationRecord? record = await _journal.forScenario(
      accountId: _accountId,
      scenarioId: draft.id,
    );
    if (record?.contentDraftId != null) {
      try {
        status = await _content.status(draft.id);
      } on Exception {
        status = null;
      }
    }
    _state = ScenarioPublicationViewState(
      phase: ScenarioPublicationPhase.ready,
      draftTitle: draft.title,
      serverRevision: revision,
      record: record,
      status: status,
      share: _share,
      message: message,
    );
    notifyListeners();
  }
}

final class _LocalRefusal implements Exception {
  const _LocalRefusal(this.code);
  final String code;
}
