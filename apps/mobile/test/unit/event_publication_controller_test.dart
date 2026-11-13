import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/event_publication_controller.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';

import '../fixtures/create/user_event_draft.dart';

void main() {
  late _Gate gate;
  late _Gateway gateway;
  late _Uploader uploader;
  late _Journal journal;
  late _Covers covers;
  late CreateDraftEntity draft;

  EventPublicationController controller() => EventPublicationController(
    drafts: _Drafts(() => draft),
    gateway: gateway,
    covers: uploader,
    coverSource: covers,
    journal: journal,
    gate: gate,
  );

  setUp(() {
    gate = _Gate();
    gateway = _Gateway();
    uploader = _Uploader();
    journal = _Journal();
    covers = _Covers(Uint8List.fromList(<int>[1, 2, 3]));
    draft = userEventDraft(
      pageId: 'page-1',
      coverPath: 'cover.png',
      localId: 'loc_42',
    );
  });

  test('a closed gate sends nothing at all', () async {
    gate.open = false;
    final c = controller();
    await c.load();
    await c.save();
    await c.uploadCover();
    await c.submit();
    expect(gateway.calls, isEmpty);
    expect(uploader.calls, 0);
    expect(c.state.message, 'not_allowed');
  });

  test('save creates once, then updates with the stored revision', () async {
    final c = controller();
    await c.load();
    expect(c.state.draftTitle, draft.title);
    await c.save();
    await c.save();
    expect(gateway.calls.map((call) => call.$1), <String>[
      'createDraft',
      'status',
      'status',
      'updateDraft',
      'status',
      'status',
    ]);
    final create = gateway.calls.first.$2;
    final update = gateway.calls[3].$2;
    expect(
      create['publisherRef'],
      const PublisherRef(type: PublisherType.page, id: 'page-1'),
    );
    expect(update['expectedRevision'], 1);
    expect(c.state.record?.draftRevision, 2);
    // The same intent always uses the same key.
    expect(create['key'], startsWith('evp-'));
    expect(create['key'], endsWith(':create'));
  });

  test(
    'the cover is uploaded once for the same bytes and bound by id',
    () async {
      final c = controller();
      await c.load();
      await c.save();
      await c.uploadCover();
      await c.uploadCover();
      expect(uploader.calls, 1);
      final updates = gateway.calls.where((call) => call.$1 == 'updateDraft');
      final cover = (updates.last.$2['body']! as Map)['media']! as Map;
      expect((cover['coverImage']! as Map)['mediaId'], 'asset-1');
      expect(uploader.lastContentId, 'content-1');
    },
  );

  test(
    'publish is offered only after the server reports an approval',
    () async {
      final c = controller();
      await c.load();
      await c.save();
      await c.submit();
      expect(c.state.status?.latestSubmissionState, 'under_review');
      expect(c.state.canPublish, isFalse);
      gateway.submissionState = 'approved_for_publication';
      await c.refresh();
      expect(c.state.canPublish, isTrue);
      await c.publish();
      final publish = gateway.calls.firstWhere(
        (call) => call.$1 == 'publishApproved',
      );
      expect(publish.$2['submissionId'], 'submission-1');
      expect(publish.$2['expectedPointerRevision'], 0);
      expect(c.state.status?.visibility, 'visible');
      await c.hide();
      expect(c.state.status?.visibility, 'withdrawn');
      expect(c.state.myObjects.single.status?.visibility, 'withdrawn');
    },
  );

  test('a draft with capabilities outside the subset is never sent', () async {
    draft = draft.copyWith(
      eventData: draft.eventData!.copyWith(
        admission: const EventAdmissionDraft(
          admissionMode: null,
          registrationMode: null,
          confirmationMode: null,
        ),
      ),
    );
    final c = controller();
    await c.load();
    await c.save();
    expect(gateway.calls.where((call) => call.$1 == 'createDraft'), isEmpty);
    expect(c.state.message, 'unsupported_capability:admission');
  });

  test(
    'M1 D1: a lost publish answer is retried with the journaled payload',
    () async {
      final c = controller();
      await c.load();
      await c.save();
      await c.submit();
      gateway.submissionState = 'approved_for_publication';
      await c.refresh();
      gateway.losePublishAnswer = true;
      await c.publish();
      expect(c.state.phase, EventPublicationPhase.offline);
      expect(gateway.publications, 1, reason: 'the server applied it');
      // A restart: a new controller over the same journal retries the same payload.
      final again = controller();
      await again.load();
      await again.publish();
      expect(again.state.message, isNull, reason: again.state.message);
      expect(gateway.publications, 1, reason: 'exactly one publication');
      expect(
        gateway.calls
            .where((call) => call.$1 == 'publishApproved')
            .map((call) => call.$2['expectedPointerRevision']),
        <Object?>[0, 0],
        reason: 'the retry sends the first payload, not the moved pointer',
      );
    },
  );

  test('a server refusal is shown as its code', () async {
    gateway.refuseCreate = 'creator_verification_required';
    final c = controller();
    await c.load();
    await c.save();
    expect(c.state.message, 'creator_verification_required');
    expect(c.state.record, isNull);
    expect(await journal.list(), isEmpty);
  });
}

