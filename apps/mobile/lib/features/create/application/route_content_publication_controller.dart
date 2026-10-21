import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/entities/route_content_publication.dart';
import '../domain/entities/route_sync_data.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/route_content_publication_gateway.dart';
import '../domain/repositories/route_sync_repository.dart';

enum RouteContentPublicationPhase { loading, ready, working, noDraft }

final class RouteContentPublicationViewState {
  const RouteContentPublicationViewState({
    required this.phase,
    this.draftTitle,
    this.routeId,
    this.serverRevision,
    this.trim,
    this.record,
    this.status,
    this.message,
  });

  final RouteContentPublicationPhase phase;
  final String? draftTitle;

  /// The server Route of this draft (J1 sync); null until it was saved there.
  final String? routeId;
  final int? serverRevision;
  final RoutePrivacyTrim? trim;
  final RouteContentPublicationRecord? record;
  final EventPublicationStatus? status;

  /// Last refusal or failure code (server code, or a local one).
  final String? message;

  bool get _idle => phase == RouteContentPublicationPhase.ready;
  bool get _reviewing => status?.latestSubmissionState == 'under_review';
  bool get _approved =>
      status?.latestSubmissionState == 'approved_for_publication';
  bool get _locked => _reviewing || _approved;
  bool get canSync => _idle && !_locked;
  bool get canHideEnds => _idle && serverRevision != null && !_locked;
  bool get canPrepare => _idle && serverRevision != null && !_locked;
  bool get canUploadCover =>
      _idle && record?.contentDraftId != null && !_locked;
  bool get canSubmit => _idle && record?.contentRevision != null && !_locked;
  bool get canPublish => _idle && _approved;
  bool get canHide => _idle && status?.visibility == 'visible';
  bool get published =>
      status?.currentPublishedRevisionId != null &&
      status?.visibility == 'visible';
}

/// Test-path coordinator of one Route publication (J2 / RTE-PUB-01): the
/// user's Create Route is saved on the server through the J1 sync, its ends
/// can be hidden, its current revision is pinned to an immutable public
/// snapshot, bound to its one Content draft with the shared public fields and
/// cover, submitted, reviewed by staff (or approved by the publisher's earned
/// trust) and published or hidden by the owner. It owns no rule: Route,
/// Content, Media and moderation decide on the server, and every call passes
/// the default-off Route publication test entry.
final class RouteContentPublicationController extends ChangeNotifier {
  RouteContentPublicationController({
    required String accountId,
    required String defaultContentLocale,
    required PublisherRef publisherRef,
    required RouteDraftSource drafts,
    required RouteSyncRepository sync,
    required RouteDistributionGateway distribution,
    required EventPublicationGateway content,
    required EventCoverUploader uploader,
    required EventCoverSource mediaSource,
    required RouteContentPublicationJournal journal,
    required EventPublicationCommandGate gate,
    String marketId = 'LV',
  }) : _accountId = accountId,
       _locale = defaultContentLocale,
       _publisher = publisherRef,
       _drafts = drafts,
       _sync = sync,
       _distribution = distribution,
       _content = content,
       _uploader = uploader,
       _mediaSource = mediaSource,
       _journal = journal,
       _gate = gate,
       _marketId = marketId;

  /// RP-02: what "hide the private ends" sets (the recorded-GPS minimum).
  static const RoutePrivacyTrim recommendedTrim = RoutePrivacyTrim(
    startMeters: 200,
    endMeters: 200,
  );

  final String _accountId;
  final String _locale;
  final PublisherRef _publisher;
  final RouteDraftSource _drafts;
  final RouteSyncRepository _sync;
  final RouteDistributionGateway _distribution;
  final EventPublicationGateway _content;
  final EventCoverUploader _uploader;
  final EventCoverSource _mediaSource;
  final RouteContentPublicationJournal _journal;
  final EventPublicationCommandGate _gate;
  final String _marketId;

  CreateDraftEntity? _draft;
  RouteContentPublicationViewState _state =
      const RouteContentPublicationViewState(
        phase: RouteContentPublicationPhase.loading,
      );

