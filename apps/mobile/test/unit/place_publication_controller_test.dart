import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/place_publication_controller.dart';
import 'package:recharge/features/create/data/file_place_publication_journal.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/entities/place_publication.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/place_publication_gateway.dart';
import 'package:recharge/features/create/domain/usecases/build_place_content_body.dart';

import '../fixtures/create/user_place_draft.dart';

/// D3.1 §5.4–§5.6: the Place publication controller against an in-memory
/// Content server with idempotent keys and injected failures. One server draft
/// per account, publisher and local draft whatever fails in between; media
/// keys follow the photos, not their positions; a record of another account,
/// publisher or server author is never used.
void main() {
  late Directory temp;
  late _Server server;
  late _Uploader uploader;
  late _Media media;
  late _Gate gate;
  late FilePlacePublicationJournal journal;

  const String cover = 'C:/photos/cover.png';
  const List<String> gallery = <String>['C:/photos/a.png', 'C:/photos/b.png'];

  CreateDraftEntity draft({List<String> photos = gallery}) => userPlaceDraft(
    pageId: 'page-1',
    coverPath: cover,
    galleryPaths: photos,
    localId: 'local-place-1',
  );

  PlacePublicationController controller(
    CreateDraftEntity current, {
    String account = 'account-a',
  }) => PlacePublicationController(
    accountId: account,
    drafts: _Drafts(current),
    gateway: server,
    reader: server,
    uploader: uploader,
    mediaSource: media,
    journal: journal,
    gate: gate,
    clock: () => DateTime.utc(2026, 10, 10, 12),
  );

  PlacePublicationScope scope(
    CreateDraftEntity current, {
    String account = 'account-a',
  }) => PlacePublicationScope(
    accountId: account,
    publisherRef: current.placeData!.publisherRef,
    localDraftId: current.id,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('place-publication-');
    server = _Server();
    uploader = _Uploader();
    media = _Media(<String, Uint8List>{
      cover: Uint8List.fromList(<int>[1, 1, 1]),
      gallery[0]: Uint8List.fromList(<int>[2, 2, 2]),
      gallery[1]: Uint8List.fromList(<int>[3, 3, 3]),
    });
    gate = _Gate();
    journal = FilePlacePublicationJournal(File('${temp.path}/places.json'));
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('a closed entry sends nothing', () async {
    gate.open = false;
    final PlacePublicationController c = controller(draft());
    await c.load();
    await c.save();
    await c.uploadMedia();
    expect(c.state.message, 'not_allowed');
    expect(server.calls, isEmpty);
    expect(uploader.intents, isEmpty);
  });

  test(
    'the first save creates an empty draft, then saves the body with the server author',
    () async {
      final CreateDraftEntity current = draft();
      final PlacePublicationController c = controller(current);
      await c.load();
      await c.save();
      expect(c.state.message, isNull);
      expect(server.calls.take(2).toList(), <String>[
        'createDraft',
        'updateDraft',
      ]);
      expect(server.creates.single.body, isEmpty);
      expect(server.creates.single.key, '${scope(current).keyBase}:create');
      final _Draft stored = server.drafts.values.single;
      expect(
        (stored.body['provenance']!
            as Map<String, Object?>)['submittedByUserId'],
        'server-user-a',
      );
      final PlacePublicationRecord record = c.state.record!;
      expect(record.authorApplied, isTrue);
      expect(record.serverOwnerUserId, 'server-user-a');
      expect(record.draftRevision, 2);
    },
  );

  test('a lost createDraft answer is replayed into the same draft', () async {
    final PlacePublicationController c = controller(draft());
    await c.load();
    server.loseAnswerOf.add('createDraft');
    await c.save();
    expect(c.state.phase, PlacePublicationPhase.offline);
    expect(c.state.record, isNull);
    await c.save();
    expect(c.state.message, isNull);
    expect(server.drafts, hasLength(1), reason: 'never a second draft');
    expect(server.creates, hasLength(2));
    expect(server.creates[0].key, server.creates[1].key);
  });

  test(
    'a failed body save after the create only repeats the body save',
    () async {
      final PlacePublicationController c = controller(draft());
      await c.load();
      server.failBefore.add('updateDraft');
      await c.save();
      final PlacePublicationRecord? recorded = await journal.forLocalDraft(
        accountId: 'account-a',
        publisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-1',
        ),
        localDraftId: 'local-place-1',
      );
      expect(
        recorded?.authorApplied,
        isFalse,
        reason: 'created, body not saved',
      );
      expect(c.state.canSubmit, isFalse);
      await c.save();
      expect(
        server.creates,
        hasLength(1),
        reason: 'the draft is not created again',
      );
      expect(c.state.record?.authorApplied, isTrue);
      expect(server.drafts, hasLength(1));
    },
  );

  test(
    'a lost body save answer is replayed, a changed body reads the revision back',
    () async {
      final CreateDraftEntity current = draft();
      final PlacePublicationController c = controller(current);
      await c.load();
      await c.save();
      server.loseAnswerOf.add('updateDraft');
      await c.save(); // revision 2 -> 3 on the server; the answer is lost
      expect(c.state.record?.draftRevision, 2);
      await c.save(); // same body, same key: the stored answer is replayed
      expect(c.state.message, isNull);
      expect(c.state.record?.draftRevision, 3);
      // A different body under the stale revision: read back once and saved.
      server.loseAnswerOf.add('updateDraft');
      await c.save(); // 3 -> 4, answer lost; the local record still says 3
      final PlacePublicationController changed = controller(
        current.copyWith(title: 'Kronvalda park pond and fountain'),
      );
      await changed.load();
      await changed.save();
      expect(changed.state.message, isNull);
      expect(server.drafts.values.single.revision, 5);
      expect(
        server.drafts.values.single.body['title'],
        'Kronvalda park pond and fountain',
      );
      expect(server.calls, contains('getDraft'));
    },
  );

  test(
    'media are uploaded once per photo and bytes, whatever the order',
    () async {
      final CreateDraftEntity current = draft();
      final PlacePublicationController c = controller(current);
      await c.load();
      await c.save();
      await c.uploadMedia();
      expect(c.state.message, isNull);
      final PlacePublicationScope s = scope(current);
      String intent(String ref, int byte) => s.uploadIntentId(
        ref == cover ? s.coverAttachmentId : s.galleryAttachmentId(ref),
        sha256.convert(<int>[byte, byte, byte]).toString(),
      );
      expect(uploader.intents, <String>[
        intent(cover, 1),
        intent(gallery[0], 2),
        intent(gallery[1], 3),
      ]);
      final Map<String, Object?> body = server.drafts.values.single.body;
      final Map<String, Object?> bodyMedia =
          body['media']! as Map<String, Object?>;
      expect(
        (bodyMedia['coverImage']! as Map<String, Object?>)['mediaId'],
        uploader.assetFor(intent(cover, 1)),
      );
      // Again, and with the gallery reversed: nothing is uploaded again.
      await c.uploadMedia();
      final PlacePublicationController reordered = controller(
        draft(photos: gallery.reversed.toList()),
      );
      await reordered.load();
      await reordered.uploadMedia();
      expect(uploader.intents, hasLength(3));
      final Map<String, Object?> reorderedMedia =
          server.drafts.values.single.body['media']! as Map<String, Object?>;
      expect(
        (reorderedMedia['gallery']! as List<Object?>)
            .map((item) => (item! as Map<String, Object?>)['mediaId'])
            .toList(),
        <String?>[
          uploader.assetFor(intent(gallery[1], 3)),
          uploader.assetFor(intent(gallery[0], 2)),
        ],
      );
      // New bytes for one photo: exactly one new upload.
      media.files[gallery[0]] = Uint8List.fromList(<int>[9, 9, 9]);
      await reordered.uploadMedia();
      expect(uploader.intents, hasLength(4));
      expect(uploader.intents.last, intent(gallery[0], 9));
    },
  );

  test(
    'submit needs the saved author; publish and hide use the server status',
    () async {
      final PlacePublicationController c = controller(draft());
      await c.load();
      await c.submit();
      expect(c.state.message, 'save_required');
      await c.save();
      await c.submit();
      expect(c.state.message, isNull);
      expect(c.state.record?.submissionId, 'submission-1');
      server.approve('submission-1');
      await c.refresh();
      expect(c.state.canPublish, isTrue);
      await c.publish();
      expect(server.calls, contains('publishApprovedRevision'));
      expect(c.state.canHide, isTrue);
      await c.hide();
      expect(server.calls.last, 'withdrawPublication');
    },
  );

  test(
    'another account never uses the record and lists only its own places',
    () async {
      final CreateDraftEntity current = draft();
      final PlacePublicationController a = controller(current);
      await a.load();
      await a.save();
      final PlacePublicationController b = controller(
        current,
        account: 'account-b',
      );
      await b.load();
      expect(b.state.record, isNull);
      expect(b.state.myObjects, isEmpty);
      await b.save();
      expect(server.drafts, hasLength(2), reason: 'B has its own server draft');
      expect(server.creates[0].key, isNot(server.creates[1].key));
      expect(b.state.myObjects.map((item) => item.record.accountId), <String>[
        'account-b',
      ]);
      expect(
        (await journal.list('account-a')).single.contentId,
        isNot(b.state.record!.contentId),
      );
    },
  );

  test(
    'a record whose server author or publisher differs is not used',
    () async {
      final CreateDraftEntity current = draft();
      final PlacePublicationController a = controller(current);
      await a.load();
      await a.save();
      final PlacePublicationRecord saved = a.state.record!;
      // The server now reports another author for that draft.
      server.drafts[saved.draftId] = server.drafts[saved.draftId]!.withOwner(
        'someone-else',
      );
      final PlacePublicationController again = controller(current);
      await again.load();
      expect(again.state.record, isNull);
      // A record of the same draft for another publisher is never returned.
      expect(
        await journal.forLocalDraft(
          accountId: 'account-a',
          publisherRef: const PublisherRef(
            type: PublisherType.user,
            id: 'page-1',
          ),
          localDraftId: current.id,
        ),
        isNull,
      );
    },
  );

  test(
    'an unsupported draft sends nothing, not even the empty draft',
    () async {
      final CreateDraftEntity current = draft();
      final CreateDraftEntity seasonal = current.copyWith(
        placeData: current.placeData!.copyWith(
          hours: const PlaceHoursDraft(mode: PlaceHoursMode.seasonal),
        ),
      );
      final PlacePublicationController c = controller(seasonal);
      await c.load();
      await c.save();
      expect(c.state.message, 'unsupported_capability:hours.seasonal');
      expect(server.calls, isEmpty);
    },
  );

  test(
    'M1 D1: a lost publish answer is retried with the journaled payload',
    () async {
      final PlacePublicationController c = controller(draft());
      await c.load();
      await c.save();
      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      server.approve('submission-1');
      await c.refresh();
      server.loseAnswerOf.add('publishApprovedRevision');
      await c.publish();
      expect(c.state.phase, PlacePublicationPhase.offline);
      expect(server.publications, 1, reason: 'the server applied it');
      // A restart: a new controller over the same journal retries the same payload.
      final PlacePublicationController again = controller(draft());
      await again.load();
      await again.publish();
      expect(again.state.message, isNull, reason: again.state.message);
      expect(server.publications, 1, reason: 'exactly one publication');
    },
  );

  test(
    'M1 D2: a newer revision written elsewhere is a conflict; only the explicit choice saves over it',
    () async {
      final PlacePublicationController c = controller(draft());
      await c.load();
      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      final String draftId = c.state.record!.draftId;
      final int saved = server.drafts[draftId]!.revision;
      const Map<String, Object?> elsewhere = <String, Object?>{
        'title': 'elsewhere',
      };
      server.writeElsewhere(draftId, elsewhere);
      final PlacePublicationController mine = controller(
        draft().copyWith(title: 'Edited on this install'),
      );
      await mine.load();
      await mine.save();
      expect(mine.state.message, 'revision_conflict');
      expect(mine.state.conflict?.serverRevision, saved + 1);
      expect(
        server.drafts[draftId]!.body,
        elsewhere,
        reason: 'nothing overwritten',
      );
      await mine.save();
      expect(mine.state.message, 'revision_conflict');
      expect(
        server.drafts[draftId]!.revision,
        saved + 1,
        reason: 'no automatic overwrite',
      );
      server.writeElsewhere(draftId, const <String, Object?>{'title': 'again'});
      await mine.refresh();
      expect(
        mine.state.conflict?.serverRevision,
        saved + 2,
        reason: 'the actual revision',
      );
      expect(mine.state.canSaveOverServerVersion, isTrue);
      await mine.saveOverServerVersion();
      expect(mine.state.message, isNull, reason: mine.state.message);
      expect(mine.state.conflict, isNull);
      expect(server.drafts[draftId]!.revision, saved + 3);
      expect(
        server.drafts[draftId]!.body,
        isNot(<String, Object?>{'title': 'again'}),
      );
    },
  );
}

