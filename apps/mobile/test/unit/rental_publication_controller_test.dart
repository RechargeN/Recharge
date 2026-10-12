import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/rental_publication_controller.dart';
import 'package:recharge/features/create/data/file_rental_publication_journal.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/entities/rental_publication.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/place_publication_gateway.dart'
    show ContentDraftReader;
import 'package:recharge/features/create/domain/repositories/rental_publication_gateway.dart';
import 'package:recharge/features/create/domain/usecases/build_rental_content_body.dart';

import '../fixtures/create/user_rental_draft.dart';

/// D3.3 §4: the Rental publication controller against an in-memory
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
  late FileRentalPublicationJournal journal;

  const String cover = 'C:/photos/cover.png';
  const List<String> gallery = <String>['C:/photos/a.png', 'C:/photos/b.png'];

  CreateDraftEntity draft({
    List<String> photos = gallery,
    String account = 'account-a',
  }) => userRentalDraft(
    pageId: 'page-1',
    coverPath: cover,
    galleryPaths: photos,
    localId: 'local-rental-1',
    accountId: account,
  );

  RentalPublicationController controller(
    CreateDraftEntity current, {
    String account = 'account-a',
  }) => RentalPublicationController(
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

  RentalPublicationScope scope(
    CreateDraftEntity current, {
    String account = 'account-a',
  }) => RentalPublicationScope(
    accountId: account,
    publisherRef: current.rentalData!.publisherRef,
    localDraftId: current.id,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rental-publication-');
    server = _Server();
    uploader = _Uploader();
    media = _Media(<String, Uint8List>{
      cover: Uint8List.fromList(<int>[1, 1, 1]),
      gallery[0]: Uint8List.fromList(<int>[2, 2, 2]),
      gallery[1]: Uint8List.fromList(<int>[3, 3, 3]),
    });
    gate = _Gate();
    journal = FileRentalPublicationJournal(File('${temp.path}/rentals.json'));
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('a closed entry sends nothing', () async {
    gate.open = false;
    final RentalPublicationController c = controller(draft());
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
      final RentalPublicationController c = controller(current);
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
      // The attestation and the block carry this account's server id (Q3).
      expect(
        (stored.body['attestation']!
            as Map<String, Object?>)['acceptedByUserId'],
        'server-user-a',
      );
      expect(
        ((stored.body['availability']! as Map<String, Object?>)['blocks']!
                as List<Object?>)
            .cast<Map<String, Object?>>()
            .single['createdByUserId'],
        'server-user-a',
      );
      final RentalPublicationRecord record = c.state.record!;
      expect(record.authorApplied, isTrue);
      expect(record.serverOwnerUserId, 'server-user-a');
      expect(record.draftRevision, 2);
    },
  );

  test('a lost createDraft answer is replayed into the same draft', () async {
    final RentalPublicationController c = controller(draft());
    await c.load();
    server.loseAnswerOf.add('createDraft');
    await c.save();
    expect(c.state.phase, RentalPublicationPhase.offline);
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
      final RentalPublicationController c = controller(draft());
      await c.load();
      server.failBefore.add('updateDraft');
      await c.save();
      final RentalPublicationRecord? recorded = await journal.forLocalDraft(
        accountId: 'account-a',
        publisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-1',
        ),
        localDraftId: 'local-rental-1',
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
      final RentalPublicationController c = controller(current);
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
      final RentalPublicationController changed = controller(
        current.copyWith(
          rentalData: current.rentalData!.copyWith(
            title: 'Kipsala sea kayak and canoe rental',
          ),
        ),
      );
      await changed.load();
      await changed.save();
      expect(changed.state.message, isNull);
      expect(server.drafts.values.single.revision, 5);
      expect(
        server.drafts.values.single.body['title'],
        'Kipsala sea kayak and canoe rental',
      );
      expect(server.calls, contains('getDraft'));
    },
  );

  test(
    'media are uploaded once per photo and bytes, whatever the order',
    () async {
      final CreateDraftEntity current = draft();
      final RentalPublicationController c = controller(current);
      await c.load();
      await c.save();
      await c.uploadMedia();
      expect(c.state.message, isNull);
      final RentalPublicationScope s = scope(current);
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
      expect(
        (body['mediaRefs']! as List<Object?>).first,
        uploader.assetFor(intent(cover, 1)),
      );
      // Again, and with the gallery reversed: nothing is uploaded again.
      await c.uploadMedia();
      final RentalPublicationController reordered = controller(
        draft(photos: gallery.reversed.toList()),
      );
      await reordered.load();
      await reordered.uploadMedia();
      expect(uploader.intents, hasLength(3));
      final List<Object?> reorderedMedia =
          server.drafts.values.single.body['mediaRefs']! as List<Object?>;
      expect(reorderedMedia.skip(1).toList(), <String?>[
        uploader.assetFor(intent(gallery[1], 3)),
        uploader.assetFor(intent(gallery[0], 2)),
      ]);
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
      final RentalPublicationController c = controller(draft());
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
    'another account never sends A\'s confirmation and keeps its own records',
    () async {
      final CreateDraftEntity current = draft();
      final RentalPublicationController a = controller(current);
      await a.load();
      await a.save();
      final RentalPublicationController b = controller(
        current,
        account: 'account-b',
      );
      await b.load();
      expect(b.state.record, isNull);
      expect(b.state.myObjects, isEmpty);
      // A's attestation and block are never rewritten to B (Q3): nothing is sent.
      final int callsBefore = server.calls.length;
      await b.save();
      expect(
        b.state.message,
        'unsupported_capability:rental.attestation_foreign,rental.block_foreign',
      );
      expect(server.calls.length, callsBefore);
      expect(server.drafts, hasLength(1));
      // B's own confirmed draft gets its own server draft and record.
      final RentalPublicationController own = controller(
        draft(account: 'account-b'),
        account: 'account-b',
      );
      await own.load();
      await own.save();
      expect(own.state.message, isNull);
      expect(server.drafts, hasLength(2), reason: 'B has its own server draft');
      expect(own.state.myObjects.map((item) => item.record.accountId), <String>[
        'account-b',
      ]);
    },
  );

  test(
    'a record whose server author or publisher differs is not used',
    () async {
      final CreateDraftEntity current = draft();
      final RentalPublicationController a = controller(current);
      await a.load();
      await a.save();
      final RentalPublicationRecord saved = a.state.record!;
      // The server now reports another author for that draft.
      server.drafts[saved.draftId] = server.drafts[saved.draftId]!.withOwner(
        'someone-else',
      );
      final RentalPublicationController again = controller(current);
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
    'saving never rewrites the Create draft: its block keeps revision 0',
    () async {
      final CreateDraftEntity current = draft();
      final RentalPublicationController c = controller(current);
      await c.load();
      await c.save();
      await c.save();
      final Map<String, Object?> body = server.drafts.values.single.body;
      final Map<String, Object?> block =
          ((body['availability']! as Map<String, Object?>)['blocks']!
                      as List<Object?>)
                  .single!
              as Map<String, Object?>;
      expect(block['revision'], 1);
      expect(current.rentalData!.availability.blocks.single.revision, 0);
    },
  );

  test(
    'an unsupported draft sends nothing, not even the empty draft',
    () async {
      final CreateDraftEntity current = draft();
      final CreateDraftEntity groupPhotos = current.copyWith(
        rentalData: current.rentalData!.copyWith(
          inventoryGroups: <RentalInventoryGroup>[
            current.rentalData!.inventoryGroups.single.copyWith(
              photoRefs: <String>['C:/photos/group.png'],
            ),
          ],
        ),
      );
      final RentalPublicationController c = controller(groupPhotos);
      await c.load();
      await c.save();
      expect(c.state.message, 'unsupported_capability:rental.group_photos');
      expect(server.calls, isEmpty);
    },
  );
}

final class _Drafts implements RentalDraftSource {
  _Drafts(this.draft);

  final CreateDraftEntity draft;

  @override
  Future<CreateDraftEntity?> current() async => draft;
}

final class _Gate implements RentalPublicationCommandGate {
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
    _submissionStates[submissionId] = 'published';
    _pointerRevision = 1;
    _visibility = 'visible';
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