  RouteContentPublicationViewState get state => _state;

  Future<void> load() async {
    if (!_gate.allowed) {
      _state = const RouteContentPublicationViewState(
        phase: RouteContentPublicationPhase.noDraft,
        message: 'not_allowed',
      );
      notifyListeners();
      return;
    }
    final CreateDraftEntity? draft = await _drafts.current();
    _draft =
        draft?.objectType == CreateObjectType.route && draft?.routeData != null
        ? draft
        : null;
    if (_draft == null) {
      _state = const RouteContentPublicationViewState(
        phase: RouteContentPublicationPhase.noDraft,
      );
      notifyListeners();
      return;
    }
    await _run(() async {
      try {
        await _sync.restore();
      } on RouteSyncFailure catch (error) {
        throw _LocalRefusal(error.code);
      }
    });
  }

  Future<void> refresh() => _run(() async {});

  /// Saves the current Create Route on the server (J1 owner sync).
  Future<void> syncRoute() => _run(() async {
    final CreateDraftEntity draft = _draft!;
    await _syncCall(
      () => _sync.save(
        localDraftId: draft.id,
        title: draft.title,
        route: draft.routeData!,
        expectedRevision: _state.serverRevision ?? 0,
      ),
    );
  });

  /// RP-02: hides 200 m at both ends of the stored Route.
  Future<void> hidePrivateEnds() => _run(() async {
    await _syncCall(
      () => _sync.setPrivacyTrim(
        routeId: _state.routeId!,
        trim: recommendedTrim,
        expectedRevision: _state.serverRevision!,
      ),
    );
  });