final class _Drafts implements PlaceDraftSource {
  _Drafts(this.draft);

  final CreateDraftEntity draft;

  @override
  Future<CreateDraftEntity?> current() async => draft;
}

final class _Gate implements PlacePublicationCommandGate {
  bool open = true;

  @override
  bool get allowed => open;

  @override
  void assertAllowed() {
    if (!open) throw StateError('closed');
  }
}

final class _Media implements EventCoverSource {
  _Media(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<Uint8List?> read(String reference) async => files[reference];
}

final class _Uploader implements EventCoverUploader {
  final List<String> intents = <String>[];
  final Map<String, String> _assets = <String, String>{};

  String? assetFor(String intent) => _assets[intent];

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    intents.add(intentId);
    return _assets.putIfAbsent(intentId, () => 'asset-${_assets.length + 1}');
  }
}

final class _Draft {
  const _Draft({
    required this.contentId,
    required this.revision,
    required this.owner,
    required this.body,
  });

  final String contentId;
  final int revision;
  final String owner;
  final Map<String, Object?> body;

  _Draft withOwner(String value) => _Draft(
    contentId: contentId,
    revision: revision,
    owner: value,
    body: body,
  );
}

/// In-memory Content: drafts with revisions and authors, idempotent keys
/// (same key and payload replay the stored answer), and injected failures.
final class _Server implements EventPublicationGateway, ContentDraftReader {
  final Map<String, _Draft> drafts = <String, _Draft>{};
  final List<String> calls = <String>[];
  final List<({String key, Map<String, Object?> body})> creates =
      <({String key, Map<String, Object?> body})>[];
  final Set<String> loseAnswerOf = <String>{};
  final Map<String, String> _publishReplies = <String, String>{};
  int publications = 0;
  final Set<String> failBefore = <String>{};
  final Map<String, (String, EventServerDraftRef)> _replies =
      <String, (String, EventServerDraftRef)>{};
  final Map<String, String> _submissionStates = <String, String>{};
  String? _latestSubmission;
  int? _pointerRevision;
  String? _visibility;
  int _counter = 0;