final class _Gate implements EventPublicationCommandGate {
  bool open = true;

  @override
  bool get allowed => open;

  @override
  void assertAllowed() {
    if (!open) throw StateError('closed');
  }
}

final class _Drafts implements EventDraftSource {
  _Drafts(this._read);

  final CreateDraftEntity Function() _read;

  @override
  Future<CreateDraftEntity?> current() async => _read();
}

final class _Covers implements EventCoverSource {
  _Covers(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List?> read(String reference) async => bytes;
}

final class _Uploader implements EventCoverUploader {
  int calls = 0;
  String? lastContentId;

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    calls += 1;
    lastContentId = contentId;
    expect(declaredMediaType, 'image/png');
    return 'asset-$calls';
  }
}

final class _Journal implements EventPublicationJournal {
  final List<EventPublicationRecord> records = <EventPublicationRecord>[];

  @override
  Future<EventPublicationRecord?> forLocalDraft(String localDraftId) async {
    for (final record in records) {
      if (record.localDraftId == localDraftId) return record;
    }
    return null;
  }

  @override
  Future<List<EventPublicationRecord>> list() async => List.of(records);

  @override
  Future<void> save(EventPublicationRecord record) async {
    records
      ..removeWhere((item) => item.localDraftId == record.localDraftId)
      ..insert(0, record);
  }
}

final class _Gateway implements EventPublicationGateway {
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  int revision = 0;
  String? submissionState;
  String? visibility;
  int pointerRevision = 0;
  String? refuseCreate;
  final Map<String, String> publishReplies = <String, String>{};
  int publications = 0;
  bool losePublishAnswer = false;

  @override
  Future<EventServerDraftRef> createDraft({
    required PublisherRef publisherRef,
    required String marketId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async {
    calls.add((
      'createDraft',
      <String, Object?>{
        'publisherRef': publisherRef,
        'body': body,
        'key': idempotencyKey,
      },
    ));
    if (refuseCreate != null) throw EventPublicationRejected(refuseCreate!);
    revision = 1;
    return const EventServerDraftRef(
      contentId: 'content-1',
      draftId: 'draft-1',
      revision: 1,
    );
  }

  @override
  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async {
    calls.add((
      'updateDraft',
      <String, Object?>{
        'expectedRevision': expectedRevision,
        'body': body,
        'key': idempotencyKey,
      },
    ));
    revision = expectedRevision + 1;
    return EventServerDraftRef(
      contentId: 'content-1',
      draftId: draftId,
      revision: revision,
    );
  }

  @override
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  }) async {
    calls.add(('submit', <String, Object?>{'revision': expectedDraftRevision}));
    submissionState = 'under_review';
    return 'submission-1';
  }

  @override
  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add((
      'publishApproved',
      <String, Object?>{
        'submissionId': submissionId,
        'expectedPointerRevision': expectedPointerRevision,
      },
    ));
    // Like Content: a key replays its stored answer only for the same payload.
    final String fingerprint = '$submissionId:$expectedPointerRevision';
    final String? stored = publishReplies[idempotencyKey];
    if (stored != null) {
      if (stored != fingerprint) {
        throw const EventPublicationRejected('idempotency_conflict');
      }
    } else {
      publishReplies[idempotencyKey] = fingerprint;
      publications += 1;
      submissionState = 'published';
      visibility = 'visible';
      pointerRevision = 1;
    }
    if (losePublishAnswer) {
      losePublishAnswer = false;
      throw const EventPublicationUnavailable('transport');
    }
  }

  @override
  Future<void> withdraw({
    required String contentId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add((
      'withdraw',
      <String, Object?>{'expectedPointerRevision': expectedPointerRevision},
    ));
    visibility = 'withdrawn';
    pointerRevision += 1;
  }

  @override
  Future<EventPublicationStatus> status(String contentId) async {
    calls.add(('status', <String, Object?>{'contentId': contentId}));
    return EventPublicationStatus(
      contentId: contentId,
      latestSubmissionId: submissionState == null ? null : 'submission-1',
      latestSubmissionState: submissionState,
      pointerRevision: visibility == null ? null : pointerRevision,
      visibility: visibility,
      currentPublishedRevisionId: visibility == null ? null : 'revision-1',
    );
  }
}