  /// Pins the current server revision to an immutable public snapshot and
  /// binds it to the Route's one Content draft (created on first use).
  Future<void> prepare() => _run(() async {
    final CreateDraftEntity draft = _draft!;
    final String routeId = _state.routeId!;
    final int revision = _state.serverRevision!;
    final RouteDistributionRef pinned = await _distribution.distribute(
      routeId: routeId,
      expectedRevision: revision,
      idempotencyKey: 'rte-dist:$routeId:$revision',
    );
    RouteContentPublicationRecord record =
        (_state.record ??
                RouteContentPublicationRecord(
                  accountId: _accountId,
                  localDraftId: draft.id,
                  routeId: routeId,
                  routeRevisionId: pinned.routeRevisionId,
                  contentHash: pinned.contentHash,
                  distribution: pinned.distribution,
                  publisherRef: _publisher,
                ))
            .copyWith(
              routeRevisionId: pinned.routeRevisionId,
              contentHash: pinned.contentHash,
              distribution: pinned.distribution,
            );
    await _journal.save(record);
    final Map<String, Object?> body = _body(draft, record);
    final EventServerDraftRef ref;
    if (record.contentDraftId == null) {
      ref = await _content.createDraft(
        publisherRef: record.publisherRef,
        marketId: _marketId,
        body: body,
        idempotencyKey: 'rte-content:$routeId',
      );
    } else {
      ref = await _content.updateDraft(
        draftId: record.contentDraftId!,
        expectedRevision: record.contentRevision!,
        body: body,
        idempotencyKey: _key('rte-bind', record, body),
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
    RouteContentPublicationRecord record = _state.record!;
    final Uint8List? bytes = await _mediaSource.read(draft.media.coverImage);
    if (bytes == null) throw const _LocalRefusal('media_missing');
    final String digest = sha256.convert(bytes).toString();
    final String assetId =
        record.coverSha256 == digest && record.coverAssetId != null
        ? record.coverAssetId!
        : await _uploader.upload(
            intentId: 'rte-cover:${record.routeId}:${digest.substring(0, 16)}',
            bytes: bytes,
            declaredMediaType: _mediaType(bytes),
            publisherRef: record.publisherRef,
            contentId: record.routeId,
          );
    record = record.copyWith(coverAssetId: assetId, coverSha256: digest);
    final Map<String, Object?> body = _body(draft, record);
    final EventServerDraftRef ref = await _content.updateDraft(
      draftId: record.contentDraftId!,
      expectedRevision: record.contentRevision!,
      body: body,
      idempotencyKey: _key('rte-cover', record, body),
    );
    await _journal.save(record.copyWith(contentRevision: ref.revision));
  });

  Future<void> submit() => _run(() async {
    final RouteContentPublicationRecord record = _state.record!;
    await _content.submit(
      draftId: record.contentDraftId!,
      expectedDraftRevision: record.contentRevision!,
      idempotencyKey:
          'rte-submit:${record.contentDraftId}:${record.contentRevision}',
    );
  });

  Future<void> publish() => _run(() async {
    final EventPublicationStatus status = _state.status!;
    await _content.publishApproved(
      submissionId: status.latestSubmissionId!,
      expectedPointerRevision: status.pointerRevision ?? 0,
      idempotencyKey: 'rte-publish:${status.latestSubmissionId}',
    );
  });

  Future<void> hide() => _run(() async {
    final EventPublicationStatus status = _state.status!;
    await _content.withdraw(
      contentId: status.contentId,
      expectedPointerRevision: status.pointerRevision!,
      idempotencyKey: 'rte-hide:${status.contentId}:${status.pointerRevision}',
    );
  });

  Map<String, Object?> _body(
    CreateDraftEntity draft,
    RouteContentPublicationRecord record,
  ) => <String, Object?>{
    'title': record.distribution['title'],
    'shortDescription': draft.shortDescription,
    'fullDescription': draft.fullDescription,
    'contentLocale': _locale,
    'categoryId': draft.mainCategory,
    'subcategoryId': draft.subcategory,
    'media': <String, Object?>{
      if (record.coverAssetId != null)
        'coverImage': <String, Object?>{
          'mediaId': record.coverAssetId,
          'altText': <String, Object?>{_locale: draft.title},
        },
      if (record.coverAssetId != null) 'rightsConfirmed': true,
    },
    'route': <String, Object?>{
      'ref': <String, Object?>{
        'routeId': record.routeId,
        'routeRevisionId': record.routeRevisionId,
        'contentHash': record.contentHash,
      },
      'distribution': record.distribution,
    },
  };

  /// The same body always replays the same command; a new body gets a new key.
  static String _key(
    String prefix,
    RouteContentPublicationRecord record,
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

  static Future<void> _syncCall(Future<Object?> Function() call) async {
    try {
      await call();
    } on RouteSyncFailure catch (error) {
      throw _LocalRefusal(error.code);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_draft == null) return;
    _state = RouteContentPublicationViewState(
      phase: RouteContentPublicationPhase.working,
      draftTitle: _state.draftTitle,
      routeId: _state.routeId,
      serverRevision: _state.serverRevision,
      trim: _state.trim,
      record: _state.record,
      status: _state.status,
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
    final String? routeId = _sync.routeIdFor(draft.id);
    RouteSyncEntry? entry;
    if (routeId != null) {
      try {
        entry = await _sync.refresh(routeId);
      } on RouteSyncFailure catch (error) {
        message ??= error.code;
        entry = _sync.cached(routeId);
      }
    }
    final RouteContentPublicationRecord? record = await _journal.forDraft(
      accountId: _accountId,
      localDraftId: draft.id,
    );
    EventPublicationStatus? status;
    if (record?.contentDraftId != null) {
      try {
        status = await _content.status(record!.routeId);
      } on Exception {
        status = null;
      }
    }
    _state = RouteContentPublicationViewState(
      phase: RouteContentPublicationPhase.ready,
      draftTitle: draft.title,
      routeId: entry == null ? null : routeId,
      serverRevision: entry?.revision,
      trim: entry?.privacyTrim,
      record: record,
      status: status,
      message: message,
    );
    notifyListeners();
  }
}

final class _LocalRefusal implements Exception {
  const _LocalRefusal(this.code);
  final String code;
}