  /// The account behind the current call: the first create makes it A.
  String owner = 'server-user-a';

  void approve(String submissionId) =>
      _submissionStates[submissionId] = 'approved_for_publication';

  /// M1 D2: another install of the same author saves the draft.
  void writeElsewhere(String draftId, Map<String, Object?> body) {
    final _Draft current = drafts[draftId]!;
    drafts[draftId] = _Draft(
      contentId: current.contentId,
      revision: current.revision + 1,
      owner: current.owner,
      body: body,
    );
  }

  EventServerDraftRef _ref(String draftId) {
    final _Draft draft = drafts[draftId]!;
    return EventServerDraftRef(
      contentId: draft.contentId,
      draftId: draftId,
      revision: draft.revision,
      createdByUserId: draft.owner,
    );
  }

  Future<EventServerDraftRef> _idempotent(
    String command,
    String key,
    Map<String, Object?> payload,
    EventServerDraftRef Function() apply,
  ) async {
    calls.add(command);
    if (failBefore.remove(command)) {
      throw const EventPublicationUnavailable('transport');
    }
    final String fingerprint = jsonEncode(payload);
    final (String, EventServerDraftRef)? stored = _replies[key];
    final EventServerDraftRef reply;
    if (stored != null) {
      if (stored.$1 != fingerprint) {
        throw const EventPublicationRejected('idempotency_conflict');
      }
      reply = stored.$2;
    } else {
      reply = apply();
      _replies[key] = (fingerprint, reply);
    }
    if (loseAnswerOf.remove(command)) {
      throw const EventPublicationUnavailable('transport');
    }
    return reply;
  }

