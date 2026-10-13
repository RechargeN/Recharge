import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/collection_content_publication_controller.dart';
import 'package:recharge/features/create/data/file_collection_publication_journal.dart';
import 'package:recharge/features/create/domain/entities/collection_content_publication.dart';
import 'package:recharge/features/create/domain/entities/collection_item_draft.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/collection_content_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/place_publication_gateway.dart';
import 'package:recharge/features/create/domain/usecases/build_collection_content_body.dart';

import '../fixtures/create/user_collection_draft.dart';

/// D3.4 §5.4–§5.6: the Collection publication controller against an
/// in-memory Content server with idempotent keys and injected failures. One
/// server draft per account, publisher and local draft whatever fails in
/// between; the composition review always belongs to the revision the save
/// produces; a record of another account, publisher or server author is never
/// used; a draft that cannot map sends nothing.
void main() {
  late Directory temp;
  late _Server server;
  late _Uploader uploader;
  late _Media media;
  late _Gate gate;
  late _Membership membership;
  late FileCollectionPublicationJournal journal;

  const String cover = 'C:/photos/collection-cover.png';

  CreateDraftEntity draft({
    Set<String>? acknowledged = const <String>{},
    String title = 'Quiet corners of central Riga',
    VisibilityType visibility = VisibilityType.public,
  }) => userCollectionDraft(
    pageId: 'page-1',
    members: collectionCompatMembers(),
    coverPath: cover,
    acknowledged: acknowledged,
    title: title,
    visibility: visibility,
  );

  CollectionContentPublicationController controller(
    CreateDraftEntity current, {
    String account = 'account-a',
  }) => CollectionContentPublicationController(
    accountId: account,
    drafts: _Drafts(current),
    gateway: server,
    reader: server,
    uploader: uploader,
    mediaSource: media,
    journal: journal,
    membership: membership,
    gate: gate,
    clock: () => DateTime.utc(2026, 10, 12, 12),
  );

  CollectionPublicationScope scope(
    CreateDraftEntity current, {
    String account = 'account-a',
  }) => CollectionPublicationScope(
    accountId: account,
    publisherRef: current.collectionData!.publisherRef,
    localDraftId: current.id,
  );

  int reviewedRevisionOf(Map<String, Object?> body) =>
      (body['compositionReview']! as Map<String, Object?>)['draftRevision']!
          as int;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('collection-publication-');
    server = _Server();
    uploader = _Uploader();
    media = _Media(<String, Uint8List>{
      cover: Uint8List.fromList(<int>[1, 1, 1]),
    });
    gate = _Gate();
    membership = _Membership();
    journal = FileCollectionPublicationJournal(
      File('${temp.path}/collections.json'),
    );
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('a closed entry sends nothing and asks no membership', () async {
    gate.open = false;
    final CollectionContentPublicationController c = controller(draft());
    await c.load();
    await c.save();
    await c.uploadMedia();
    expect(c.state.message, 'not_allowed');
    expect(server.calls, isEmpty);
    expect(uploader.intents, isEmpty);
    expect(membership.asked, isEmpty);
  });

  test('a draft without a current review is refused before any call', () async {
    for (final CreateDraftEntity current in <CreateDraftEntity>[
      draft(acknowledged: null),
      draft(visibility: VisibilityType.private),
    ]) {
      final CollectionContentPublicationController c = controller(current);
      await c.load();
      await c.save();
      expect(c.state.message, startsWith('unsupported_capability:'));
    }
    expect(server.calls, isEmpty, reason: 'not even the empty draft');
  });

  test(
    'the first save creates an empty draft, then the body reviewed for the revision it produces',
    () async {
      final CreateDraftEntity current = draft();
      final CollectionContentPublicationController c = controller(current);
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
      expect(stored.revision, 2);
      expect(reviewedRevisionOf(stored.body), 2);
      final CollectionPublicationRecord record = c.state.record!;
      expect(record.bodySaved, isTrue);
      expect(record.serverOwnerUserId, 'server-user-a');
      expect(record.draftRevision, 2);
      // Every item's server status is shown, in the draft's order.
      expect(
        c.state.members.map(
          (CollectionMemberStatus item) => item.ref.stableKey,
        ),
        current.collectionData!.items.map(
          (CollectionItemDraft item) => item.ref.stableKey,
        ),
      );
    },
  );

  test('a lost createDraft answer is replayed into the same draft', () async {
    final CollectionContentPublicationController c = controller(draft());
    await c.load();
    server.loseAnswerOf.add('createDraft');
    await c.save();
    expect(c.state.phase, CollectionPublicationPhase.offline);
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
      final CollectionContentPublicationController c = controller(draft());
      await c.load();
      server.failBefore.add('updateDraft');
      await c.save();
      final CollectionPublicationRecord? recorded = await journal.forLocalDraft(
        accountId: 'account-a',
        publisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-1',
        ),
        localDraftId: 'local-collection-1',
      );
      expect(recorded?.bodySaved, isFalse, reason: 'created, body not saved');
      expect(c.state.canSubmit, isFalse);
      await c.save();
      expect(server.creates, hasLength(1));
      expect(c.state.record?.bodySaved, isTrue);
      expect(server.drafts, hasLength(1));
    },
  );

  test(
    'a revision the server moved past is read back and the review re-bound to the new revision',
    () async {
      final CreateDraftEntity current = draft();
      final CollectionContentPublicationController c = controller(current);
      await c.load();
      await c.save(); // revision 2
      server.loseAnswerOf.add('updateDraft');
      final CollectionContentPublicationController changed = controller(
        current.copyWith(title: 'Quiet corners, second walk'),
      );
      await changed.load();
      await changed.save(); // 2 -> 3, answer lost; the record still says 2
      expect(changed.state.record?.draftRevision, 2);
      final CollectionContentPublicationController again = controller(
        current.copyWith(title: 'Quiet corners, third walk'),
      );
      await again.load();
      await again.save(); // revision conflict at 2 -> read back 3 -> 4
      expect(again.state.message, isNull);
      final _Draft stored = server.drafts.values.single;
      expect(stored.revision, 4);
      expect(stored.body['title'], 'Quiet corners, third walk');
      expect(reviewedRevisionOf(stored.body), 4);
      expect(server.calls, contains('getDraft'));
    },
  );

  test('the cover is uploaded once per bytes and bound to the body', () async {
    final CreateDraftEntity current = draft();
    final CollectionContentPublicationController c = controller(current);
    await c.load();
    await c.save();
    await c.uploadMedia();
    await c.uploadMedia();
    expect(
      uploader.intents,
      hasLength(1),
      reason: 'the same bytes replay nothing',
    );
    expect(
      uploader.intents.single,
      scope(
        current,
      ).uploadIntentId(scope(current).coverAttachmentId, _sha(<int>[1, 1, 1])),
    );
    final Map<String, Object?> body = server.drafts.values.single.body;
    expect(
      (body['media']! as Map<String, Object?>)['coverImage'],
      <String, Object?>{'mediaId': 'asset-1'},
    );
    // New bytes for the same cover: one new upload and a new asset.
    media.files[cover] = Uint8List.fromList(<int>[9, 9, 9]);
    await c.uploadMedia();
    expect(uploader.intents, hasLength(2));
    expect(
      ((server.drafts.values.single.body['media']!
              as Map<String, Object?>)['coverImage']!
          as Map<String, Object?>)['mediaId'],
      'asset-2',
    );
  });

  test(
    'submit, staff approval, publish and hide follow the server status',
    () async {
      final CollectionContentPublicationController c = controller(draft());
      await c.load();
      await c.save();
      expect(c.state.canSubmit, isTrue);
      await c.submit();
      expect(c.state.status?.latestSubmissionState, 'under_review');
      expect(c.state.canPublish, isFalse);
      server.approve('submission-1');
      await c.refresh();
      expect(c.state.canPublish, isTrue);
      await c.publish();
      expect(c.state.status?.visibility, 'visible');
      await c.hide();
      expect(c.state.status?.visibility, 'withdrawn');
      expect(c.state.myObjects, hasLength(1));
    },
  );

  test(
    'another account or publisher never uses a record; a foreign author is ignored',
    () async {
      final CreateDraftEntity current = draft();
      final CollectionContentPublicationController a = controller(current);
      await a.load();
      await a.save();
      final CollectionContentPublicationController b = controller(
        current,
        account: 'account-b',
      );
      await b.load();
      expect(b.state.record, isNull);
      expect(b.state.myObjects, isEmpty);
      await b.save();
      expect(
        server.drafts,
        hasLength(2),
        reason: 'account B gets its own draft',
      );

      // The server reports another author for A's draft: the record is not used.
      final String draftIdA = (await journal.list('account-a')).single.draftId;
      server.drafts[draftIdA] = server.drafts[draftIdA]!.withOwner('intruder');
      final CollectionContentPublicationController fresh = controller(current);
      await fresh.load();
      expect(fresh.state.record, isNull);
    },
  );

  test('member statuses are the server answer, shown not decided', () async {
    membership.statuses['place:${collectionCompatMemberIds[1]}'] = 'withheld';
    membership.statuses['place:${collectionCompatMemberIds[2]}'] = 'unknown';
    final CollectionContentPublicationController c = controller(draft());
    await c.load();
    expect(
      c.state.members.map((CollectionMemberStatus item) => item.status),
      <String>['eligible', 'withheld', 'unknown'],
    );
    // Shown only: the save still goes to the server, which decides at submit.
    await c.save();
    expect(c.state.message, isNull);
  });
}

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

final class _Drafts implements CollectionDraftSource {
  _Drafts(this.value);

  final CreateDraftEntity? value;

  @override
  Future<CreateDraftEntity?> current() async => value;
}

final class _Gate implements CollectionPublicationCommandGate {
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

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    if (_assets.containsKey(intentId)) return _assets[intentId]!;
    intents.add(intentId);
    return _assets[intentId] = 'asset-${_assets.length + 1}';
  }
}

final class _Membership implements CollectionMembershipReader {
  final Map<String, String> statuses = <String, String>{};
  final List<String> asked = <String>[];

  @override
  Future<CollectionMemberStatus> statusOf(CollectionObjectRef ref) async {
    asked.add(ref.stableKey);
    return CollectionMemberStatus(
      ref: ref,
      status: statuses[ref.stableKey] ?? 'eligible',
    );
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
        final String author = drafts.isEmpty
            ? 'server-user-a'
            : 'server-user-$_counter';
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