  @override
  Future<EventServerDraftRef> createDraft({
    required PublisherRef publisherRef,
    required String marketId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) {
    creates.add((key: idempotencyKey, body: body));
    return _idempotent(
      'createDraft',
      idempotencyKey,
      <String, Object?>{'publisher': publisherRef.id, 'body': body},
      () {
        _counter += 1;
        final String draftId = 'draft-$_counter';
        // A second account (another key scope) is another server user.
        final String author = drafts.isEmpty ? owner : 'server-user-$_counter';
        drafts[draftId] = _Draft(
          contentId: 'content-$_counter',
          revision: 1,
          owner: author,
          body: body,
        );
        return _ref(draftId);
      },
    );
  }

  @override
  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) => _idempotent(
    'updateDraft',
    idempotencyKey,
    <String, Object?>{
      'draftId': draftId,
      'expectedRevision': expectedRevision,
      'body': body,
    },
    () {
      final _Draft current = drafts[draftId]!;
      if (current.revision != expectedRevision) {
        throw const EventPublicationRejected('revision_conflict');
      }
      drafts[draftId] = _Draft(
        contentId: current.contentId,
        revision: current.revision + 1,
        owner: current.owner,
        body: body,
      );
      return _ref(draftId);
    },
  );

  @override
  Future<EventServerDraftRef> draft(String draftId) async {
    calls.add('getDraft');
    if (!drafts.containsKey(draftId)) {
      throw const EventPublicationRejected('not_found');
    }
    return _ref(draftId);
  }

  @override
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  }) async {
    calls.add('submitForPublication');
    _latestSubmission = 'submission-1';
    _submissionStates['submission-1'] = 'under_review';
    return 'submission-1';
  }

  @override
  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add('publishApprovedRevision');
    // Like Content: a key replays its stored answer only for the same payload.
    final String fingerprint = '$submissionId:$expectedPointerRevision';
    final String? stored = _publishReplies[idempotencyKey];
    if (stored != null) {
      if (stored != fingerprint) {
        throw const EventPublicationRejected('idempotency_conflict');
      }
    } else {
      _publishReplies[idempotencyKey] = fingerprint;
      publications += 1;
      _submissionStates[submissionId] = 'published';
      _pointerRevision = (_pointerRevision ?? 0) + 1;
      _visibility = 'visible';
    }
    if (loseAnswerOf.remove('publishApprovedRevision')) {
      throw const EventPublicationUnavailable('transport');
    }
  }

  @override
  Future<void> withdraw({
    required String contentId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add('withdrawPublication');
    _pointerRevision = (_pointerRevision ?? 0) + 1;
    _visibility = 'withdrawn';
  }

  @override
  Future<EventPublicationStatus> status(String contentId) async =>
      EventPublicationStatus(
        contentId: contentId,
        latestSubmissionId: _latestSubmission,
        latestSubmissionState: _latestSubmission == null
            ? null
            : _submissionStates[_latestSubmission],
        pointerRevision: _pointerRevision,
        visibility: _visibility,
        currentPublishedRevisionId: _visibility == null ? null : 'revision-1',
      );
}
